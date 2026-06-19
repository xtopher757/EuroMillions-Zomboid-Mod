--[[ ============================================================================
     Timed action: scratching a EuroMillions scratchcard.
     The card is consumed locally (the client owns its own inventory), then the
     outcome is requested from the server which rolls it and pays out. See
     EuroMillions_Prizes.lua (EM.requestScratch) and EuroMillions_Server.lua.
============================================================================ ]]

require "TimedActions/ISBaseTimedAction"
require "EuroMillions/EuroMillions_Shared"
require "EuroMillions_Prizes"

local EM = EuroMillions

ISEMScratchAction = ISBaseTimedAction:derive("ISEMScratchAction")

function ISEMScratchAction:isValid()
    return self.item and self.character:getInventory():contains(self.item)
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

    -- Consume the card and leave behind a used one (own-inventory edits sync).
    inv:Remove(self.item)
    inv:AddItem("EuroMillions.ScratchUsed")

    -- Ask the server (or, in SP, act locally) for the outcome + payout.
    EM.requestScratch(character, cardType)

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
