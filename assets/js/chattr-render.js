// Pure Chattr post rendering — shared by chattr/index.html and generator/index.html.
// No fetch, no auto-init: just functions that turn post/account data into HTML.

const ICONS = {
  reply: '<svg viewBox="0 0 24 24"><path d="M1.75 12.75c0-4.97 4.03-9 9-9h2.5c4.97 0 9 4.03 9 9s-4.03 9-9 9h-1l-5.5 3.25v-4.06a9 9 0 0 1-5-8.19z" fill="none" stroke="currentColor" stroke-width="1.8"/></svg>',
  repost: '<svg viewBox="0 0 24 24"><path d="M4.5 8.5L8 5m0 0l3.5 3.5M8 5v11a3 3 0 0 0 3 3h2m6.5-3.5L16 19m0 0l-3.5-3.5M16 19V8a3 3 0 0 0-3-3h-2" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/></svg>',
  like: '<svg viewBox="0 0 24 24"><path d="M12 20.5s-8-4.7-8-10.2C4 7 5.9 5 8.4 5c1.6 0 3 .9 3.6 2.2C12.6 5.9 14 5 15.6 5 18.1 5 20 7 20 10.3c0 5.5-8 10.2-8 10.2z" fill="none" stroke="currentColor" stroke-width="1.8"/></svg>',
  views: '<svg viewBox="0 0 24 24"><path d="M5 19V10M12 19V5m7 14v-7" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/></svg>'
};

function actionsHTML(p) {
  return `
    <div class="actions">
      <span class="act reply">${ICONS.reply}<span>${esc(p.replies || "")}</span></span>
      <span class="act repost">${ICONS.repost}<span>${esc(p.reposts || "")}</span></span>
      <span class="act like">${ICONS.like}<span>${esc(p.likes || "")}</span></span>
      <span class="act views">${ICONS.views}<span>${esc(p.views || "")}</span></span>
    </div>`;
}

function pollHTML(poll) {
  const max = Math.max(...poll.options.map(o => o.pct));
  const bars = poll.options.map(o => `
    <div class="poll-opt ${o.pct === max ? "winner" : ""}">
      <div class="poll-fill" style="width:${o.pct}%"></div>
      <span class="poll-label">${esc(o.label)}</span>
      <span class="poll-pct">${o.pct}%</span>
    </div>`).join("");
  return `<div class="poll">${bars}<div class="poll-meta">${esc(poll.meta)}</div></div>`;
}

function quoteHTML(q, accounts) {
  const a = accounts[q.author];
  return `
    <div class="quote-card">
      <div class="quote-head">
        ${avatarHTML(a.color, a.initials, "avatar-xs")}
        <span class="name">${esc(a.name)}</span>${badgeFor(a.verified)}
        <span class="meta">@${esc(a.handle)} · ${esc(q.time)}</span>
      </div>
      <div class="quote-text">${rich(q.text)}</div>
    </div>`;
}

function replyHTML(r, accounts) {
  const a = accounts[r.author];
  return `
    <div class="post-reply">
      <div class="gutter">${avatarHTML(a.color, a.initials, "avatar-sm")}</div>
      <div class="content">
        <div class="post-head">
          <span class="name">${esc(a.name)}</span>${badgeFor(a.verified)}
          <span class="meta">@${esc(a.handle)} · ${esc(r.time)}</span>
        </div>
        <div class="post-text">${rich(r.text)}</div>
        <div class="actions"><span class="act like">${ICONS.like}<span>${esc(r.likes || "")}</span></span></div>
      </div>
    </div>`;
}

function postHTML(p, accounts, polls) {
  const a = accounts[p.author];
  const quote = p.quote ? quoteHTML(p.quote, accounts) : "";
  const poll = p.poll ? pollHTML(polls[p.poll]) : "";
  const thread = (p.thread || []).map(r => replyHTML(r, accounts)).join("");
  return `
    <article class="post">
      <div class="gutter">${avatarHTML(a.color, a.initials, "")}</div>
      <div class="content">
        <div class="post-head">
          <span class="name">${esc(a.name)}</span>${badgeFor(a.verified)}
          <span class="meta">@${esc(a.handle)} · ${esc(p.time)}</span>
        </div>
        <div class="post-text">${rich(p.text)}</div>
        ${poll}${quote}${actionsHTML(p)}
      </div>
      ${thread}
    </article>`;
}

function trendsHTML(trends) {
  const items = trends.map(t => `
    <li>
      <div class="trend-cat">${esc(t.category)}</div>
      <div class="trend-tag">${esc(t.tag)}</div>
      <div class="trend-posts">${esc(t.posts)}</div>
    </li>`).join("");
  return `<div class="widget"><h3>What's happening</h3><ul class="trends">${items}</ul></div>`;
}
