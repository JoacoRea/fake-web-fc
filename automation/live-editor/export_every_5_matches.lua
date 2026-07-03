--[[
  automation/live-editor/export_every_5_matches.lua

  Runs INSIDE FC-26 Live Editor (Lua Engine -> Execute), DLL-injected into the
  running FC 26 process. Adapted from the official example scripts shipped in
  that tool's own `lua/` folder:
    - export_fixtures.lua      -> GetFCEDataManager(), GetValidStandings(), GetValidFixtures()
    - export_season_stats.lua  -> per-player season stat reads
    - track_cm_events.lua      -> AddEventHandler("pre__CareerModeEvent", ...) pattern

  Every time 5 more matches have been played since the last export, this writes
  a human-readable text report (table, recent results, upcoming fixtures, top
  scorers) to a local file. No network calls, no tokens, no cloud dependency --
  you open the file, copy its contents, and paste them into a Claude Code chat
  on the fake-web-fc repo, which turns it into new Chattr/Threadit content.

  See automation/live-editor/README.md for setup + calibration steps.

  IMPORTANT: field names below (row.WinsHome, mgr:GetSquadPlayers, etc.) are a
  best-faith reconstruction from the documented behaviour of the official
  export_fixtures.lua / export_season_stats.lua scripts, not their literal
  source. Cross-check against your local copies of those two files and adjust
  field names if they differ before relying on this.
--]]

-- =====================================================================
-- CONFIG
-- =====================================================================
local CLUB_NAME       = "Chelsea"
local MATCHES_PER_EXPORT = 5
local OUTPUT_DIR      = "" -- empty = write next to this script; or set an
                            -- absolute path e.g. "C:\\Users\\you\\Desktop\\"
local STATE_FILE      = "fake_web_fc_last_export.txt" -- written next to this script
local TOP_SCORERS_CAP = 10

-- =====================================================================
-- CALIBRATION -- the ONE placeholder you must discover yourself.
-- Run the official track_cm_events.lua once, play/sim one match, read the
-- printed event names in the Live Editor console, and find the one that
-- corresponds to "a match just finished" (not documented publicly).
-- =====================================================================
local TARGET_EVENT_NAME = "REPLACE_WITH_CALIBRATED_EVENT_NAME"

-- =====================================================================
-- STATE (only export once every MATCHES_PER_EXPORT new matches played)
-- =====================================================================
local function read_last_export_count()
  local f = io.open(STATE_FILE, "r")
  if not f then return 0 end
  local contents = f:read("*a")
  f:close()
  return tonumber(contents) or 0
end

local function write_last_export_count(n)
  local f = io.open(STATE_FILE, "w")
  if f then
    f:write(tostring(n))
    f:close()
  else
    print("[fake-web-fc] WARNING: could not write state file " .. STATE_FILE)
  end
end

-- =====================================================================
-- DATA READING -- adapted from export_fixtures.lua / export_season_stats.lua
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
    return nil, -1
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

  local club_played = -1
  for _, row in ipairs(computed) do
    if row.team_id == club_team_id then
      club_played = row.p
      break
    end
  end

  return computed, club_played
end

local function build_fixtures_and_form(mgr, club_team_id)
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
        table.insert(played, {
          date = fx.Date,
          comp = fx.CompetitionName or fx.Competition,
          home_team = fx.HomeTeamName or fx.HomeTeam,
          away_team = fx.AwayTeamName or fx.AwayTeam,
          home_score = fx.HomeScore,
          away_score = fx.AwayScore,
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

  return upcoming, played
end

local function build_top_scorers(mgr, club_team_id)
  local ok, players = pcall(function() return mgr:GetSquadPlayers(club_team_id) end)
  if not ok or not players then
    print("[fake-web-fc] GetSquadPlayers failed: " .. tostring(players))
    return {}
  end

  local stats = {}
  for _, player in ipairs(players) do
    local ok2, s = pcall(function() return mgr:GetPlayerSeasonStats(player.PlayerId) end)
    if ok2 and s then
      table.insert(stats, {
        name = player.Name or player.LastName,
        appearances = s.Appearances or 0,
        goals = s.Goals or 0,
        assists = s.Assists or 0,
        avg_rating = s.AverageRating or s.AvgRating,
        motm = s.ManOfTheMatch or s.MOTM or 0,
      })
    end
  end

  table.sort(stats, function(a, b) return (a.goals + a.assists) > (b.goals + b.assists) end)
  local top = {}
  for i = 1, math.min(TOP_SCORERS_CAP, #stats) do
    table.insert(top, stats[i])
  end
  return top
end

-- =====================================================================
-- TEXT REPORT -- human-readable, meant to be read and pasted by a person
-- =====================================================================

local function format_report(club_played, table_rows, upcoming, played, top_scorers)
  local lines = {}
  local function add(s) table.insert(lines, s or "") end

  add("=== FAKE-WEB-FC SAVE EXPORT ===")
  add("Generated: " .. os.date("%Y-%m-%d %H:%M"))
  add(CLUB_NAME .. " - matches played: " .. tostring(club_played))
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

  add("-- RECENT RESULTS (since last export) --")
  if #played == 0 then
    add("(none)")
  else
    for _, m in ipairs(played) do
      add(string.format(
        "%s [%s] %s %d-%d %s",
        m.date or "?", m.comp or "?", m.home_team or "?", m.home_score, m.away_score, m.away_team or "?"
      ))
    end
  end
  add("")

  add("-- UPCOMING FIXTURES --")
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

  add("-- TOP SCORERS / ASSISTS (season so far) --")
  for _, p in ipairs(top_scorers) do
    add(string.format(
      "%-20s Apps:%-3d Goals:%-3d Assists:%-3d Avg:%s MOTM:%d",
      p.name or "?", p.appearances, p.goals, p.assists,
      tostring(p.avg_rating or "?"), p.motm
    ))
  end
  add("")
  add("=== END OF EXPORT -- copy everything above into your Claude Code chat ===")

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
-- EVENT HOOK
-- =====================================================================

local function on_career_mode_event(event_id)
  local ok, event_name = pcall(function() return GetCMEventNameByID(event_id) end)
  if not ok or event_name ~= TARGET_EVENT_NAME then
    return -- not the event we care about; CareerModeEvent fires constantly
  end

  local mgr_ok, mgr = pcall(function() return GetFCEDataManager() end)
  if not mgr_ok or not mgr then
    print("[fake-web-fc] Could not get data manager, skipping this check.")
    return
  end

  local club_team_id = find_team_id_by_name(mgr, CLUB_NAME)
  if not club_team_id then
    print("[fake-web-fc] Could not resolve team id for '" .. CLUB_NAME .. "'.")
    return
  end

  local table_rows, club_played = build_table(mgr, club_team_id)
  if not table_rows then return end

  local last_export_count = read_last_export_count()
  if (club_played - last_export_count) < MATCHES_PER_EXPORT then
    return -- not 5 new matches yet, stay quiet
  end

  print(string.format(
    "[fake-web-fc] %d new matches played since last export -- generating report.",
    club_played - last_export_count
  ))

  local upcoming, played = build_fixtures_and_form(mgr, club_team_id)
  local top_scorers = build_top_scorers(mgr, club_team_id)
  local report = format_report(club_played, table_rows, upcoming, played, top_scorers)

  write_report_file(report)
  write_last_export_count(club_played)
end

-- =====================================================================
-- REGISTER + STARTUP MESSAGE
-- =====================================================================

AddEventHandler("pre__CareerModeEvent", on_career_mode_event)

print("[fake-web-fc] export_every_5_matches.lua loaded.")
print("[fake-web-fc] Watching for CareerMode event: " .. tostring(TARGET_EVENT_NAME))
print("[fake-web-fc] Will export a report every " .. MATCHES_PER_EXPORT .. " matches played.")
if TARGET_EVENT_NAME == "REPLACE_WITH_CALIBRATED_EVENT_NAME" then
  print("[fake-web-fc] WARNING: TARGET_EVENT_NAME is still a placeholder! Run track_cm_events.lua first.")
end
