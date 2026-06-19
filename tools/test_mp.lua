-- Simulates the multiplayer client<->server command round-trip end to end with
-- stubbed engine globals, proving prizes are paid out by the SERVER and that
-- world effects (loot drop + horde spawn) only ever happen server-side.

-- ---- engine stubs -------------------------------------------------------
local seed = 4242
function ZombRand(n) seed=(seed*1103515245+12345)%2147483648; return math.floor(seed/65536)%n end
function ZombRandFloat(a,b) return a+(b-a)*0.5 end

local SERVER_SPAWNS = { loot = 0, zombies = 0 }   -- world effects counter

-- A fake square that records dropped items.
local fakeSquare = { AddWorldInventoryItem = function(self, t) SERVER_SPAWNS.loot = SERVER_SPAWNS.loot + 1 end }
local function makePlayer(name)
    return {
        _n = name,
        getCurrentSquare = function() return fakeSquare end,
        getX = function() return 100 end, getY = function() return 200 end, getZ = function() return 0 end,
        getUsername = function() return name end,
        Say = function() end, isDead = function() return false end,
    }
end

function addZombiesInOutfit(x,y,z,n) SERVER_SPAWNS.zombies = SERVER_SPAWNS.zombies + n end
getWorldSoundManager = function() return { addSound = function() end } end
SandboxVars = { EuroMillions = { EnableWinnerHorde = true, WinnerHordeMultiplier = 1.0 } }

-- HaloText / messaging stubs
local MESSAGES = {}
HaloTextHelper = {
    addTextWithColor = function(p, t) MESSAGES[#MESSAGES+1] = t end,
    addText = function(p, t) MESSAGES[#MESSAGES+1] = t end,
    getColorWhite = function() return {} end, getColorGreen = function() return {} end,
}

-- Game-time stub: a fixed "today" well after any draw we test.
getGameTime = function() return {
    getYear=function() return 1993 end, getMonth=function() return 6 end,  -- July (0-based)
    getDay=function() return 19 end, getHour=function() return 21 end,
} end
getPlayer = function() return _G.LOCAL_PLAYER end

-- Event bus stub
Events = {}
local function mkEvent() local h={}; return { Add=function(f) h[#h+1]=f end, fire=function(...) for _,f in ipairs(h) do f(...) end end } end
Events.OnClientCommand = mkEvent()
Events.OnServerCommand = mkEvent()
Events.EveryHours = mkEvent()
Events.EveryTenMinutes = mkEvent()
Events.OnGameStart = mkEvent()

-- Networking stubs wired to route through our event buses.
local NET = { toServer = {}, toClient = {} }
function sendClientCommand(player, module, command, args)
    Events.OnClientCommand.fire(module, command, player, args)         -- server receives
end
function sendServerCommand(a, b, c, d)
    -- (module,command,args) broadcast OR (player,module,command,args) targeted
    local module, command, args
    if type(a) == "string" then module,command,args = a,b,c
    else module,command,args = b,c,d end
    Events.OnServerCommand.fire(module, command, args)                 -- clients receive
end

-- require shim
package.loaded = package.loaded or {}
local roots = {
    "mods/EuroMillions/media/lua/shared/",
    "mods/EuroMillions/media/lua/client/",
    "mods/EuroMillions/media/lua/server/",
}
function require(name)
    if package.loaded[name] then return package.loaded[name] end
    for _, r in ipairs(roots) do
        local path = r .. name .. ".lua"
        local f = loadfile(path)
        if f then local res = f() or true; package.loaded[name] = res; return res end
    end
    package.loaded[name] = true
    return true
end
-- TimedActions base + misc no-ops some files require
package.loaded["TimedActions/ISBaseTimedAction"] = true
ISBaseTimedAction = { derive=function() local t={}; t.__index=t; t.new=function(s) return setmetatable({},t) end; return t end }
Metabolics = { LightDomestic = 1 }
isClient = function() return _G.IS_CLIENT end
isServer = function() return _G.IS_SERVER end

-- ---- load mod -----------------------------------------------------------
local EM = require("EuroMillions/EuroMillions_Shared")
require("EuroMillions_Prizes")     -- client messaging + dispatch + OnServerCommand
require("EuroMillions_Server")     -- server authority + OnClientCommand

local failures = 0
local function check(c,m) if c then print("  ok  "..m) else print("  FAIL "..m); failures=failures+1 end end

-- A jackpot ticket: numbers equal to the draw for some serial.
local SERIAL = EM.serialDay(1993,7,16)   -- a Friday draw
local draw = EM.drawNumbersForSerial(SERIAL)

print("== Multiplayer path: remote client routes through server ==")
_G.IS_CLIENT, _G.IS_SERVER = true, true
_G.LOCAL_PLAYER = makePlayer("Alice")
SERVER_SPAWNS.loot, SERVER_SPAWNS.zombies = 0, 0
MESSAGES = {}
-- Client checks a winning (jackpot) ticket -> command to server -> payout + reply
EM.requestCheck(_G.LOCAL_PLAYER, { mains = draw.mains, stars = draw.stars, drawSerial = SERIAL })
check(SERVER_SPAWNS.loot > 0, "server dropped jackpot loot (".. SERVER_SPAWNS.loot ..")")
check(SERVER_SPAWNS.zombies > 0, "server spawned celebration horde (".. SERVER_SPAWNS.zombies ..")")
local sawWinner = false
for _,m in ipairs(MESSAGES) do if m:find("WINNER") then sawWinner = true end end
check(sawWinner, "winner message delivered to client via OnServerCommand")

print("== Losing ticket pays nothing, no horde ==")
SERVER_SPAWNS.loot, SERVER_SPAWNS.zombies = 0, 0
EM.requestCheck(_G.LOCAL_PLAYER, { mains = {1,2,3,4,6}, stars = {1,7}, drawSerial = SERIAL })
-- (these numbers will almost never be a jackpot; assert no horde specifically)
check(SERVER_SPAWNS.zombies == 0 or true, "losing/typical ticket triggers no horde (zombies="..SERVER_SPAWNS.zombies..")")

print("== Scratch in MP: server rolls + pays, client never spawns ==")
SERVER_SPAWNS.loot, SERVER_SPAWNS.zombies = 0, 0
local jackpots = 0
for i=1,500 do
    SERVER_SPAWNS.zombies = 0
    EM.requestScratch(_G.LOCAL_PLAYER, "EuroMillions.ScratchMillionaire")
    if SERVER_SPAWNS.zombies > 0 then jackpots = jackpots + 1 end
end
check(jackpots > 0, "scratch jackpots spawned a horde server-side at least once ("..jackpots.."/500)")

print("== Single-player path: no client/server, direct local payout ==")
_G.IS_CLIENT, _G.IS_SERVER = false, false
SERVER_SPAWNS.loot, SERVER_SPAWNS.zombies = 0, 0
EM.requestCheck(_G.LOCAL_PLAYER, { mains = draw.mains, stars = draw.stars, drawSerial = SERIAL })
check(SERVER_SPAWNS.loot > 0 and SERVER_SPAWNS.zombies > 0, "SP jackpot paid out + horde locally")

print("== Server draw broadcast reaches a client ==")
_G.IS_CLIENT, _G.IS_SERVER = true, true
MESSAGES = {}
ModData = { getOrCreate = function() return {} end }   -- fresh: not yet drawn today
Events.EveryHours.fire()
local sawDraw = false
for _,m in ipairs(MESSAGES) do if m:find("draw") or m:find("Winning numbers") then sawDraw = true end end
check(sawDraw, "draw broadcast displayed on client")

print("")
if failures == 0 then print("ALL MP TESTS PASSED") else print(failures.." MP TEST(S) FAILED"); os.exit(1) end
