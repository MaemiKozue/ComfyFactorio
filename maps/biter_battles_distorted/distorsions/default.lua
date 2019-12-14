local Enemies = require "maps.biter_battles_distorted.enemies"
local Spying = require "maps.biter_battles_distorted.spying"
local bb = require "maps.biter_battles_distorted.game"


local const = {
	enemies = {
		north = "north_biters",
		south = "south_biters"
	}
}


local function on_science_sent (event)
	local player = game.players[event.player_id]
	local opposite = bb.other_side(player.force.name)
	local biter_force_name = const.enemies[opposite]
	local food = event.type
	local flask_amount = event.count
	Enemies.set_evo_and_threat(flask_amount, food, biter_force_name)
end


local function on_fish_sent (event)
	local player = game.players[event.player_id]
	Spying.spy_fish(player)
end


local export = {
	name = "Normal",
	short_description = nil,
	description = "This is the default behaviour of Biter Battles\n"
		.."Science sent will feed the opposite side biters, leading them to"
		.." increased evolution and threat.\n"
		.."Sending a fish will provide "..(Spying.duration_per_unit/60).." seconds"
		.." (cumulable) of map view of opponent's map view",
	on_science_sent = on_science_sent,
	on_fish_sent = on_fish_sent,
}


return export
