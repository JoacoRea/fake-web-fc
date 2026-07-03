// Chattr Lab — paste last-5-matches recap, Gemini 2.5 Flash generates a batch
// of Chattr-style posts client-side. No persistence, no server: this calls
// the Gemini API directly from the browser using the key in config.js.

const PERSONA_NOTES = `
Recurring fan personas (use their established voice, don't invent new personas):
- danny (CFCDanny): euphoric, ALL CAPS, "WE ARE SO BACK", emotional swings.
- sue (BluesTilIDie_Sue): chronic pessimist, dark/dry humor, expects disaster.
- terry (ShedEndTerry): boomer, "in my day...", finds something to complain
  about even in a big win, grudgingly comes around eventually.
- marcus (xG_Marcus): the stats defender, cites xG/underlying numbers, calm.
- chloe (CarefreeChloe): optimistic, sharp banter, teases other accounts.
- gaz (GoonerGaz): rival Arsenal fan who shows up to wind Chelsea fans up.

Other accounts available when relevant: chelseafc (official club account,
gold-verified), skysports, fabrizio (Fabrizio Romano, transfer scoops),
ornstein (David Ornstein, exclusives), optajoe (stats account), and any
current-squad player accounts present in the roster below (post in first
person as the player, understated, positive).
`.trim();

function buildPrompt(accounts, matchesText, count) {
  const roster = Object.entries(accounts)
    .map(([id, a]) => `- ${id}: ${a.name} (@${a.handle})`)
    .join("\n");

  return `
You are writing fictional social media posts for "Chattr", a parody of X/Twitter,
reacting to real results from a Chelsea FC career-mode save in EA Sports FC 26.

Account roster (use ONLY these ids as "author", never invent new ones):
${roster}

${PERSONA_NOTES}

Here is what actually happened in the last matches, as reported by the user:
"""
${matchesText}
"""

Write exactly ${count} posts reacting to this. Mix accounts: some hard-news posts
from media/official accounts, some emotional fan reactions, some banter between
personas. React ONLY to what's in the recap above plus plausible immediate
reactions to it -- don't invent unrelated transfers or results. Keep posts short
(1-3 sentences, Twitter-length), punchy, and true to each account's voice.

For "time", use short relative labels like a live feed: "just now", "2m", "8m",
"23m", "1h" (most recent first). For replies/reposts/likes/views, use plausible
short strings like "214", "3.4K", "890", "18.7K", "1.2M" -- vary them, bigger
accounts and bigger news get bigger numbers.
`.trim();
}

const RESPONSE_SCHEMA = {
  type: "ARRAY",
  items: {
    type: "OBJECT",
    properties: {
      author: { type: "STRING" },
      time: { type: "STRING" },
      text: { type: "STRING" },
      replies: { type: "STRING" },
      reposts: { type: "STRING" },
      likes: { type: "STRING" },
      views: { type: "STRING" }
    },
    required: ["author", "time", "text", "replies", "reposts", "likes", "views"]
  }
};

async function callGemini(prompt) {
  const url = `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent?key=${GEMINI_API_KEY}`;

  const res = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      contents: [{ parts: [{ text: prompt }] }],
      generationConfig: {
        responseMimeType: "application/json",
        responseSchema: RESPONSE_SCHEMA
      }
    })
  });

  if (!res.ok) {
    if (res.status === 429) {
      throw new Error("Se acabó la cuota gratis de Gemini por ahora — probá de nuevo más tarde.");
    }
    if (res.status === 400 || res.status === 403) {
      throw new Error("La API key no funcionó. Revisá que esté bien pegada y restringida en generator/config.js.");
    }
    throw new Error(`Gemini respondió con un error (HTTP ${res.status}).`);
  }

  const data = await res.json();
  const text = data?.candidates?.[0]?.content?.parts?.[0]?.text;
  if (!text) throw new Error("La respuesta de Gemini vino vacía o con un formato inesperado.");

  let posts;
  try {
    posts = JSON.parse(text);
  } catch (e) {
    throw new Error("No se pudo interpretar el JSON que devolvió Gemini.");
  }
  if (!Array.isArray(posts)) throw new Error("Gemini no devolvió una lista de posts.");
  return posts;
}

function setStatus(msg, isError) {
  const el = document.getElementById("status");
  el.textContent = msg || "";
  el.classList.toggle("error", !!isError);
}

async function onGenerate() {
  const btn = document.getElementById("generate-btn");
  const matchesText = document.getElementById("matches-input").value.trim();
  const count = Math.max(1, Math.min(30, parseInt(document.getElementById("count-input").value, 10) || 12));

  if (!matchesText) {
    setStatus("Pegá primero el resumen de los últimos partidos.", true);
    return;
  }
  if (typeof GEMINI_API_KEY === "undefined" || GEMINI_API_KEY === "PASTE_YOUR_API_KEY_HERE") {
    setStatus("Falta config.js con tu API key (ver generator/README.md) — esto solo funciona corriendo el sitio en tu PC.", true);
    return;
  }

  btn.disabled = true;
  setStatus("Generando…");
  document.getElementById("feed").innerHTML = "";

  try {
    const accounts = await loadJSON("../data/accounts.json");
    const prompt = buildPrompt(accounts, matchesText, count);
    const rawPosts = await callGemini(prompt);

    const validPosts = rawPosts.filter(p => {
      const ok = p && typeof p.author === "string" && accounts[p.author];
      if (!ok) console.warn("[chattr-lab] Descartado (autor inválido):", p && p.author);
      return ok;
    });

    if (validPosts.length === 0) {
      setStatus("Gemini no devolvió posts usables. Probá de nuevo.", true);
      return;
    }

    document.getElementById("feed").innerHTML =
      validPosts.map(p => postHTML(p, accounts, {})).join("");
    setStatus(`Listo — ${validPosts.length} posts generados (no se guardan en ningún lado).`);
  } catch (err) {
    setStatus(err.message, true);
  } finally {
    btn.disabled = false;
  }
}

document.getElementById("generate-btn").addEventListener("click", onGenerate);
