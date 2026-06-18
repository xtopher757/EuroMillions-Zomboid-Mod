--[[ ============================================================================
     EuroMillions - prize payout & the Winner's Celebration event.

     Cash is worthless after the outbreak, so prizes pay out in survival loot
     dropped at the winner's feet. The catch: claiming a Match-5 prize sets off
     the EuroMillions "Winner's Celebration" - sirens, fanfare, and every
     walker for blocks around shuffling in to congratulate you in person.
============================================================================ ]]

require "EuroMillions/EuroMillions_Shared"
local EM = EuroMillions

----------------------------------------------------------------------------
-- Messaging helpers
----------------------------------------------------------------------------
function EM.halo(player, text, r, g, b)
    if not player then return end
    local ok = pcall(function()
        HaloTextHelper.addTextWithColor(player, text, r or 1, g or 0.84, b or 0.16)
    end)
    if not ok then
        pcall(function()
            HaloTextHelper.addText(player, text, HaloTextHelper.getColorWhite())
        end)
    end
end

function EM.announce(text)
    -- On-screen server-style broadcast line + console echo.
    pcall(function()
        local player = getSpecificPlayer(0)
        if player then HaloTextHelper.addText(player, text, HaloTextHelper.getColorGreen()) end
    end)
    print("[EuroMillions] " .. tostring(text))
end

----------------------------------------------------------------------------
-- Drop a prize bundle on the winner's square
----------------------------------------------------------------------------
local function dropLoot(player, lootList)
    local sq = player:getCurrentSquare()
    if not sq then return 0 end
    local dropped = 0
    for _, entry in ipairs(lootList) do
        local count = entry.min or 1
        if entry.max and entry.max > entry.min then
            count = entry.min + ZombRand(entry.max - entry.min + 1)
        end
        for _ = 1, count do
            local ok = pcall(function()
                sq:AddWorldInventoryItem(entry.item, 0.0 + ZombRandFloat(0.1, 0.9),
                                                      0.0 + ZombRandFloat(0.1, 0.9), 0.0)
            end)
            if ok then dropped = dropped + 1 end
        end
    end
    return dropped
end

----------------------------------------------------------------------------
-- The Winner's Celebration: noise + a converging horde
----------------------------------------------------------------------------
local function spawnCelebrationHorde(player, minZ, maxZ)
    if SandboxVars and SandboxVars.EuroMillions
       and SandboxVars.EuroMillions.EnableWinnerHorde == false then
        return 0
    end
    local count = minZ + ZombRand(math.max(1, maxZ - minZ + 1))
    local px, py, pz = player:getX(), player:getY(), player:getZ()
    local spawned = 0
    -- Spread the crowd around the winner in a ring so they shamble inward.
    local clusters = 8
    for i = 1, clusters do
        local angle = (i / clusters) * 2 * math.pi
        local radius = 9 + ZombRand(6)
        local zx = px + math.cos(angle) * radius
        local zy = py + math.sin(angle) * radius
        local n = math.ceil(count / clusters)
        local ok = pcall(function()
            addZombiesInOutfit(zx, zy, pz, n, "", 50)
        end)
        if ok then spawned = spawned + n end
    end
    if spawned == 0 then
        -- Engine spawn unavailable; at least make the noise that draws them.
        pcall(function() addSound(player, px, py, pz, 250, 200) end)
    end
    return spawned
end

local function makeCelebrationNoise(player)
    -- A loud "fanfare" so nearby zombies are alerted even where spawning fails.
    pcall(function()
        getWorldSoundManager():addSound(player, player:getX(), player:getY(),
            player:getZ(), 200, 180)
    end)
end

----------------------------------------------------------------------------
-- Award a prize for a scored ticket / scratchcard
--   tier    : 1..13 (0 handled by caller as "no win")
--   sourceName: label for messaging ("ticket" / "scratchcard")
----------------------------------------------------------------------------
function EM.awardPrize(player, tier, sourceName)
    local prize = EM.PRIZE[tier]
    if not prize then return end
    sourceName = sourceName or "ticket"

    local tierName = EM.TIER_NAME[tier] or ("Tier " .. tostring(tier))

    if EM.isJackpotTier(tier) then
        -- The big one. Fanfare first, then the loot, then the company.
        EM.halo(player, "*** EUROMILLIONS WINNER! ***", 1, 0.84, 0.16)
        player:Say("I... I WON THE EUROMILLIONS!")
        dropLoot(player, prize.loot)
        makeCelebrationNoise(player)
        local mult = (SandboxVars and SandboxVars.EuroMillions
                      and SandboxVars.EuroMillions.WinnerHordeMultiplier) or 1.0
        local lo = math.floor((prize.hordeMin or 10) * mult)
        local hi = math.floor((prize.hordeMax or 20) * mult)
        local n = spawnCelebrationHorde(player, lo, hi)
        EM.announce("EuroMillions: A WINNER has been found! Claim your prize... if you can keep it.")
        if n > 0 then
            EM.halo(player, "The whole neighbourhood heard. They're coming to celebrate.", 1, 0.3, 0.2)
        end
        return tier, true
    end

    -- Quiet wins: just drop the goods.
    local dropped = dropLoot(player, prize.loot)
    if prize.freePlay then
        EM.halo(player, "Match 2! You win a FREE Lucky Dip play slip.", 0.6, 1, 0.6)
        player:Say("A free go? I'll take it.")
    else
        EM.halo(player, "Winner! " .. tierName .. " - prize at your feet.", 0.6, 1, 0.6)
        player:Say("Hey, a little win!")
    end
    return tier, false
end

return EM
