-- Pure unit tests for Match.resolve. No WoW client needed.
-- Run: busted spec/   (from addon root)

package.path = package.path .. ";./?.lua"
-- Match.lua does `local addonName, addon = ...`; require passes the module name
-- as ..., so addon is nil and it just returns the table. Perfect for testing.
local Match = require("Match")

local function cand(questID, itemName, headerZone)
    return { questID = questID, itemID = questID * 10, itemName = itemName, headerZone = headerZone }
end

describe("Match.resolve", function()
    it("returns nil with no candidates", function()
        assert.is_nil(Match.resolve({}, "Netherstorm", {}))
    end)

    it("matches when header zone equals current zone", function()
        local c = cand(1, "Mantle", "Netherstorm")
        assert.are.equal(c, Match.resolve({ c }, "Netherstorm", {}))
    end)

    it("hides when zone differs", function()
        local c = cand(1, "Mantle", "Netherstorm")
        assert.is_nil(Match.resolve({ c }, "Shattrath City", {}))
    end)

    it("override zone beats header zone", function()
        local c = cand(1, "Mantle", "Netherstorm")
        local overrides = { [1] = { zone = "Zangarmarsh" } }
        assert.is_nil(Match.resolve({ c }, "Netherstorm", overrides))
        assert.are.equal(c, Match.resolve({ c }, "Zangarmarsh", overrides))
    end)

    it("skips disabled quests", function()
        local c = cand(1, "Mantle", "Netherstorm")
        assert.is_nil(Match.resolve({ c }, "Netherstorm", { [1] = { disabled = true } }))
    end)

    it("breaks ties by priority then scan order", function()
        local a = cand(1, "A", "Netherstorm")
        local b = cand(2, "B", "Netherstorm")
        -- no priority: first in scan order wins
        assert.are.equal(a, Match.resolve({ a, b }, "Netherstorm", {}))
        -- b has lower priority number -> b wins despite later order
        assert.are.equal(b, Match.resolve({ a, b }, "Netherstorm", { [2] = { priority = 1 } }))
    end)

    it("returns the in-zone survivor count as second value", function()
        local a = cand(1, "A", "Netherstorm")
        local b = cand(2, "B", "Netherstorm")
        local c = cand(3, "C", "Zangarmarsh")
        local _, count = Match.resolve({ a, b, c }, "Netherstorm", {})
        assert.are.equal(2, count)
    end)

    it("delegates winner choice to an injected pickFn", function()
        local a = cand(1, "A", "Netherstorm")
        local b = cand(2, "B", "Netherstorm")
        local called = false
        local pickFn = function(survivors)
            called = true
            return survivors[#survivors].candidate  -- pick LAST, unlike default
        end
        local best = Match.resolve({ a, b }, "Netherstorm", {}, nil, pickFn)
        assert.is_true(called)
        assert.are.equal(b, best)
    end)

    it("drops a candidate with no gate zone (nil header, no override)", function()
        local c = cand(1, "Mantle", nil)
        assert.is_nil(Match.resolve({ c }, "Netherstorm", {}))
    end)

    it("drops everything when currentZone is nil", function()
        local c = cand(1, "Mantle", "Netherstorm")
        local best, count = Match.resolve({ c }, nil, {})
        assert.is_nil(best)
        assert.are.equal(0, count)
    end)

    it("treats nil overrides the same as empty overrides", function()
        local c = cand(1, "Mantle", "Netherstorm")
        assert.are.equal(c, Match.resolve({ c }, "Netherstorm", nil))
    end)

    it("disabled beats an override zone that would otherwise match", function()
        local c = cand(1, "Mantle", "Netherstorm")
        local overrides = { [1] = { zone = "Zangarmarsh", disabled = true } }
        assert.is_nil(Match.resolve({ c }, "Zangarmarsh", overrides))
    end)

    it("among equal-priority survivors, earliest scan order wins", function()
        local a = cand(1, "A", "Netherstorm")
        local b = cand(2, "B", "Netherstorm")
        local overrides = { [1] = { priority = 5 }, [2] = { priority = 5 } }
        assert.are.equal(a, Match.resolve({ a, b }, "Netherstorm", overrides))
    end)

    it("calls the log callback (does not require it)", function()
        local c = cand(1, "Mantle", "Netherstorm")
        local calls = 0
        local log = function() calls = calls + 1 end
        Match.resolve({ c }, "Netherstorm", {}, log)
        assert.is_true(calls > 0)
    end)
end)

describe("Match.pickBest", function()
    local function surv(questID, name, order)
        return { candidate = name, questID = questID, order = order }
    end

    it("returns nil for no survivors", function()
        assert.is_nil(Match.pickBest({}, {}))
    end)

    it("lower priority number wins over scan order", function()
        local s = { surv(1, "A", 1), surv(2, "B", 2) }
        assert.are.equal("B", Match.pickBest(s, { [2] = { priority = 1 } }))
    end)

    it("no priorities -> first in scan order wins", function()
        local s = { surv(1, "A", 1), surv(2, "B", 2) }
        assert.are.equal("A", Match.pickBest(s, {}))
    end)
end)
