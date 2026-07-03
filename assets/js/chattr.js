// Chattr feed bootstrap — fetches data/*.json and renders using
// assets/js/chattr-render.js (ICONS, postHTML, trendsHTML, etc).

async function initChattr() {
  const [accounts, posts, polls, trends, season] = await Promise.all([
    loadJSON("../data/accounts.json"),
    loadJSON("../data/posts.json"),
    loadJSON("../data/polls.json"),
    loadJSON("../data/trends.json"),
    loadJSON("../data/season.json")
  ]);

  document.getElementById("game-date").textContent = season.currentDate;
  document.getElementById("feed").innerHTML = posts.map(p => postHTML(p, accounts, polls)).join("");
  document.getElementById("sidebar").innerHTML =
    trendsHTML(trends) + tableWidgetHTML(season) + fixturesWidgetHTML(season);
}

initChattr().catch(err => {
  document.getElementById("feed").innerHTML =
    `<div class="load-error">Could not load feed data (${esc(err.message)}). If you opened this file directly, serve it over HTTP instead.</div>`;
});
