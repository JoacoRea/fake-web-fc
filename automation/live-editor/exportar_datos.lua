--[[
  automation/live-editor/exportar_datos.lua

  MANUAL export -- the recommended workflow. Runs INSIDE FC-26 Live Editor
  (Lua Engine -> Execute) and immediately writes a text report next to this
  script: league table, last N results, next N fixtures, and season stats
  for the whole squad. No event hooks, no counters, no state file -- you
  decide when there's enough new material for a site update, you run it,
  you paste the .txt into a Claude Code chat on the fake-web-fc repo.

  Its sibling export_every_5_matches.lua is the automatic (event-driven)
  variant of the same idea; both share the same data-reading approach.

  IMPORTANT: field names below (row.WinsHome, mgr:GetSquadPlayers, etc.) are
  a best-faith reconstruction from the documented behaviour of the official
  export_fixtures.lua / export_season_stats.lua scripts, not their literal
  source. Cross-check against your local copies of those two files and
  adjust field names if they differ before relying on this.
--]]

-- =====================================================================
-- CONFIG
-- =====================================================================
local CLUB_NAME   = "Chelsea"
local LAST_N      = 5   -- how many recent results to include
local NEXT_N      = 5   -- how many upcoming fixtures to include
local OUTPUT_DIR  = ""  -- empty = write next to this script; or set an
                        -- absolute path e.g. "C:\\Users\\you\\Desktop\\"
local TOP_CONTRIBUTORS = 10  -- top players by goals+assists
local TOP_RATED        = 5   -- top players by average rating
local MIN_APPS_FOR_RATING = 8 -- ignore tiny samples in the ratings ranking

-- =====================================================================
-- DATA READING -- same approach as export_every_5_matches.lua
-- =====================================================================

local function find_team_id_by_name(mgr, name)
  local ok, teams = pcall(function() return mgr:GetTeams() end)
  if not ok or not teams then return nil end
  for _, team in ipairs(teams) do
    if team.Name == name or team.TeamName == name then
      return team.TeamId or team.Id
    end
  end
  return nil
end

local function build_table(mgr, club_team_id)
  local ok, raw_rows = pcall(function() return GetValidStandings(mgr) end)
  if not ok or not raw_rows then
    print("[fake-web-fc] GetValidStandings failed: " .. tostring(raw_rows))
    return nil
  end

  local computed = {}
  for _, row in ipairs(raw_rows) do
    local w = (row.WinsHome or 0) + (row.WinsAway or 0)
    local d = (row.DrawsHome or 0) + (row.DrawsAway or 0)
    local l = (row.LossesHome or 0) + (row.LossesAway or 0)
    local gf = (row.GoalsForHome or 0) + (row.GoalsForAway or 0)
    local ga = (row.GoalsAgainstHome or 0) + (row.GoalsAgainstAway or 0)
    table.insert(computed, {
      team = row.TeamName or row.Name,
      team_id = row.TeamId or row.Id,
      p = w + d + l, w = w, d = d, l = l,
      gd = gf - ga, pts = (w * 3) + d,
    })
  end

  table.sort(computed, function(a, b)
    if a.pts ~= b.pts then return a.pts > b.pts end
    return a.gd > b.gd
  end)

  return computed
end

local function build_fixtures_and_results(mgr, club_team_id)
  local ok, raw_fixtures = pcall(function() return GetValidFixtures(mgr) end)
  if not ok or not raw_fixtures then
    print("[fake-web-fc] GetValidFixtures failed: " .. tostring(raw_fixtures))
    return {}, {}
  end

  local upcoming, played = {}, {}
  for _, fx in ipairs(raw_fixtures) do
    local is_home = fx.HomeTeamId == club_team_id
    local is_away = fx.AwayTeamId == club_team_id
    if is_home or is_away then
      local has_score = fx.HomeScore ~= nil and fx.AwayScore ~= nil
        and fx.HomeScore ~= -1 and fx.AwayScore ~= -1
      if has_score then
        local our_score   = is_home and fx.HomeScore or fx.AwayScore
        local their_score = is_home and fx.AwayScore or fx.HomeScore
        local outcome = (our_score > their_score) and "W"
          or (our_score < their_score) and "L" or "D"
        table.insert(played, {
          date = fx.Date,
          comp = fx.CompetitionName or fx.Competition,
          home_team = fx.HomeTeamName or fx.HomeTeam,
          away_team = fx.AwayTeamName or fx.AwayTeam,
          home_score = fx.HomeScore,
          away_score = fx.AwayScore,
          outcome = outcome,
        })
      else
        table.insert(upcoming, {
          comp = fx.CompetitionName or fx.Competition,
          date = fx.Date,
          opponent = is_home and (fx.AwayTeamName or fx.AwayTeam)
                              or (fx.HomeTeamName or fx.HomeTeam),
          home = is_home,
        })
      end
    end
  end

  table.sort(played, function(a, b) return (a.date or "") < (b.date or "") end)
  table.sort(upcoming, function(a, b) return (a.date or "") < (b.date or "") end)

  -- keep only the LAST_N most recent results and NEXT_N nearest fixtures
  local recent = {}
  for i = math.max(1, #played - LAST_N + 1), #played do
    table.insert(recent, played[i])
  end
  local next_up = {}
  for i = 1, math.min(NEXT_N, #upcoming) do
    table.insert(next_up, upcoming[i])
  end

  return next_up, recent
end

local function build_squad_stats(mgr, club_team_id)
  local ok, players = pcall(function() return mgr:GetSquadPlayers(club_team_id) end)
  if not ok or not players then
    print("[fake-web-fc] GetSquadPlayers failed: " .. tostring(players))
    return {}
  end

  local stats = {}
  for _, player in ipairs(players) do
    local ok2, s = pcall(function() return mgr:GetPlayerSeasonStats(player.PlayerId) end)
    if ok2 and s and (s.Appearances or 0) > 0 then
      table.insert(stats, {
        name = player.Name or player.LastName,
        appearances = s.Appearances or 0,
        goals = s.Goals or 0,
        assists = s.Assists or 0,
        avg_rating = tonumber(s.AverageRating or s.AvgRating) or 0,
        motm = s.ManOfTheMatch or s.MOTM or 0,
      })
    end
  end
  return stats
end

-- =====================================================================
-- TEXT REPORT
-- =====================================================================

local function format_report(table_rows, upcoming, recent, squad)
  local lines = {}
  local function add(s) table.insert(lines, s or "") end

  add("=== FAKE-WEB-FC SAVE EXPORT (manual) ===")
  add("Generated: " .. os.date("%Y-%m-%d %H:%M"))
  add("")

  add("-- LEAGUE TABLE --")
  for i, row in ipairs(table_rows) do
    local marker = (row.team == CLUB_NAME) and "  <-- US" or ""
    add(string.format(
      "%2d. %-20s P%-3d W%-2d D%-2d L%-2d GD%+4d Pts%3d%s",
      i, row.team, row.p, row.w, row.d, row.l, row.gd, row.pts, marker
    ))
  end
  add("")

  add(string.format("-- LAST %d RESULTS (all competitions) --", LAST_N))
  if #recent == 0 then
    add("(none)")
  else
    local form = {}
    for _, m in ipairs(recent) do
      add(string.format(
        "%s [%s] %s %d-%d %s  (%s)",
        m.date or "?", m.comp or "?", m.home_team or "?",
        m.home_score, m.away_score, m.away_team or "?", m.outcome
      ))
      table.insert(form, m.outcome)
    end
    add("Form: " .. table.concat(form, " "))
  end
  add("")

  add(string.format("-- NEXT %d FIXTURES --", NEXT_N))
  if #upcoming == 0 then
    add("(none)")
  else
    for _, f in ipairs(upcoming) do
      add(string.format(
        "%s [%s] %s %s",
        f.date or "?", f.comp or "?", f.home and "vs" or "@", f.opponent or "?"
      ))
    end
  end
  add("")

  add(string.format("-- TOP %d BY GOALS+ASSISTS (season) --", TOP_CONTRIBUTORS))
  table.sort(squad, function(a, b) return (a.goals + a.assists) > (b.goals + b.assists) end)
  for i = 1, math.min(TOP_CONTRIBUTORS, #squad) do
    local p = squad[i]
    add(string.format(
      "%-20s Apps:%-3d Goals:%-3d Assists:%-3d Avg:%-4s MOTM:%d",
      p.name or "?", p.appearances, p.goals, p.assists,
      tostring(p.avg_rating), p.motm
    ))
  end
  add("")

  add(string.format("-- TOP %d BY AVG RATING (min %d apps) --", TOP_RATED, MIN_APPS_FOR_RATING))
  local rated = {}
  for _, p in ipairs(squad) do
    if p.appearances >= MIN_APPS_FOR_RATING then table.insert(rated, p) end
  end
  table.sort(rated, function(a, b) return a.avg_rating > b.avg_rating end)
  for i = 1, math.min(TOP_RATED, #rated) do
    local p = rated[i]
    add(string.format(
      "%-20s Avg:%-4s Apps:%-3d MOTM:%d",
      p.name or "?", tostring(p.avg_rating), p.appearances, p.motm
    ))
  end
  add("")
  add("=== END OF EXPORT ===")
  add("Copy everything above into your Claude Code chat, plus anything the")
  add("game's memory can't capture: transfers, injuries, dressing-room drama,")
  add("cup runs in other competitions, whatever should shape the posts.")

  return table.concat(lines, "\n")
end

local function write_report_file(text)
  local dir = OUTPUT_DIR
  if dir ~= "" and not dir:match("[/\\]$") then
    dir = dir .. "\\"
  end
  local filename = dir .. string.format("fake_web_fc_export_%s.txt", os.date("%Y-%m-%d_%H-%M-%S"))

  local f = io.open(filename, "w")
  if not f then
    print("[fake-web-fc] Could not open file for writing: " .. filename)
    print("[fake-web-fc] Check that OUTPUT_DIR (if set) exists and is correct.")
    return
  end
  f:write(text)
  f:close()

  print("[fake-web-fc] Export written to " .. filename)
  print("[fake-web-fc] Open it, copy everything, and paste into your Claude Code chat.")
end

-- =====================================================================
-- RUN IMMEDIATELY -- no event hook: executing the script IS the trigger
-- =====================================================================

local mgr_ok, mgr = pcall(function() return GetFCEDataManager() end)
if not mgr_ok or not mgr then
  print("[fake-web-fc] Could not get data manager. Is a career save loaded?")
  return
end

local club_team_id = find_team_id_by_name(mgr, CLUB_NAME)
if not club_team_id then
  print("[fake-web-fc] Could not resolve team id for '" .. CLUB_NAME .. "'.")
  return
end

local table_rows = build_table(mgr, club_team_id)
if not table_rows then return end

local upcoming, recent = build_fixtures_and_results(mgr, club_team_id)
local squad = build_squad_stats(mgr, club_team_id)

write_report_file(format_report(table_rows, upcoming, recent, squad))
