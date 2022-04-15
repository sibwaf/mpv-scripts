--[[
	fuzzydir / by sibwaf / https://github.com/sibwaf/mpv-scripts

	Allows using "**" wildcards in sub-file-paths and audio-file-paths
    so you don't have to specify all the possible directory names.

    Basically, allows you to do this and never have the need to edit any paths ever again:
    audio-file-paths = **
    sub-file-paths = **

	MIT license - do whatever you want, but I'm not responsible for any possible problems.
	Please keep the URL to the original repository. Thanks!
]]

--[[
    Configuration:

    # max_search_depth
    
    Determines the max depth of recursive search, should be >= 1

    Examples for "sub-file-paths = **":
    "max_search_depth = 1" => mpv will be able to find [xyz.ass, subs/xyz.ass]
    "max_search_depth = 2" => mpv will be able to find [xyz.ass, subs/xyz.ass, subs/moresubs/xyz.ass]

    Please be careful when setting this value too high as it can result in awful performance or even stack overflow
]]
local max_search_depth = 3

local utils = require "mp.utils"

local default_audio_paths = mp.get_property_native("options/audio-file-paths")
local default_sub_paths = mp.get_property_native("options/sub-file-paths")

function starts_with(str, prefix)
    return string.sub(str, 1, string.len(prefix)) == prefix
end

function ends_with(str, suffix)
    return suffix == "" or string.sub(str, -string.len(suffix)) == suffix
end

function add_all(to, from)
    for index, element in pairs(from) do
        table.insert(to, element)
    end
end

function contains(t, e)
    for index, element in pairs(t) do
        if element == e then
            return true
        end
    end
    return false
end

function normalize(path)
    if path == "." then
        return ""
    end

    if starts_with(path, "./") or starts_with(path, ".\\") then
        path = string.sub(path, 3, -1)
    end
    if ends_with(path, "/") or ends_with(path, "\\") then
        path = string.sub(path, 1, -2)
    end

    return path
end

function traverse(path, level)
    level = level or 1
    if level > max_search_depth then
        return {}
    end

    local found = utils.readdir(path, "dirs")
    if found == nil then
        return {}
    end

    local result = {}
    for index, file in pairs(found) do
        local full_path = utils.join_path(path, file)
        table.insert(result, full_path)
        add_all(result, traverse(full_path, level + 1))
    end

    return result
end

function explode(from, working_directory)
    local result = {}
    for index, path in pairs(from) do
        path = utils.join_path(working_directory, normalize(path))
        local parent, leftover = utils.split_path(path)

        if leftover == "**" then
            table.insert(result, parent)
            add_all(result, traverse(parent))
        else
            table.insert(result, path)
        end
    end

    local normalized = {}
    for index, path in pairs(result) do
        local normalized_path = normalize(path)
        if not contains(normalized, normalized_path) and normalized_path ~= normalize(working_directory) then
            table.insert(normalized, normalized_path)
        end
    end

    return normalized
end

function explode_all()
    local video_path = mp.get_property("path")
    local working_directory, filename = utils.split_path(video_path)

    local audio_paths = explode(default_audio_paths, working_directory)
    mp.set_property_native("options/audio-file-paths", audio_paths)

    local sub_paths = explode(default_sub_paths, working_directory)
    mp.set_property_native("options/sub-file-paths", sub_paths)
end

mp.add_hook("on_load", 50, explode_all)

function rescan_paths()
    local audio_file_paths_changed = false
    local sub_file_paths_changed = false
    local function on_audio_file_paths_changed()
        audio_file_paths_changed = true
        mp.unobserve_property(on_audio_file_paths_changed)
        if audio_file_paths_changed and sub_file_paths_changed then
            mp.commandv("sync", "rescan-external-files")
        end
    end
    local function on_sub_file_paths_changed()
        sub_file_paths_changed = true
        mp.unobserve_property(on_sub_file_paths_changed)
        if audio_file_paths_changed and sub_file_paths_changed then
            mp.commandv("sync", "rescan-external-files")
        end
    end
    mp.observe_property("options/audio-file-paths", nil, on_audio_file_paths_changed)
    mp.observe_property("options/sub-file-paths", nil, on_sub_file_paths_changed)
    explode_all()
end

mp.register_script_message("rescan-paths", rescan_paths)
