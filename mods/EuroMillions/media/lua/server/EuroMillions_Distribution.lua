--[[ ============================================================================
     EuroMillions - loot distribution.

     Salts EuroMillions play slips, scratchcards and flyers into the kinds of
     places they'd really be found: shop counters, gas-station shelves,
     magazine racks and convenience stores. Rather than hard-code exact table
     names (which vary across versions), we match procedural tables by keyword
     so placement stays broad and version-resilient.
============================================================================ ]]

require "Items/ProceduralDistributions"

local LOOT = {
    { item = "EuroMillions.TicketBlank",        weight = 4 },
    { item = "EuroMillions.Flyer",              weight = 3 },
    { item = "EuroMillions.ScratchGoldRush",    weight = 2 },
    { item = "EuroMillions.ScratchLuckyStars",  weight = 2 },
    { item = "EuroMillions.ScratchMillionaire", weight = 1 },
    { item = "EuroMillions.Scratch777",         weight = 1 },
    { item = "EuroMillions.ScratchUsed",        weight = 1 },
}

-- Procedural table names containing any of these fragments get lottery loot.
local KEYWORDS = {
    "Counter", "Magazine", "GasStorage", "Store", "Till", "Shelf",
    "Conv", "PostOffice", "Gigamart", "Bin", "Locker", "Wallet", "Bag",
}

local function nameMatches(name)
    for _, kw in ipairs(KEYWORDS) do
        if string.find(name, kw) then return true end
    end
    return false
end

local function addLoot(items)
    for _, entry in ipairs(LOOT) do
        table.insert(items, entry.item)
        table.insert(items, entry.weight)
    end
end

local function patchDistribution()
    local list = ProceduralDistributions and ProceduralDistributions.list
    if not list then return end
    local patched = 0
    for name, def in pairs(list) do
        if type(def) == "table" and def.items and nameMatches(name) then
            addLoot(def.items)
            patched = patched + 1
        end
    end
    print("[EuroMillions] Loot injected into " .. patched .. " distribution tables.")
end

Events.OnPreDistributionMerge.Add(patchDistribution)
