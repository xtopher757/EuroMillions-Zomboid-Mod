--[[ ============================================================================
     EuroMillions - inventory right-click menu.
       * Scratchcards   -> "Scratch Card"
       * Blank slip     -> "Fill Out Play Slip" (Choose Numbers / Lucky Dip)
       * Filled ticket  -> "Check EuroMillions Ticket" on/after its draw
       * Flyer          -> "Read Flyer"
============================================================================ ]]

require "EuroMillions/EuroMillions_Shared"
require "EuroMillions_Prizes"
require "EuroMillions_TicketUI"
require "timedactions/ISEMScratchAction"
require "timedactions/ISEMFillTicketAction"

local EM = EuroMillions

local SCRATCH_TYPES = {
    ["EuroMillions.ScratchMillionaire"] = true,
    ["EuroMillions.ScratchLuckyStars"]  = true,
    ["EuroMillions.ScratchGoldRush"]    = true,
    ["EuroMillions.Scratch777"]         = true,
}

----------------------------------------------------------------------------
-- Helpers
----------------------------------------------------------------------------
local function unwrapItem(entry)
    if not entry then return nil end
    if instanceof and instanceof(entry, "InventoryItem") then return entry end
    if entry.items and entry.items[1] then return entry.items[1] end
    return entry
end

local function hasWritingTool(player)
    local inv = player:getInventory()
    local ok, found = pcall(function()
        return inv:containsTypeRecurse("Pen") or inv:containsTypeRecurse("Pencil")
    end)
    if ok and found then return true end
    -- Fallback: manual scan.
    local items = inv:getItems()
    for i = 0, items:size() - 1 do
        local t = items:get(i):getType()
        if t == "Pen" or t == "Pencil" then return true end
    end
    return false
end

----------------------------------------------------------------------------
-- Actions
----------------------------------------------------------------------------
local function doScratch(player, item)
    ISTimedActionQueue.add(ISEMScratchAction:new(player, item))
end

local function doLuckyDip(player, blank)
    local pick = EM.luckyDip()
    ISTimedActionQueue.add(ISEMFillTicketAction:new(player, blank, pick))
end

local function doChooseNumbers(player, blank)
    ISEMTicketUI.open(player, blank)
end

local function doCheckTicket(player, ticket)
    local md = ticket:getModData()
    if not md.mains or not md.drawSerial then
        EM.halo(player, "This slip hasn't been filled out.", 0.8, 0.8, 0.8)
        return
    end
    local today = EM.getToday()
    if today.serial < md.drawSerial then
        EM.halo(player, "The " .. (md.drawName or "next") .. " draw hasn't happened yet.", 0.9, 0.9, 0.5)
        return
    end
    if md.checked then
        EM.halo(player, "You already checked this ticket.", 0.8, 0.8, 0.8)
        return
    end

    -- Record the result locally for the tooltip, then let the server pay out
    -- authoritatively (it re-derives the tier so the prize/horde are server-spawned).
    local draw = EM.drawNumbersForSerial(md.drawSerial)
    local _, _, tier = EM.score(md.mains, md.stars, draw.mains, draw.stars)
    md.checked = true
    md.resultTier = tier

    EM.requestCheck(player, md)
end

local function doReadFlyer(player)
    local lines = {
        EM.SLOGANS[ZombRand(#EM.SLOGANS) + 1],
        "Draws every Tuesday & Friday. Play 5 numbers + 2 Lucky Stars.",
        "Match 2 for a free Lucky Dip. Match all 5 + 2 Stars for the jackpot.",
        "Please play responsibly. Winners may attract a crowd.",
    }
    for _, ln in ipairs(lines) do
        EM.halo(player, ln, 1, 0.84, 0.16)
    end
    player:Say("'" .. EM.TAGLINE .. "'")
end

----------------------------------------------------------------------------
-- Context menu hook
----------------------------------------------------------------------------
local function onFillContext(playerIdx, context, itemsList)
    local player = getSpecificPlayer(playerIdx)
    if not player then return end

    -- Collect the distinct items the player clicked.
    local seen = {}
    for _, entry in ipairs(itemsList) do
        local item = unwrapItem(entry)
        if item and not seen[item] then
            seen[item] = true
            local fullType = item:getFullType()

            if SCRATCH_TYPES[fullType] then
                context:addOption("Scratch Card", player, function() doScratch(player, item) end)

            elseif fullType == "EuroMillions.TicketBlank" then
                local sub = ISContextMenu:getNew(context)
                local opt = context:addOption("Fill Out Play Slip", player, nil)
                context:addSubMenu(opt, sub)
                if hasWritingTool(player) then
                    sub:addOption("Choose Numbers...", player, function() doChooseNumbers(player, item) end)
                    sub:addOption("Lucky Dip (random)", player, function() doLuckyDip(player, item) end)
                else
                    local d = sub:addOption("Need a pen or pencil", player, nil)
                    d.notAvailable = true
                end

            elseif fullType == "EuroMillions.Ticket" then
                local md = item:getModData()
                local opt = context:addOption("Check EuroMillions Ticket", player,
                    function() doCheckTicket(player, item) end)
                if md.checked then
                    opt.notAvailable = true
                    local tip = ISToolTip:new()
                    tip:setName("Check EuroMillions Ticket")
                    local res = md.resultTier and md.resultTier > 0
                        and ("Won: " .. (EM.TIER_NAME[md.resultTier] or "")) or "No prize"
                    tip.description = "Already checked. " .. res
                    opt.toolTip = tip
                elseif md.drawName then
                    local tip = ISToolTip:new()
                    tip:setName("Check EuroMillions Ticket")
                    tip.description = "Numbers: " .. table.concat(md.mains or {}, " ")
                        .. "  Stars: " .. table.concat(md.stars or {}, " ")
                        .. " <LINE> Draw: " .. md.drawName
                    opt.toolTip = tip
                end

            elseif fullType == "EuroMillions.Flyer" then
                context:addOption("Read Flyer", player, function() doReadFlyer(player) end)
            end
        end
    end
end

Events.OnFillInventoryObjectContextMenu.Add(onFillContext)
