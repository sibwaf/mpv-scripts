--[[
	reload / by sibwaf / https://github.com/sibwaf/mpv-scripts

	Reopens the current playing file and seeks to the same timestamp on a button press ([Shift+R] by default).
    Useful for situations when you are watching YouTube/streams and your connection breaks for some reason.

	MIT license - do whatever you want, but I'm not responsible for any possible problems.
	Please keep the URL to the original repository. Thanks!
]]

function reload()
    local path = mp.get_property("path")
    if path ~= nil then
        local time = mp.get_property_number("time-pos")
        mp.commandv("loadfile", path, "replace", "start=" .. time)
    end
end

mp.add_key_binding("R", "reload", reload)
