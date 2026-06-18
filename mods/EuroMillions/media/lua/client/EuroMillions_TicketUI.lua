--[[ ============================================================================
     EuroMillions play-slip UI.
     Mark 5 main numbers (1-50) and 2 Lucky Stars (1-12), or hit Lucky Dip for
     a random line. Confirm to fill out the slip into a dated ticket.
============================================================================ ]]

require "ISUI/ISPanel"
require "ISUI/ISButton"
require "EuroMillions/EuroMillions_Shared"
require "EuroMillions_Prizes"
require "timedactions/ISEMFillTicketAction"

local EM = EuroMillions

ISEMTicketUI = ISPanel:derive("ISEMTicketUI")

local NAVY  = {r=0.08, g=0.11, b=0.31, a=1.0}
local GOLD  = {r=1.0,  g=0.78, b=0.16, a=1.0}
local CELL  = {r=0.16, g=0.20, b=0.40, a=1.0}
local CELLH = {r=0.30, g=0.36, b=0.62, a=1.0}
local WHITE = {r=0.95, g=0.96, b=1.0,  a=1.0}

local CELL_SIZE = 26
local PAD = 4

function ISEMTicketUI:initialise()
    ISPanel.initialise(self)
end

local function mkButton(self, x, y, w, h, label, onclick, kind, value)
    local btn = ISButton:new(x, y, w, h, label, self, onclick)
    btn:initialise()
    btn:instantiate()
    btn.kind = kind
    btn.value = value
    btn:setFont(UIFont.Small)
    btn.borderColor = {r=0.5, g=0.55, b=0.7, a=1.0}
    self:addChild(btn)
    return btn
end

function ISEMTicketUI:createChildren()
    self.selMains = {}
    self.selStars = {}
    self.mainButtons = {}
    self.starButtons = {}

    local startY = 58
    -- Main numbers 1..50 in a 10-wide grid.
    local cols = 10
    for n = 1, EM.MAIN_MAX do
        local i = n - 1
        local col = i % cols
        local row = math.floor(i / cols)
        local x = PAD + col * (CELL_SIZE + PAD)
        local y = startY + row * (CELL_SIZE + PAD)
        self.mainButtons[n] = mkButton(self, x, y, CELL_SIZE, CELL_SIZE,
            tostring(n), self.onNumber, "main", n)
    end

    local starsY = startY + 5 * (CELL_SIZE + PAD) + 26
    self.starsLabelY = starsY - 20
    -- Lucky Stars 1..12 in a 6-wide grid.
    local scols = 6
    for n = 1, EM.STAR_MAX do
        local i = n - 1
        local col = i % scols
        local row = math.floor(i / scols)
        local x = PAD + col * (CELL_SIZE + PAD)
        local y = starsY + row * (CELL_SIZE + PAD)
        self.starButtons[n] = mkButton(self, x, y, CELL_SIZE, CELL_SIZE,
            tostring(n), self.onStar, "star", n)
    end

    local rowY = starsY + 2 * (CELL_SIZE + PAD) + 12
    local bw = (self.width - PAD * 5) / 4
    self.btnDip = mkButton(self, PAD, rowY, bw, 28, "Lucky Dip", self.onLuckyDip)
    self.btnClear = mkButton(self, PAD*2 + bw, rowY, bw, 28, "Clear", self.onClear)
    self.btnConfirm = mkButton(self, PAD*3 + bw*2, rowY, bw, 28, "Confirm", self.onConfirm)
    self.btnCancel = mkButton(self, PAD*4 + bw*3, rowY, bw, 28, "Cancel", self.onCancel)
    self.btnConfirm.textColor = GOLD

    self:refresh()
end

function ISEMTicketUI:countSel(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end

function ISEMTicketUI:onNumber(button)
    local n = button.value
    if self.selMains[n] then
        self.selMains[n] = nil
    elseif self:countSel(self.selMains) < EM.MAIN_COUNT then
        self.selMains[n] = true
    end
    self:refresh()
end

function ISEMTicketUI:onStar(button)
    local n = button.value
    if self.selStars[n] then
        self.selStars[n] = nil
    elseif self:countSel(self.selStars) < EM.STAR_COUNT then
        self.selStars[n] = true
    end
    self:refresh()
end

function ISEMTicketUI:onLuckyDip()
    local pick = EM.luckyDip()
    self.selMains, self.selStars = {}, {}
    for _, v in ipairs(pick.mains) do self.selMains[v] = true end
    for _, v in ipairs(pick.stars) do self.selStars[v] = true end
    self:refresh()
end

function ISEMTicketUI:onClear()
    self.selMains, self.selStars = {}, {}
    self:refresh()
end

function ISEMTicketUI:onCancel()
    self:close()
end

function ISEMTicketUI:onConfirm()
    if self:countSel(self.selMains) ~= EM.MAIN_COUNT
       or self:countSel(self.selStars) ~= EM.STAR_COUNT then
        return
    end
    local mains, stars = {}, {}
    for n in pairs(self.selMains) do mains[#mains+1] = n end
    for n in pairs(self.selStars) do stars[#stars+1] = n end
    table.sort(mains); table.sort(stars)

    if self.blank and self.character:getInventory():contains(self.blank) then
        ISTimedActionQueue.add(ISEMFillTicketAction:new(self.character, self.blank,
            { mains = mains, stars = stars }))
    end
    self:close()
end

function ISEMTicketUI:refresh()
    for n, btn in pairs(self.mainButtons) do
        if self.selMains[n] then
            btn.backgroundColor = GOLD
            btn.textColor = NAVY
        else
            btn.backgroundColor = CELL
            btn.textColor = WHITE
        end
        btn.backgroundColorMouseOver = CELLH
    end
    for n, btn in pairs(self.starButtons) do
        if self.selStars[n] then
            btn.backgroundColor = GOLD
            btn.textColor = NAVY
        else
            btn.backgroundColor = CELL
            btn.textColor = WHITE
        end
        btn.backgroundColorMouseOver = CELLH
    end
    local ready = self:countSel(self.selMains) == EM.MAIN_COUNT
                  and self:countSel(self.selStars) == EM.STAR_COUNT
    self.btnConfirm:setEnable(ready)
end

function ISEMTicketUI:prerender()
    ISPanel.prerender(self)
    -- Header band
    self:drawRect(0, 0, self.width, 50, 1.0, NAVY.r, NAVY.g, NAVY.b)
    self:drawTextCentre(EM.BRAND, self.width/2, 8, GOLD.r, GOLD.g, GOLD.b, 1, UIFont.Large)
    self:drawTextCentre("Pick " .. EM.MAIN_COUNT .. " numbers  -  " .. EM.TAGLINE,
        self.width/2, 32, WHITE.r, WHITE.g, WHITE.b, 1, UIFont.Small)

    local mc = self:countSel(self.selMains)
    local sc = self:countSel(self.selStars)
    self:drawText("Numbers: " .. mc .. "/" .. EM.MAIN_COUNT,
        PAD, self.starsLabelY - 28, WHITE.r, WHITE.g, WHITE.b, 1, UIFont.Small)
    self:drawText("Lucky Stars: " .. sc .. "/" .. EM.STAR_COUNT .. "  (1-" .. EM.STAR_MAX .. ")",
        PAD, self.starsLabelY, GOLD.r, GOLD.g, GOLD.b, 1, UIFont.Small)
end

function ISEMTicketUI:close()
    self:setVisible(false)
    self:removeFromUIManager()
    if ISEMTicketUI.instance == self then ISEMTicketUI.instance = nil end
end

function ISEMTicketUI:new(character, blank)
    local cols = 10
    local w = PAD + cols * (CELL_SIZE + PAD) + PAD
    local h = 58 + 5 * (CELL_SIZE + PAD) + 26 + 2 * (CELL_SIZE + PAD) + 12 + 28 + PAD
    local x = (getCore():getScreenWidth() - w) / 2
    local y = (getCore():getScreenHeight() - h) / 2
    local o = ISPanel:new(x, y, w, h)
    setmetatable(o, self)
    self.__index = self
    o.character = character
    o.blank = blank
    o.backgroundColor = {r=0.10, g=0.12, b=0.22, a=0.95}
    o.borderColor = GOLD
    o.moveWithMouse = true
    return o
end

function ISEMTicketUI.open(character, blank)
    if ISEMTicketUI.instance then ISEMTicketUI.instance:close() end
    local ui = ISEMTicketUI:new(character, blank)
    ui:initialise()
    ui:addToUIManager()
    ISEMTicketUI.instance = ui
    return ui
end
