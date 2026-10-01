// FNF Launcher friends server — a Cloudflare Worker with one KV binding: STATUS.
//
//   POST /status          {id, name, playing, mod_url, art_url}  -> stores your status
//   GET  /status?ids=1,2  -> {"1": {...}, ...} for the ids that are online
//
// A status expires 15 minutes after its last heartbeat; expired = offline.
// Only GameBanana links are stored, so a status can never point someone's
// launcher at an arbitrary download.

const TTL_SECONDS = 900;
const MAX_IDS = 300;
const ID_RE = /^\d{1,12}$/;
const MOD_URL_RE = /^https:\/\/gamebanana\.com\/mods\/\d+$/;
const ART_URL_RE = /^https:\/\/images\.gamebanana\.com\/[\w\/.\-]+$/;

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

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

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
