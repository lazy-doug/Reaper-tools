-- @description Relative Midi Action Pairs GUI Config
-- @version 1.0
-- @author Lazy Doug
-- @license MIT
-- @changelog
--   + Initial release
-- @about
--   # Relative CC Config GUI
--   Graphical interface to configure MIDI CC routing and relative encoder behavior.
-- @provides
--   [main] Relative Midi Action Pairs/Relative Midi Action Pairs Config.lua
--   Relative Midi Action Pairs/Relative Midi Action Pairs Main.lua

local path = reaper.GetResourcePath() .. '/Scripts/Relative CC Toolkit/Relative Midi Action Pairs Main.lua'

local ok, result = pcall(dofile, path)
if ok and type(result) == "function" then
  result("config")
else
  reaper.ShowMessageBox("Failed to load Relative CC Package.lua\\n" .. tostring(result), "Error", 0)
end
