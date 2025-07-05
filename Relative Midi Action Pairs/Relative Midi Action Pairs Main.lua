-- Package: Relative Midi Action Pairs
-- Fires different actions for each relative CC direction
-- @noindex



local EXTSECTION = "Relative_CC_Toolkit"

------------------------------------------------
-- Shared Configuration I/O via ExtState
------------------------------------------------
local function load_config()
  local configs = {}
  local lookup = {}
  local count = tonumber(reaper.GetExtState(EXTSECTION, "count")) or 0
  for i = 1, count do
    local line = reaper.GetExtState(EXTSECTION, tostring(i))
    local cc, chan, inc, dec = line:match("CC=(%d+),CHAN=(%d+),INC=(%d+),DEC=(%d+)")
    if cc and chan and inc and dec then
      local cfg = {
        cc = tonumber(cc),
        chan = tonumber(chan),
        inc = tonumber(inc),
        dec = tonumber(dec)
      }
      table.insert(configs, cfg)
      lookup[cfg.cc .. ":" .. cfg.chan] = cfg
    end
  end
  table.sort(configs, function(a, b)
    if a.chan == b.chan then return a.cc < b.cc else return a.chan < b.chan end
  end)
  return configs, lookup
end

local CONFIGS, CONFIG_LOOKUP = load_config()

local function save_config(configs)
  reaper.DeleteExtState(EXTSECTION, "count", true)
  for i = 1, #configs do
    local cfg = configs[i]
    local line = string.format("CC=%d,CHAN=%d,INC=%d,DEC=%d", cfg.cc, cfg.chan, cfg.inc, cfg.dec)
    reaper.SetExtState(EXTSECTION, tostring(i), line, true)
  end
  reaper.SetExtState(EXTSECTION, "count", tostring(#configs), true)
  CONFIGS, CONFIG_LOOKUP = load_config() -- Refresh after save
end

------------------------------------------------
-- GUI CONFIG FUNCTION
------------------------------------------------
local function config_gui()
  local ctx = reaper.ImGui_CreateContext('Relative CC Config')
  local FONT_SIZE = reaper.GetOS():match('Win') and 14 or 16
  local FONT = reaper.ImGui_CreateFont('sans-serif', FONT_SIZE)
  reaper.ImGui_Attach(ctx, FONT)

  local configs = CONFIGS
  local new_entry = { cc = 0, chan = 1, inc = 0, dec = 0 }

  local function get_action_name(cmd)
    local name = reaper.ReverseNamedCommandLookup(cmd)
    if name and name ~= "" then
      return name
    else
      local name = reaper.kbd_getTextFromCmd(cmd, 0)
      return (name ~= "") and name or "(Unknown)"
    end
  end

  local function loop()
    local visible, open = reaper.ImGui_Begin(ctx, 'Relative CC Config Manager', true)
    if visible then
      reaper.ImGui_PushFont(ctx, FONT)

      reaper.ImGui_Separator(ctx)

      if reaper.ImGui_BeginTable(ctx, "config_table", 7, reaper.ImGui_TableFlags_Borders()) then
        reaper.ImGui_TableSetupColumn(ctx, "Channel")
        reaper.ImGui_TableSetupColumn(ctx, "CC")
        reaper.ImGui_TableSetupColumn(ctx, "Dec action ID")
        reaper.ImGui_TableSetupColumn(ctx, "Dec action name", reaper.ImGui_TableColumnFlags_WidthStretch(), 3.0)
        reaper.ImGui_TableSetupColumn(ctx, "Inc action ID")
        reaper.ImGui_TableSetupColumn(ctx, "Inc action name", reaper.ImGui_TableColumnFlags_WidthStretch(), 3.0)
        reaper.ImGui_TableSetupColumn(ctx, "Action")
        reaper.ImGui_TableHeadersRow(ctx)

        for i = 1, #configs do
          local cfg = configs[i]
          reaper.ImGui_TableNextRow(ctx)
          reaper.ImGui_TableSetColumnIndex(ctx, 0)
          reaper.ImGui_Text(ctx, tostring(cfg.chan))
          reaper.ImGui_TableSetColumnIndex(ctx, 1)
          reaper.ImGui_Text(ctx, tostring(cfg.cc))
          reaper.ImGui_TableSetColumnIndex(ctx, 2)
          reaper.ImGui_Text(ctx, tostring(cfg.dec))
          reaper.ImGui_TableSetColumnIndex(ctx, 3)
          reaper.ImGui_Text(ctx, get_action_name(cfg.dec))
          reaper.ImGui_TableSetColumnIndex(ctx, 4)
          reaper.ImGui_Text(ctx, tostring(cfg.inc))
          reaper.ImGui_TableSetColumnIndex(ctx, 5)
          reaper.ImGui_Text(ctx, get_action_name(cfg.inc))
          reaper.ImGui_TableSetColumnIndex(ctx, 6)
          if reaper.ImGui_Button(ctx, "Delete##" .. i) then
            table.remove(configs, i)
            save_config(configs)
          end
        end

        reaper.ImGui_TableNextRow(ctx)
        reaper.ImGui_TableSetColumnIndex(ctx, 0)
        reaper.ImGui_SetNextItemWidth(ctx, -1)
        _, new_entry.chan = reaper.ImGui_InputInt(ctx, '##new_chan', new_entry.chan)
        reaper.ImGui_TableSetColumnIndex(ctx, 1)
        reaper.ImGui_SetNextItemWidth(ctx, -1)
        _, new_entry.cc = reaper.ImGui_InputInt(ctx, '##new_cc', new_entry.cc)
        reaper.ImGui_TableSetColumnIndex(ctx, 2)
        reaper.ImGui_SetNextItemWidth(ctx, -1)
        _, new_entry.dec = reaper.ImGui_InputInt(ctx, '##new_dec', new_entry.dec)
        reaper.ImGui_TableSetColumnIndex(ctx, 3)
        reaper.ImGui_Text(ctx, get_action_name(new_entry.dec))
        reaper.ImGui_TableSetColumnIndex(ctx, 4)
        reaper.ImGui_SetNextItemWidth(ctx, -1)
        _, new_entry.inc = reaper.ImGui_InputInt(ctx, '##new_inc', new_entry.inc)
        reaper.ImGui_TableSetColumnIndex(ctx, 5)
        reaper.ImGui_Text(ctx, get_action_name(new_entry.inc))
        reaper.ImGui_TableSetColumnIndex(ctx, 6)
        if reaper.ImGui_Button(ctx, 'Add##new') then
          local duplicate = false
          for _, cfg in ipairs(configs) do
            if cfg.cc == new_entry.cc and cfg.chan == new_entry.chan then
              duplicate = true
              break
            end
          end
          if not duplicate then
            table.insert(configs, {
              cc = new_entry.cc,
              chan = new_entry.chan,
              inc = new_entry.inc,
              dec = new_entry.dec
            })
            save_config(configs)
          else
            reaper.ShowMessageBox("A mapping for this Channel+CC combination already exists.", "Duplicate Entry", 0)
          end
        end

        reaper.ImGui_EndTable(ctx)
      end

      reaper.ImGui_PopFont(ctx)
      reaper.ImGui_End(ctx)
    end
    if open then reaper.defer(loop) end
  end

  loop()
end

------------------------------------------------
-- MIDI HANDLER FUNCTION
------------------------------------------------
local function handle_midi()
  local _, _, _, _, mode, _, val, context = reaper.get_action_context()
  if mode <= 0 or not context:match("^midi") then return end
  if val == 0 then return end

  local status_hex, cc_hex = context:match("midi:(%x+):(%x+)")
  if not status_hex or not cc_hex then return end

  local status = tonumber(status_hex, 16)
  if (status & 0xF0) ~= 0xB0 then return end -- Not CC

  local cc = tonumber(cc_hex, 16)
  local chan = (status & 0x0F) + 1
  local key = cc .. ":" .. chan

  local cfg = CONFIG_LOOKUP[key]
  if not cfg then return end

  if val > 0 then
    reaper.Main_OnCommand(cfg.inc, 0)
  elseif val < 0 then
    reaper.Main_OnCommand(cfg.dec, 0)
  end
end

------------------------------------------------
-- Return dispatcher function
------------------------------------------------
return function(mode)
  if mode == "config" then
    config_gui()
  elseif mode == "handler" then
    handle_midi()
  end
end
