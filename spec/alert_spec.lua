-- Pure unit tests for Alert.shouldAlert. No WoW client needed.
-- Run: busted spec/

package.path = package.path .. ";./?.lua"
local Alert = require("Alert")

describe("Alert.shouldAlert", function()
    it("alerts when an item first appears (nil -> item)", function()
        assert.is_true(Alert.shouldAlert(nil, 11162))
    end)

    it("alerts when the shown item changes (item -> other item)", function()
        assert.is_true(Alert.shouldAlert(11162, 10256))
    end)

    it("does not re-alert when the same item stays shown", function()
        assert.is_false(Alert.shouldAlert(11162, 11162))
    end)

    it("does not alert when the button hides (item -> nil)", function()
        assert.is_false(Alert.shouldAlert(11162, nil))
    end)

    it("does not alert on nil -> nil", function()
        assert.is_false(Alert.shouldAlert(nil, nil))
    end)
end)
