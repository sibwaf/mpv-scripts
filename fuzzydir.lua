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

    
    # discovery_threshold

    fuzzydir will skip paths which contain more than discovery_threshold directories in them

    This is done to keep at least some garbage from getting into *-file-paths properties in case of big collections:
    - dir1 <- will be ignored on opening video.mp4 as it's probably unrelated to the file
    - ...
    - dir999 <- will be ignored
    - video.mp4

    Use 0 to disable this behavior completely
]]

local max_search_depth = 3
local discovery_threshold = 10

----------

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

function call_command(command)
    local process = mp.command_native({
        name = "subprocess",
        playback_only = false,
        capture_stdout = true,
        args = command,
    })

    if process.status ~= 0 then
        return nil
    end

    local result = {}
    for line in string.gmatch(process.stdout, "([^\r\n]+)") do
        table.insert(result, line)
    end
    return result
end

-- Platform-dependent optimization

local powershell_version = call_command({
    "powershell.exe",
    "-NoProfile",
    "-Command",
    "$Host.Version.Major",
})
if powershell_version ~= nil then
    powershell_version = tonumber(powershell_version[1])
end
if powershell_version == nil then
    powershell_version = -1
end

function fast_readdir(path)
    if powershell_version >= 3 then
        return call_command({
            "powershell.exe",
            "-NoProfile",
            "-Command",
            "& { Get-ChildItem -LiteralPath FileSystem::\"" .. path .. "\" -Directory | foreach { $_.Name } }",
        })
    end

    return utils.readdir(path, "dirs")
end

-- Platform-dependent optimization end

function traverse(search_path, current_path, level, cache)
    if level > max_search_depth then
        return {}
    end

    local full_path = utils.join_path(search_path, current_path)

    if cache[full_path] ~= nil then
        return cache[full_path]
    end

    local result = {}

    local discovered_paths = fast_readdir(full_path)
    if discovered_paths == nil then
        -- noop
    elseif discovery_threshold > 0 and #discovered_paths > discovery_threshold then
        -- noop
    else
        for _, discovered_path in pairs(discovered_paths) do
            local new_path = utils.join_path(current_path, discovered_path)

            table.insert(result, new_path)
            add_all(result, traverse(search_path, new_path, level + 1, cache))
        end
    end

    cache[full_path] = result

    return result
end

function explode(raw_paths, search_path, cache)
    local result = {}
    for _, raw_path in pairs(raw_paths) do
        local parent, leftover = utils.split_path(raw_path)
        if leftover == "**" then
            table.insert(result, parent)
            add_all(result, traverse(search_path, parent, 1, cache))
        else
            table.insert(result, raw_path)
        end
    end

    local normalized = {}
    for index, path in pairs(result) do
        local normalized_path = normalize(path)
        if not contains(normalized, normalized_path) and normalized_path ~= "" then
            table.insert(normalized, normalized_path)
        end
    end

    return normalized
end

function explode_all()
    local video_path = mp.get_property("path")
    local search_path, _ = utils.split_path(video_path)
    local cache = {}

    local audio_paths = explode(default_audio_paths, search_path, cache)
    mp.set_property_native("options/audio-file-paths", audio_paths)

    local sub_paths = explode(default_sub_paths, search_path, cache)
    mp.set_property_native("options/sub-file-paths", sub_paths)
end

mp.add_hook("on_load", 50, explode_all)
