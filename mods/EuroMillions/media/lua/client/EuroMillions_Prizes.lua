--[[ ============================================================================
     EuroMillions - CLIENT messaging & dispatch.

     The client never spawns world loot or zombies itself (that wouldn't work
     on a server). Instead it asks the server to perform the payout, and the
     server replies with a "result" command that this file turns into on-screen
     feedback. In single-player the integrated server runs in the same Lua state
     as the client, so we skip the round-trip and call EM.serverAward directly.
============================================================================ ]]

require "EuroMillions/EuroMillions_Shared"
local EM = EuroMillions

----------------------------------------------------------------------------
-- On-screen helpers
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
    local lp = getPlayer()
    if lp then
        pcall(function() HaloTextHelper.addText(lp, text, HaloTextHelper.getColorGreen()) end)
    end
    print("[EuroMillions] " .. tostring(text))
end

-- True when this machine is a remote MP client and must route through the server.
local function isRemoteClient()
    return isClient()
end

----------------------------------------------------------------------------
-- Turn a scored result into player feedback (runs on the winner's machine)
----------------------------------------------------------------------------
function EM.showResult(player, tier, source, drawInfo)
    player = player or getPlayer()
    if not player then return end

    if drawInfo and drawInfo.mains then
        EM.halo(player, "Winning balls: " .. table.concat(drawInfo.mains, " ")
            .. "  Stars: " .. table.concat(drawInfo.stars or {}, " "), 0.7, 0.85, 1.0)
    end

    if not tier or tier == 0 then
        EM.halo(player, "Not a winner this time. Could it be you next time?", 0.8, 0.8, 0.8)
        player:Say("Damn. Nothing.")
        return
    end

    local tierName = EM.TIER_NAME[tier] or ("Tier " .. tostring(tier))

    if EM.isJackpotTier(tier) then
        EM.halo(player, "*** EUROMILLIONS WINNER! ***  " .. tierName, 1, 0.84, 0.16)
        EM.halo(player, "Your prize landed at your feet... and the whole neighbourhood heard.", 1, 0.3, 0.2)
        player:Say("I... I WON THE EUROMILLIONS!")
    elseif EM.PRIZE[tier] and EM.PRIZE[tier].freePlay then
        EM.halo(player, "Match 2! A FREE Lucky Dip slip dropped at your feet.", 0.6, 1, 0.6)
        player:Say("A free go? I'll take it.")
    else
        EM.halo(player, "Winner! " .. tierName .. " - prize at your feet.", 0.6, 1, 0.6)
        player:Say("Hey, a little win!")
    end
end

-- Someone, somewhere, hit a jackpot.
function EM.showWinnerAlert(name)
    local lp = getPlayer()
    if not lp then return end
    local who = name and (name .. " ") or ""
    EM.halo(lp, "EuroMillions: " .. who .. "is a WINNER! A celebration is underway...", 1, 0.84, 0.16)
end

-- Draw-night broadcast display.
function EM.showBroadcast(payload)
    if not payload then return end
    EM.announce(EM.BROADCAST_INTRO[ZombRand(#EM.BROADCAST_INTRO) + 1])
    EM.announce(EM.BRAND .. " " .. (payload.dayName or "") .. " draw - jackpot EUR "
        .. tostring(payload.jackpot) .. " million.")
    EM.announce("Winning numbers: " .. table.concat(payload.mains or {}, "  ")
        .. "    Lucky Stars: " .. table.concat(payload.stars or {}, "  "))
    EM.announce("Check your tickets. Could it be you?")
end

----------------------------------------------------------------------------
-- Dispatch: ask the server (MP) or act locally (SP / integrated host)
----------------------------------------------------------------------------
function EM.requestScratch(player, cardType)
    if isRemoteClient() then
        sendClientCommand(player, EM.MODULE, "scratch", { cardType = cardType })
    else
        local tier = EM.rollScratch(cardType)
        local jackpot = EM.serverAward(player, tier)
        EM.showResult(player, tier, "scratch")
        if jackpot then EM.showWinnerAlert(player:getUsername()) end
    end
end

-- md is the ticket's mod data (already validated as drawn + unchecked by caller)
function EM.requestCheck(player, md)
    if isRemoteClient() then
        sendClientCommand(player, EM.MODULE, "checkTicket",
            { mains = md.mains, stars = md.stars, drawSerial = md.drawSerial })
        EM.halo(player, "Scanning ticket...", 0.7, 0.85, 1.0)
    else
        local draw = EM.drawNumbersForSerial(md.drawSerial)
        local _, _, tier = EM.score(md.mains, md.stars, draw.mains, draw.stars)
        local jackpot = EM.serverAward(player, tier)
        EM.showResult(player, tier, "ticket", { mains = draw.mains, stars = draw.stars })
        if jackpot then EM.showWinnerAlert(player:getUsername()) end
    end
end

----------------------------------------------------------------------------
-- Server -> client replies
----------------------------------------------------------------------------
local function onServerCommand(module, command, args)
    if module ~= EM.MODULE then return end
    if command == "result" then
        EM.showResult(getPlayer(), args and args.tier, args and args.source,
            args and { mains = args.mains, stars = args.stars })
    elseif command == "winnerAlert" then
        EM.showWinnerAlert(args and args.name)
    elseif command == "drawBroadcast" then
        EM.showBroadcast(args)
    end
end
Events.OnServerCommand.Add(onServerCommand)
