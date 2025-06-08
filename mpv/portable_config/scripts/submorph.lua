--[[
Name: SubMorph
Author: Gemini
Version: 7.7
Description:
    Processes external and embedded ASS/SSA subtitles. The script now uses a
    reference height (e.g., 720p) set in the config file. All style values
    (font size, outline, shadow) are scaled relative to this reference,
    providing simple and predictable results across all subtitle files.
--]]

local msg = require 'mp.msg'
local utils = require 'mp.utils'
local options = require 'mp.options'

-- Script name for logs and config file
local SCRIPT_NAME = "SubMorph"
msg.log_prefix = "[" .. SCRIPT_NAME .. "] "

-- Configuration with default values
local config = {
    enable = 'always',

    -- --- Reference Settings ---
    -- The script will scale your style settings so they appear on screen
    -- as if you were watching a video at this reference height.
    reference_height = 720,

    -- --- Style Settings ---
    -- These options define the target style for the reference_height above.
    font_name = 'Candara',
    font_size = 65, -- This is the font size you want at 720p
    primary_colour = '&H00FFFFFF',
    secondary_colour = '&H000000FF',
    outline_colour = '&H00000000',
    back_colour = '&H00000000',
    bold = -1,
    italic = 0,
    underline = 0,
    strikeout = 0,
    scale_x = 100,
    scale_y = 100,
    spacing = 0,
    angle = 0,
    border_style = 1,
    outline = 2.5, -- This is the outline thickness you want at 720p
    shadow = 1.0,  -- This is the shadow distance you want at 720p
    alignment = 2,
    margin_l = 10,
    margin_r = 10,
    margin_v = 25,
    encoding = 1
}
options.read_options(config, SCRIPT_NAME)

local SM_TEMP_DIR = nil

-- ### HELPER FUNCTIONS ### --

function get_sm_temp_dir()
    if SM_TEMP_DIR then return SM_TEMP_DIR end
    local temp_dir = os.getenv("TEMP") or os.getenv("TMPDIR") or os.getenv("TMP") or "/tmp"
    local path = utils.join_path(temp_dir, "MPV_SM")
    local info = utils.file_info(path)
    if not info then
        local platform = mp.get_property_native("platform") or "unknown"
        local res
        if platform == "windows" then
            res = utils.subprocess({args = {"cmd", "/c", "mkdir", path:gsub("/", "\\")}})
        else
            res = utils.subprocess({args = {"mkdir", "-p", path}})
        end
        if res.status ~= 0 and not utils.file_info(path) then
             msg.error("Failed to create temp directory: " .. path)
             return nil
        end
    end
    info = utils.file_info(path)
    if info and info.is_dir then
        SM_TEMP_DIR = path
        return path
    else
        msg.error("Temp path exists but is not a directory: " .. path)
        return nil
    end
end

function clean_sm_temp_dir()
    local path = get_sm_temp_dir()
    if not path then return end
    msg.verbose("Cleaning temp directory: " .. path)
    local files, err = utils.readdir(path, "files")
    if files then
        for _, file in ipairs(files) do
            pcall(os.remove, utils.join_path(path, file))
        end
        msg.verbose("Cleanup complete.")
    else
        msg.warn("Could not read temp directory content: " .. tostring(err))
    end
end

function sanitize_filename(name)
    if not name then return "unknown" end
    name = name:match("([^/\\]*)$")
    name = name:gsub("%.[^.]*$", "")
    name = name:gsub('[\\/:%*%?%"%<>|]', "_")
    if #name > 100 then name = name:sub(1, 100) end
    return name
end

function read_file_content(path)
    local file, err = io.open(path, "rb")
    if not file then
        msg.warn("Failed to open subtitle file: " .. path .. " | Error: " .. tostring(err))
        return nil
    end
    local content = file:read("*a")
    file:close()
    if content:sub(1, 3) == "\239\187\191" then
        content = content:sub(4)
    end
    return content
end

function ensure_resolution_headers(content)
    local play_res_x_val = content:match("[Pp][Ll][Aa][Yy][Rr][Ee][Ss][Xx]:%s*(%d+)")
    local play_res_y_val = content:match("[Pp][Ll][Aa][Yy][Rr][Ee][Ss][Yy]:%s*(%d+)")

    local has_layout_x = content:match("[Ll][Aa][Yy][Oo][Uu][Tt][Rr][Ee][Ss][Xx]:")
    local has_layout_y = content:match("[Ll][Aa][Yy][Oo][Uu][Tt][Rr][Ee][Ss][Yy]:")

    local needs_play_x = not play_res_x_val
    local needs_play_y = not play_res_y_val
    local needs_layout_x = play_res_x_val and not has_layout_x
    local needs_layout_y = play_res_y_val and not has_layout_y

    if not (needs_play_x or needs_play_y or needs_layout_x or needs_layout_y) then
        return content
    end

    local lines = {}
    for line in content:gmatch("([^\r\n]*)") do
        table.insert(lines, line)
    end

    local insertion_point = -1
    for i, line in ipairs(lines) do
        if line:match("^%[Script Info%s*%+?%s*%]$") then
            insertion_point = i
            break
        end
    end

    if insertion_point == -1 then
        msg.warn("Could not find [Script Info] section. Cannot add/modify resolution headers.")
        return content
    end

    local added_headers = {}
    if needs_layout_y then
        table.insert(lines, insertion_point + 1, "LayoutResY: " .. play_res_y_val)
        table.insert(added_headers, "LayoutResY")
    end
    if needs_layout_x then
        table.insert(lines, insertion_point + 1, "LayoutResX: " .. play_res_x_val)
        table.insert(added_headers, "LayoutResX")
    end

    if needs_play_y then
        table.insert(lines, insertion_point + 1, "PlayResY: 360")
        table.insert(added_headers, "PlayResY")
    end
    if needs_play_x then
        table.insert(lines, insertion_point + 1, "PlayResX: 640")
        table.insert(added_headers, "PlayResX")
    end

    if #added_headers > 0 then
        msg.verbose("Added missing headers to subtitle data: " .. table.concat(added_headers, ", "))
    end

    return table.concat(lines, "\r\n")
end


-- ### HEURISTIC ENGINE ### --
function find_dialogue_styles(content)
    local defined_styles = {}
    for line in content:gmatch("([^\r\n]*)") do
        if line:match("^[Ss][Tt][Yy][Ll][Ee]:") then
            local parts = {}
            for part in line:gmatch("([^,]+)") do table.insert(parts, part) end
            local style_name = parts[1]:match(":[%s]*(.*)")
            if style_name then
                defined_styles[style_name] = { name = style_name, alignment = tonumber(parts[18]) or 2 }
            end
        end
    end
    if next(defined_styles) == nil then return nil end

    local function robust_parse_dialogue(line)
        local data = line:match("^[Dd][Ii][Aa][Ll][Oo][Gg][Uu][Ee]:%s*(.*)")
        if not data then return nil end
        local parts = {}
        local current_pos = 1
        for i = 1, 9 do
            local sep_pos = data:find(",", current_pos)
            if not sep_pos then return nil end
            table.insert(parts, data:sub(current_pos, sep_pos - 1))
            current_pos = sep_pos + 1
        end
        table.insert(parts, data:sub(current_pos))
        return parts[4], parts[5], parts[9], parts[10] -- Style, Name, Effect, Text
    end

    local style_scores = {}
    for line in content:gmatch("([^\r\n]*)") do
        if line:match("^[Dd][Ii][Aa][Ll][Oo][Gg][Uu][Ee]:") then
            local style, name, effect, text = robust_parse_dialogue(line)
            if style and text then
                local score = 0
                local clean_style = style:match("^%s*(.-)%s*$")
                
                local style_data = defined_styles[clean_style]
                if style_data then
                    if style_data.name:lower():match("default") or style_data.name:lower():match("dialogue") then score = score + 10 end
                    if style_data.name:lower():match("sign") or style_data.name:lower():match("karaoke") or style_data.name:lower():match("title") then score = score - 20 end
                    if style_data.alignment and (style_data.alignment <= 3) then score = score + 5 end
                end

                if name and name ~= "" then score = score + 50 end
                if effect and effect ~= "" then score = score - 20 end

                local clean_text = text:gsub("{[^}]*}", ""):gsub("\\N", " ")
                if text:match("\\pos") or text:match("\\move") or text:match("\\org") or text:match("\\fad") or text:match("\\t%(") then score = score - 100 end
                if text:match("^[A-ZА-Я][a-zа-я]+:") then score = score + 15 end
                if clean_text:match("[.?!]$") or clean_text:match("[.?!]..$") then score = score + 5 end
                if clean_text:match("^[A-ZА-Я]") then score = score + 2 end
                if clean_text:upper() == clean_text and clean_text:match("%a") and #clean_text > 5 then score = score - 5 end
                
                style_scores[clean_style] = (style_scores[clean_style] or 0) + score
            end
        end
    end

    local dialogue_styles = {}
    for style, score in pairs(style_scores) do
        if score >= 0 then
            table.insert(dialogue_styles, style)
        end
    end

    if #dialogue_styles > 0 then
        msg.verbose("Detected " .. #dialogue_styles .. " dialogue style(s) to process: " .. table.concat(dialogue_styles, ", "))
        return dialogue_styles
    else
        msg.warn("Could not detect any dialogue styles. Falling back to first defined style.")
        for line_fallback in content:gmatch("([^\r\n]*)") do
            local first_style_name = line_fallback:match("^[Ss][Tt][Yy][Ll][Ee]:%s*([^,]+),")
            if first_style_name then
                msg.verbose("Fallback: Main style is first defined style: '" .. first_style_name .. "'.")
                return {first_style_name}
            end
        end
        return nil
    end
end

function process_sub_content(content, dialogue_styles_table)
    local sub_res_y = nil
    local play_res_y_line = content:match("([^\r\n]*[Pp][Ll][Aa][Yy][Rr][Ee][Ss][Yy]:[^\r\n]*)")
    if play_res_y_line then
        local res_y_capture = play_res_y_line:match("[Pp][Ll][Aa][Yy][Rr][Ee][Ss][Yy]:%s*(%d+)")
        if res_y_capture then sub_res_y = tonumber(res_y_capture) end
    end
    if not sub_res_y then return nil end

    local dialogue_style_map = {}
    for _, style_name in ipairs(dialogue_styles_table) do
        dialogue_style_map[style_name] = true
    end

    local original_formats = {}
    for line in content:gmatch("([^\r\n]*)") do
        local style_name = line:match("^[Ss][Tt][Yy][Ll][Ee]:%s*([^,]+),")
        if style_name and dialogue_style_map[style_name] then
            local parts = {}
            for part in line:gmatch("([^,]+)") do table.insert(parts, part) end
            original_formats[style_name] = {
                bold = parts[8] or tostring(config.bold),
                italic = parts[9] or tostring(config.italic)
            }
        end
    end

    local adjustment_factor = sub_res_y / config.reference_height
    local new_font_size = config.font_size * adjustment_factor
    local new_outline = config.outline * adjustment_factor
    local new_shadow = config.shadow * adjustment_factor

    msg.verbose(string.format("Reference-based scaling: SubResY=%d, RefH=%d, Adj_Factor=%.2f", sub_res_y, config.reference_height, adjustment_factor))
    msg.verbose(string.format("New values for file: Font Size=%.2f, Outline=%.2f, Shadow=%.2f", new_font_size, new_outline, new_shadow))

    local new_lines = {}
    for line in content:gmatch("([^\r\n]*)") do
        local style_name = line:match("^[Ss][Tt][Yy][Ll][Ee]:%s*([^,]+),")
        if style_name and dialogue_style_map[style_name] then
            local orig_fmt = original_formats[style_name] or {}
            local new_settings_parts = {
                config.font_name, string.format("%.2f", new_font_size), config.primary_colour, config.secondary_colour,
                config.outline_colour, config.back_colour, orig_fmt.bold or tostring(config.bold),
                orig_fmt.italic or tostring(config.italic), tostring(config.underline), tostring(config.strikeout),
                tostring(config.scale_x), tostring(config.scale_y), tostring(config.spacing),
                tostring(config.angle), tostring(config.border_style), string.format("%.2f", new_outline),
                string.format("%.2f", new_shadow), tostring(config.alignment), tostring(config.margin_l),
                tostring(config.margin_r), tostring(config.margin_v), tostring(config.encoding)
            }
            local new_style_line = "Style: " .. style_name .. "," .. table.concat(new_settings_parts, ",")
            table.insert(new_lines, new_style_line)
        else
            table.insert(new_lines, line)
        end
    end
    
    return table.concat(new_lines, "\r\n")
end

function extract_embedded_sub(active_track, track_list)
    local video_path = mp.get_property_native("path")
    if not video_path then return nil end

    local ffmpeg_sub_index = -1
    for _, track in ipairs(track_list) do
        if track.type == "sub" then
            ffmpeg_sub_index = ffmpeg_sub_index + 1
            if track.id == active_track.id then break end
        end
    end
    if ffmpeg_sub_index == -1 then return nil end

    local temp_dir = get_sm_temp_dir()
    if not temp_dir then return nil end
    
    local original_name = sanitize_filename(active_track.title or "embedded_sub")
    local extracted_filename = string.format("SM_extracted_%s_%d.ass", original_name, math.random(10000, 99999))
    local extracted_filepath = utils.join_path(temp_dir, extracted_filename)
    
    local args = { "ffmpeg", "-y", "-i", video_path, "-map", "0:s:" .. ffmpeg_sub_index, "-c", "copy", extracted_filepath }
    local res = utils.subprocess({ args = args })

    if res.status ~= 0 then
        msg.error("Error extracting subtitles: " .. (res.stderr or "N/A"))
        return nil
    end

    msg.verbose("Embedded subtitles extracted successfully.")
    return extracted_filepath, (active_track.title or "embedded_sub")
end

function write_and_load_temp_sub(modified_content, original_name)
    local base_path = get_sm_temp_dir()
    if not base_path then return end
    
    local sanitized_name = sanitize_filename(original_name)
    local temp_filename = string.format("SM_%s_%d.ass", sanitized_name, math.random(10000, 99999))
    local temp_path = utils.join_path(base_path, temp_filename)
    
    local file, err = io.open(temp_path, "w")
    if not file then
        msg.error("Failed to create temp file: " .. temp_path .. " | Error: " .. tostring(err))
        return
    end
    file:write(modified_content)
    file:close()

    local original_sub_id = mp.get_property_native("sid")
    if original_sub_id and original_sub_id ~= "no" then
        mp.commandv("sub-remove", original_sub_id)
    end
    mp.commandv("sub-add", temp_path, "select")
    msg.verbose("Modified subtitle file loaded.")
    mp.osd_message(SCRIPT_NAME .. ": Style applied", 2)
end

-- ### CORE LOGIC ### --

local processed_tracks = {}

function run_processing_on_track(sid)
    if not sid or sid == "no" or sid == false or processed_tracks[sid] then return end
    local track_list = mp.get_property_native("track-list")
    if not track_list then return end
    
    local active_track
    for i, track in ipairs(track_list) do
        if track.id == sid and track.type == "sub" then
            active_track = track; break
        end
    end
    if not active_track then return end

    if active_track.external and active_track["external-filename"] then
        if active_track["external-filename"]:match("SM_") then return end
    end

    if active_track.codec ~= "ass" and active_track.codec ~= "ssa" then return end

    local sub_content_path, original_name_for_file
    if active_track.external and active_track["external-filename"] then
        msg.verbose("External subtitle file detected.")
        sub_content_path = active_track["external-filename"]
        original_name_for_file = sub_content_path
    else
        msg.verbose("Embedded subtitle track detected. Attempting extraction via ffmpeg...")
        sub_content_path, original_name_for_file = extract_embedded_sub(active_track, track_list)
    end

    if not sub_content_path then return end
    
    local content = read_file_content(sub_content_path)
    if not content then return end
    
    content = ensure_resolution_headers(content)
    
    local dialogue_styles = find_dialogue_styles(content)
    if not dialogue_styles or #dialogue_styles == 0 then
        msg.warn("No dialogue styles found to process.")
        return
    end
    
    local modified_content = process_sub_content(content, dialogue_styles)
    if not modified_content then return end
    
    processed_tracks[sid] = true
    write_and_load_temp_sub(modified_content, original_name_for_file)
end

function manual_run_trigger()
    if config.enable == 'no' then
        mp.osd_message(SCRIPT_NAME .. ": Disabled in config", 2)
        return
    end
    
    msg.verbose("Manual trigger activated.")
    local sid = mp.get_property_native("sid")
    if not sid or sid == "no" or sid == false then
        mp.osd_message(SCRIPT_NAME .. ": No active subtitle track", 2)
        return
    end
    
    local track_list = mp.get_property_native("track-list")
    if not track_list then return end
    local active_track
    for _, track in ipairs(track_list) do
        if track.id == sid then active_track = track; break end
    end
    
    if active_track and active_track.external and active_track["external-filename"] then
        if active_track["external-filename"]:match("SM_") then
            mp.osd_message(SCRIPT_NAME .. ": Style already applied", 2)
            return
        end
    end

    if processed_tracks[sid] then
        mp.osd_message(SCRIPT_NAME .. ": Style already applied", 2)
        return
    end

    run_processing_on_track(sid)
end

function on_sid_change(_, sid)
    if config.enable ~= 'always' then return end
    run_processing_on_track(sid)
end

function on_new_file_loaded()
    processed_tracks = {}

    local timer = mp.add_timeout(0.5, function()
        local track_list = mp.get_property_native("track-list")
        if not track_list or #track_list == 0 then return end

        local current_sid = mp.get_property_native("sid")
        local is_sid_valid = false
        if current_sid and current_sid ~= "no" and current_sid ~= false then
            for _, track in ipairs(track_list) do
                if track.id == current_sid then
                    is_sid_valid = true
                    break
                end
            end
        end

        if is_sid_valid then
            if config.enable == 'always' then
                 run_processing_on_track(current_sid)
            end
        else
            msg.verbose("Previously selected track not found. Resetting subtitles.")
            mp.set_property_native("sid", "no")

            local reset_timer = mp.add_timeout(0.05, function()
                mp.set_property_native("sid", "auto")
            end)
        end
    end)
end

-- ### INITIALIZATION ### --

if config.enable == 'no' then
    msg.info(SCRIPT_NAME .. " is disabled in the config file.")
    return
end

-- Initial cleanup and registration
clean_sm_temp_dir()
mp.observe_property("sid", "native", on_sid_change)
mp.register_event("file-loaded", on_new_file_loaded)
mp.register_event("shutdown", clean_sm_temp_dir)
mp.register_script_message("run-submorph", manual_run_trigger)

msg.info(SCRIPT_NAME .. "SubMorph v7.7 loaded. Mode: " .. config.enable)
