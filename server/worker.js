// FNF Launcher friends server — a Cloudflare Worker with one KV binding: STATUS.
//
//   POST /status          {id, name, playing, mod_url, art_url}  -> stores your status
//   GET  /status?ids=1,2  -> {"1": {...}, ...} for the ids that are online
//
// Theme gallery (custom themes shared between everyone using this server):
//   GET    /themes                 -> [{id, name, author, size, created}] newest first
//   GET    /themes/<id>            -> {id, name, author, size, created, data} (data: base64 .fnftheme)
//   POST   /themes                 {name, author, data} -> {id, token}  (token deletes it)
//   DELETE /themes/<id>?token=...  -> {ok: true}
// A .fnftheme is a zip; anything else is refused. 10 uploads per IP per day.
//
// A status expires 15 minutes after its last heartbeat; expired = offline.
// Only GameBanana links are stored, so a status can never point someone's
// launcher at an arbitrary download.

const TTL_SECONDS = 900;
const MAX_IDS = 300;
const ID_RE = /^\d{1,12}$/;
const MOD_URL_RE = /^https:\/\/gamebanana\.com\/mods\/\d+$/;
const ART_URL_RE = /^https:\/\/images\.gamebanana\.com\/[\w\/.\-]+$/;

const MAX_THEME_BYTES = 1500000; // decoded .fnftheme size
const MAX_THEMES = 300;
const UPLOADS_PER_DAY = 10;
const THEME_ID_RE = /^[0-9a-f]{12}$/;
const BASE64_RE = /^[A-Za-z0-9+/]+={0,2}$/;

const HEADERS = {
  "content-type": "application/json",
  "access-control-allow-origin": "*",
};

function json(body, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: HEADERS });
}

function text(value, max) {
  return typeof value === "string" ? value.trim().slice(0, max) : "";
}

function matches(value, re) {
  return typeof value === "string" && re.test(value) ? value : "";
}

function randomHex(bytes) {
  const a = new Uint8Array(bytes);
  crypto.getRandomValues(a);
  return [...a].map((x) => x.toString(16).padStart(2, "0")).join("");
}

async function sha256(text) {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(text));
  return [...new Uint8Array(digest)].map((x) => x.toString(16).padStart(2, "0")).join("");
}

async function themeIndex(env) {
  return JSON.parse((await env.STATUS.get("themes:index")) || "[]");
}

async function handleThemes(request, env, url) {
  const parts = url.pathname.split("/").filter(Boolean); // ["themes"] or ["themes", id]
  const id = parts[1] || "";
  if (parts.length > 2 || (id && !THEME_ID_RE.test(id))) {
    return json({ error: "not found" }, 404);
  }

  if (request.method === "GET" && !id) {
    return json(await themeIndex(env));
  }

  if (request.method === "GET") {
    const theme = await env.STATUS.get(`theme:${id}`);
    if (!theme) return json({ error: "not found" }, 404);
    const t = JSON.parse(theme);
    delete t.token_hash;
    return json(t);
  }

  if (request.method === "POST" && !id) {
    const ip = request.headers.get("cf-connecting-ip") || "unknown";
    const day = new Date().toISOString().slice(0, 10);
    const rlKey = `rl:${ip}:${day}`;
    const count = parseInt((await env.STATUS.get(rlKey)) || "0", 10);
    if (count >= UPLOADS_PER_DAY) {
      return json({ error: "too many uploads today" }, 429);
    }
    let body;
    try {
      body = await request.json();
    } catch {
      return json({ error: "invalid json" }, 400);
    }
    const name = text(body.name, 48);
    const author = text(body.author, 48);
    const data = typeof body.data === "string" ? body.data.replace(/\s/g, "") : "";
    if (!name || !data || !BASE64_RE.test(data)) {
      return json({ error: "name and data are required" }, 400);
    }
    let bytes;
    try {
      bytes = Uint8Array.from(atob(data), (c) => c.charCodeAt(0));
    } catch {
      return json({ error: "data isn't base64" }, 400);
    }
    if (bytes.length > MAX_THEME_BYTES) {
      return json({ error: "theme is too big (1.5 MB max)" }, 413);
    }
    if (bytes.length < 4 || bytes[0] !== 0x50 || bytes[1] !== 0x4b || bytes[2] !== 0x03 || bytes[3] !== 0x04) {
      return json({ error: "that isn't a .fnftheme" }, 400);
    }
    const newId = randomHex(6);
    const token = randomHex(16);
    const meta = { id: newId, name, author, size: bytes.length, created: Date.now() };
    await env.STATUS.put(`theme:${newId}`, JSON.stringify({ ...meta, data, token_hash: await sha256(token) }));
    const index = [meta, ...(await themeIndex(env))];
    for (const old of index.splice(MAX_THEMES)) {
      await env.STATUS.delete(`theme:${old.id}`);
    }
    await env.STATUS.put("themes:index", JSON.stringify(index));
    await env.STATUS.put(rlKey, String(count + 1), { expirationTtl: 86400 });
    return json({ id: newId, token });
  }

  if (request.method === "DELETE" && id) {
    const theme = await env.STATUS.get(`theme:${id}`);
    if (!theme) return json({ error: "not found" }, 404);
    const token = url.searchParams.get("token") || "";
    if (!token || (await sha256(token)) !== JSON.parse(theme).token_hash) {
      return json({ error: "wrong token" }, 403);
    }
    await env.STATUS.delete(`theme:${id}`);
    const index = (await themeIndex(env)).filter((t) => t.id !== id);
    await env.STATUS.put("themes:index", JSON.stringify(index));
    return json({ ok: true });
  }

  return json({ error: "method not allowed" }, 405);
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    if (url.pathname === "/themes" || url.pathname.startsWith("/themes/")) {
      return handleThemes(request, env, url);
    }

    if (url.pathname === "/status" && request.method === "POST") {
      let body;
      try {
        body = await request.json();
      } catch {
        return json({ error: "invalid json" }, 400);
      }
      const id = String(body.id ?? "");
      if (!ID_RE.test(id)) {
        return json({ error: "invalid id" }, 400);
      }
      const status = {
        id,
        name: text(body.name, 64),
        playing: text(body.playing, 128),
        mod_url: matches(body.mod_url, MOD_URL_RE),
        art_url: matches(body.art_url, ART_URL_RE),
        ts: Date.now(),
      };
      await env.STATUS.put(`s:${id}`, JSON.stringify(status), { expirationTtl: TTL_SECONDS });
      return json({ ok: true });
    }

    if (url.pathname === "/status" && request.method === "GET") {
      const ids = (url.searchParams.get("ids") || "")
        .split(",")
        .filter((id) => ID_RE.test(id))
        .slice(0, MAX_IDS);
      const out = {};
      await Promise.all(
        ids.map(async (id) => {
          const value = await env.STATUS.get(`s:${id}`);
          if (value) out[id] = JSON.parse(value);
        }),
      );
      return json(out);
    }

    if (url.pathname === "/") {
      return new Response("FNF Launcher friends server is running.\n", {
        headers: { "content-type": "text/plain" },
      });
    }

    return json({ error: "not found" }, 404);
  },
};
