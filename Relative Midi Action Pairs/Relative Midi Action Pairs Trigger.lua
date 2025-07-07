-- @description Relative Midi Action Pairs Trigger
-- @version 1.2
-- @author Lazy Doug
-- @license MIT
-- @changelog
--   + Refactor
--   + Optimization
-- @about
--   # Relative CC MIDI Handler
--   Routes incoming MIDI CC from encoders to Reaper actions according to config.
-- @provides
--   [main] Relative Midi Action Pairs/Relative Midi Action Pairs Trigger.lua
--   Relative Midi Action Pairs/Relative Midi Action Pairs Main.lua



local EXTSECTION = "Relative_CC_Toolkit"

local function load_config()
  local lookup = {}
  local count = tonumber(reaper.GetExtState(EXTSECTION, "count")) or 0
  for i = 1, count do
    local line = reaper.GetExtState(EXTSECTION, tostring(i))
    local cc, chan, inc, dec = line:match("CC=(%d+),CHAN=(%d+),INC=([^,]+),DEC=([^,]+)")
    if cc and chan and inc and dec then
      local cfg = {
        cc = tonumber(cc),
        chan = tonumber(chan),
        inc = tostring(inc),
        dec = tostring(dec)
      }
      lookup[cfg.cc .. ":" .. cfg.chan] = cfg
    end
  end

  return lookup
end


local _, _, _, _, mode, _, val, context = reaper.get_action_context()
if mode <= 0 or not context:match("^midi") then return end
if val == 0 then return end

local status_hex, cc_hex = context:match("midi:(%x+):(%x+)")
if not status_hex or not cc_hex then return end

local status = tonumber(status_hex, 16)
if (status & 0xF0) ~= 0xB0 then return end

local cc = tonumber(cc_hex, 16)
local chan = (status & 0x0F) + 1
local key = cc .. ":" .. chan

local CONFIG_LOOKUP = load_config()
local cfg = CONFIG_LOOKUP[key]

if not cfg then return end

if val > 0 then
  local numeric_cmd = reaper.NamedCommandLookup(cfg.inc) or cfg.inc
  reaper.Main_OnCommand(numeric_cmd, 0)
elseif val < 0 then
  local numeric_cmd = reaper.NamedCommandLookup(cfg.dec) or cfg.inc
  reaper.Main_OnCommand(numeric_cmd, 0)
end
