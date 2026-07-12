-- Pure unit tests for Waypoint.provider. No WoW client needed.
-- (set/clear/available are WoW-only and verified in-game.)
-- Run: busted spec/

package.path = package.path .. ";./?.lua"
local Waypoint = require("Waypoint")

describe("Waypoint.provider", function()
    it("prefers TomTom when present", function()
        assert.are.equal("tomtom", Waypoint.provider(true, true))
        assert.are.equal("tomtom", Waypoint.provider(true, false))
    end)

    it("falls back to native when TomTom absent", function()
        assert.are.equal("native", Waypoint.provider(false, true))
    end)

    it("returns nil when neither backend is available", function()
        assert.is_nil(Waypoint.provider(false, false))
    end)
end)
