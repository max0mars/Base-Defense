-- Base Defense leaderboard tables (Cloudflare D1 / SQLite).
-- Apply with: npx wrangler d1 execute base-defense-leaderboard --remote --file=schema.sql

-- Every run the game registered when it started; started_at is the server's clock (ms)
CREATE TABLE IF NOT EXISTS runs (
  run_id     TEXT PRIMARY KEY,
  player_id  TEXT NOT NULL,
  started_at INTEGER NOT NULL,
  submitted  INTEGER NOT NULL DEFAULT 0
);

-- Finished runs. deck: JSON [{id, tier, quantity}], artifacts: JSON [id]
CREATE TABLE IF NOT EXISTS scores (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  run_id       TEXT NOT NULL UNIQUE,
  player_id    TEXT NOT NULL,
  name         TEXT NOT NULL,
  level        INTEGER NOT NULL,
  main_turret  TEXT NOT NULL,
  damage_dealt INTEGER NOT NULL,
  kills        INTEGER NOT NULL,
  duration_s   INTEGER NOT NULL,
  deck         TEXT NOT NULL,
  artifacts    TEXT NOT NULL,
  created_at   INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS scores_by_rank ON scores (level DESC, damage_dealt DESC, created_at ASC);
