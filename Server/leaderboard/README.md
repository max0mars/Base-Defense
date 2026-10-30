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
`MIN_SECONDS_PER_LEVEL` (in `wrangler.toml`) per completed level, timed from when
the run started. Change it and run `npx wrangler deploy` again.

The clock starts when the server first hears about the run. If the game was
offline when the run started, it registers the run once it's back online, and
a long run timed from then may be turned down.

## Removing an entry

```sh
npx wrangler d1 execute base-defense-leaderboard --remote --command "SELECT id, name, level FROM scores ORDER BY id DESC LIMIT 20"
npx wrangler d1 execute base-defense-leaderboard --remote --command "DELETE FROM scores WHERE id = 123"
```
