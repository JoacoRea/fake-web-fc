--[[
  automation/live-editor/export_every_5_matches.lua

  AUTOMATIC variant of exportar_datos.lua (the manual export, which is the
  recommended workflow -- see README.md). Execute this once per play
  session from Lua Engine and it stays resident: every time 5 more
  matches have been played since the last export, it writes the same text
  report to your Desktop. The match-count state persists in a small file
  so the counter survives game restarts.

  Trigger: Career Mode Event 137, misleadingly named "JOB_OFFER_ACCEPTED",
  which fires exactly once at the final whistle (discovered with the
  official track_cm_events.lua; ~20s later comes the post-match world-
  update burst of CPU_TRANSFER_INFO / BOARD_EMAIL_EVENT / ABOUT_TO_INIT_MODE).
  If it ever fires in some other context, the match counter makes that a
  harmless no-op.

  The memory-reading plumbing is copied verbatim from the official
  lua/export_fixtures.lua; season stats follow lua/export_season_stats.lua.
--]]

MEMORY = require 'imports/core/memory'
require 'imports/other/helpers'
require 'imports/services/enums'
require 'imports/career_mode/helpers'

assert(IsInCM(), "Script must be executed in career mode")

-- =====================================================================
-- CONFIG
-- =====================================================================
local CLUB_NAME  = "Chelsea"
-- There are TWO teams named "Chelsea" in the game world (men's and women's);
-- the league name pins down which one we mean. See exportar_datos.lua.
local LEAGUE_NAME = "Premier League"
local MATCHES_PER_EXPORT = 5
local LAST_N     = 5   -- how many recent results to include in the report
local NEXT_N     = 5   -- how many upcoming fixtures to include
local TOP_CONTRIBUTORS    = 10
local TOP_RATED           = 5
local MIN_APPS_FOR_RATING = 8
local OUTPUT_DIR = "C:\\Games\\Exports\\"
local STATE_FILE = OUTPUT_DIR .. "fake_web_fc_last_export.txt"

local TARGET_EVENT_NAME = "JOB_OFFER_ACCEPTED"

-- =====================================================================
-- MEMORY PLUMBING -- copied from the official export_fixtures.lua
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

    StandingsData["mTeamId"] = MEMORY:ReadInt(mCurrent + 0x04)

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
-- DATE HELPERS -- same heuristics as exportar_datos.lua
-- =====================================================================

local LILIAN_TO_JDN = 2299160 -- lilian day 1 == JDN 2299161 == 1582-10-15

local function jdn_to_ymd(jdn)
    local a = jdn + 32044
    local b = math.floor((4*a + 3) / 146097)
    local c = a - math.floor(146097*b / 4)
    local d = math.floor((4*c + 3) / 1461)
    local e = c - math.floor(1461*d / 4)
    local m = math.floor((5*e + 2) / 153)
    local day = e - math.floor((153*m + 2) / 5) + 1
    local month = m + 3 - 12*math.floor(m/10)
    local year = 100*b + d - 4800 + math.floor(m/10)
    return year, month, day
end

local function ymd_to_jdn(y, m, d)
    local a = math.floor((14 - m) / 12)
    local yy = y + 4800 - a
    local mm = m + 12*a - 3
    return d + math.floor((153*mm + 2) / 5) + 365*yy
        + math.floor(yy/4) - math.floor(yy/100) + math.floor(yy/400) - 32045
end

local function format_game_date(raw)
    if raw >= 19000000 and raw <= 30001231 then -- looks like yyyymmdd
        return string.format("%04d-%02d-%02d",
            math.floor(raw/10000), math.floor(raw/100) % 100, raw % 100)
    elseif raw > 100000 and raw < 400000 then -- looks like a lilian day count
        local y, m, d = jdn_to_ymd(raw + LILIAN_TO_JDN)
        return string.format("%04d-%02d-%02d", y, m, d)
    end
    return tostring(raw)
end

local function today_as_gamedate(raw_sample)
    local cur = GetCurrentDate()
    if raw_sample >= 19000000 and raw_sample <= 30001231 then
        return cur.year*10000 + cur.month*100 + cur.day
    elseif raw_sample > 100000 and raw_sample < 400000 then
        return ymd_to_jdn(cur.year, cur.month, cur.day) - LILIAN_TO_JDN
    end
    return nil -- unknown encoding: don't filter by date
end

-- =====================================================================
-- DATA GATHERING -- same approach as exportar_datos.lua
-- =====================================================================

local team_name_cache = {}
local function team_name(id)
    if team_name_cache[id] == nil then
        local ok, name = pcall(function() return GetTeamName(id) end)
        team_name_cache[id] = (ok and name) or ("Team " .. tostring(id))
    end
    return team_name_cache[id]
end

local function row_played(row)
    return row.mHomeWins + row.mHomeDraws + row.mHomeLosses
         + row.mAwayWins + row.mAwayDraws + row.mAwayLosses
end

-- Team id and competition id must come from the SAME standings row (the two
-- same-named Chelsea teams can otherwise split between sections). Prefer the
-- row whose competition name matches LEAGUE_NAME; fall back to most played.
local function find_club_and_league(standings)
    local best_row, named_row = nil, nil
    for _, row in ipairs(standings) do
        if team_name(row.mTeamId) == CLUB_NAME then
            if best_row == nil or row_played(row) > row_played(best_row) then
                best_row = row
            end
            if named_row == nil and LEAGUE_NAME ~= "" then
                local ok, comp = pcall(function()
                    return GetCompetitionNameByObjID(row.mCompObjId)
                end)
                if ok and comp and string.find(comp, LEAGUE_NAME, 1, true) then
                    named_row = row
                end
            end
        end
    end
    local row = named_row or best_row
    if not row then return nil, nil end
    return row.mTeamId, row.mCompObjId
end

local function build_league_table(standings, league_comp)
    local rows = {}
    for _, row in ipairs(standings) do
        if row.mCompObjId == league_comp then
            local w = row.mHomeWins + row.mAwayWins
            local d = row.mHomeDraws + row.mAwayDraws
            local l = row.mHomeLosses + row.mAwayLosses
            local gf = row.mHomeGoalsFor + row.mAwayGoalsFor
            local ga = row.mHomeGoalsAgainst + row.mAwayGoalsAgainst
            table.insert(rows, {
                team = team_name(row.mTeamId),
                p = w + d + l, w = w, d = d, l = l,
                gd = gf - ga, pts = row.mPoints,
            })
        end
    end
    table.sort(rows, function(a, b)
        if a.pts ~= b.pts then return a.pts > b.pts end
        return a.gd > b.gd
    end)
    return rows
end

local function build_fixtures_and_results(fixtures, club_id)
    local upcoming, played = {}, {}

    for _, fx in ipairs(fixtures) do
        local ok, home_id, away_id = pcall(function()
            return GetStandingsByIndex(fx.mHomeStandingId).mTeamId,
                   GetStandingsByIndex(fx.mAwayStandingId).mTeamId
        end)
        if ok and (home_id == club_id or away_id == club_id) then
            local is_home = home_id == club_id
            local comp_ok, comp = pcall(function()
                return GetCompetitionNameByObjID(fx.mCompObjId)
            end)
            local entry = {
                date = fx.mDate,
                comp = (comp_ok and comp) or ("Comp " .. tostring(fx.mCompObjId)),
                home_team = team_name(home_id),
                away_team = team_name(away_id),
                home = is_home,
                opponent = team_name(is_home and away_id or home_id),
            }
            if fx.mGameCompletion then
                entry.home_score = fx.mHomeScore
                entry.away_score = fx.mAwayScore
                entry.home_pens = fx.mHomePenalties
                entry.away_pens = fx.mAwayPenalties
                local ours   = is_home and fx.mHomeScore or fx.mAwayScore
                local theirs = is_home and fx.mAwayScore or fx.mHomeScore
                entry.outcome = (ours > theirs) and "W" or (ours < theirs) and "L" or "D"
                table.insert(played, entry)
            else
                table.insert(upcoming, entry)
            end
        end
    end

    table.sort(played, function(a, b) return a.date < b.date end)
    table.sort(upcoming, function(a, b) return a.date < b.date end)

    local recent = {}
    for i = math.max(1, #played - LAST_N + 1), #played do
        table.insert(recent, played[i])
    end
    local today = (#upcoming > 0) and today_as_gamedate(upcoming[1].date) or nil
    local next_up = {}
    for _, f in ipairs(upcoming) do
        if #next_up >= NEXT_N then break end
        if today == nil or f.date >= today then
            table.insert(next_up, f)
        end
    end

    -- #played doubles as the total-matches counter for the export trigger
    return next_up, recent, #played
end

local function build_squad_stats(club_id)
    local ok, all_stats = pcall(function() return GetPlayersStats() end)
    if not ok or not all_stats then
        print("[fake-web-fc] GetPlayersStats failed: " .. tostring(all_stats))
        return {}
    end

    local team_of = {}
    local totals = {}
    for i = 1, #all_stats do
        local s = all_stats[i]
        local pid = s.playerid
        if pid and pid > 0 and pid < 4294967295 and (s.app or 0) > 0 then
            if team_of[pid] == nil then
                local ok2, tid = pcall(function() return GetTeamIdFromPlayerId(pid) end)
                team_of[pid] = (ok2 and tid) or -1
            end
            if team_of[pid] == club_id then
                local t = totals[pid] or { app = 0, rated_app = 0, goals = 0, assists = 0, motm = 0, rating_pts = 0 }
                t.app = t.app + s.app
                t.goals = t.goals + (s.goals or 0)
                t.assists = t.assists + (s.assists or 0)
                t.motm = t.motm + (s.motm or 0)
                -- Some rows carry avg=0; average only over rated appearances
                -- (see exportar_datos.lua).
                if (s.avg or 0) > 0 then
                    t.rated_app = t.rated_app + s.app
                    t.rating_pts = t.rating_pts + s.avg / 10
                end
                totals[pid] = t
            end
        end
    end

    local list = {}
    for pid, t in pairs(totals) do
        local ok3, pname = pcall(function() return GetPlayerName(pid) end)
        table.insert(list, {
            name = (ok3 and pname) or ("Player " .. tostring(pid)),
            appearances = t.app,
            goals = t.goals,
            assists = t.assists,
            motm = t.motm,
            avg_rating = t.rated_app > 0 and (t.rating_pts / t.rated_app) or 0,
        })
    end
    return list
end

-- =====================================================================
-- TEXT REPORT -- same layout as exportar_datos.lua
-- =====================================================================

local function score_string(m)
    local s = string.format("%d-%d", m.home_score, m.away_score)
    local hp, ap = m.home_pens or 0, m.away_pens or 0
    -- 255 (0xFF) is the game's "no shootout" sentinel, not a real pen count
    if hp < 100 and ap < 100 and (hp + ap) > 0 then
        s = s .. string.format(" (%d-%d pens)", hp, ap)
    end
    return s
end

local function format_report(table_rows, upcoming, recent, squad)
    local lines = {}
    local function add(s) table.insert(lines, s or "") end

    add("=== FAKE-WEB-FC SAVE EXPORT (auto, every " .. MATCHES_PER_EXPORT .. " matches) ===")
    add("Generated: " .. os.date("%Y-%m-%d %H:%M"))
    local cur = GetCurrentDate()
    add(string.format("In-game date: %04d-%02d-%02d", cur.year, cur.month, cur.day))
    add("")

    add("-- LEAGUE TABLE --")
    for i, row in ipairs(table_rows) do
        local marker = (row.team == CLUB_NAME) and "  <-- US" or ""
        add(string.format(
            "%2d. %-22s P%-3d W%-2d D%-2d L%-2d GD%+4d Pts%3d%s",
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
                "%s [%s] %s %s %s  (%s)",
                format_game_date(m.date), m.comp, m.home_team, score_string(m),
                m.away_team, m.outcome
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
                format_game_date(f.date), f.comp, f.home and "vs" or "@", f.opponent
            ))
        end
    end
    add("")

    add(string.format("-- TOP %d BY GOALS+ASSISTS (season, all comps) --", TOP_CONTRIBUTORS))
    table.sort(squad, function(a, b) return (a.goals + a.assists) > (b.goals + b.assists) end)
    for i = 1, math.min(TOP_CONTRIBUTORS, #squad) do
        local p = squad[i]
        add(string.format(
            "%-24s Apps:%-3d Goals:%-3d Assists:%-3d Avg:%.2f MOTM:%d",
            p.name, p.appearances, p.goals, p.assists, p.avg_rating, p.motm
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
            "%-24s Avg:%.2f Apps:%-3d MOTM:%d",
            p.name, p.avg_rating, p.appearances, p.motm
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
    local filename = OUTPUT_DIR .. string.format(
        "fake_web_fc_export_%s.txt", os.date("%Y-%m-%d_%H-%M-%S"))

    local f = io.open(filename, "w+")
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
-- EVENT HOOK -- handler signature as in the official track_cm_events.lua
-- =====================================================================

local function on_career_mode_event(events_manager, event_id, event)
    local ok, event_name = pcall(function() return GetCMEventNameByID(event_id) end)
    if not ok or event_name ~= TARGET_EVENT_NAME then
        return -- not the event we care about; CareerModeEvent fires constantly
    end

    local standings = GetValidStandings()
    if #standings == 0 then return end

    local club_id, league_comp = find_club_and_league(standings)
    if not club_id then
        print("[fake-web-fc] Could not find '" .. CLUB_NAME .. "' in any standings.")
        return
    end

    local upcoming, recent, total_played = build_fixtures_and_results(GetValidFixtures(), club_id)

    local last_export_count = read_last_export_count()
    if total_played < last_export_count then
        -- fixture list reset (new season started): restart the counter
        print("[fake-web-fc] New season detected, resetting match counter.")
        write_last_export_count(total_played)
        return
    end
    if (total_played - last_export_count) < MATCHES_PER_EXPORT then
        return -- not enough new matches yet, stay quiet
    end

    print(string.format(
        "[fake-web-fc] %d new matches played since last export -- generating report.",
        total_played - last_export_count
    ))

    local table_rows = build_league_table(standings, league_comp)
    local squad = build_squad_stats(club_id)

    write_report_file(format_report(table_rows, upcoming, recent, squad))
    write_last_export_count(total_played)
end

AddEventHandler("pre__CareerModeEvent", on_career_mode_event)

print("[fake-web-fc] export_every_5_matches.lua loaded.")
print("[fake-web-fc] Watching for CareerMode event: " .. TARGET_EVENT_NAME)
print("[fake-web-fc] Will export a report every " .. MATCHES_PER_EXPORT .. " matches played.")
