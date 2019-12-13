local Enemies = require "maps.biter_battles_distorted.enemies"
local bb = require "maps.biter_battles_distorted.game"

local const = {
	enemies = {
		north = "north_biters",
		south = "south_biters"
	},
	red_science_boost = 1.5
}


local function on_science_sent (event)
	local player = game.players[event.player_id]
	local opposite = bb.other_side(player.force.name)
	local biter_force_name = const.enemies[opposite]
	local food = event.type
	local flask_amount = event.count
	if food == "automation-science-pack" then
		flask_amount = flask_amount * const.red_science_boost
	end
	Enemies.set_evo_and_threat(flask_amount, food, biter_force_name)
end


local export = {
	name = "Automated Automation",
	short_description = "[img=item/automation-science-pack][color=green]+50%[/color]",
	description = {"", "Sending ", {"item-name.automation-science-pack"}, " is 50% more effective"},
	on_science_sent = on_science_sent,
}


return export
