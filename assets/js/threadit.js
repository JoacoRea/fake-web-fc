// Threadit — thread list + thread view with hash routing (#/thread/<id>)

const UP = '<svg viewBox="0 0 24 24"><path d="M12 4l7 8h-4v8h-6v-8H5z" fill="currentColor"/></svg>';
const DOWN = '<svg viewBox="0 0 24 24"><path d="M12 20l-7-8h4V4h6v8h4z" fill="currentColor"/></svg>';
const BUBBLE = '<svg viewBox="0 0 24 24"><path d="M4 5h16v11H8l-4 4z" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linejoin="round"/></svg>';
const TAB_HOT = '<svg viewBox="0 0 24 24"><path fill="#ff4500" d="M12 2.7c.4 2.8-.8 4.4-2.1 5.9C8.6 10.1 7.2 11.7 7.2 14a4.8 4.8 0 0 0 9.6 0c0-1.4-.5-2.7-1.3-3.8-.4 1-1 1.7-1.9 2.1.6-2.9-.3-6.7-1.6-9.6z"/></svg>';
const TAB_NEW = '<svg viewBox="0 0 24 24"><path fill="#f2c744" d="M12 3Q13 11 21 12Q13 13 12 21Q11 13 3 12Q11 11 12 3z"/></svg>';
const TAB_TOP = '<svg viewBox="0 0 24 24"><path fill="#e2b719" d="M6.5 3.5h11v4a5.5 5.5 0 0 1-4 5.3V15h2.3v2H8.2v-2h2.3v-2.2a5.5 5.5 0 0 1-4-5.3v-4z"/><path d="M6.5 5H4.2a3.3 3.3 0 0 0 3 3.3M17.5 5h2.3a3.3 3.3 0 0 1-3 3.3" fill="none" stroke="#e2b719" stroke-width="1.6" stroke-linecap="round"/></svg>';

let THREADS = [];
let SEASON = null;

function userTag(name) {
  return `<span class="t-user">${avatarHTML(nameColor(name), name[0].toUpperCase(), "avatar-xs")}u/${esc(name)}</span>`;
}

function flairHTML(flair) {
  const slug = flair.toLowerCase().replace(/[^a-z]+/g, "-");
  return `<span class="flair flair-${slug}">${esc(flair)}</span>`;
}

function commentCount(t) {
  return t.comments.reduce((n, c) => n + 1 + (c.replies || []).length, 0);
}

function cardHTML(t) {
  return `
    <article class="t-card" onclick="location.hash='#/thread/${t.id}'">
      <div class="votes">
        <span class="vote up">${UP}</span>
        <span class="score">${esc(t.upvotes)}</span>
        <span class="vote down">${DOWN}</span>
      </div>
      <div class="t-body">
        <div class="t-meta">${flairHTML(t.flair)} Posted by ${userTag(t.author)} · ${esc(t.time)}</div>
        <h2 class="t-title">${esc(t.title)}</h2>
        <div class="t-preview">${rich(t.body.split("\n")[0])}</div>
        <div class="t-foot">${BUBBLE}<span>${commentCount(t)} comments</span></div>
      </div>
    </article>`;
}

function commentHTML(c, isReply) {
  const replies = (c.replies || []).map(r => commentHTML(r, true)).join("");
  const neg = String(c.upvotes).startsWith("-");
  return `
    <div class="comment ${isReply ? "comment-reply" : ""}">
      <div class="c-head">${userTag(c.author)}<span class="c-time">· ${esc(c.time)}</span></div>
      <div class="c-text">${rich(c.text)}</div>
      <div class="c-foot ${neg ? "neg" : ""}">
        <span class="vote up">${UP}</span><span class="score">${esc(c.upvotes)}</span><span class="vote down">${DOWN}</span>
        <span class="c-reply">Reply</span>
      </div>
      ${replies}
    </div>`;
}

function threadViewHTML(t) {
  return `
    <div class="t-view">
      <a class="back" href="#/">← t/chelseafc</a>
      <article class="t-card t-open">
        <div class="votes">
          <span class="vote up">${UP}</span>
          <span class="score">${esc(t.upvotes)}</span>
          <span class="vote down">${DOWN}</span>
        </div>
        <div class="t-body">
          <div class="t-meta">${flairHTML(t.flair)} Posted by ${userTag(t.author)} · ${esc(t.time)}</div>
          <h1 class="t-title">${esc(t.title)}</h1>
          <div class="t-full">${rich(t.body)}</div>
        </div>
      </article>
      <div class="c-sort">Sort by: <b>Best</b> · ${commentCount(t)} comments</div>
      <div class="comments">${t.comments.map(c => commentHTML(c, false)).join("")}</div>
    </div>`;
}

function render() {
  const main = document.getElementById("main");
  const m = location.hash.match(/^#\/thread\/(.+)$/);
  const thread = m && THREADS.find(t => t.id === m[1]);
  if (thread) {
    main.innerHTML = threadViewHTML(thread);
    window.scrollTo(0, 0);
  } else {
    main.innerHTML = `
      <div class="t-tabs"><span class="tab active">${TAB_HOT} Hot</span><span class="tab">${TAB_NEW} New</span><span class="tab">${TAB_TOP} Top</span></div>
      ${THREADS.map(cardHTML).join("")}`;
  }
}

async function initThreadit() {
  [THREADS, SEASON] = await Promise.all([
    loadJSON("../data/threads.json"),
    loadJSON("../data/season.json")
  ]);
  document.getElementById("game-date").textContent = SEASON.currentDate;
  document.getElementById("sidebar").innerHTML = `
    <div class="widget about">
      <div class="about-banner"></div>
      <h3>t/chelseafc</h3>
      <p>The front page of the Kings of London. Match threads, transfer talk, Terry's opinions.</p>
      <div class="about-stats"><div><b>412k</b><span>Blue Lions</span></div><div><b>8.4k</b><span>at the Bridge</span></div></div>
    </div>
    ${tableWidgetHTML(SEASON)}
    ${fixturesWidgetHTML(SEASON)}`;
  render();
  window.addEventListener("hashchange", render);
}

initThreadit().catch(err => {
  document.getElementById("main").innerHTML =
    `<div class="load-error">Could not load forum data (${esc(err.message)}). If you opened this file directly, serve it over HTTP instead.</div>`;
});
