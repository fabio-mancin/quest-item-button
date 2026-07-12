-- Structural validation of the shipped Data table. No WoW client needed.
-- Guards against a malformed override/byItem entry rotting the dataset — it
-- checks SHAPE, not game correctness (IDs can't be verified offline).
-- Run: busted spec/

package.path = package.path .. ";./?.lua"
local Data = require("Data")

-- keys an overrides entry is allowed to carry, and the type each must be
local OVERRIDE_KEYS = {
    zone = "string",
    subzone = "string",
    priority = "number",
    disabled = "boolean",
}

local function isPositiveInt(n)
    return type(n) == "number" and n > 0 and math.floor(n) == n
end

describe("Data.overrides", function()
    it("is a table", function()
        assert.are.equal("table", type(Data.overrides))
    end)

    it("keys are positive integer questIDs", function()
        for questID in pairs(Data.overrides) do
            assert.is_true(isPositiveInt(questID), "bad questID key: " .. tostring(questID))
        end
    end)

    it("entries only carry known keys of the right type", function()
        for questID, o in pairs(Data.overrides) do
            assert.are.equal("table", type(o), "override " .. questID .. " is not a table")
            for k, v in pairs(o) do
                local want = OVERRIDE_KEYS[k]
                assert.is_truthy(want, ("override %d has unknown key '%s'"):format(questID, tostring(k)))
                assert.are.equal(want, type(v),
                    ("override %d key '%s' should be %s, got %s"):format(questID, k, want, type(v)))
            end
        end
    end)

    it("has no disabled entry that also sets a zone (contradiction)", function()
        for questID, o in pairs(Data.overrides) do
            if o.disabled then
                assert.is_nil(o.zone, "override " .. questID .. " is disabled AND sets a zone")
            end
        end
    end)
end)

describe("Data.byItem", function()
    it("is a table", function()
        assert.are.equal("table", type(Data.byItem))
    end)

    it("keys (itemID) and values (questID) are positive integers", function()
        for itemID, questID in pairs(Data.byItem) do
            assert.is_true(isPositiveInt(itemID), "bad itemID key: " .. tostring(itemID))
            assert.is_true(isPositiveInt(questID), "bad questID value: " .. tostring(questID))
        end
    end)

    it("does not attach an item to a quest that is disabled in overrides", function()
        for itemID, questID in pairs(Data.byItem) do
            local o = Data.overrides[questID]
            assert.is_falsy(o and o.disabled,
                ("byItem %d -> quest %d, but that quest is disabled"):format(itemID, questID))
        end
    end)
end)
