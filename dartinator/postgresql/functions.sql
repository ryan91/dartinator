CREATE OR REPLACE FUNCTION add_player(player_name VARCHAR(64))
RETURNS INT LANGUAGE plpgsql AS $$
  DECLARE
    v_row_count INT;
  BEGIN
    INSERT INTO Users (name) VALUES (player_name) ON CONFLICT DO NOTHING;
    GET DIAGNOSTICS v_row_count = ROW_COUNT;
    RETURN v_row_count;
END; $$;

CREATE OR REPLACE FUNCTION get_multiplier(radius INT)
RETURNS INT LANGUAGE plpgsql AS $$
  BEGIN
    IF radius = 0 OR radius = 5 THEN RETURN 2; END IF;
    IF radius = 3 THEN RETURN 3; END IF;
    IF radius = 6 THEN RETURN 0; END IF;
    RETURN 1;
END; $$;

CREATE OR REPLACE FUNCTION get_board_base_value(field_id INT)
RETURNS INT LANGUAGE plpgsql AS $$
  BEGIN
    FOR ref IN 1..61 BY 20 LOOP
      IF field_id = ref THEN RETURN 20; END IF;
    END LOOP;
    FOR ref IN 2..62 BY 20 LOOP
      IF field_id = ref THEN RETURN 1; END IF;
    END LOOP;
    FOR ref IN 3..63 BY 20 LOOP
      IF field_id = ref THEN RETURN 18; END IF;
    END LOOP;
    FOR ref IN 4..64 BY 20 LOOP
      IF field_id = ref THEN RETURN 4; END IF;
    END LOOP;
    FOR ref IN 5..65 BY 20 LOOP
      IF field_id = ref THEN RETURN 13; END IF;
    END LOOP;
    FOR ref IN 6..66 BY 20 LOOP
      IF field_id = ref THEN RETURN 6; END IF;
    END LOOP;
    FOR ref IN 7..67 BY 20 LOOP
      IF field_id = ref THEN RETURN 10; END IF;
    END LOOP;
    FOR ref IN 8..68 BY 20 LOOP
      IF field_id = ref THEN RETURN 15; END IF;
    END LOOP;
    -- TODO remaining cases
    RETURN 0;
END; $$;

CREATE OR REPLACE FUNCTION get_board_value(field_id INT)
RETURNS INT LANGUAGE plpgsql AS $$
  DECLARE
    base INT;
    mult INT;
  BEGIN
    SELECT get_multiplier(field_id) INTO mult;
    SELECT get_board_base_value(field_id) INTO base;
    RETURN mult * base;
END; $$;

CREATE OR REPLACE FUNCTION next_player()
RETURNS INT LANGUAGE plpgsql AS $$
  DECLARE
    running_game_id INT;
    next_player_id INT;
  BEGIN
    SELECT get_running_game() INTO running_game_id;
    SELECT playerid INTO next_player_id FROM players WHERE next = 1 AND
      gameid = running_game_id;
    return next_player_id;
END; $$;

CREATE OR REPLACE FUNCTION next_player_name()
RETURNS VARCHAR(64) LANGUAGE plpgsql AS $$
  DECLARE
    next_player_id INT;
    next_player_name VARCHAR(64);
  BEGIN
    SELECT next_player() INTO next_player_id;
    SELECT name INTO next_player_name FROM users WHERE id = next_player_id;
    RETURN next_player_name;
END; $$;

CREATE OR REPLACE FUNCTION get_initial_score(game_mode GameMode)
RETURNS INT LANGUAGE plpgsql AS $$
  BEGIN
    IF game_mode = '101' THEN RETURN 101; END IF;
    IF game_mode = '201' THEN RETURN 201; END IF;
    IF game_mode = '301' THEN RETURN 301; END IF;
    IF game_mode = '401' THEN RETURN 401; END IF;
    IF game_mode = '501' THEN RETURN 501; END IF;
END; $$;

CREATE OR REPLACE FUNCTION round_robin_inc(x INT, n INT)
RETURNS INT LANGUAGE plpgsql AS $$
  BEGIN
    IF x = n THEN RETURN 1; END IF;
    RETURN x + 1;
END; $$;

CREATE OR REPLACE FUNCTION get_running_game()
RETURNS INT LANGUAGE plpgsql AS $$
  DECLARE
    game_id INT;
  BEGIN
    SELECT id INTO game_id FROM games WHERE day = (select max(day) FROM games);
    RETURN game_id;
END; $$;

CREATE OR REPLACE FUNCTION new_game(
  players VARCHAR(32)[],
  game_mode GameMode,
  in_mode InOutMode,
  out_mode InOutMode,
  sets INT,
  legs INT)
RETURNS VOID LANGUAGE plpgsql AS $$
  DECLARE
    gameid INT;
    userid INT;
    score INT;
    player VARCHAR(32);
    next INT;
  BEGIN
    INSERT INTO Games (sets, legs) VALUES (sets, legs);
    SELECT lastval() into gameid;
    SELECT get_initial_score(game_mode) INTO score;
    INSERT INTO N01Options (gameid, inmode, outmode, score) VALUES
      (gameid, in_mode, out_mode, score);
    next := 1;
    FOREACH player IN ARRAY players LOOP
      SELECT id INTO userid FROM Users where name = player;
      IF NOT FOUND THEN
        RAISE EXCEPTION 'Player % not found', player;
      END IF;
      INSERT INTO Players (playerid, gameid, next, starting, sets, legs, score)
      VALUES (userid, gameid, next, next, 0, 0, score);
      next := next + 1;
    END LOOP;
END; $$;

CREATE OR REPLACE FUNCTION register_throw(darts_json json)
RETURNS INT LANGUAGE plpgsql AS $$
  DECLARE
    player_score INT;
    next_player_id INT;
    running_game_id INT;
    dart_score INT;
    nr_players INT;
    out_mode InOutMode;
    mult INT;
    radius INT;
    value INT;
    radius_before INT;
    value_before INT;
    dart_data json;
    ret INT;
  BEGIN
    ret := 0;
    radius_before := -1;
    value_before := -1;
    SELECT next_player() INTO next_player_id;
    SELECT get_running_game() INTO running_game_id;
    SELECT count(*) INTO nr_players FROM players where gameid = running_game_id;
    SELECT score INTO player_score FROM players
      WHERE gameid = running_game_id AND playerid = next_player_id;
    SELECT outmode FROM n01options INTO out_mode WHERE gameid = running_game_id;
    FOR dart_data IN SELECT * FROM json_array_elements(darts_json) LOOP
      SELECT dart_data->'radius' INTO radius;
      SELECT dart_data->'value' INTO value;
      SELECT get_multiplier(radius) INTO mult;
      dart_score:= mult * value;
      player_score := player_score - dart_score;
      IF player_score < 0 THEN
        RETURN 3;
      END IF;
      IF player_score = 0 THEN
        IF out_mode = 'single' THEN
          ret := 1;
        ELSIF out_mode = 'double' THEN
          IF mult = 2 THEN ret := 1; END IF;
          ret := 2;
        ELSIF out_mode = 'masters' THEN
          IF mult = 2 OR mult = 3 THEN ret := 1; END IF;
          ret := 2;
        ELSIF out_mode = '2single' THEN
          IF mult = 2 OR (radius = radius_before AND value = value_before) THEN
            ret := 1;
          END IF;
          ret := 2;
        END IF;
        EXIT;
      END IF;
      radius_before := radius;
      value_before := value;
    END LOOP;
    UPDATE players SET score = player_score
      WHERE gameid = running_game_id AND playerid = next_player_id;
    UPDATE players SET next = round_robin_inc(next, nr_players) WHERE gameid = running_game_id;
    RETURN ret;
END; $$;

CREATE OR REPLACE VIEW get_game_info AS (
  SELECT *
  FROM (
    SELECT p.gameid, array_agg(p.next) AS next,
      array_agg(p.starting) AS starting, array_agg(p.score) AS playerscore,
      array_agg(p.sets) AS playersets, array_agg(p.legs) AS playerlegs,
      array_agg(p.name) as name
    FROM (
      SELECT p.gameid, p.next, p.starting, p.score, p.sets, p.legs, u.name
      FROM players p JOIN users u ON p.playerid = u.id
    ) p
    GROUP BY p.gameid
  ) p JOIN (
    SELECT g.*, n.inmode, n.outmode, n.score
    FROM
      ( SELECT g.*
        FROM games g
        WHERE g.id = get_running_game()
      ) g
    JOIN n01options n ON g.id = n.gameid
  ) g ON p.gameid = g.id
);

CREATE OR REPLACE VIEW get_game_info_as_json AS (
  SELECT row_to_json(t) AS gameinfo FROM (
    SELECT * FROM get_game_info
  ) t
);
