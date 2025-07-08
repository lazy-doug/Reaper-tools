-- @description Relative Midi Action Pairs GUI Config
-- @version 1.3
-- @author Lazy Doug
-- @license MIT
-- @changelog
--   + Trigger optimization
-- @about
--   # Relative CC Config GUI
--   Graphical interface to configure MIDI CC routing and relative encoder behavior.
-- @provides
--   [main] Relative Midi Action Pairs/Relative Midi Action Pairs Config.lua
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

local EXT_SECTION           = "Lazy-Doug RMAP"
local CHANNELS_EXT_KEY      = "channels"
local CONFIG_CH_EXT_SECTION = "Lazy-Doug RMAP config"

------------------------------------------------
-- Shared Configuration I/O via ExtState
------------------------------------------------
local function load_config()
  local table_configs = {}
  local nested_configs = {}
  local channelsRaw = reaper.GetExtState(EXT_SECTION, CHANNELS_EXT_KEY)

  local channels = json.decode(channelsRaw)

  if not channels then
    return table_configs, nested_configs
  end


  table.sort(channels, function(a, b) return tonumber(a) < tonumber(b) end)

  for _, ch in ipairs(channels) do
    ch = tostring(ch)
    local channelConfig = reaper.GetExtState(CONFIG_CH_EXT_SECTION, ch)

    if channelConfig then
      local ok, ccData = pcall(json.decode, channelConfig)

      if ok and type(ccData) == "table" then
        local sorted_ccs = {}
        for k in pairs(ccData) do
          table.insert(sorted_ccs, k)
        end
        table.sort(sorted_ccs, function(a, b) return tonumber(a) < tonumber(b) end)

        for _, cc in ipairs(sorted_ccs) do
          local commands = ccData[cc]
          cc = tostring(cc)
          local inc = tostring(commands.inc or "")
          local dec = tostring(commands.dec or "")

          nested_configs[ch] = nested_configs[ch] or {}
          nested_configs[ch][cc] = { inc = inc, dec = dec }

          table.insert(table_configs, {
            ch = ch,
            cc = cc,
            inc = inc,
            dec = dec
          })
        end
      end
    end
  end



  return table_configs, nested_configs
end

local TABLE_CONFIGS, NESTED_CONFIGS = load_config()

local function table_config_to_extstate(table_configs)
  local nested = {}

  for _, cfg in ipairs(table_configs) do
    local ch = tostring(cfg.ch)
    local cc = tostring(cfg.cc)
    local inc = tostring(cfg.inc or "")
    local dec = tostring(cfg.dec or "")

    nested[ch] = nested[ch] or {}
    nested[ch][cc] = { inc = inc, dec = dec }
  end

  return nested
end

local function save_config(ext_configs)
  local channels = {}

  for ch, ch_cfg in pairs(ext_configs) do
    table.insert(channels, ch)



    local json_string = json.encode(ch_cfg)

    reaper.SetExtState(CONFIG_CH_EXT_SECTION, tostring(ch), json_string, true)
  end


  reaper.SetExtState(EXT_SECTION, CHANNELS_EXT_KEY, json.encode(channels), true)

  TABLE_CONFIGS, NESTED_CONFIGS = load_config()
end

------------------------------------------------
-- GUI CONFIG
------------------------------------------------
local _, _, sectionID, cmdID = reaper.get_action_context()
local ctx = reaper.ImGui_CreateContext('Relative CC Config')
local FONT_SIZE = reaper.GetOS():match('Win') and 14 or 16
local FONT = reaper.ImGui_CreateFont('sans-serif', FONT_SIZE)
reaper.ImGui_Attach(ctx, FONT)

local new_entry = { cc = 0, ch = 1, inc = 0, dec = 0 }
local editing_index = nil
local edit_entry = { cc = 0, ch = 1, inc = '', dec = '' }

local function get_action_name(cmd)
  local numeric_cmd = reaper.NamedCommandLookup(cmd) or cmd
  local name = reaper.kbd_getTextFromCmd(numeric_cmd, 0)
  return (name ~= "") and name or "(Unknown)"
end


local function check_duplicate(entry, index)
  for j, cfg in ipairs(TABLE_CONFIGS) do
    if j ~= index and tonumber(cfg.cc) == entry.cc and tonumber(cfg.chan) == entry.chan then
      return true
    end
  end
end

local function loop()
  local visible, open = reaper.ImGui_Begin(ctx, 'Relative CC Config Manager', true)
  if visible then
    reaper.ImGui_PushFont(ctx, FONT)

    -- Export Button
    if reaper.ImGui_Button(ctx, "Export Config") then
      local ok, path = reaper.JS_Dialog_BrowseForSaveFile("Save Config", reaper.GetResourcePath(),
        "Lazy-Doug-RMAP-config.json",
        "*.json")
      if ok and path and path ~= "" then
        local file = io.open(path, "w")
        if file then
          file:write(json.encode(NESTED_CONFIGS))
          file:close()
          reaper.ShowMessageBox("Config exported to:\n" .. path, "Export Complete", 0)
        else
          reaper.ShowMessageBox("Failed to write export file.", "Export Error", 0)
        end
      end
    end

    reaper.ImGui_SameLine(ctx)

    -- Import Button
    if reaper.ImGui_Button(ctx, "Import Config") then
      local ok, path = reaper.JS_Dialog_BrowseForOpenFiles("Import Config", reaper.GetResourcePath(), "",
        "JSON files (*.json)\0*.json\0All files (*.*)\0*.*\0", false)
      if ok and path and path ~= "" then
        local file = io.open(path, "r")
        if file then
          local content = file:read("*a")
          file:close()

          local parsed = json.decode(content)

          local valid = type(parsed) == "table"

          if valid then
            for ch, cc_config in pairs(parsed) do
              if type(cc_config) ~= "table"
                  or tonumber(ch) == nil then
                valid = false
                break
              end



              for cc, commands in pairs(cc_config) do
                if type(commands) ~= "table"
                    or tonumber(cc) == nil
                    or commands.inc == nil
                    or commands.dec == nil
                    or type(commands.inc) ~= "string"
                    or type(commands.dec) ~= "string" then
                  valid = false
                  break
                end
              end

              if not valid then
                break
              end
            end
          end

          if valid then
            save_config(parsed)
            reaper.ShowMessageBox("Config imported from:\n" .. path, "Import Complete", 0)
          else
            reaper.ShowMessageBox("Invalid config format in selected file.", "Import Error", 0)
          end
        else
          reaper.ShowMessageBox("Could not open file.", "Import Error", 0)
        end
      end
    end


    reaper.ImGui_SameLine(ctx)

    -- Reset Button
    if reaper.ImGui_Button(ctx, "Reset Config") then
      local confirm = reaper.ShowMessageBox("Are you sure you want to reset all config entries?", "Confirm Reset", 1)
      if confirm == 1 then
        save_config({})
      end
    end

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


      for i, row_cfg in ipairs(TABLE_CONFIGS) do
        local editing = (editing_index == i)
        reaper.ImGui_TableNextRow(ctx)

        if editing then
          reaper.ImGui_TableSetColumnIndex(ctx, 0)
          reaper.ImGui_SetNextItemWidth(ctx, -1)
          _, edit_entry.ch = reaper.ImGui_InputInt(ctx, '##edit_chan' .. i, edit_entry.ch)
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
              TABLE_CONFIGS[i] = { cc = edit_entry.cc, ch = edit_entry.ch, inc = edit_entry.inc, dec = edit_entry.dec }
              save_config(table_config_to_extstate(TABLE_CONFIGS))
              editing_index = nil
            else
              reaper.ShowMessageBox('Conflict: Duplicate Channel+CC.', 'Update Error', 0)
            end
          end
          reaper.ImGui_SameLine(ctx)
          if reaper.ImGui_Button(ctx, 'Cancel##' .. i) then editing_index = nil end
        else
          reaper.ImGui_TableSetColumnIndex(ctx, 0)
          reaper.ImGui_Text(ctx, tostring(row_cfg.ch))
          reaper.ImGui_TableSetColumnIndex(ctx, 1)
          reaper.ImGui_Text(ctx, tostring(row_cfg.cc))
          reaper.ImGui_TableSetColumnIndex(ctx, 2)
          reaper.ImGui_Text(ctx, tostring(row_cfg.dec))
          reaper.ImGui_TableSetColumnIndex(ctx, 3)
          reaper.ImGui_Text(ctx, get_action_name(row_cfg.dec))
          reaper.ImGui_TableSetColumnIndex(ctx, 4)
          reaper.ImGui_Text(ctx, tostring(row_cfg.inc))
          reaper.ImGui_TableSetColumnIndex(ctx, 5)
          reaper.ImGui_Text(ctx, get_action_name(row_cfg.inc))
          reaper.ImGui_TableSetColumnIndex(ctx, 6)
          if reaper.ImGui_Button(ctx, 'Edit##' .. i) then
            editing_index = i
            edit_entry.cc = row_cfg.cc
            edit_entry.ch = row_cfg.ch
            edit_entry.inc = tostring(row_cfg.inc)
            edit_entry.dec = tostring(row_cfg.dec)
          end
          reaper.ImGui_SameLine(ctx)
          if reaper.ImGui_Button(ctx, 'Delete##' .. i) then
            table.remove(TABLE_CONFIGS, i)
            save_config(table_config_to_extstate(TABLE_CONFIGS))
            break
          end
        end
      end

      reaper.ImGui_TableNextRow(ctx)
      reaper.ImGui_TableSetColumnIndex(ctx, 0)
      reaper.ImGui_SetNextItemWidth(ctx, -1)
      _, new_entry.ch = reaper.ImGui_InputInt(ctx, '##new_chan', new_entry.ch)
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
          table.insert(TABLE_CONFIGS, {
            ch = new_entry.ch,
            cc = new_entry.cc,
            dec = new_entry.dec,
            inc = new_entry.inc,
          })
          save_config(table_config_to_extstate(TABLE_CONFIGS))
        else
          reaper.ShowMessageBox("A mapping for this Channel+CC combination already exists.", "Duplicate Entry", 0)
        end
      end

      reaper.ImGui_EndTable(ctx)
    end

    reaper.ImGui_PopFont(ctx)
    reaper.ImGui_End(ctx)
  end
  if open and not reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Key_Escape()) then
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
