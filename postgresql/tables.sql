CREATE TABLE IF NOT EXISTS Users (
  id SERIAL NOT NULL,
  name VARCHAR(64) NOT NULL,
  img BYTEA,
  UNIQUE(name)
);

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'inoutmode') THEN
    CREATE TYPE InOutMode AS ENUM ('double', 'masters', 'single', '2single');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'gamemode') THEN
    CREATE TYPE GameMode AS ENUM ('101', '201', '301', '401', '501');
  END IF;
END
$$;

-- https://www.programmingoneonone.com/2020/05/binary-tree-array-representation.html
CREATE TABLE IF NOT EXISTS Tournaments (
  treeid INT NOT NULL,
  playerid INT
);

-- n01: [ sets, legs, {sin, din, min}, {sout, dout, mout} ]
CREATE TABLE IF NOT EXISTS Games (
  id SERIAL PRIMARY KEY,
  day TIMESTAMP NOT NULL DEFAULT now(),
  sets INT NOT NULL DEFAULT 1,
  legs INT NOT NULL DEFAULT 1
);

CREATE TABLE IF NOT EXISTS N01Options (
  gameid INT PRIMARY KEY NOT NULL,
  inmode InOutMode NOT NULL,
  outmode InOutMode NOT NULL,
  score INT NOT NULL,
  FOREIGN KEY (gameid) REFERENCES Games(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS Players (
  playerid INT NOT NULL,
  gameid   INT NOT NULL,
  next     INT NOT NULL,
  starting INT NOT NULL,
  score    INT
);
