--[[ ============================================================================
     Timed action: filling out a EuroMillions play slip.
     Consumes a blank slip and produces a dated EuroMillions Ticket carrying
     the player's 5 numbers + 2 Lucky Stars in its mod data, entered into the
     next upcoming draw.
============================================================================ ]]

require "TimedActions/ISBaseTimedAction"
require "EuroMillions/EuroMillions_Shared"
require "EuroMillions_Prizes"

local EM = EuroMillions

ISEMFillTicketAction = ISBaseTimedAction:derive("ISEMFillTicketAction")

function ISEMFillTicketAction:isValid()
    return self.blank and self.character:getInventory():contains(self.blank)
end

function ISEMFillTicketAction:start()
    self.blank:setJobType("Filling out play slip...")
    self.blank:setJobDelta(0.0)
end

function ISEMFillTicketAction:update()
    self.character:setMetabolicTarget(Metabolics.LightDomestic)
end

function ISEMFillTicketAction:stop()
    self.blank:setJobDelta(0.0)
    ISBaseTimedAction.stop(self)
end

function ISEMFillTicketAction:perform()
    self.blank:setJobDelta(0.0)
    local character = self.character
    local inv = character:getInventory()

    inv:Remove(self.blank)
    local ticket = inv:AddItem("EuroMillions.Ticket")

    local today = EM.getToday()
    local drawSerial = EM.nextDrawSerial(today)
    local md = ticket:getModData()
    md.mains    = self.picks.mains
    md.stars    = self.picks.stars
    md.drawSerial = drawSerial
    md.drawName = EM.drawDayName(drawSerial)
    md.checked  = false
    md.boughtSerial = today.serial

    local nums = table.concat(self.picks.mains, " ")
    local stars = table.concat(self.picks.stars, " ")
    EM.halo(character, "Ticket entered for " .. md.drawName .. "'s draw!", 0.6, 1, 0.6)
    character:Say("My numbers: " .. nums .. "  Stars: " .. stars)

    ISBaseTimedAction.perform(self)
end

function ISEMFillTicketAction:new(character, blank, picks, time)
    local o = ISBaseTimedAction.new(self, character)
    o.blank = blank
    o.picks = picks            -- { mains = {...}, stars = {...} }
    o.stopOnWalk = true
    o.stopOnRun = true
    o.maxTime = time or 150
    if character:isTimedActionInstant() then o.maxTime = 1 end
    return o
end
