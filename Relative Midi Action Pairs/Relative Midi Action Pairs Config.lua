-- @description Relative Midi Action Pairs GUI Config
-- @version 1.2
-- @author Lazy Doug
-- @license MIT
-- @changelog
--   + Toolbar button toggle behavior
-- @about
--   # Relative CC Config GUI
--   Graphical interface to configure MIDI CC routing and relative encoder behavior.
-- @provides
--   [main] Relative Midi Action Pairs/Relative Midi Action Pairs Config.lua
--   Relative Midi Action Pairs/Relative Midi Action Pairs Main.lua



local EXTSECTION = "Relative_CC_Toolkit"

------------------------------------------------
-- Shared Configuration I/O via ExtState
------------------------------------------------
local function load_config()
  local configs = {}
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
      table.insert(configs, cfg)
    end
  end
  table.sort(configs, function(a, b)
    if a.chan == b.chan then return a.cc < b.cc else return a.chan < b.chan end
  end)
  return configs
end

local CONFIGS = load_config()

local function save_config(configs)
  reaper.DeleteExtState(EXTSECTION, "count", true)
  for i = 1, #configs do
    local cfg = configs[i]
    local line = string.format("CC=%d,CHAN=%d,INC=%s,DEC=%s", cfg.cc, cfg.chan, tostring(cfg.inc), tostring(cfg.dec))
    reaper.SetExtState(EXTSECTION, tostring(i), line, true)
  end
  reaper.SetExtState(EXTSECTION, "count", tostring(#configs), true)
  CONFIGS = load_config() -- Refresh after save
end

------------------------------------------------
-- GUI CONFIG
------------------------------------------------
local _, _, sectionID, cmdID = reaper.get_action_context()
local ctx = reaper.ImGui_CreateContext('Relative CC Config')
local FONT_SIZE = reaper.GetOS():match('Win') and 14 or 16
local FONT = reaper.ImGui_CreateFont('sans-serif', FONT_SIZE)
reaper.ImGui_Attach(ctx, FONT)

local configs = CONFIGS
local new_entry = { cc = 0, chan = 1, inc = 0, dec = 0 }
local editing_index = nil
local edit_entry = { cc = 0, chan = 1, inc = '', dec = '' }

local function get_action_name(cmd)
  local numeric_cmd = reaper.NamedCommandLookup(cmd) or cmd
  local name = reaper.kbd_getTextFromCmd(numeric_cmd, 0)
  return (name ~= "") and name or "(Unknown)"
end


local function check_duplicate(entry, index)
  for j, cfg in ipairs(configs) do
    if j ~= index and cfg.cc == entry.cc and cfg.chan == entry.chan then
      return true
    end
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
        local editing = (editing_index == i)
        local cfg = configs[i]
        reaper.ImGui_TableNextRow(ctx)

        if editing then
          reaper.ImGui_TableSetColumnIndex(ctx, 0)
          reaper.ImGui_SetNextItemWidth(ctx, -1)
          _, edit_entry.chan = reaper.ImGui_InputInt(ctx, '##edit_chan' .. i, edit_entry.chan)
          reaper.ImGui_TableSetColumnIndex(ctx, 1)
          reaper.ImGui_SetNextItemWidth(ctx, -1)
          _, edit_entry.cc = reaper.ImGui_InputInt(ctx, '##edit_cc' .. i, edit_entry.cc)
          reaper.ImGui_TableSetColumnIndex(ctx, 2)
          reaper.ImGui_SetNextItemWidth(ctx, -1)
          _, edit_entry.dec = reaper.ImGui_InputText(ctx, '##edit_dec' .. i, edit_entry.dec, 256)
          reaper.ImGui_TableSetColumnIndex(ctx, 3)
          reaper.ImGui_Text(ctx, get_action_name(edit_entry.dec))
          reaper.ImGui_TableSetColumnIndex(ctx, 4)
          reaper.ImGui_SetNextItemWidth(ctx, -1)
          _, edit_entry.inc = reaper.ImGui_InputText(ctx, '##edit_inc' .. i, edit_entry.inc, 256)
          reaper.ImGui_TableSetColumnIndex(ctx, 5)
          reaper.ImGui_Text(ctx, get_action_name(edit_entry.inc))
          reaper.ImGui_TableSetColumnIndex(ctx, 6)
          if reaper.ImGui_Button(ctx, 'Save##' .. i) then
            local duplicate = check_duplicate(edit_entry, i)
            if not duplicate then
              configs[i] = { cc = edit_entry.cc, chan = edit_entry.chan, inc = edit_entry.inc, dec = edit_entry.dec }
              save_config(configs)
              editing_index = nil
            else
              reaper.ShowMessageBox('Conflict: Duplicate Channel+CC.', 'Update Error', 0)
            end
          end
          reaper.ImGui_SameLine(ctx)
          if reaper.ImGui_Button(ctx, 'Cancel##' .. i) then editing_index = nil end
        else
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
          if reaper.ImGui_Button(ctx, 'Edit##' .. i) then
            editing_index = i
            edit_entry.cc = cfg.cc
            edit_entry.chan = cfg.chan
            edit_entry.inc = tostring(cfg.inc)
            edit_entry.dec = tostring(cfg.dec)
          end
          reaper.ImGui_SameLine(ctx)
          if reaper.ImGui_Button(ctx, 'Delete##' .. i) then
            table.remove(configs, i)
            save_config(configs)
            break
          end
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
      _, new_entry.dec = reaper.ImGui_InputText(ctx, '##new_dec', new_entry.dec)
      reaper.ImGui_TableSetColumnIndex(ctx, 3)
      reaper.ImGui_Text(ctx, get_action_name(new_entry.dec))
      reaper.ImGui_TableSetColumnIndex(ctx, 4)
      reaper.ImGui_SetNextItemWidth(ctx, -1)
      _, new_entry.inc = reaper.ImGui_InputText(ctx, '##new_inc', new_entry.inc)
      reaper.ImGui_TableSetColumnIndex(ctx, 5)
      reaper.ImGui_Text(ctx, get_action_name(new_entry.inc))
      reaper.ImGui_TableSetColumnIndex(ctx, 6)
      if reaper.ImGui_Button(ctx, 'Add##new') then
        local duplicate = check_duplicate(new_entry)
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
  if open then
    reaper.defer(loop)
  end
end

local function Exit()
  reaper.set_action_options(8)
  reaper.RefreshToolbar2(sectionID, cmdID)
end

reaper.atexit(Exit)
reaper.set_action_options(1|4)

reaper.defer(loop)
