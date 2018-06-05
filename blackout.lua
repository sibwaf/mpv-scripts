--[[
Theoratically, can be any of:
"brightness", "contrast", "saturation", "gamma", "hue"

In practice, "contrast" seems to work best.

Setting it to "saturation" or "hue" is pretty much pointless
as you will get gray-scale or a colored negative video instead of black screen.
]]
local property = "contrast"

local saved_value = nil
local saved_sid = nil

function toggle_blackout()
	if saved_value then
		mp.set_property(property, saved_value)
		saved_value = nil

		mp.set_property("sid", saved_sid)
		saved_sid = nil
	else
		mp.set_property("pause", "yes")

		saved_value = mp.get_property(property)
		mp.set_property(property, -100)

		saved_sid = mp.get_property("sid")
		mp.set_property("sid", "no")
	end
end

function on_pause_change(name, value)
	if not value and saved_value then
		toggle_blackout()
	end
end

mp.add_key_binding("b", "blackout", toggle_blackout)
mp.observe_property("pause", "bool", on_pause_change)
