--[[ ============================================================================
     EuroMillions - client-side advertising.

     Ambient brand messaging and the per-player welcome. The actual draw
     broadcast is driven by the server clock (see EuroMillions_Server.lua) and
     arrives here as a "drawBroadcast" command handled in EuroMillions_Prizes.lua,
     so every player on the server sees the same draw at the same time.
============================================================================ ]]

require "EuroMillions/EuroMillions_Shared"
require "EuroMillions_Prizes"

local EM = EuroMillions

----------------------------------------------------------------------------
-- Welcome / brand intro on load (local player only)
----------------------------------------------------------------------------
local function onGameStart()
    local player = getPlayer()
    if not player then return end
    local today = EM.getToday()
    local nextSerial = EM.nextDrawSerial(today)
    local jackpot = EM.jackpotEstimate(nextSerial)
    EM.halo(player, EM.BRAND .. ": " .. EM.TAGLINE, 1, 0.84, 0.16)
    EM.halo(player, "Next draw: " .. EM.drawDayName(nextSerial)
        .. ".  Estimated jackpot EUR " .. jackpot .. "M", 0.7, 0.85, 1.0)
    print("[EuroMillions] Loaded. Next draw " .. EM.drawDayName(nextSerial)
        .. ", estimated jackpot EUR " .. jackpot .. "M")
end
Events.OnGameStart.Add(onGameStart)

----------------------------------------------------------------------------
-- Ambient advertising (each player sees their own)
----------------------------------------------------------------------------
local AD_CHANCE = 18   -- ~1 in 18 ten-minute ticks => a few ads per in-game day
local function ambientAd()
    if ZombRand(AD_CHANCE) ~= 0 then return end
    local player = getPlayer()
    if not player or player:isDead() then return end
    local slogan = EM.SLOGANS[ZombRand(#EM.SLOGANS) + 1]
    EM.halo(player, slogan, 1, 0.84, 0.16)
end
Events.EveryTenMinutes.Add(ambientAd)
