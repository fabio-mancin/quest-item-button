-- Pure unit tests for Learn.note. No WoW client needed.
-- Run: busted spec/

package.path = package.path .. ";./?.lua"
local Learn = require("Learn")

describe("Learn.note", function()
    it("records a brand-new observation and reports it", function()
        local store = {}
        assert.is_true(Learn.note(store, 11162, "Netherstorm"))
        assert.are.equal("Netherstorm", store[11162])
    end)

    it("dedupes an identical repeat observation", function()
        local store = {}
        assert.is_true(Learn.note(store, 11162, "Netherstorm"))
        assert.is_false(Learn.note(store, 11162, "Netherstorm"))
    end)

    it("reports again when the zone changes", function()
        local store = {}
        Learn.note(store, 11162, "Netherstorm")
        assert.is_true(Learn.note(store, 11162, "Zangarmarsh"))
        assert.are.equal("Zangarmarsh", store[11162])
    end)

    it("skips quests already covered by shipped data", function()
        local store = {}
        local known = function(q) return q == 11162 end
        assert.is_false(Learn.note(store, 11162, "Netherstorm", known))
        assert.is_nil(store[11162])
        -- an unknown quest still records
        assert.is_true(Learn.note(store, 99999, "Nagrand", known))
    end)

    it("ignores nil/empty inputs", function()
        local store = {}
        assert.is_false(Learn.note(store, nil, "Netherstorm"))
        assert.is_false(Learn.note(store, 11162, nil))
        assert.is_false(Learn.note(store, 11162, ""))
        assert.are.equal(0, next(store) and 1 or 0)
    end)
end)
