--[[
	blackout / by sibwaf / https://github.com/sibwaf/mpv-scripts

	Turns the screen completely black and pauses on a button press ([b] by default)
	so you can hide whatever you are watching from other people fast enough.
	Unpause or press the same button to go back.

	May not work if your VO driver doesn't support changing contrast.

	MIT license - do whatever you want, but I'm not responsible for any possible problems.
	Please keep the URL to the original repository. Thanks!
]]

--[[
	Configuration:

	# property

	In theory, can be any of: "brightness", "contrast", "saturation", "gamma", "hue".
	In practice, "contrast" seems to work best. Setting it to "saturation" or "hue"
	is pretty much pointless as you will get gray-scale or a colored negative video.
]]

local property = "contrast"

----------

local watch_later_options_default = mp.get_property_native("watch-later-options")
local watch_later_options_blackout = {}

for _, option in pairs(watch_later_options_default) do
	if option == property then
		-- remove
	elseif option == "sid" then
		-- remove
	elseif option == "secondary-sid" then
		-- remove
	else
		table.insert(watch_later_options_blackout, option)
	end
end

local saved_value = nil
local saved_sid = nil
local saved_secondary_sid = nil

function toggle_blackout()
	if saved_value then
		mp.set_property(property, saved_value)
		saved_value = nil

		mp.set_property("sid", saved_sid)
		saved_sid = nil

		mp.set_property("secondary-sid", saved_secondary_sid)
		saved_secondary_sid = nil

		mp.set_property_native("watch-later-options", watch_later_options_default)
	else
		mp.set_property("pause", "yes")

		saved_value = mp.get_property(property)
		mp.set_property(property, -100)

		saved_sid = mp.get_property("sid")
		mp.set_property("sid", "no")

		saved_secondary_sid = mp.get_property("secondary-sid")
		mp.set_property("secondary-sid", "no")

		mp.set_property_native("watch-later-options", watch_later_options_blackout)
	end
end

function on_pause_change(name, value)
	if not value and saved_value then
		toggle_blackout()
	end
end

mp.add_key_binding("b", "blackout", toggle_blackout)
mp.observe_property("pause", "bool", on_pause_change)
