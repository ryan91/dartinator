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

CREATE OR REPLACE FUNCTION starting_player()
RETURNS INT LANGUAGE plpgsql AS $$
  DECLARE
    running_game_id INT;
    starting_player_id INT;
  BEGIN
    SELECT get_running_game() INTO running_game_id;
    SELECT playerid INTO starting_player_id FROM players WHERE starting = 1
      AND gameid = running_game_id;
    return starting_player_id;
END; $$;

CREATE OR REPLACE FUNCTION starting_player_name()
RETURNS VARCHAR(64) LANGUAGE plpgsql AS $$
  DECLARE
    starting_player_id INT;
    starting_player_name VARCHAR(64);
  BEGIN
    SELECT next_player() INTO starting_player_id;
    SELECT name INTO starting_player_name FROM users
      WHERE id = starting_player_id;
    RETURN starting_player_name;
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
    SELECT id INTO game_id FROM games WHERE day = (SELECT MAX(day) FROM games);
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

CREATE OR REPLACE function game_has_winner()
RETURNS BOOLEAN LANGUAGE plpgsql AS $$
  DECLARE
    running_game_id INT;
    max_sets INT;
    game_sets INT;
  BEGIN
    SELECT get_running_game() INTO running_game_id;
    SELECT MAX(sets) INTO max_sets FROM players WHERE gameid = running_game_id;
    SELECT sets INTO game_sets FROM games WHERE id = running_game_id;
    RETURN max_sets = game_sets;
  END
$$;

CREATE OR REPLACE function get_winner()
RETURNS VARCHAR(64) LANGUAGE plpgsql AS $$
  DECLARE
    running_game_id INT;
    winner_id INT;
    winner_name VARCHAR(64);
  BEGIN
    SELECT get_running_game() INTO running_game_id;
    SELECT playerid INTO winner_id FROM players
      WHERE gameid = running_game_id AND sets = (
        SELECT MAX(sets) FROM players WHERE gameid = running_game_id
      );
    SELECT name INTO winner_name FROM users WHERE id = winner_id;
    RETURN winner_name;
  END
$$;

-- 0: game shot and leg
-- 1: game shot and set
-- 2: game shot and match
CREATE OR REPLACE FUNCTION
increment_legs_and_sets(running_game_id INT, player_id INT)
RETURNS INT LANGUAGE plpgsql AS $$
  DECLARE
    player_legs INT;
    player_sets INT;
    game_legs INT;
    game_sets INT;
  BEGIN
    SELECT sets, legs INTO player_sets, player_legs FROM players
      WHERE playerid = player_id AND running_game_id = gameid;
    SELECT sets, legs INTO game_sets, game_legs FROM games
      WHERE id = running_game_id;

    player_legs := player_legs + 1;

    IF player_legs = game_legs THEN
      player_sets := player_sets + 1;
      player_legs := 0;
    END IF;

    UPDATE players SET sets = player_sets, legs = player_legs
      WHERE gameid = running_game_id AND playerid = player_id;

    IF player_sets = game_sets THEN
      RETURN 2;
    END IF;

    IF player_legs = 0 THEN
      RETURN 1;
    END IF;

    RETURN 0;
  END;
$$;

-- 0: normal throw
-- 1: game shot and leg
-- 2: game shot and set
-- 3: game shot and match
-- 4: no score
CREATE OR REPLACE FUNCTION register_throw(darts_json json)
RETURNS INT LANGUAGE plpgsql AS $$
  DECLARE
    player_score INT;
    next_player_id INT;
    running_game_id INT;
    dart_score INT;
    dart_score_sum INT;
    nr_players INT;
    out_mode InOutMode;
    mult INT;
    radius INT;
    value INT;
    radius_before INT;
    value_before INT;
    dart_data json;
    game_score INT;
    ret INT;
  BEGIN
    ret := 0;
    dart_score_sum := 0;
    radius_before := -1;
    value_before := -1;
    SELECT next_player() INTO next_player_id;
    SELECT get_running_game() INTO running_game_id;
    SELECT count(*) INTO nr_players FROM players where gameid = running_game_id;
    SELECT score INTO player_score FROM players
      WHERE gameid = running_game_id AND playerid = next_player_id;
    SELECT outmode, score INTO out_mode, game_score
      FROM n01options WHERE gameid = running_game_id;
    FOR dart_data IN SELECT * FROM json_array_elements(darts_json) LOOP
      SELECT dart_data->'radius' INTO radius;
      SELECT dart_data->'value' INTO value;
      SELECT get_multiplier(radius) INTO mult;
      dart_score := mult * value;
      dart_score_sum := dart_score_sum + dart_score;
      player_score := player_score - dart_score;
      IF player_score < 0 THEN
        ret := 4;
        EXIT;
      ELSIF player_score = 0 THEN
        IF out_mode = 'single' THEN
          ret := 1;
        ELSIF out_mode = 'double' THEN
          IF mult = 2 THEN
            ret := 1;
          ELSE
            ret := 4;
          END IF;
        ELSIF out_mode = 'masters' THEN
          IF mult = 2 OR mult = 3 THEN
            ret := 1;
          ELSE
            ret := 4;
          END IF;
        ELSIF out_mode = '2single' THEN
          IF mult = 2 OR (radius = radius_before AND value = value_before) THEN
            ret := 1;
          ELSE
            ret := 4;
          END IF;
        END IF;
        EXIT;
      END IF;
      radius_before := radius;
      value_before := value;
    END LOOP;
    IF ret = 1 THEN
      SELECT increment_legs_and_sets(running_game_id, next_player_id) INTO ret;
      UPDATE players SET score = game_score,
        starting = round_robin_inc(starting, nr_players)
        WHERE gameid = running_game_id;
      UPDATE players SET next = starting WHERE gameid = running_game_id;
      ret := ret + 1;
      RETURN ret;
    ELSIF ret != 4 THEN
      UPDATE players SET score = player_score
        WHERE gameid = running_game_id AND playerid = next_player_id;
    END IF;
    UPDATE players SET next = round_robin_inc(next, nr_players)
      WHERE gameid = running_game_id;
    IF dart_score_sum = 0 THEN
      ret := 4;
    END IF;
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
