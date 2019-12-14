local Enemies = require "maps.biter_battles_distorted.enemies"
local bb = require "maps.biter_battles_distorted.game"

local const = {
	enemies = {
		north = "north_biters",
		south = "south_biters"
	},
	mil_science_nerf = 0.8
}


local function on_science_sent (event)
	local player = game.players[event.player_id]
	local opposite = bb.other_side(player.force.name)
	local biter_force_name = const.enemies[opposite]
	local food = event.type
	local flask_amount = event.count
	if food == "military-science-pack" then
		flask_amount = flask_amount * const.mil_science_nerf
	end
	Enemies.set_evo_and_threat(flask_amount, food, biter_force_name)
end


local export = {
	name = "Tired Soldiers",
	short_description = "[img=item/military-science-pack][color=red]-20%[/color]",
	description = {"", "Sending ", {"item-name.military-science-pack"}, " is 20% less effective"},
	on_science_sent = on_science_sent,
}


return export
