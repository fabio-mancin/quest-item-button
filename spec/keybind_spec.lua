-- Pure unit tests for Keybind.normalize. No WoW client needed.
-- (Keybind.apply is WoW-only and verified in-game.)
-- Run: busted spec/

package.path = package.path .. ";./?.lua"
local Keybind = require("Keybind")

describe("Keybind.normalize", function()
    it("uppercases a key", function()
        assert.are.equal("F", Keybind.normalize("f"))
    end)

    it("passes modifier chords through, uppercased", function()
        assert.are.equal("CTRL-SHIFT-Q", Keybind.normalize("ctrl-shift-q"))
    end)

    it("strips surrounding whitespace", function()
        assert.are.equal("F", Keybind.normalize("  f  "))
    end)

    it("returns nil for empty / whitespace-only", function()
        assert.is_nil(Keybind.normalize(""))
        assert.is_nil(Keybind.normalize("   "))
    end)

    it("returns nil for non-strings", function()
        assert.is_nil(Keybind.normalize(nil))
        assert.is_nil(Keybind.normalize(123))
    end)
end)
