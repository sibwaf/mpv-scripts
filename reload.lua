function reload()
    local path = mp.get_property("path")
    if path ~= nil then
        local time = mp.get_property_number("time-pos")
        mp.commandv("loadfile", path, "replace", "start=" .. time)
    end
end

mp.add_key_binding("R", "reload", reload)
