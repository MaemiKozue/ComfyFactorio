local Enemies = require "maps.biter_battles_distorted.enemies"


local const = {
	enemies = {
		north = "north_biters",
		south = "south_biters"
	}
}


local function on_science_sent (event)
	local player = game.players[event.player_id]
	local biter_force_name = const.enemies[player.force.name]
	local food = event.type
	local flask_amount = event.count
	Enemies.set_evo_and_threat(flask_amount, food, biter_force_name)
	game.print("It's reversed effect, they sent to their own team :(")
end


local export = {
	name = "Malediction",
	short_description = "Reversed effect",
	description = "Science sent will feed your own biters, resulting in danger for your team!",
	on_science_sent = on_science_sent,
}


return export
