// Pure Threadit rendering — shared by threadit/index.html and generator/index.html.
// No fetch, no routing state: just functions that turn thread/comment data into HTML.

const UP = '<svg viewBox="0 0 24 24"><path d="M12 4l7 8h-4v8h-6v-8H5z" fill="currentColor"/></svg>';
const DOWN = '<svg viewBox="0 0 24 24"><path d="M12 20l-7-8h4V4h6v8h4z" fill="currentColor"/></svg>';
const BUBBLE = '<svg viewBox="0 0 24 24"><path d="M4 5h16v11H8l-4 4z" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linejoin="round"/></svg>';
const TAB_HOT = '<svg viewBox="0 0 24 24"><path fill="#ff4500" d="M12 2.7c.4 2.8-.8 4.4-2.1 5.9C8.6 10.1 7.2 11.7 7.2 14a4.8 4.8 0 0 0 9.6 0c0-1.4-.5-2.7-1.3-3.8-.4 1-1 1.7-1.9 2.1.6-2.9-.3-6.7-1.6-9.6z"/></svg>';
const TAB_NEW = '<svg viewBox="0 0 24 24"><path fill="#f2c744" d="M12 3Q13 11 21 12Q13 13 12 21Q11 13 3 12Q11 11 12 3z"/></svg>';
const TAB_TOP = '<svg viewBox="0 0 24 24"><path fill="#e2b719" d="M6.5 3.5h11v4a5.5 5.5 0 0 1-4 5.3V15h2.3v2H8.2v-2h2.3v-2.2a5.5 5.5 0 0 1-4-5.3v-4z"/><path d="M6.5 5H4.2a3.3 3.3 0 0 0 3 3.3M17.5 5h2.3a3.3 3.3 0 0 1-3 3.3" fill="none" stroke="#e2b719" stroke-width="1.6" stroke-linecap="round"/></svg>';

const LION_ICON = '<svg viewBox="0 0 24 24"><g fill="#d78f1e"><circle cx="12" cy="4.7" r="2.8"/><circle cx="17.52" cy="6.98" r="2.8"/><circle cx="19.8" cy="12.5" r="2.8"/><circle cx="17.52" cy="18.02" r="2.8"/><circle cx="12" cy="20.3" r="2.8"/><circle cx="6.48" cy="18.02" r="2.8"/><circle cx="4.2" cy="12.5" r="2.8"/><circle cx="6.48" cy="6.98" r="2.8"/><circle cx="12" cy="12.5" r="8"/></g><circle cx="12" cy="12.9" r="6" fill="#f2c14e"/><ellipse cx="12" cy="15.2" rx="2.7" ry="2.1" fill="#fbe8bd"/><circle cx="9.7" cy="11.5" r=".9" fill="#3d2508"/><circle cx="14.3" cy="11.5" r=".9" fill="#3d2508"/><path d="M10.95 14.1h2.1L12 15.5z" fill="#3d2508"/><path d="M12 15.5v.9" stroke="#3d2508" stroke-width=".9" stroke-linecap="round"/></svg>';
const BALL_ICON = '<svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="8.5" fill="#fff"/><path d="M12 8.8l3.04 2.21-1.16 3.58h-3.76l-1.16-3.58z" fill="#101b1e"/><path d="M12 8.8V4.7M15.04 11.01l4.1-1.33M13.88 14.59l2.53 3.49M10.12 14.59l-2.53 3.49M8.96 11.01l-4.1-1.33" stroke="#101b1e" stroke-width="1.1"/></svg>';
const GLOBE_ICON = '<svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="9" fill="none" stroke="#fff" stroke-width="1.3"/><ellipse cx="12" cy="12" rx="4" ry="9" fill="none" stroke="#fff" stroke-width="1.1"/><path d="M3.2 9h17.6M3.2 15h17.6" stroke="#fff" stroke-width="1.1" fill="none"/><circle cx="15.5" cy="15.5" r="4.2" fill="#101b1e" stroke="#fff" stroke-width=".8"/><path d="M15.5 12.6l1 .7-.4 1.2h-1.2l-.4-1.2z" fill="#fff"/></svg>';

// Community config: banner gradient, icon, name/description, member stats.
// Sidebar league table + fixtures widgets only make sense for t/chelseafc
// (they're Chelsea-biased with an "us" marker), so only that community sets
// showClubWidgets.
const COMMUNITIES = {
  chelseafc: {
    name: "Chelsea FC", path: "t/chelseafc",
    banner: "linear-gradient(90deg, #034694, #0a67c2 60%, #05529e)",
    iconBg: "#034694", icon: LION_ICON,
    description: "The front page of the Kings of London. Match threads, transfer talk, Terry's opinions.",
    stats: [["412k", "Blue Lions"], ["8.4k", "at the Bridge"]],
    showClubWidgets: true
  },
  premierleague: {
    name: "Premier League", path: "t/premierleague",
    banner: "linear-gradient(90deg, #3d0e5c, #6f2da8 60%, #3d0e5c)",
    iconBg: "#3d0e5c", icon: BALL_ICON,
    description: "All 20 clubs, one table, zero chill. Results, rumours and referee conspiracy theories.",
    stats: [["2.1M", "subscribers"], ["41.3k", "here now"]],
    showClubWidgets: false
  },
  football: {
    name: "Football", path: "t/football",
    banner: "linear-gradient(90deg, #0c3d24, #1c7a4d 60%, #0c3d24)",
    iconBg: "#0c3d24", icon: GLOBE_ICON,
    description: "The world's game. Every league, every scandal, every 2am highlight rabbit hole.",
    stats: [["8.7M", "subscribers"], ["102k", "here now"]],
    showClubWidgets: false
  }
};

function communityChromeHTML(sub) {
  const c = COMMUNITIES[sub] || COMMUNITIES.chelseafc;
  return `
    <div class="community-banner" style="background:${c.banner}"></div>
    <div class="community-bar">
      <div class="community-bar-inner">
        <div class="community-icon" style="background:${c.iconBg}">${c.icon}</div>
        <div class="community-names">
          <h1>${esc(c.name)}</h1>
          <div class="sub">${esc(c.path)}</div>
        </div>
        <div class="join-btn">Joined</div>
      </div>
    </div>`;
}

function communityAboutHTML(sub) {
  const c = COMMUNITIES[sub] || COMMUNITIES.chelseafc;
  const stats = c.stats.map(([n, l]) => `<div><b>${esc(n)}</b><span>${esc(l)}</span></div>`).join("");
  return `
    <div class="widget about">
      <div class="about-banner" style="background:${c.banner}"></div>
      <h3>${esc(c.path)}</h3>
      <p>${esc(c.description)}</p>
      <div class="about-stats">${stats}</div>
    </div>`;
}

function subNavHTML(activeSub) {
  return `
    <div class="sub-nav">
      ${Object.entries(COMMUNITIES).map(([id, c]) => `
        <a href="#/r/${id}" class="sub-nav-item ${id === activeSub ? "active" : ""}">${esc(c.path)}</a>
      `).join("")}
    </div>`;
}

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
    <article class="t-card" onclick="location.hash='#/r/${t.sub}/thread/${t.id}'">
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
      <a class="back" href="#/r/${t.sub}">← t/${t.sub}</a>
      ${threadBodyHTML(t)}
      <div class="c-sort">Sort by: <b>Best</b> · ${commentCount(t)} comments</div>
      <div class="comments">${t.comments.map(c => commentHTML(c, false)).join("")}</div>
    </div>`;
}
