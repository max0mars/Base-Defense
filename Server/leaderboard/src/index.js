// Base Defense leaderboard - a Cloudflare Worker backed by a D1 database.
//
//   POST /runs    { runId, playerId }                 a run started (timed from now)
//   POST /scores  { runId, playerId, name, level, mainTurret, runSeconds,
//                   damageDealt, kills, deck, artifacts }   a run ended
//   GET  /scores?limit=50                             the top runs
//   GET  /scores/around?runId=...                     a run's rank, and the 5 runs
//                                                     around it (itself included)
//
// The only cheating check is timing: a run's result is turned down if it
// reached its level faster than MIN_SECONDS_PER_LEVEL per completed level.
// The run's length is the longer of the server's own measure (from when it
// first heard about the run) and runSeconds, the game's measure. A game that
// was offline when the run started registers it late, which makes the
// server's measure too short, but the game's measure covers the whole run.
// Losing a real score is worse than letting a cheat through, so a result is
// accepted even if its run was never registered.

const ID = /^[0-9a-f]{32}$/;
const TOKEN = /^[A-Za-z0-9_\-]{1,64}$/;
const NAME_MAX = 16;
const DECK_MAX = 1000;
const ARTIFACTS_MAX = 500;
const AROUND_COUNT = 5;

// Every score with its rank; the one place the leaderboard's order is defined
const RANKED = `SELECT *, ROW_NUMBER() OVER (ORDER BY level DESC, damage_dealt DESC, created_at ASC, id ASC) AS rank
                  FROM scores`;

class BadRequest extends Error {}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    try {
      if (url.pathname === "/runs" && request.method === "POST") return await startRun(request, env);
      if (url.pathname === "/scores" && request.method === "POST") return await submitScore(request, env);
      if (url.pathname === "/scores" && request.method === "GET") return await topScores(url, env);
      if (url.pathname === "/scores/around" && request.method === "GET") return await scoresAround(url, env);
      return reply(404, { error: "not_found", message: "No such endpoint." });
    } catch (e) {
      if (e instanceof BadRequest) return reply(400, { error: "bad_request", message: e.message });
      console.error(e);
      return reply(500, { error: "server_error", message: "Something went wrong on the server." });
    }
  },
};

function reply(status, data) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

// --- Validation --------------------------------------------------------------

async function readJson(request) {
  try {
    const data = await request.json();
    if (data && typeof data === "object" && !Array.isArray(data)) return data;
  } catch {}
  throw new BadRequest("The body must be a JSON object.");
}

function id(value, field) {
  if (typeof value !== "string" || !ID.test(value)) throw new BadRequest(`${field} must be 32 hex digits.`);
  return value;
}

function token(value, field) {
  if (typeof value !== "string" || !TOKEN.test(value)) throw new BadRequest(`${field} is invalid.`);
  return value;
}

function int(value, field, min, max) {
  if (!Number.isInteger(value) || value < min || value > max) {
    throw new BadRequest(`${field} must be a whole number from ${min} to ${max}.`);
  }
  return value;
}

// Same rule as the game's Leaderboard.cleanName: printable ASCII, trimmed
function name(value) {
  const cleaned = typeof value === "string" ? value.replace(/[^\x20-\x7e]/g, "").trim().slice(0, NAME_MAX) : "";
  if (!cleaned) throw new BadRequest("A name is required.");
  return cleaned;
}

function deck(value) {
  if (!Array.isArray(value) || value.length > DECK_MAX) throw new BadRequest(`deck must be a list of up to ${DECK_MAX} cards.`);
  return value.map((card, i) => {
    if (!card || typeof card !== "object") throw new BadRequest(`deck[${i}] must be an object.`);
    return {
      id: token(card.id, `deck[${i}].id`),
      tier: int(card.tier, `deck[${i}].tier`, 1, 10),
      quantity: int(card.quantity, `deck[${i}].quantity`, 1, 9999),
    };
  });
}

function artifacts(value) {
  if (!Array.isArray(value) || value.length > ARTIFACTS_MAX) {
    throw new BadRequest(`artifacts must be a list of up to ${ARTIFACTS_MAX} ids.`);
  }
  return value.map((a, i) => token(a, `artifacts[${i}]`));
}

function formatDuration(seconds) {
  const m = Math.floor(seconds / 60);
  const s = Math.floor(seconds % 60);
  return `${m}m ${String(s).padStart(2, "0")}s`;
}

// --- Endpoints ---------------------------------------------------------------

async function startRun(request, env) {
  const body = await readJson(request);
  const runId = id(body.runId, "runId");
  const playerId = id(body.playerId, "playerId");
  // A repeat (the game retrying after a lost response) keeps the first start time
  await env.DB.prepare("INSERT OR IGNORE INTO runs (run_id, player_id, started_at) VALUES (?, ?, ?)")
    .bind(runId, playerId, Date.now())
    .run();
  return reply(200, { ok: true });
}

async function submitScore(request, env) {
  const body = await readJson(request);
  const entry = {
    runId: id(body.runId, "runId"),
    playerId: id(body.playerId, "playerId"),
    name: name(body.name),
    level: int(body.level, "level", 1, 100000),
    mainTurret: token(body.mainTurret, "mainTurret"),
    // Missing from runs that started before the game sent it
    runSeconds: body.runSeconds == null ? null : int(body.runSeconds, "runSeconds", 0, Number.MAX_SAFE_INTEGER),
    damageDealt: int(body.damageDealt, "damageDealt", 0, Number.MAX_SAFE_INTEGER),
    kills: int(body.kills, "kills", 0, Number.MAX_SAFE_INTEGER),
    deck: deck(body.deck),
    artifacts: artifacts(body.artifacts),
  };

  const run = await env.DB.prepare("SELECT started_at, submitted FROM runs WHERE run_id = ?")
    .bind(entry.runId)
    .first();
  if (run && run.submitted) {
    return reply(409, { error: "already_submitted", message: "This run is already on the leaderboard." });
  }

  // Timing: every completed level takes at least MIN_SECONDS_PER_LEVEL. With
  // neither measure (an unregistered run from an older game) it isn't checked.
  const now = Date.now();
  const serverSeconds = run ? (now - run.started_at) / 1000 : 0;
  const elapsed = Math.max(serverSeconds, entry.runSeconds ?? 0);
  const minimum = (entry.level - 1) * Number(env.MIN_SECONDS_PER_LEVEL || 20);
  if ((run || entry.runSeconds !== null) && elapsed < minimum) {
    return reply(422, {
      error: "too_fast",
      message: `Level ${entry.level} in ${formatDuration(elapsed)} is faster than the ${formatDuration(minimum)} minimum.`,
    });
  }

  const results = await env.DB.batch([
    // A run the server never heard about starts when the game says it did
    env.DB.prepare("INSERT OR IGNORE INTO runs (run_id, player_id, started_at) VALUES (?, ?, ?)")
      .bind(entry.runId, entry.playerId, Math.round(now - elapsed * 1000)),
    env.DB.prepare("UPDATE runs SET submitted = 1 WHERE run_id = ? AND submitted = 0").bind(entry.runId),
    env.DB.prepare(
      `INSERT OR IGNORE INTO scores
         (run_id, player_id, name, level, main_turret, damage_dealt, kills, duration_s, deck, artifacts, created_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
    ).bind(entry.runId, entry.playerId, entry.name, entry.level, entry.mainTurret, entry.damageDealt, entry.kills,
      Math.round(elapsed), JSON.stringify(entry.deck), JSON.stringify(entry.artifacts), now),
  ]);
  if (results[2].meta.changes === 0) {
    return reply(409, { error: "already_submitted", message: "This run is already on the leaderboard." });
  }

  const ranked = await env.DB.prepare(`SELECT rank FROM (${RANKED}) WHERE run_id = ?`).bind(entry.runId).first();
  return reply(200, { ok: true, rank: ranked.rank });
}

// A scores row as the game sees it (run and player ids stay private)
function toEntry(r) {
  return {
    id: r.id,
    rank: r.rank,
    name: r.name,
    level: r.level,
    mainTurret: r.main_turret,
    damageDealt: r.damage_dealt,
    kills: r.kills,
    durationSeconds: r.duration_s,
    deck: JSON.parse(r.deck),
    artifacts: JSON.parse(r.artifacts),
    createdAt: r.created_at,
  };
}

async function topScores(url, env) {
  const limit = Math.min(100, Math.max(1, parseInt(url.searchParams.get("limit"), 10) || 50));
  const { results } = await env.DB.prepare(`SELECT * FROM (${RANKED}) WHERE rank <= ? ORDER BY rank`).bind(limit).all();
  return reply(200, { scores: results.map(toEntry) });
}

// AROUND_COUNT runs around this one: normally two ahead and two behind, shifted
// so there are still AROUND_COUNT when it's near the top or the bottom
async function scoresAround(url, env) {
  const runId = id(url.searchParams.get("runId"), "runId");
  const mine = await env.DB.prepare(
    `SELECT rank, (SELECT COUNT(*) FROM scores) AS total FROM (${RANKED}) WHERE run_id = ?`
  ).bind(runId).first();
  if (!mine) return reply(404, { error: "unknown_run", message: "This run isn't on the leaderboard." });

  const first = Math.max(1, Math.min(mine.rank - Math.floor(AROUND_COUNT / 2), mine.total - AROUND_COUNT + 1));
  const { results } = await env.DB.prepare(`SELECT * FROM (${RANKED}) WHERE rank BETWEEN ? AND ? ORDER BY rank`)
    .bind(first, first + AROUND_COUNT - 1)
    .all();
  return reply(200, {
    rank: mine.rank,
    total: mine.total,
    scores: results.map((r) => ({ ...toEntry(r), you: r.run_id === runId })),
  });
}
