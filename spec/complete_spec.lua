-- Pure unit tests for Complete.isComplete. No WoW client needed.
-- Run: busted spec/

package.path = package.path .. ";./?.lua"
local Complete = require("Complete")

local function lb(...)
    local t = {}
    for _, finished in ipairs({ ... }) do
        t[#t + 1] = { finished = finished }
    end
    return t
end

describe("Complete.isComplete", function()
    it("is false for an empty objective list", function()
        assert.is_false(Complete.isComplete({}))
    end)

    it("is false for nil", function()
        assert.is_false(Complete.isComplete(nil))
    end)

    it("is true when the single objective is finished", function()
        assert.is_true(Complete.isComplete(lb(true)))
    end)

    it("is true when every objective is finished", function()
        assert.is_true(Complete.isComplete(lb(true, true, true)))
    end)

    it("is false when any objective is unfinished", function()
        assert.is_false(Complete.isComplete(lb(true, false, true)))
    end)

    it("is false when all objectives are unfinished", function()
        assert.is_false(Complete.isComplete(lb(false, false)))
    end)
end)
