-- Unit tests for Config: default merge, account vs profile scoping, profile
-- management, and migration from the old flat layout. No WoW client needed.
-- Run: busted spec/

package.path = package.path .. ";./?.lua"
local Config = require("Config")

-- Deterministic character key so tests don't depend on WoW globals.
local charKey = "Tester - Realm"
Config.charKey = function() return charKey end

before_each(function()
    _G.QuestItemButtonDB = nil     -- fresh SavedVariable each test
    charKey = "Tester - Realm"
end)

describe("Config defaults & scoping", function()
    it("fills a default on first read", function()
        assert.is_true(Config.get("hideComplete"))   -- default true
        assert.is_false(Config.get("locked"))        -- default false
    end)

    it("persists a set value", function()
        Config.set("locked", true)
        assert.is_true(Config.get("locked"))
    end)

    it("initialises nested default tables", function()
        assert.are.equal("table", type(Config.get("disabledQuests")))
        Config.setQuestDisabled(123, true)
        assert.is_true(Config.isQuestDisabled(123))
        Config.setQuestDisabled(123, false)
        assert.is_false(Config.isQuestDisabled(123))
    end)

    it("stores minimap at account scope (shared across profiles)", function()
        Config.get("minimap").hide = true
        Config.setProfile("Other")
        assert.is_true(Config.get("minimap").hide)   -- same table across profiles
    end)
end)

describe("Config profiles", function()
    it("starts on the Default profile", function()
        assert.are.equal("Default", Config.currentProfile())
    end)

    it("isolates settings between profiles", function()
        Config.set("locked", true)               -- Default
        Config.setProfile("Alt")
        assert.is_false(Config.get("locked"))    -- Alt gets its own default
        Config.set("locked", true)               -- Alt
        Config.setProfile("Default")
        assert.is_true(Config.get("locked"))     -- Default unchanged
    end)

    it("lists profiles sorted", function()
        Config.setProfile("Alt")
        Config.setProfile("Zzz")
        Config.setProfile("Default")
        assert.are.same({ "Alt", "Default", "Zzz" }, Config.profileNames())
    end)

    it("copies settings from another profile", function()
        Config.set("distanceYards", 250)         -- Default
        Config.setProfile("Alt")
        Config.copyProfile("Default")
        assert.are.equal(250, Config.get("distanceYards"))
    end)

    it("resets the current profile to defaults", function()
        Config.set("distanceYards", 250)
        Config.resetProfile()
        assert.are.equal(100, Config.get("distanceYards"))
    end)

    it("deletes a non-current profile but refuses the current/last one", function()
        Config.setProfile("Alt")                 -- current = Alt, also creates it
        Config.setProfile("Default")             -- back to Default
        Config.deleteProfile("Alt")
        assert.are.same({ "Default" }, Config.profileNames())
        Config.deleteProfile("Default")          -- current -> refused
        assert.are.same({ "Default" }, Config.profileNames())
    end)
end)

describe("Config migration", function()
    it("lifts an old flat layout into profiles.Default", function()
        _G.QuestItemButtonDB = { locked = true, distanceYards = 175 }
        assert.is_true(Config.get("locked"))
        assert.are.equal(175, Config.get("distanceYards"))
        assert.are.equal("Default", Config.currentProfile())
        assert.is_nil(_G.QuestItemButtonDB.locked)   -- moved out of the root
        assert.is_truthy(_G.QuestItemButtonDB.profiles.Default)
    end)
end)
