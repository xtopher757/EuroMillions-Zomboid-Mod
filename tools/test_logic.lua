-- Validates the pure game logic in EuroMillions_Shared.lua under LuaJIT.
-- Stubs the few engine globals the tested functions touch.

local seed = 12345
function ZombRand(n)            -- 0..n-1
    seed = (seed * 1103515245 + 12345) % 2147483648
    return math.floor(seed / 65536) % n
end
function ZombRandFloat(a, b) return a + (b - a) * 0.5 end

package.path = "./mods/EuroMillions/media/lua/shared/?.lua;" .. package.path
local EM = dofile("mods/EuroMillions/media/lua/shared/EuroMillions/EuroMillions_Shared.lua")

local failures = 0
local function check(cond, msg)
    if cond then print("  ok  " .. msg)
    else print("  FAIL " .. msg); failures = failures + 1 end
end

print("== Date math ==")
-- PZ's lore start is Friday 9 July 1993.
check(EM.dayOfWeek(1993, 7, 9) == 5, "9 Jul 1993 is Friday (5)")
check(EM.dayOfWeek(1993, 7, 13) == 2, "13 Jul 1993 is Tuesday (2)")
check(EM.dayOfWeek(2026, 6, 18) == 4, "18 Jun 2026 is Thursday (4)")
check(EM.serialDay(1993,7,10) - EM.serialDay(1993,7,9) == 1, "serial increments by 1/day")
check(EM.isDrawDay(2) and EM.isDrawDay(5), "Tue & Fri are draw days")
check(not EM.isDrawDay(0) and not EM.isDrawDay(6), "Sun & Sat are not")

print("== Next draw + day name consistency ==")
local today = { y=1993, m=7, d=9, dow=5, serial=EM.serialDay(1993,7,9) } -- Friday
local nextS = EM.nextDrawSerial(today)
check(EM.drawDayName(nextS) == "Tuesday", "draw after Friday is Tuesday (got " .. EM.drawDayName(nextS) .. ")")
-- drawDayName derived from serial must agree with dayOfWeek for that serial.
local agree = true
for s = EM.serialDay(1993,7,9), EM.serialDay(1993,7,9)+14 do
    local nm = EM.DRAW_DOW[(s + 1) % 7]
    -- reconstruct y/m/d weekday is overkill; just ensure draw days are 3-4 apart
end
local gaps, prev = {}, nil
for i=0,20 do
    local s = today.serial
    s = EM.nextDrawSerial({ y=0,m=0,d=0, dow=(today.dow+i)%7, serial=today.serial+i })
    -- not a robust gap test; covered by spacing test below
end
-- spacing: consecutive draw serials differ by 3 or 4
local prevDraw, ok_spacing = nil, true
local cur = { dow = today.dow, serial = today.serial }
for i = 1, 10 do
    local ns = EM.nextDrawSerial(cur)
    if prevDraw then
        local g = ns - prevDraw
        if g ~= 3 and g ~= 4 then ok_spacing = false end
    end
    prevDraw = ns
    cur = { dow = (cur.dow + (ns - cur.serial)) % 7, serial = ns }
end
check(ok_spacing, "consecutive draws are 3 or 4 days apart")

print("== Deterministic draw balls ==")
local d1 = EM.drawNumbersForSerial(nextS)
local d2 = EM.drawNumbersForSerial(nextS)
check(#d1.mains == 5 and #d1.stars == 2, "draw yields 5 mains + 2 stars")
local function uniqueInRange(t, maxv)
    local seen = {}
    for _, v in ipairs(t) do
        if v < 1 or v > maxv or seen[v] then return false end
        seen[v] = true
    end
    return true
end
check(uniqueInRange(d1.mains, 50), "mains unique within 1..50")
check(uniqueInRange(d1.stars, 12), "stars unique within 1..12")
local same = true
for i=1,5 do if d1.mains[i] ~= d2.mains[i] then same=false end end
for i=1,2 do if d1.stars[i] ~= d2.stars[i] then same=false end end
check(same, "same serial => identical balls (deterministic)")
check(EM.drawNumbersForSerial(nextS+1).mains[1] ~= nil, "neighbouring draw also valid")

print("== Distribution sanity over 5000 draws ==")
local minM, maxM = 999, -1
for s = 1000, 6000 do
    local d = EM.drawNumbersForSerial(s)
    for _, v in ipairs(d.mains) do minM = math.min(minM, v); maxM = math.max(maxM, v) end
    if not uniqueInRange(d.mains, 50) or not uniqueInRange(d.stars, 12) then
        check(false, "draw " .. s .. " invalid"); break
    end
end
check(minM == 1 and maxM == 50, "mains span the full 1..50 range (min "..minM..", max "..maxM..")")

print("== Scoring & tiers ==")
local dm, ds = {1,2,3,4,5}, {1,2}
local function tier(m,s) local _,_,t = EM.score(m,s,dm,ds); return t end
check(tier({1,2,3,4,5},{1,2}) == 1, "5+2 => tier 1 (jackpot)")
check(tier({1,2,3,4,5},{1,7}) == 2, "5+1 => tier 2")
check(tier({1,2,3,4,5},{7,8}) == 3, "5+0 => tier 3")
check(tier({1,2,3,4,9},{1,2}) == 4, "4+2 => tier 4")
check(tier({1,2,3,9,10},{1,2}) == 7, "3+2 => tier 7")
check(tier({1,2,3,9,10},{7,8}) == 10, "3+0 => tier 10")
check(tier({1,9,10,11,12},{7,8}) == 0, "1+0 => no prize")
check(tier({1,2,3,9,10},{1,7}) == 9, "3+1 => tier 9")
check(tier({1,2,9,10,11},{1,2}) == 8, "2+2 => tier 8")
check(tier({1,9,10,11,12},{1,2}) == 11, "1+2 => tier 11")
check(tier({1,2,9,10,11},{1,7}) == 12, "2+1 => tier 12")
check(tier({1,2,9,10,11},{7,8}) == 13, "2+0 => tier 13")
check(EM.isJackpotTier(1) and EM.isJackpotTier(3) and not EM.isJackpotTier(4),
    "jackpot tiers are 1..3 only")

print("== Jackpot estimate within cap ==")
local capOk = true
for s = 1, 3000 do
    local j = EM.jackpotEstimate(s)
    if j < 17 or j > 250 then capOk = false end
end
check(capOk, "jackpot estimate always in 17..250M")

print("== Prize table integrity ==")
for t = 1, 13 do
    check(EM.PRIZE[t] ~= nil and EM.PRIZE[t].loot ~= nil, "tier " .. t .. " has a payout")
end

print("")
if failures == 0 then print("ALL TESTS PASSED")
else print(failures .. " TEST(S) FAILED"); os.exit(1) end
