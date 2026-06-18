--[[ ============================================================================
     Timed action: scratching a EuroMillions scratchcard.
     Each card family has its own prize profile. The Millionaire Maker can,
     very rarely, pay out an *instant* jackpot - fanfare, horde and all.
============================================================================ ]]

require "TimedActions/ISBaseTimedAction"
require "EuroMillions/EuroMillions_Shared"
require "EuroMillions_Prizes"

local EM = EuroMillions

-- Weighted outcome tables per card. Each row is { tier, weight }; tier 0 = no win.
-- Tiers reuse the shared prize table (1..3 = jackpot-style instant wins).
EM.SCRATCH_ODDS = {
    ["EuroMillions.ScratchMillionaire"] = {
        {0, 620}, {13, 150}, {10, 90}, {6, 60}, {4, 40}, {2, 28}, {1, 12},
    },
    ["EuroMillions.ScratchLuckyStars"] = {
        {0, 600}, {13, 180}, {10, 110}, {7, 60}, {5, 35}, {3, 15},
    },
    ["EuroMillions.ScratchGoldRush"] = {
        {0, 480}, {13, 260}, {10, 150}, {6, 70}, {4, 30}, {3, 10},
    },
    ["EuroMillions.Scratch777"] = {
        {0, 700}, {13, 90}, {9, 90}, {5, 60}, {3, 40}, {2, 12}, {1, 8},
    },
}

function EM.rollScratch(cardType)
    local table_ = EM.SCRATCH_ODDS[cardType] or EM.SCRATCH_ODDS["EuroMillions.ScratchGoldRush"]
    local total = 0
    for _, row in ipairs(table_) do total = total + row[2] end
    local roll = ZombRand(total)
    local acc = 0
    for _, row in ipairs(table_) do
        acc = acc + row[2]
        if roll < acc then return row[1] end
    end
    return 0
end

----------------------------------------------------------------------------
ISEMScratchAction = ISBaseTimedAction:derive("ISEMScratchAction")

function ISEMScratchAction:isValid()
    return self.item and self.character:getInventory():contains(self.item)
end

function ISEMScratchAction:waitToStart()
    self.character:faceLocation(self.character:getX(), self.character:getY())
    return false
end

function ISEMScratchAction:update()
    self.character:setMetabolicTarget(Metabolics.LightDomestic)
end

function ISEMScratchAction:start()
    self.item:setJobType("Scratching card...")
    self.item:setJobDelta(0.0)
end

function ISEMScratchAction:stop()
    self.item:setJobDelta(0.0)
    ISBaseTimedAction.stop(self)
end

function ISEMScratchAction:perform()
    self.item:setJobDelta(0.0)
    local character = self.character
    local inv = character:getInventory()
    local cardType = self.item:getFullType()

    inv:Remove(self.item)
    inv:AddItem("EuroMillions.ScratchUsed")

    local tier = EM.rollScratch(cardType)
    if tier == 0 then
        EM.halo(character, "Not a winner. Better luck next time!", 0.8, 0.8, 0.8)
        character:Say("Damn. Nothing.")
    else
        EM.awardPrize(character, tier, "scratchcard")
    end

    ISBaseTimedAction.perform(self)
end

function ISEMScratchAction:new(character, item, time)
    local o = ISBaseTimedAction.new(self, character)
    o.item = item
    o.stopOnWalk = true
    o.stopOnRun = true
    o.maxTime = time or 180
    if character:isTimedActionInstant() then o.maxTime = 1 end
    return o
end
