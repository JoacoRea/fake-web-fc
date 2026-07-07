--[[
  automation/live-editor/export_every_5_matches.lua

  Runs INSIDE FC-26 Live Editor (Lua Engine -> Execute), DLL-injected into the
  running FC 26 process. Built on the REAL API used by the official example
  scripts shipped with the tool (verified against their source):
    - export_fixtures.lua      -> GetFCEDataManager() / GetValidStandings() /
                                  GetValidFixtures() / GetStandingsByIndex()
                                  (memory readers, copied verbatim below)
    - export_season_stats.lua  -> GetPlayersStats(), GetPlayerName(),
                                  GetTeamIdFromPlayerId(), avg-rating math
    - lua/scripts/vpro_always_starter.lua (FC-25) ->
                                  ENUM_CM_EVENT_MSG_USER_MATCH_COMPLETED etc.
                                  + the (events_manager, event_id, event)
                                  handler signature on post__CareerModeEvent

  Every time MATCHES_PER_EXPORT more club matches are completed (played or
  simmed), this writes a human-readable text report (league table, recent
  results, upcoming fixtures, top scorers) to a local file. No network calls,
  no tokens, no cloud dependency -- you open the file, copy its contents, and
  paste them into a Claude Code chat on the fake-web-fc repo, which turns it
  into new Chattr/Threadit content.

  See automation/live-editor/README.md for setup steps.
--]]

MEMORY = require 'imports/core/memory'
require 'imports/other/helpers'        -- GetTeamName, GetPlayerName, GetCurrentDate, IsInCM, ...
require 'imports/services/enums'       -- ENUM_djb2IFCEInterface_CLSS
require 'imports/career_mode/helpers'  -- GetCMEventNameByID
-- Career-mode event id enums (ENUM_CM_EVENT_MSG_*). Present in the tool's
-- install; if this require ever fails we fall back to matching event names.
pcall(function() require 'imports/career_mode/enums' end)

-- =====================================================================
-- CONFIG
-- =====================================================================
local CLUB_NAME          = "Chelsea"
local LEAGUE_NAME        = "Premier League" -- used to pick which table to print
local MATCHES_PER_EXPORT = 5
local OUTPUT_DIR         = string.format("%s\\Desktop\\", os.getenv('USERPROFILE') or ".")
local STATE_FILE         = OUTPUT_DIR .. "fake_web_fc_last_export.txt"
local TOP_SCORERS_CAP    = 10

-- =====================================================================
-- MEMORY READERS -- copied verbatim from the official export_fixtures.lua
-- =====================================================================

function GetFCEDataManager()
  local IFCEInterface = GetPlugin(ENUM_djb2IFCEInterface_CLSS)
  return MEMORY:ReadMultilevelPointer(IFCEInterface, {0x18, 0x10, 0x08, 0x00})
end

function GetValidStandings()
  local result = {}

  local FCEDataManager = GetFCEDataManager()
  local StandingsDataList = MEMORY:ReadPointer(FCEDataManager + 0x88)

  local itemSize = 0x18 -- sizeof(StandingsData)
  local mBegin = MEMORY:ReadPointer(StandingsDataList + 0x28)
  local max_items_count = MEMORY:ReadInt(StandingsDataList + 0x1C) - 1

  local mCurrent = 0
  for i = 0, max_items_count do
    mCurrent = mBegin + (itemSize*i)

    local is_used = MEMORY:ReadBool(mCurrent + 0x16)
    local mTeamId = MEMORY:ReadInt(mCurrent + 0x04)
    if is_used and mTeamId > 0 then
      local StandingsData = {}
      StandingsData["mId"] = MEMORY:ReadShort(mCurrent + 0x00)
      StandingsData["mCompObjId"] = MEMORY:ReadShort(mCurrent + 0x02)
      StandingsData["mTeamId"] = mTeamId
      StandingsData["mTeamIndex"] = MEMORY:ReadChar(mCurrent + 0x08)
      StandingsData["mHomeWins"] = MEMORY:ReadChar(mCurrent + 0x09)
      StandingsData["mHomeDraws"] = MEMORY:ReadChar(mCurrent + 0x0A)
      StandingsData["mHomeLosses"] = MEMORY:ReadChar(mCurrent + 0x0B)
      StandingsData["mHomeGoalsFor"] = MEMORY:ReadChar(mCurrent + 0x0C)
      StandingsData["mHomeGoalsAgainst"] = MEMORY:ReadChar(mCurrent + 0x0D)
      StandingsData["mAwayWins"] = MEMORY:ReadChar(mCurrent + 0x0E)
      StandingsData["mAwayDraws"] = MEMORY:ReadChar(mCurrent + 0x0F)
      StandingsData["mAwayLosses"] = MEMORY:ReadChar(mCurrent + 0x10)
      StandingsData["mAwayGoalsFor"] = MEMORY:ReadChar(mCurrent + 0x11)
      StandingsData["mAwayGoalsAgainst"] = MEMORY:ReadChar(mCurrent + 0x12)
      StandingsData["mPoints"] = MEMORY:ReadShort(mCurrent + 0x14)

      table.insert(result, StandingsData)
    end
  end

  return result
end

function GetStandingsByIndex(idx)
  local StandingsData = {}

  local FCEDataManager = GetFCEDataManager()
  local StandingsDataList = MEMORY:ReadPointer(FCEDataManager + 0x88)

  local itemSize = 0x18 -- sizeof(StandingsData)
  local mBegin = MEMORY:ReadPointer(StandingsDataList + 0x28)

  local mCurrent = mBegin + (itemSize*idx)

  StandingsData["mId"] = MEMORY:ReadShort(mCurrent + 0x00)
  StandingsData["mCompObjId"] = MEMORY:ReadShort(mCurrent + 0x02)
  StandingsData["mTeamId"] = MEMORY:ReadInt(mCurrent + 0x04)
  StandingsData["mPoints"] = MEMORY:ReadShort(mCurrent + 0x14)

  return StandingsData
end

function GetValidFixtures()
  local result = {}

  local FCEDataManager = GetFCEDataManager()
  local FixtureDataList = MEMORY:ReadPointer(FCEDataManager + 0x60)

  local itemSize = 0x18 -- sizeof(FixtureData)
  local mBegin = MEMORY:ReadPointer(FixtureDataList + 0x28)
  local max_items_count = MEMORY:ReadInt(FixtureDataList + 0x1C) - 1

  local mCurrent = 0
  for i = 0, max_items_count do
    mCurrent = mBegin + (itemSize*i)

    local is_used = MEMORY:ReadBool(mCurrent + 0x14)

    if is_used then
      local FixtureData = {}
      FixtureData["mDate"] = MEMORY:ReadInt(mCurrent + 0x00)
      FixtureData["mTime"] = MEMORY:ReadShort(mCurrent + 0x04)
      FixtureData["mId"] = MEMORY:ReadShort(mCurrent + 0x06)
      FixtureData["mCompObjId"] = MEMORY:ReadShort(mCurrent + 0x08)
      FixtureData["mHomeStandingId"] = MEMORY:ReadShort(mCurrent + 0x0A)
      FixtureData["mAwayStandingId"] = MEMORY:ReadShort(mCurrent + 0x0C)
      FixtureData["mMatchGroupId"] = MEMORY:ReadChar(mCurrent + 0x0E)
      FixtureData["mHomeScore"] = MEMORY:ReadChar(mCurrent + 0x0F)
      FixtureData["mHomePenalties"] = MEMORY:ReadChar(mCurrent + 0x10)
      FixtureData["mAwayScore"] = MEMORY:ReadChar(mCurrent + 0x11)
      FixtureData["mAwayPenalties"] = MEMORY:ReadChar(mCurrent + 0x12)
      FixtureData["mGameCompletion"] = MEMORY:ReadBool(mCurrent + 0x13)

      table.insert(result, FixtureData)
    end
  end

  return result
end

-- =====================================================================
-- DATE DECODING -- FixtureData.mDate is a raw int; its encoding is not
-- documented, so decode by shape and fall back to the raw value.
-- =====================================================================

-- days since 1970-01-01 -> y, m, d (Howard Hinnant's civil_from_days)
local function civil_from_days(z)
  z = z + 719468
  local era = math.floor(z / 146097)
  local doe = z - era * 146097
  local yoe = math.floor((doe - math.floor(doe/1460) + math.floor(doe/36524)
              - math.floor(doe/146096)) / 365)
  local y = yoe + era * 400
  local doy = doe - (365*yoe + math.floor(yoe/4) - math.floor(yoe/100))
  local mp = math.floor((5*doy + 2) / 153)
  local d = doy - math.floor((153*mp + 2) / 5) + 1
  local m = (mp < 10) and (mp + 3) or (mp - 9)
  if m <= 2 then y = y + 1 end
  return y, m, d
end

local function format_game_date(v)
  if type(v) ~= "number" or v <= 0 then return "?" end
  local y = math.floor(v / 10000)
  local m = math.floor(v / 100) % 100
  local d = v % 100
  if y >= 1900 and y <= 2100 and m >= 1 and m <= 12 and d >= 1 and d <= 31 then
    return string.format("%04d-%02d-%02d", y, m, d) -- looks like YYYYMMDD
  end
  if v >= 140000 and v <= 190000 then -- days since 1582-10-14 (classic FIFA epoch)
    local yy, mm, dd = civil_from_days(v - 141428)
    return string.format("%04d-%02d-%02d", yy, mm, dd)
  end
  if v >= 700000 and v <= 780000 then -- days since 0001-01-01
    local yy, mm, dd = civil_from_days(v - 719162)
    return string.format("%04d-%02d-%02d", yy, mm, dd)
  end
  return tostring(v) -- unknown encoding: raw value still sorts chronologically
end

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
-- DATA GATHERING
-- =====================================================================

local function get_comp_name(compobjid)
  local ok, name = pcall(function() return GetCompetitionNameByObjID(compobjid) end)
  if ok and name and name ~= "" then return name end
  return "comp#" .. tostring(compobjid)
end

local function get_team_name(teamid)
  local ok, name = pcall(function() return GetTeamName(teamid) end)
  if ok and name and name ~= "" then return name end
  return "team#" .. tostring(teamid)
end

-- Returns the club's team id and its standings rows (one per competition).
local function find_club(standings)
  local club_id, club_rows = nil, {}
  for _, row in ipairs(standings) do
    if club_id == nil and get_team_name(row.mTeamId) == CLUB_NAME then
      club_id = row.mTeamId
    end
  end
  if club_id then
    for _, row in ipairs(standings) do
      if row.mTeamId == club_id then table.insert(club_rows, row) end
    end
  end
  return club_id, club_rows
end

local function row_totals(row)
  local w = row.mHomeWins + row.mAwayWins
  local d = row.mHomeDraws + row.mAwayDraws
  local l = row.mHomeLosses + row.mAwayLosses
  local gf = row.mHomeGoalsFor + row.mAwayGoalsFor
  local ga = row.mHomeGoalsAgainst + row.mAwayGoalsAgainst
  return w, d, l, gf, ga
end

-- Picks which of the club's competitions is "the league": by name first,
-- falling back to the competition where the club has played the most games.
local function pick_league_compobjid(club_rows)
  local best_id, best_played = nil, -1
  for _, row in ipairs(club_rows) do
    local name = get_comp_name(row.mCompObjId):lower()
    if name:find(LEAGUE_NAME:lower(), 1, true) then
      return row.mCompObjId
    end
    local w, d, l = row_totals(row)
    if (w + d + l) > best_played then
      best_played = w + d + l
      best_id = row.mCompObjId
    end
  end
  return best_id
end

local function build_league_table(standings, league_compobjid)
  local computed = {}
  for _, row in ipairs(standings) do
    if row.mCompObjId == league_compobjid then
      local w, d, l, gf, ga = row_totals(row)
      table.insert(computed, {
        team = get_team_name(row.mTeamId),
        team_id = row.mTeamId,
        p = w + d + l, w = w, d = d, l = l,
        gd = gf - ga, pts = row.mPoints,
      })
    end
  end

  table.sort(computed, function(a, b)
    if a.pts ~= b.pts then return a.pts > b.pts end
    return a.gd > b.gd
  end)

  return computed
end

-- Splits the club's fixtures into completed and upcoming. Standing ids on a
-- fixture are indexes into the standings array (as in export_fixtures.lua);
-- resolved team ids are cached per call.
local function build_fixtures(club_team_id)
  local standing_cache = {}
  local function team_id_of_standing(idx)
    if standing_cache[idx] == nil then
      local ok, s = pcall(function() return GetStandingsByIndex(idx) end)
      standing_cache[idx] = (ok and s) and s.mTeamId or -1
    end
    return standing_cache[idx]
  end

  local ok, fixtures = pcall(GetValidFixtures)
  if not ok or not fixtures then
    print("[fake-web-fc] GetValidFixtures failed: " .. tostring(fixtures))
    return {}, {}
  end

  local completed, upcoming = {}, {}
  for _, fx in ipairs(fixtures) do
    local home_id = team_id_of_standing(fx.mHomeStandingId)
    local away_id = team_id_of_standing(fx.mAwayStandingId)
    if home_id == club_team_id or away_id == club_team_id then
      local entry = {
        date = fx.mDate,
        comp = get_comp_name(fx.mCompObjId),
        home_team = get_team_name(home_id),
        away_team = get_team_name(away_id),
        home = home_id == club_team_id,
        home_score = fx.mHomeScore,
        away_score = fx.mAwayScore,
      }
      if fx.mGameCompletion then
        table.insert(completed, entry)
      else
        table.insert(upcoming, entry)
      end
    end
  end

  local by_date = function(a, b) return (a.date or 0) < (b.date or 0) end
  table.sort(completed, by_date)
  table.sort(upcoming, by_date)

  return completed, upcoming
end

-- Aggregates GetPlayersStats() (per-competition rows) into season totals for
-- the club's players. avg-rating math follows export_season_stats.lua: the
-- raw value is a running sum of (rating * 10) across appearances.
local function build_top_scorers(club_team_id)
  local ok, all_stats = pcall(function() return GetPlayersStats() end)
  if not ok or not all_stats then
    print("[fake-web-fc] GetPlayersStats failed: " .. tostring(all_stats))
    return {}
  end

  local per_player = {}
  for i = 1, #all_stats do
    local stat = all_stats[i]
    local playerid = stat.playerid
    if playerid and playerid > 0 and playerid < 4294967295 and (stat.app or 0) > 0 then
      local ok2, team_id = pcall(function() return GetTeamIdFromPlayerId(playerid) end)
      if ok2 and team_id == club_team_id then
        local agg = per_player[playerid]
        if not agg then
          local ok3, name = pcall(function() return GetPlayerName(playerid) end)
          agg = {
            name = (ok3 and name and name ~= "") and name or ("player#" .. playerid),
            appearances = 0, goals = 0, assists = 0, motm = 0, raw_avg = 0,
          }
          per_player[playerid] = agg
        end
        agg.appearances = agg.appearances + stat.app
        agg.goals = agg.goals + (stat.goals or 0)
        agg.assists = agg.assists + (stat.assists or 0)
        agg.motm = agg.motm + (stat.motm or 0)
        agg.raw_avg = agg.raw_avg + (stat.avg or 0)
      end
    end
  end

  local list = {}
  for _, agg in pairs(per_player) do
    if agg.appearances > 0 then
      agg.avg_rating = string.format("%0.2f", (agg.raw_avg / agg.appearances) / 10)
    else
      agg.avg_rating = "?"
    end
    table.insert(list, agg)
  end

  table.sort(list, function(a, b) return (a.goals + a.assists) > (b.goals + b.assists) end)
  local top = {}
  for i = 1, math.min(TOP_SCORERS_CAP, #list) do
    table.insert(top, list[i])
  end
  return top
end

-- =====================================================================
-- TEXT REPORT -- human-readable, meant to be read and pasted by a person
-- =====================================================================

local function format_report(matches_played, new_matches, league_name, table_rows,
                             recent, upcoming, top_scorers)
  local lines = {}
  local function add(s) table.insert(lines, s or "") end

  local save_date = "?"
  local okd, cur = pcall(function() return GetCurrentDate() end)
  if okd and cur then
    save_date = string.format("%04d-%02d-%02d", cur.year, cur.month, cur.day)
  end

  add("=== FAKE-WEB-FC SAVE EXPORT ===")
  add("Generated: " .. os.date("%Y-%m-%d %H:%M") .. " (in-save date: " .. save_date .. ")")
  add(CLUB_NAME .. " - matches completed this season (all comps): " .. tostring(matches_played))
  add("")

  add("-- " .. string.upper(league_name or "LEAGUE") .. " TABLE --")
  for i, row in ipairs(table_rows) do
    local marker = (row.team == CLUB_NAME) and "  <-- US" or ""
    add(string.format(
      "%2d. %-22s P%-3d W%-2d D%-2d L%-2d GD%+4d Pts%3d%s",
      i, row.team, row.p, row.w, row.d, row.l, row.gd, row.pts, marker
    ))
  end
  add("")

  add(string.format("-- RECENT RESULTS (last %d) --", new_matches))
  if #recent == 0 then
    add("(none)")
  else
    for _, m in ipairs(recent) do
      add(string.format(
        "%s [%s] %s %d-%d %s",
        format_game_date(m.date), m.comp, m.home_team, m.home_score, m.away_score, m.away_team
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
        format_game_date(f.date), f.comp,
        f.home and "vs" or "@",
        f.home and f.away_team or f.home_team
      ))
    end
  end
  add("")

  add("-- TOP SCORERS / ASSISTS (season so far, all comps) --")
  if #top_scorers == 0 then
    add("(no stats found)")
  else
    for _, p in ipairs(top_scorers) do
      add(string.format(
        "%-22s Apps:%-3d Goals:%-3d Assists:%-3d Avg:%s MOTM:%d",
        p.name, p.appearances, p.goals, p.assists, p.avg_rating, p.motm
      ))
    end
  end
  add("")
  add("=== END OF EXPORT -- copy everything above into your Claude Code chat ===")

  return table.concat(lines, "\n")
end

local function write_report_file(text)
  local filename = OUTPUT_DIR
    .. string.format("fake_web_fc_export_%s.txt", os.date("%Y-%m-%d_%H-%M-%S"))

  local f = io.open(filename, "w")
  if not f then
    print("[fake-web-fc] Could not open file for writing: " .. filename)
    print("[fake-web-fc] Check that OUTPUT_DIR exists: " .. OUTPUT_DIR)
    return
  end
  f:write(text)
  f:close()

  print("[fake-web-fc] Export written to " .. filename)
  print("[fake-web-fc] Open it, copy everything, and paste into your Claude Code chat.")
end

-- =====================================================================
-- MAIN CHECK -- runs on match-completed / day-passed events
-- =====================================================================

local UPCOMING_FIXTURES_CAP = 8

local function run_export_check()
  if not IsInCM() then return end

  local ok, standings = pcall(GetValidStandings)
  if not ok or not standings then
    print("[fake-web-fc] GetValidStandings failed: " .. tostring(standings))
    return
  end

  local club_team_id, club_rows = find_club(standings)
  if not club_team_id then
    print("[fake-web-fc] Could not find '" .. CLUB_NAME .. "' in the standings.")
    return
  end

  local completed, upcoming = build_fixtures(club_team_id)
  local matches_played = #completed

  local last_export_count = read_last_export_count()
  if matches_played < last_export_count then
    -- fixture list restarted (new season / new save): re-arm quietly
    write_last_export_count(matches_played)
    return
  end
  local new_matches = matches_played - last_export_count
  if new_matches < MATCHES_PER_EXPORT then
    return -- not enough new matches yet, stay quiet
  end

  print(string.format(
    "[fake-web-fc] %d new matches completed since last export -- generating report.",
    new_matches
  ))

  local league_compobjid = pick_league_compobjid(club_rows)
  local league_name = league_compobjid and get_comp_name(league_compobjid) or "league"
  local table_rows = build_league_table(standings, league_compobjid)

  local recent = {}
  for i = math.max(1, #completed - new_matches + 1), #completed do
    table.insert(recent, completed[i])
  end
  local next_up = {}
  for i = 1, math.min(UPCOMING_FIXTURES_CAP, #upcoming) do
    table.insert(next_up, upcoming[i])
  end

  local top_scorers = build_top_scorers(club_team_id)
  local report = format_report(matches_played, new_matches, league_name,
                               table_rows, recent, next_up, top_scorers)

  write_report_file(report)
  write_last_export_count(matches_played)
end

-- =====================================================================
-- EVENT HOOK -- post__CareerModeEvent fires for every CM action; we react
-- to completed matches, plus day-passed so simmed matches are caught too.
-- =====================================================================

local function is_interesting_event(event_id)
  if ENUM_CM_EVENT_MSG_USER_MATCH_COMPLETED ~= nil then
    return event_id == ENUM_CM_EVENT_MSG_USER_MATCH_COMPLETED
        or event_id == ENUM_CM_EVENT_MSG_USER_MATCH_COMPLETED_IN_TOURNAMENT
        or event_id == ENUM_CM_EVENT_MSG_DAY_PASSED
  end
  -- enums unavailable: fall back to the event name (as printed by the
  -- official track_cm_events.lua)
  local ok, name = pcall(function() return GetCMEventNameByID(event_id) end)
  if not ok or type(name) ~= "string" then return false end
  return name:find("MATCH_COMPLETED", 1, true) ~= nil
      or name:find("DAY_PASSED", 1, true) ~= nil
end

local function on_career_mode_event(events_manager, event_id, event)
  if not is_interesting_event(event_id) then return end
  local ok, err = pcall(run_export_check)
  if not ok then
    print("[fake-web-fc] export check failed: " .. tostring(err))
  end
end

AddEventHandler("post__CareerModeEvent", on_career_mode_event)

print("[fake-web-fc] export_every_5_matches.lua loaded.")
print("[fake-web-fc] Will export a report every " .. MATCHES_PER_EXPORT .. " completed matches.")
print("[fake-web-fc] Output folder: " .. OUTPUT_DIR)
if ENUM_CM_EVENT_MSG_USER_MATCH_COMPLETED == nil then
  print("[fake-web-fc] NOTE: career_mode/enums not found -- matching events by name instead.")
end

-- Also check immediately on execute, so a pending export isn't missed if the
-- script wasn't loaded when the 5th match finished.
if IsInCM() then
  local ok, err = pcall(run_export_check)
  if not ok then
    print("[fake-web-fc] initial check failed: " .. tostring(err))
  end
end
