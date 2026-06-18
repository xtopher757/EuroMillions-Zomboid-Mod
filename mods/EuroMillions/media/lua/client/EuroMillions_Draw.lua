--[[ ============================================================================
     EuroMillions - advertising & the automated draw broadcast.

     The lottery's automated systems outlived its customers. Twice a week, on
     Tuesday and Friday nights, the pre-recorded draw still goes out over the
     airwaves. Between draws, the brand keeps dreaming at you.
============================================================================ ]]

require "EuroMillions/EuroMillions_Shared"
require "EuroMillions_Prizes"

local EM = EuroMillions

local function gdata()
    return ModData.getOrCreate("EuroMillions")
end

----------------------------------------------------------------------------
-- Welcome / brand intro on load
----------------------------------------------------------------------------
local function onGameStart()
    local player = getSpecificPlayer(0)
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
-- Ambient advertising
----------------------------------------------------------------------------
local AD_CHANCE = 18   -- ~1 in 18 ten-minute ticks => a few ads per in-game day
local function ambientAd()
    if ZombRand(AD_CHANCE) ~= 0 then return end
    local player = getSpecificPlayer(0)
    if not player or player:isDead() then return end
    local slogan = EM.SLOGANS[ZombRand(#EM.SLOGANS) + 1]
    EM.halo(player, slogan, 1, 0.84, 0.16)
end
Events.EveryTenMinutes.Add(ambientAd)

----------------------------------------------------------------------------
-- Draw-night broadcast (once per draw, fired the first in-game hour after 8pm)
----------------------------------------------------------------------------
local function maybeBroadcastDraw()
    local player = getSpecificPlayer(0)
    if not player or player:isDead() then return end
    local today = EM.getToday()
    if not EM.isDrawDay(today.dow) then return end
    if today.hour < 20 then return end

    local data = gdata()
    if data.lastDrawSerial == today.serial then return end
    data.lastDrawSerial = today.serial

    local draw = EM.drawNumbersForSerial(today.serial)
    local jackpot = EM.jackpotEstimate(today.serial)

    EM.announce(EM.BROADCAST_INTRO[ZombRand(#EM.BROADCAST_INTRO) + 1])
    EM.announce(EM.BRAND .. " " .. EM.drawDayName(today.serial)
        .. " draw - tonight's jackpot was EUR " .. jackpot .. " million.")
    EM.announce("Winning numbers: " .. table.concat(draw.mains, "  ")
        .. "    Lucky Stars: " .. table.concat(draw.stars, "  "))
    EM.announce("Check your tickets. Could it be you?")
end
Events.EveryHours.Add(maybeBroadcastDraw)
