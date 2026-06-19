--[[ ============================================================================
     EuroMillions - SERVER authority.

     World state in Project Zomboid multiplayer is owned by the server: only the
     server may spawn zombies or drop world items so that every player sees them
     and they persist. This module performs all prize payouts and the Winner's
     Celebration horde, driven by client commands, and broadcasts the twice-
     weekly draw to every player.

     In single-player the integrated server runs this file in the same Lua state
     as the client, so the client dispatch calls EM.serverAward directly (see
     EuroMillions_Prizes.lua) and the command round-trip is skipped.
============================================================================ ]]

require "EuroMillions/EuroMillions_Shared"
local EM = EuroMillions

----------------------------------------------------------------------------
-- Authoritative prize drop (server owns the world)
----------------------------------------------------------------------------
local function dropLoot(player, lootList)
    local sq = player:getCurrentSquare()
    if not sq then return 0 end
    local dropped = 0
    for _, entry in ipairs(lootList) do
        local count = entry.min or 1
        if entry.max and entry.max > (entry.min or 1) then
            count = (entry.min or 1) + ZombRand(entry.max - (entry.min or 1) + 1)
        end
        for _ = 1, count do
            local ok = pcall(function()
                sq:AddWorldInventoryItem(entry.item,
                    ZombRandFloat(0.1, 0.9), ZombRandFloat(0.1, 0.9), 0.0)
            end)
            if ok then dropped = dropped + 1 end
        end
    end
    return dropped
end

----------------------------------------------------------------------------
-- The Winner's Celebration horde (server-authoritative spawn)
----------------------------------------------------------------------------
local function spawnHorde(player, minZ, maxZ)
    local sv = SandboxVars and SandboxVars.EuroMillions
    if sv and sv.EnableWinnerHorde == false then return 0 end
    local mult = (sv and sv.WinnerHordeMultiplier) or 1.0
    local lo = math.floor((minZ or 10) * mult)
    local hi = math.floor((maxZ or 20) * mult)
    if hi < lo then hi = lo end
    if hi <= 0 then return 0 end

    local count = lo
    if hi > lo then count = lo + ZombRand(hi - lo + 1) end
    if count <= 0 then return 0 end

    local px, py, pz = player:getX(), player:getY(), player:getZ()
    local spawned = 0
    local clusters = 8
    local per = math.max(1, math.ceil(count / clusters))
    for i = 1, clusters do
        local angle = (i / clusters) * 2 * math.pi
        local radius = 9 + ZombRand(6)
        local zx = px + math.cos(angle) * radius
        local zy = py + math.sin(angle) * radius
        local ok = pcall(function()
            -- B41 signature: addZombiesInOutfit(x, y, z, nbZombie, outfit, femaleChance)
            addZombiesInOutfit(zx, zy, pz, per, nil, 50)
        end)
        if ok then spawned = spawned + per end
    end

    if spawned == 0 then
        -- Engine spawn unavailable: at least make the noise that pulls walkers.
        pcall(function()
            getWorldSoundManager():addSound(player, px, py, pz, 250, 200)
        end)
    end
    return spawned
end

local function celebrationNoise(player)
    pcall(function()
        getWorldSoundManager():addSound(player, player:getX(), player:getY(),
            player:getZ(), 200, 180)
    end)
end

----------------------------------------------------------------------------
-- Award a scored prize: drop the loot, and for Match-5+ throw the party.
-- Returns isJackpot so callers can fire winner alerts.
----------------------------------------------------------------------------
function EM.serverAward(player, tier)
    local prize = EM.PRIZE[tier]
    if not player or not prize then return false end

    dropLoot(player, prize.loot)

    if EM.isJackpotTier(tier) then
        celebrationNoise(player)
        spawnHorde(player, prize.hordeMin, prize.hordeMax)
        return true
    end
    return false
end

----------------------------------------------------------------------------
-- Client command handling (multiplayer remote clients)
----------------------------------------------------------------------------
local function onClientCommand(module, command, player, args)
    if module ~= EM.MODULE or not player then return end

    if command == "scratch" then
        local tier = EM.rollScratch(args and args.cardType)
        local jackpot = EM.serverAward(player, tier)
        sendServerCommand(player, EM.MODULE, "result",
            { tier = tier, source = "scratch" })
        if jackpot then
            sendServerCommand(EM.MODULE, "winnerAlert", { name = player:getUsername() })
        end

    elseif command == "checkTicket" then
        if not args or not args.drawSerial or not args.mains or not args.stars then return end
        local today = EM.getToday()
        if today.serial < args.drawSerial then return end   -- draw hasn't happened
        local draw = EM.drawNumbersForSerial(args.drawSerial)
        local _, _, tier = EM.score(args.mains, args.stars, draw.mains, draw.stars)
        local jackpot = EM.serverAward(player, tier)
        sendServerCommand(player, EM.MODULE, "result",
            { tier = tier, source = "ticket", mains = draw.mains, stars = draw.stars })
        if jackpot then
            sendServerCommand(EM.MODULE, "winnerAlert", { name = player:getUsername() })
        end
    end
end
Events.OnClientCommand.Add(onClientCommand)

----------------------------------------------------------------------------
-- Twice-weekly draw broadcast, driven by the server clock
----------------------------------------------------------------------------
local function gdata()
    return ModData.getOrCreate("EuroMillions")
end

local function runDrawCheck()
    local today = EM.getToday()
    if not EM.isDrawDay(today.dow) then return end
    if today.hour < 20 then return end

    local data = gdata()
    if data.lastDrawSerial == today.serial then return end
    data.lastDrawSerial = today.serial

    local draw = EM.drawNumbersForSerial(today.serial)
    local jackpot = EM.jackpotEstimate(today.serial)
    local payload = {
        serial  = today.serial,
        dayName = EM.drawDayName(today.serial),
        mains   = draw.mains,
        stars   = draw.stars,
        jackpot = jackpot,
    }

    -- Reach every player. On a dedicated server there is no local player;
    -- on an integrated host / single-player we also show the local one.
    if isServer() then
        sendServerCommand(EM.MODULE, "drawBroadcast", payload)
    end
    local lp = getPlayer()
    if lp and EM.showBroadcast then
        EM.showBroadcast(payload)
    end
end
Events.EveryHours.Add(runDrawCheck)
