-- @description Relative Midi Action Pairs Trigger
-- @version 1.0
-- @author Lazy Doug
-- @license MIT
-- @changelog
--   + Initial release
-- @about
--   # Relative CC MIDI Handler
--   Routes incoming MIDI CC from encoders to Reaper actions according to config.
-- @provides
--   [main] Relative Midi Action Pairs/Relative Midi Action Pairs Trigger.lua
--   Relative Midi Action Pairs/Relative Midi Action Pairs Main.lua



local path = reaper.GetResourcePath() .. "/Scripts/Lazy-Doug Tools/Midi Actions/Relative Midi Action Pairs Main.lua"

local ok, result = pcall(dofile, path)
if ok and type(result) == "function" then
  result("trigger")
else
  reaper.ShowMessageBox("Failed to load Main Package (Relative Midi Action Pairs Main.lua)" .. tostring(result), "Error",
    0)
end
