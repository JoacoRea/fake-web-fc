// Threadit bootstrap — thread list + thread view with hash routing
// (#/thread/<id>). Rendering functions live in assets/js/threadit-render.js.

let THREADS = [];
let SEASON = null;

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
