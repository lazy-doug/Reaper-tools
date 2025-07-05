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



local path = reaper.GetResourcePath() .. "/Scripts/Relative CC Toolkit/Relative Midi Action Pairs Main.lua"

local ok, result = pcall(dofile, path)
if ok and type(result) == "function" then
  result("handler")
else
  reaper.ShowMessageBox("Failed to load Relative CC Package.lua\\n" .. tostring(result), "Error", 0)
end
