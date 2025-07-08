-- @description Relative Midi Action Pairs Trigger
-- @version 1.3
-- @author Lazy Doug
-- @license MIT
-- @changelog
--   + Trigger optimization
-- @about
--   # Relative CC MIDI Handler
--   Routes incoming MIDI CC from encoders to Reaper actions according to config.
-- @provides
--   [main] Relative Midi Action Pairs/Relative Midi Action Pairs Trigger.lua
--   Relative Midi Action Pairs/Relative Midi Action Pairs Main.lua



------------------------------------------------
-- Lib import
------------------------------------------------
local script_path           = debug.getinfo(1, "S").source:match("@(.*[\\/])")
package.path                = package.path .. ";" .. script_path .. "lib/?.lua"
local json                  = require "json"

------------------------------------------------
-- Constants
------------------------------------------------

local CONFIG_CH_EXT_SECTION = "Lazy-Doug RMAP config"

local CACHED_CONFIG         = {}


local function check_cache(ch, cc)
  return CACHED_CONFIG.ch == ch and CACHED_CONFIG.cc == cc and CACHED_CONFIG.commands
end

local function update_cache(ch, cc, commands)
  CACHED_CONFIG.ch = ch
  CACHED_CONFIG.cc = cc
  CACHED_CONFIG.commands = commands
end

local function load_config(ch, cc)
  local channelConfig = reaper.GetExtState(CONFIG_CH_EXT_SECTION, tostring(ch))
  if not channelConfig then return end
  local ok, ccData = pcall(json.decode, channelConfig)

  if ok and type(ccData) == "table" then
    local commands = ccData[tostring(cc)]
    update_cache(ch, cc, commands)

    return commands
  end
end


local function listener()
  local _, _, _, _, mode, _, val, context = reaper.get_action_context()
  if mode <= 0 or not context:match("^midi") then return end
  if val == 0 then return end

  local status_hex, cc_hex = context:match("midi:(%x+):(%x+)")
  if not status_hex or not cc_hex then return end

  local status = tonumber(status_hex, 16)
  if (status & 0xF0) ~= 0xB0 then return end

  local ch = (status & 0x0F) + 1
  local cc = tonumber(cc_hex, 16)

  local commands = check_cache(ch, cc) and CACHED_CONFIG.commands or load_config(ch, cc)

  if not commands then return end

  if val > 0 then
    local numeric_cmd = reaper.NamedCommandLookup(commands.inc) or commands.inc
    reaper.Main_OnCommand(numeric_cmd, 0)
  elseif val < 0 then
    local numeric_cmd = reaper.NamedCommandLookup(commands.dec) or commands.inc
    reaper.Main_OnCommand(numeric_cmd, 0)
  end


  reaper.defer(listener)
end

listener()
