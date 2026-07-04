// Pure Threadit rendering — shared by threadit/index.html and generator/index.html.
// No fetch, no routing state: just functions that turn thread/comment data into HTML.

const UP = '<svg viewBox="0 0 24 24"><path d="M12 4l7 8h-4v8h-6v-8H5z" fill="currentColor"/></svg>';
const DOWN = '<svg viewBox="0 0 24 24"><path d="M12 20l-7-8h4V4h6v8h4z" fill="currentColor"/></svg>';
const BUBBLE = '<svg viewBox="0 0 24 24"><path d="M4 5h16v11H8l-4 4z" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linejoin="round"/></svg>';
const TAB_HOT = '<svg viewBox="0 0 24 24"><path fill="#ff4500" d="M12 2.7c.4 2.8-.8 4.4-2.1 5.9C8.6 10.1 7.2 11.7 7.2 14a4.8 4.8 0 0 0 9.6 0c0-1.4-.5-2.7-1.3-3.8-.4 1-1 1.7-1.9 2.1.6-2.9-.3-6.7-1.6-9.6z"/></svg>';
const TAB_NEW = '<svg viewBox="0 0 24 24"><path fill="#f2c744" d="M12 3Q13 11 21 12Q13 13 12 21Q11 13 3 12Q11 11 12 3z"/></svg>';
const TAB_TOP = '<svg viewBox="0 0 24 24"><path fill="#e2b719" d="M6.5 3.5h11v4a5.5 5.5 0 0 1-4 5.3V15h2.3v2H8.2v-2h2.3v-2.2a5.5 5.5 0 0 1-4-5.3v-4z"/><path d="M6.5 5H4.2a3.3 3.3 0 0 0 3 3.3M17.5 5h2.3a3.3 3.3 0 0 1-3 3.3" fill="none" stroke="#e2b719" stroke-width="1.6" stroke-linecap="round"/></svg>';

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

// Title + meta + body, without the "back to subreddit" link — reused by the
// full threadViewHTML() on the real site and directly by generator/index.html.
function threadBodyHTML(t) {
  return `
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
    </article>`;
}

function threadViewHTML(t) {
  return `
    <div class="t-view">
      <a class="back" href="#/">← t/chelseafc</a>
      ${threadBodyHTML(t)}
      <div class="c-sort">Sort by: <b>Best</b> · ${commentCount(t)} comments</div>
      <div class="comments">${t.comments.map(c => commentHTML(c, false)).join("")}</div>
    </div>`;
}
