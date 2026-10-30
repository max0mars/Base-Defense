# Base Defense leaderboard server

A Cloudflare Worker with a D1 (SQLite) database. The game talks to it from
`Game/Online/Leaderboard.lua`. Cloudflare's free plan covers it easily.

## Deploying

You need [Node.js](https://nodejs.org) (for `npx`) and a free Cloudflare account.
Run these from this folder (`Server/leaderboard`):

```sh
npx wrangler login
npx wrangler d1 create base-defense-leaderboard
```

Copy the `database_id` it prints into `wrangler.toml`, then:

```sh
npx wrangler d1 execute base-defense-leaderboard --remote --file=schema.sql
npx wrangler deploy
```

`deploy` prints the Worker's URL, like
`https://base-defense-leaderboard.<your-account>.workers.dev`. Put it in
`Leaderboard.URL` at the top of `Game/Online/Leaderboard.lua`. The leaderboard
stays switched off in the game while that's empty.

## Checking it works

```sh
curl https://base-defense-leaderboard.<your-account>.workers.dev/scores
```

should print `{"scores":[]}`.

## Tuning the timing check

A result is turned down if the run reached its level faster than
`MIN_SECONDS_PER_LEVEL` (in `wrangler.toml`) per completed level. Change it and
run `npx wrangler deploy` again.

A run's length is the longer of two measures: the server's, from when it first
heard about the run, and the game's own, from when the run started by the
player's clock (it's saved with the run, so it includes time the game was
closed). Going offline during a run never shortens it, so it can't get an
honest run turned down. The game's measure could be faked, which is the
trade-off for never losing a real score.

## Removing an entry

```sh
npx wrangler d1 execute base-defense-leaderboard --remote --command "SELECT id, name, level FROM scores ORDER BY id DESC LIMIT 20"
npx wrangler d1 execute base-defense-leaderboard --remote --command "DELETE FROM scores WHERE id = 123"
```
