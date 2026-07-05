// Threadit bootstrap — multi-community thread list + thread view with hash
// routing (#/r/<sub> and #/r/<sub>/thread/<id>). Rendering functions and the
// COMMUNITIES config live in assets/js/threadit-render.js.

let THREADS = [];
let SEASON = null;

function parseHash() {
  let m = location.hash.match(/^#\/r\/([a-z]+)\/thread\/(.+)$/);
  if (m) return { sub: m[1], threadId: m[2] };
  m = location.hash.match(/^#\/r\/([a-z]+)$/);
  if (m) return { sub: m[1], threadId: null };
  return { sub: "chelseafc", threadId: null };
}

function renderSidebar(sub) {
  const community = communityAboutHTML(sub);
  const clubWidgets = (COMMUNITIES[sub] && COMMUNITIES[sub].showClubWidgets && SEASON)
    ? tableWidgetHTML(SEASON) + fixturesWidgetHTML(SEASON)
    : "";
  document.getElementById("sidebar").innerHTML = community + clubWidgets;
}

function render() {
  const { sub, threadId } = parseHash();
  const validSub = COMMUNITIES[sub] ? sub : "chelseafc";

  document.getElementById("community-chrome").innerHTML = communityChromeHTML(validSub);
  document.getElementById("sub-nav").innerHTML = subNavHTML(validSub);
  renderSidebar(validSub);

  const main = document.getElementById("main");
  const subThreads = THREADS.filter(t => t.sub === validSub);
  const thread = threadId && subThreads.find(t => t.id === threadId);

  if (thread) {
    main.innerHTML = threadViewHTML(thread);
    window.scrollTo(0, 0);
  } else {
    main.innerHTML = `
      <div class="t-tabs"><span class="tab active">${TAB_HOT} Hot</span><span class="tab">${TAB_NEW} New</span><span class="tab">${TAB_TOP} Top</span></div>
      ${subThreads.map(cardHTML).join("") || `<div class="t-empty">No posts in ${esc(validSub)} yet.</div>`}`;
  }
}

async function initThreadit() {
  [THREADS, SEASON] = await Promise.all([
    loadJSON("../data/threads.json"),
    loadJSON("../data/season.json")
  ]);
  document.getElementById("game-date").textContent = SEASON.currentDate;
  render();
  window.addEventListener("hashchange", render);
}

initThreadit().catch(err => {
  document.getElementById("main").innerHTML =
    `<div class="load-error">Could not load forum data (${esc(err.message)}). If you opened this file directly, serve it over HTTP instead.</div>`;
});
