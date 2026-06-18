--[[ ============================================================================
     EuroMillions - Apocalypse Lottery
     Shared core: branding, game rules, deterministic draws, prize tiers.

     Loaded on both client and server so the draw results are identical
     everywhere. The winning numbers for any given date are derived from a
     seeded PRNG keyed on that date's serial day number, so two players who
     check tickets for the same draw always see the same balls.
============================================================================ ]]

EuroMillions = EuroMillions or {}
local EM = EuroMillions

----------------------------------------------------------------------------
-- Game rules (mirrors the real EuroMillions matrix)
----------------------------------------------------------------------------
EM.MAIN_COUNT  = 5      -- pick 5 main numbers
EM.MAIN_MAX    = 50     -- from 1..50
EM.STAR_COUNT  = 2      -- pick 2 Lucky Stars
EM.STAR_MAX    = 12     -- from 1..12

-- Draws happen on these weekdays (0=Sunday .. 6=Saturday). Tue & Fri.
EM.DRAW_DOW = { [2] = "Tuesday", [5] = "Friday" }

----------------------------------------------------------------------------
-- Branding & messaging
----------------------------------------------------------------------------
EM.BRAND   = "EuroMillions"
EM.TAGLINE = "Could it be you?"

EM.SLOGANS = {
    "EuroMillions: Could it be you?",
    "Dream big. The dead can't spend it for you.",
    "Play. Dream. Survive. Repeat.",
    "Tuesdays & Fridays - the dream never dies.",
    "One ticket could change whatever's left of your life.",
    "EuroMillions. Because hope is the last thing to rot.",
    "Imagine the things you'd buy... if any shops were open.",
    "Make your Lucky Stars align before the horde does.",
    "Life-changing jackpots. Life-ending celebrations.",
}

-- Pre-recorded 'automated draw broadcast' lines, played on draw nights.
EM.BROADCAST_INTRO = {
    "*static* ...and welcome to tonight's EuroMillions draw...",
    "*crackle* The EuroMillions automated draw system is still running...",
    "...good evening, dreamers, wherever you are...",
}

----------------------------------------------------------------------------
-- Date helpers (pure Lua so they never depend on engine constants)
----------------------------------------------------------------------------

-- Sakamoto's algorithm: weekday for a Gregorian date. 0=Sunday .. 6=Saturday.
function EM.dayOfWeek(y, m, d)
    local t = {0, 3, 2, 5, 0, 3, 5, 1, 4, 6, 2, 4}
    if m < 3 then y = y - 1 end
    return (y + math.floor(y / 4) - math.floor(y / 100) + math.floor(y / 400)
            + t[m] + d) % 7
end

-- Serial day number (Julian Day Number) - a stable integer per calendar day,
-- used as the deterministic draw seed.
function EM.serialDay(y, m, d)
    local a = math.floor((14 - m) / 12)
    local yy = y + 4800 - a
    local mm = m + 12 * a - 3
    return d + math.floor((153 * mm + 2) / 5) + 365 * yy
           + math.floor(yy / 4) - math.floor(yy / 100) + math.floor(yy / 400) - 32045
end

-- Read the current in-game date as a normalised {y, m=1..12, d=1..31}.
-- PZ's GameTime reports month/day zero-based, so we add one.
function EM.getToday()
    local gt = getGameTime()
    local y = gt:getYear()
    local m = gt:getMonth() + 1
    local d = gt:getDay() + 1
    return {
        y = y, m = m, d = d,
        hour = gt:getHour(),
        dow  = EM.dayOfWeek(y, m, d),
        serial = EM.serialDay(y, m, d),
    }
end

function EM.isDrawDay(dow)
    return EM.DRAW_DOW[dow] ~= nil
end

-- Serial day of the next draw strictly AFTER the given day. A play slip
-- filled out today is entered into the next upcoming draw.
function EM.nextDrawSerial(today)
    local serial, dow = today.serial, today.dow
    for i = 1, 7 do
        serial = serial + 1
        dow = (dow + 1) % 7
        if EM.isDrawDay(dow) then return serial, dow end
    end
    return serial, dow
end

-- Convert a serial day back to a weekday name for display.
function EM.drawDayName(serial)
    -- serial->dow: JDN 0 was a Monday; (serial + 1) % 7 maps to 0=Sunday.
    local dow = (serial + 1) % 7
    return EM.DRAW_DOW[dow] or "Draw Day"
end

----------------------------------------------------------------------------
-- Deterministic PRNG (LCG) so a given draw seed yields identical balls
-- on every machine, independent of the engine RNG state.
----------------------------------------------------------------------------
local function lcg(seed)
    local state = (seed % 2147483647)
    if state <= 0 then state = state + 2147483646 end
    return function(n)  -- returns 0 .. n-1
        state = (state * 1103515245 + 12345) % 2147483648
        return math.floor(state / 65536) % n
    end
end

-- Draw `count` unique values from 1..maxv using rng, returned sorted.
local function drawUnique(rng, count, maxv)
    local pool = {}
    for i = 1, maxv do pool[i] = i end
    for i = 1, count do
        local j = i + rng(maxv - i + 1)
        pool[i], pool[j] = pool[j], pool[i]
    end
    local out = {}
    for i = 1, count do out[i] = pool[i] end
    table.sort(out)
    return out
end

-- The winning balls for a draw, keyed deterministically on its serial day.
function EM.drawNumbersForSerial(serial)
    local rng = lcg(serial * 2654435761 + 17)
    return {
        mains = drawUnique(rng, EM.MAIN_COUNT, EM.MAIN_MAX),
        stars = drawUnique(rng, EM.STAR_COUNT, EM.STAR_MAX),
    }
end

-- A flavour-only estimated jackpot that "rolls over" pseudo-randomly per draw.
function EM.jackpotEstimate(serial)
    local rng = lcg(serial * 40503 + 99)
    local rollovers = rng(13)            -- 0..12 consecutive rollovers
    local millions = 17 + rollovers * 18 + rng(9)
    if millions > 250 then millions = 250 end  -- the real EuroMillions cap
    return millions
end

----------------------------------------------------------------------------
-- A player's own random pick ("Lucky Dip"), using the live engine RNG.
----------------------------------------------------------------------------
local function rollUnique(count, maxv)
    local chosen, out = {}, {}
    while #out < count do
        local v = ZombRand(maxv) + 1
        if not chosen[v] then
            chosen[v] = true
            out[#out + 1] = v
        end
    end
    table.sort(out)
    return out
end

function EM.luckyDip()
    return {
        mains = rollUnique(EM.MAIN_COUNT, EM.MAIN_MAX),
        stars = rollUnique(EM.STAR_COUNT, EM.STAR_MAX),
    }
end

----------------------------------------------------------------------------
-- Scoring
----------------------------------------------------------------------------
local function countMatches(picked, drawn)
    local set = {}
    for _, v in ipairs(drawn) do set[v] = true end
    local n = 0
    for _, v in ipairs(picked) do if set[v] then n = n + 1 end end
    return n
end

-- Returns matchedMains, matchedStars, tierIndex (0 = no prize).
function EM.score(ticketMains, ticketStars, drawMains, drawStars)
    local m = countMatches(ticketMains, drawMains)
    local s = countMatches(ticketStars, drawStars)
    local tier = EM.tierFor(m, s)
    return m, s, tier
end

-- The 13 EuroMillions prize tiers, best (1) to lowest (13).
function EM.tierFor(m, s)
    if m == 5 and s == 2 then return 1 end
    if m == 5 and s == 1 then return 2 end
    if m == 5 and s == 0 then return 3 end
    if m == 4 and s == 2 then return 4 end
    if m == 4 and s == 1 then return 5 end
    if m == 4 and s == 0 then return 6 end
    if m == 3 and s == 2 then return 7 end
    if m == 2 and s == 2 then return 8 end
    if m == 3 and s == 1 then return 9 end
    if m == 3 and s == 0 then return 10 end
    if m == 1 and s == 2 then return 11 end
    if m == 2 and s == 1 then return 12 end
    if m == 2 and s == 0 then return 13 end
    return 0
end

EM.TIER_NAME = {
    [1]  = "Match 5 + 2 Stars - JACKPOT",
    [2]  = "Match 5 + 1 Star",
    [3]  = "Match 5",
    [4]  = "Match 4 + 2 Stars",
    [5]  = "Match 4 + 1 Star",
    [6]  = "Match 4",
    [7]  = "Match 3 + 2 Stars",
    [8]  = "Match 2 + 2 Stars",
    [9]  = "Match 3 + 1 Star",
    [10] = "Match 3",
    [11] = "Match 1 + 2 Stars",
    [12] = "Match 2 + 1 Star",
    [13] = "Match 2",
}

-- Tiers 1..3 (any Match-5) trigger the "Winner's Celebration" horde event.
function EM.isJackpotTier(tier)
    return tier ~= nil and tier >= 1 and tier <= 3
end

----------------------------------------------------------------------------
-- Prize payouts. Money is worthless now, so prizes are survival loot.
-- Each entry is a list of { item = fullType, min, max } awarded on win.
-- `bundles` of items are added to the player's square as a "prize drop".
----------------------------------------------------------------------------
EM.PRIZE = {
    -- Jackpot: a life-changing haul. And every zombie wants to celebrate.
    [1] = { jackpot = "full", hordeMin = 28, hordeMax = 44, loot = {
        { item = "Base.Money",            min = 5, max = 5 },
        { item = "Base.Axe",              min = 1, max = 1 },
        { item = "Base.Pistol",           min = 1, max = 1 },
        { item = "Base.Bullets9mmBox",    min = 2, max = 4 },
        { item = "Base.Shotgun",          min = 1, max = 1 },
        { item = "Base.ShotgunShellsBox", min = 2, max = 3 },
        { item = "Base.HuntingRifle",     min = 1, max = 1 },
        { item = "Base.WhiskeyFull",      min = 1, max = 2 },
        { item = "Base.Cigarettes",       min = 1, max = 2 },
        { item = "Base.TinnedSoup",       min = 4, max = 8 },
        { item = "Base.WaterBottleFull",  min = 2, max = 4 },
        { item = "Base.Antibiotics",      min = 1, max = 2 },
        { item = "EuroMillions.Voucher",  min = 1, max = 1 },
    }},
    -- Mega win (5+1): great drop, smaller crowd.
    [2] = { jackpot = "mega", hordeMin = 16, hordeMax = 26, loot = {
        { item = "Base.Money",           min = 3, max = 3 },
        { item = "Base.Pistol",          min = 1, max = 1 },
        { item = "Base.Bullets9mmBox",   min = 1, max = 2 },
        { item = "Base.WhiskeyFull",     min = 1, max = 1 },
        { item = "Base.TinnedSoup",      min = 3, max = 5 },
        { item = "Base.WaterBottleFull", min = 1, max = 2 },
        { item = "Base.Antibiotics",     min = 1, max = 1 },
        { item = "EuroMillions.Voucher", min = 1, max = 1 },
    }},
    -- Big win (5+0): a tidy drop, a modest crowd.
    [3] = { jackpot = "mega", hordeMin = 10, hordeMax = 18, loot = {
        { item = "Base.Money",           min = 2, max = 2 },
        { item = "Base.Bullets9mmBox",   min = 1, max = 1 },
        { item = "Base.TinnedSoup",      min = 3, max = 5 },
        { item = "Base.WaterBottleFull", min = 1, max = 2 },
        { item = "Base.Bandage",         min = 2, max = 3 },
        { item = "EuroMillions.Voucher", min = 1, max = 1 },
    }},
    -- Mid-tier wins: useful but quiet (no horde).
    [4]  = { loot = { {item="Base.TinnedSoup",min=2,max=3},{item="Base.WhiskeyFull",min=1,max=1},{item="Base.Bandage",min=1,max=2},{item="Base.Cigarettes",min=1,max=1} } },
    [5]  = { loot = { {item="Base.TinnedSoup",min=2,max=2},{item="Base.WaterBottleFull",min=1,max=1},{item="Base.Bandage",min=1,max=1} } },
    [6]  = { loot = { {item="Base.TinnedSoup",min=1,max=2},{item="Base.Pop",min=1,max=1},{item="Base.Cigarettes",min=1,max=1} } },
    [7]  = { loot = { {item="Base.TinnedSoup",min=1,max=2},{item="Base.Pop",min=1,max=1} } },
    [8]  = { loot = { {item="Base.TinnedSoup",min=1,max=1},{item="Base.Pop",min=1,max=1} } },
    [9]  = { loot = { {item="Base.Pop",min=1,max=1},{item="Base.Crisps",min=1,max=1} } },
    [10] = { loot = { {item="Base.Pop",min=1,max=1} } },
    [11] = { loot = { {item="Base.Crisps",min=1,max=1} } },
    [12] = { loot = { {item="Base.Crisps",min=1,max=1} } },
    -- Match 2: the classic "free Lucky Dip" - win another go.
    [13] = { freePlay = true, loot = { {item="EuroMillions.TicketBlank",min=1,max=1} } },
}

return EM
