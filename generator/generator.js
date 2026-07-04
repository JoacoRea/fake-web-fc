// Chattr Lab — paste last-5-matches recap, Gemini 2.5 Flash generates a batch
// of Chattr-style posts AND Threadit-style threads client-side. No
// persistence, no server: this calls the Gemini API directly from the
// browser using the key in config.js.

const PERSONA_NOTES = `
Recurring fan personas shared by both Chattr and Threadit (use their
established voice, don't invent new personas):
- danny (CFCDanny): euphoric, ALL CAPS, "WE ARE SO BACK", emotional swings.
- sue (BluesTilIDie_Sue): chronic pessimist, dark/dry humor, expects disaster.
- terry (ShedEndTerry): boomer, "in my day...", finds something to complain
  about even in a big win, grudgingly comes around eventually.
- marcus (xG_Marcus): the stats defender, cites xG/underlying numbers, calm.
- chloe (CarefreeChloe): optimistic, sharp banter, teases other accounts.
- gaz (GoonerGaz): rival Arsenal fan who shows up to wind Chelsea fans up.

Other Chattr accounts available when relevant: chelseafc (official club
account, gold-verified), skysports, fabrizio (Fabrizio Romano, transfer
scoops), ornstein (David Ornstein, exclusives), optajoe (stats account), and
any current-squad player accounts present in the roster below (post in first
person as the player, understated, positive).

Threadit-only recurring usernames (forum has no fixed account roster --
any username string works, but reuse these established ones for
consistency): ZolaWasMyDad (nostalgic meme lord), KTBFFH_1905 (level-headed
historian, calls out nonsense calmly), KepaApologist (running joke, always
downvoted), StamfordBridgeCat (posts most Post Match Threads).
`.trim();

function buildRecentContext(posts, threads) {
  const recentPosts = posts.slice(0, 12)
    .map(p => `- [post] @${p.author}: ${p.text.slice(0, 160)}`)
    .join("\n");
  const recentThreads = threads.slice(0, 5)
    .map(t => `- [thread] "${t.title}" (${t.flair}): ${t.body.split("\n")[0].slice(0, 160)}`)
    .join("\n");
  return `${recentPosts}\n${recentThreads}`;
}

const RECENT_CONTEXT_NOTE = `
ALREADY PUBLISHED on the site (for continuity only):
"""
{{RECENT_CONTEXT}}
"""
Do NOT repeat these exact same events as if they were new. You MAY reference
or follow up on ongoing storylines from the list above if relevant to the new
recap below (transfers, injuries, cup runs). Do NOT contradict established
facts (e.g. a player already sold, an injury already reported).
`.trim();

function buildPrompt(accounts, matchesText, count, recentContext) {
  const roster = Object.entries(accounts)
    .map(([id, a]) => `- ${id}: ${a.name} (@${a.handle})`)
    .join("\n");

  return `
You are writing fictional social media posts for "Chattr", a parody of X/Twitter,
reacting to real results from a Chelsea FC career-mode save in EA Sports FC 26.

Account roster (use ONLY these ids as "author", never invent new ones):
${roster}

${PERSONA_NOTES}

${RECENT_CONTEXT_NOTE.replace("{{RECENT_CONTEXT}}", recentContext)}

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

const KNOWN_FLAIRS = [
  "Post Match Thread", "Transfer News", "Official Source", "Analysis",
  "Injury News", "Unpopular Opinion", "Shitpost Saturday", "Discussion", "Rant"
];

function buildThreadsPrompt(accounts, matchesText, count, recentContext) {
  return `
You are writing fictional forum threads for "Threadit" (t/chelseafc), a parody
of Reddit, reacting to real results from a Chelsea FC career-mode save in EA
Sports FC 26.

${PERSONA_NOTES}

Use ONLY these flairs (exact strings, for correct color-coding): ${KNOWN_FLAIRS.join(", ")}.

${RECENT_CONTEXT_NOTE.replace("{{RECENT_CONTEXT}}", recentContext)}

Here is what actually happened in the last matches, as reported by the user:
"""
${matchesText}
"""

Write exactly ${count} threads reacting to this (post-match reaction, tactical
analysis, transfer discussion, a vent/rant, a meme/shitpost -- vary the angle).
Each thread needs 2-5 top-level comments in the established personas' voices,
and 1-2 of those comments should have exactly 1 nested reply (a short back-and-
forth), matching real Reddit thread shape. Give each thread a short unique
kebab-case "id". React ONLY to what's in the recap above -- don't invent
unrelated events.

For "time", use short in-game-feeling relative labels like "just now", "12m",
"1h", "3h". For "upvotes", use plausible strings like "45", "312", "1.2k",
"4.6k" -- occasionally a contrarian comment can have a NEGATIVE upvote string
like "-23" to show it was downvoted.
`.trim();
}

const RESPONSE_SCHEMA_POSTS = {
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

const REPLY_SCHEMA = {
  type: "OBJECT",
  properties: {
    author: { type: "STRING" },
    time: { type: "STRING" },
    upvotes: { type: "STRING" },
    text: { type: "STRING" }
  },
  required: ["author", "time", "upvotes", "text"]
};

const COMMENT_SCHEMA = {
  type: "OBJECT",
  properties: {
    author: { type: "STRING" },
    time: { type: "STRING" },
    upvotes: { type: "STRING" },
    text: { type: "STRING" },
    replies: { type: "ARRAY", items: REPLY_SCHEMA }
  },
  required: ["author", "time", "upvotes", "text"]
};

const RESPONSE_SCHEMA_THREADS = {
  type: "ARRAY",
  items: {
    type: "OBJECT",
    properties: {
      id: { type: "STRING" },
      flair: { type: "STRING" },
      title: { type: "STRING" },
      author: { type: "STRING" },
      time: { type: "STRING" },
      upvotes: { type: "STRING" },
      body: { type: "STRING" },
      comments: { type: "ARRAY", items: COMMENT_SCHEMA }
    },
    required: ["id", "flair", "title", "author", "time", "upvotes", "body", "comments"]
  }
};

const RETRYABLE_STATUSES = new Set([500, 502, 503, 504]);
const MAX_ATTEMPTS = 4;
const BASE_DELAY_MS = 1000;
const MAX_DELAY_MS = 8000;

function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

async function callGemini(prompt, schema, onRetry) {
  const url = `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent?key=${GEMINI_API_KEY}`;

  let lastStatus;
  for (let attempt = 1; attempt <= MAX_ATTEMPTS; attempt++) {
    const res = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        contents: [{ parts: [{ text: prompt }] }],
        generationConfig: {
          responseMimeType: "application/json",
          responseSchema: schema
        }
      })
    });

    if (res.ok) return parseGeminiResponse(await res.json());

    lastStatus = res.status;

    if (res.status === 429) {
      throw new Error("Se acabó la cuota gratis de Gemini por ahora — probá de nuevo más tarde.");
    }
    if (res.status === 400 || res.status === 403) {
      throw new Error("La API key no funcionó. Revisá que esté bien pegada y restringida en generator/config.js.");
    }

    if (RETRYABLE_STATUSES.has(res.status)) {
      if (attempt < MAX_ATTEMPTS) {
        const backoff = Math.min(BASE_DELAY_MS * 2 ** (attempt - 1), MAX_DELAY_MS);
        const jitter = Math.random() * 600 - 300;
        const delay = Math.max(300, backoff + jitter);
        if (onRetry) onRetry(attempt, MAX_ATTEMPTS);
        await sleep(delay);
        continue;
      }
      throw new Error(`Gemini sigue saturado (HTTP ${lastStatus}) después de varios intentos. Probá de nuevo en un rato.`);
    }

    throw new Error(`Gemini respondió con un error (HTTP ${res.status}).`);
  }
}

function parseGeminiResponse(data) {
  const text = data?.candidates?.[0]?.content?.parts?.[0]?.text;
  if (!text) throw new Error("La respuesta de Gemini vino vacía o con un formato inesperado.");

  let items;
  try {
    items = JSON.parse(text);
  } catch (e) {
    throw new Error("No se pudo interpretar el JSON que devolvió Gemini.");
  }
  if (!Array.isArray(items)) throw new Error("Gemini no devolvió una lista.");
  return items;
}

function setStatus(msg, isError) {
  const el = document.getElementById("status");
  el.textContent = msg || "";
  el.classList.toggle("error", !!isError);
}

function validPost(p, accounts) {
  const ok = p && typeof p.author === "string" && accounts[p.author]
    && typeof p.text === "string" && p.text.trim();
  if (!ok) console.warn("[chattr-lab] Post descartado (autor inválido o vacío):", p && p.author);
  return ok;
}

function validComment(c) {
  return c && typeof c.author === "string" && c.author.trim()
    && typeof c.text === "string" && c.text.trim();
}

function validThread(t) {
  const ok = t && typeof t.id === "string" && t.id.trim()
    && typeof t.title === "string" && t.title.trim()
    && typeof t.body === "string" && t.body.trim()
    && typeof t.author === "string" && t.author.trim();
  if (!ok) {
    console.warn("[chattr-lab] Hilo descartado (le faltan campos):", t);
    return false;
  }
  t.flair = KNOWN_FLAIRS.includes(t.flair) ? t.flair : "Discussion";
  t.comments = Array.isArray(t.comments) ? t.comments.filter(validComment) : [];
  t.comments.forEach(c => {
    c.replies = Array.isArray(c.replies) ? c.replies.filter(validComment) : [];
  });
  return true;
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
  document.getElementById("threads-feed").innerHTML = "";

  try {
    const [accounts, recentPosts, recentThreads] = await Promise.all([
      loadJSON("../data/accounts.json"),
      loadJSON("../data/posts.json"),
      loadJSON("../data/threads.json")
    ]);
    const recentContext = buildRecentContext(recentPosts, recentThreads);

    const postsPrompt = buildPrompt(accounts, matchesText, count, recentContext);
    const threadsPrompt = buildThreadsPrompt(accounts, matchesText, Math.max(1, Math.round(count / 3)), recentContext);

    const [postsResult, threadsResult] = await Promise.allSettled([
      callGemini(postsPrompt, RESPONSE_SCHEMA_POSTS, (a, m) => setStatus(`Gemini está saturado (posts), reintentando (${a}/${m})…`)),
      callGemini(threadsPrompt, RESPONSE_SCHEMA_THREADS, (a, m) => setStatus(`Gemini está saturado (hilos), reintentando (${a}/${m})…`))
    ]);

    const notes = [];

    if (postsResult.status === "fulfilled") {
      const validPosts = postsResult.value.filter(p => validPost(p, accounts));
      document.getElementById("feed").innerHTML =
        validPosts.map(p => postHTML(p, accounts, {})).join("");
      notes.push(`${validPosts.length} posts`);
    } else {
      notes.push(`posts: ${postsResult.reason.message}`);
    }

    if (threadsResult.status === "fulfilled") {
      const validThreads = threadsResult.value.filter(validThread);
      document.getElementById("threads-feed").innerHTML = validThreads.map(t => `
        <div class="lab-thread">
          ${threadBodyHTML(t)}
          <div class="comments">${t.comments.map(c => commentHTML(c, false)).join("")}</div>
        </div>`).join("");
      notes.push(`${validThreads.length} hilos`);
    } else {
      notes.push(`hilos: ${threadsResult.reason.message}`);
    }

    const bothFailed = postsResult.status === "rejected" && threadsResult.status === "rejected";
    setStatus(
      (bothFailed ? "Falló todo — " : "Listo — ") + notes.join(" · ") + " (no se guarda en ningún lado).",
      bothFailed
    );
  } catch (err) {
    setStatus(err.message, true);
  } finally {
    btn.disabled = false;
  }
}

document.getElementById("generate-btn").addEventListener("click", onGenerate);
