local Event = require "utils.event"
local bb = require "maps.biter_battles_distorted.game"


local const = {
	science = {
		["automation-science-pack"] = "automation-science-pack",
		["logistic-science-pack"] = "logistic-science-pack",
		["military-science-pack"] = "military-science-pack",
		["chemical-science-pack"] = "chemical-science-pack",
		["production-science-pack"] = "production-science-pack",
		["utility-science-pack"] = "utility-science-pack",
		["space-science-pack"] = "space-science-pack",
	}
}


local function create_action_menu (player)
	local hook = player.gui.screen
	local frame = hook.add{
		type = "frame",
		name = "bb_actions",
		direction = "vertical",
		caption = "Actions"
	}

	local first_row = {
		"automation-science-pack",
		"logistic-science-pack",
		"military-science-pack",
		"chemical-science-pack"
	}
	local second_row = {
		"production-science-pack",
		"utility-science-pack",
		"space-science-pack"
	}
	local row
	for i, list in pairs({first_row, second_row}) do
		row = frame.add {
			type = "flow",
			name = "row_"..i,
			direction = "horizontal"
		}
		for _, science in pairs(list) do
			row.add{
				type = "sprite-button",
				name = "send_science_"..science,
				tooltip = {"", "Send some ", {"item-name."..science}},

				sprite = "item/"..science,
			}
		end
	end
	row.add{
		type = "sprite-button",
		name = "send_fish",
		tooltip = "Send a fish!",

		sprite = "item/raw-fish",
	}
end


local function destroy_action_menu (player)
	player.gui.screen.bb_actions.destroy()
end


local function on_team_joined (event)
	local player = game.players[event.player_id]
	create_action_menu(player)
end


local function on_rejoin (event)
	local player = game.players[event.player_id]
	create_action_menu(player)
end


local function on_spectate (event)
	local player = game.players[event.player_id]
	destroy_action_menu(player)
end


local function on_player_afk_spectate (event)
	local player = game.players[event.player_id]
	destroy_action_menu(player)
end


Event.add(bb.events.on_team_joined, on_team_joined)
Event.add(bb.events.on_rejoin, on_rejoin)
Event.add(bb.events.on_spectate, on_spectate)
Event.add(bb.events.on_player_afk_spectate, on_player_afk_spectate)
