// Shared helpers for Chattr + Threadit (static, no deps)

async function loadJSON(path) {
  const res = await fetch(path);
  if (!res.ok) throw new Error(`Failed to load ${path}`);
  return res.json();
}

function esc(s) {
  return String(s).replace(/[&<>"']/g, c => ({
    "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;"
  }[c]));
}

// Escape, keep line breaks, and highlight @handles and #hashtags
function rich(s) {
  return esc(s)
    .replace(/\n/g, "<br>")
    .replace(/(^|[\s(>])([@#][\wÀ-ɏ]+)/g, '$1<span class="ent">$2</span>');
}

function avatarHTML(color, initials, cls) {
  return `<span class="avatar ${cls || ""}" style="background:${color}">${esc(initials)}</span>`;
}

// Deterministic color for forum usernames (no accounts file needed)
const AVATAR_PALETTE = ["#1d9bf0", "#8e6bbf", "#d63384", "#2b9b6c", "#c47f17", "#c0455e", "#2b6cb0", "#5c6b3c", "#0aa3a3", "#a05a2c"];
function nameColor(name) {
  let h = 0;
  for (let i = 0; i < name.length; i++) h = (h * 31 + name.charCodeAt(i)) >>> 0;
  return AVATAR_PALETTE[h % AVATAR_PALETTE.length];
}

const BADGE_SVG = {
  blue: '<svg class="badge badge-blue" viewBox="0 0 24 24" aria-label="Verified"><path fill="#1d9bf0" d="M12 1.5l2.6 2 3.3-.4 1.2 3.1 3 1.6-1 3.2 1 3.2-3 1.6-1.2 3.1-3.3-.4-2.6 2-2.6-2-3.3.4-1.2-3.1-3-1.6 1-3.2-1-3.2 3-1.6 1.2-3.1 3.3.4z"/><path d="M8.4 12.3l2.4 2.4 4.8-5" fill="none" stroke="#fff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>',
  gold: '<svg class="badge badge-gold" viewBox="0 0 24 24" aria-label="Verified organisation"><path fill="#e2b719" d="M12 1.5l2.6 2 3.3-.4 1.2 3.1 3 1.6-1 3.2 1 3.2-3 1.6-1.2 3.1-3.3-.4-2.6 2-2.6-2-3.3.4-1.2-3.1-3-1.6 1-3.2-1-3.2 3-1.6 1.2-3.1 3.3.4z"/><path d="M8.4 12.3l2.4 2.4 4.8-5" fill="none" stroke="#fff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>'
};

function badgeFor(verified) {
  return verified ? (BADGE_SVG[verified] || BADGE_SVG.blue) : "";
}

// ---- Shared sidebar widgets ----

function tableWidgetHTML(season) {
  const rows = season.table.map(t => `
    <tr class="${t.us ? "us" : ""}">
      <td class="pos">${t.pos}</td>
      <td class="team">${esc(t.team)}</td>
      <td>${t.p}</td>
      <td>${esc(t.gd)}</td>
      <td class="pts">${t.pts}</td>
    </tr>`).join("");
  const form = season.form.map(r => `<span class="form-pip form-${r.toLowerCase()}">${r}</span>`).join("");
  return `
    <div class="widget">
      <h3>Premier League · ${esc(season.season)}</h3>
      <table class="league-table">
        <thead><tr><th></th><th>Club</th><th>P</th><th>GD</th><th>Pts</th></tr></thead>
        <tbody>${rows}</tbody>
      </table>
      <div class="form-row"><span class="form-label">Chelsea form</span>${form}</div>
    </div>`;
}

function fixturesWidgetHTML(season) {
  const items = season.fixtures.map(f => `
    <li>
      <div class="fx-top"><span class="fx-opp">${f.home ? "vs" : "@"} ${esc(f.opponent)}</span><span class="fx-date">${esc(f.date)}</span></div>
      <div class="fx-comp">${esc(f.comp)}</div>
    </li>`).join("");
  return `
    <div class="widget">
      <h3>Upcoming fixtures</h3>
      <ul class="fixtures">${items}</ul>
    </div>`;
}
