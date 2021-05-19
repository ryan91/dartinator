CREATE OR REPLACE FUNCTION add_player(player_name VARCHAR(64))
RETURNS INT LANGUAGE plpgsql AS $$
  DECLARE
    v_row_count INT;
  BEGIN
    INSERT INTO Users (name) VALUES (player_name) ON CONFLICT DO NOTHING;
    GET DIAGNOSTICS v_row_count = ROW_COUNT;
    RETURN v_row_count;
END; $$;

CREATE OR REPLACE FUNCTION get_multiplier(field_id INT)
RETURNS INT LANGUAGE plpgsql AS $$
  BEGIN
    IF field_id = 0 THEN RETURN 0; END IF;
    IF 1 <= field_id AND field_id <= 20 THEN RETURN 2; END IF;
    IF 41 <= field_id AND field_id <= 60 THEN RETURN 3; END IF;
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
      INSERT INTO Players (playerid, gameid, next, starting, score) VALUES
        (userid, gameid, next, next, score);
      next := next + 1;
    END LOOP;
END; $$;

CREATE OR REPLACE FUNCTION register_throw(field_ids INT[])
RETURNS VOID LANGUAGE plpgsql AS $$
  DECLARE
    player_score INT;
    next_player_id INT;
    running_game_id INT;
    dart_score INT;
    nr_players INT;
    fid INT;
  BEGIN
    SELECT next_player() INTO next_player_id;
    SELECT get_running_game() INTO running_game_id;
    SELECT count(*) INTO nr_players FROM players where gameid = running_game_id;
    SELECT score INTO player_score FROM players
      WHERE gameid = running_game_id AND playerid = next_player_id;
    FOREACH fid IN ARRAY field_ids LOOP
      SELECT get_board_value(fid) INTO dart_score;
      player_score := player_score - dart_score;
    END LOOP;
    UPDATE players SET score = player_score
      WHERE gameid = running_game_id AND playerid = next_player_id;
    UPDATE players SET next = round_robin_inc(next, nr_players) WHERE gameid = running_game_id;
END; $$;
