local Event = require "utils.event"

local const = {
	panel_name = "bb"
}

local function create_panel (pid)
	local player = game.players[pid]
	local frame = player.gui.screen.add{
		type = "frame",
		name = const.panel_name,
		caption = "Biter Battles"
	}
	frame.auto_center = true
end


local function create_panel_toggle (pid)
	local player = game.players[pid]
	player.gui.top.add{
		type = "sprite-button",
		name = "bb_toggle",

		sprite = "entity/small-biter"
	}
end

local function on_player_joined_game (event)
	local player = game.players[event.player_index]

	-- First join
	if player.online_time == 0 then
		create_panel(event.player_index)
		create_panel_toggle(event.player_index)
	end
end

local function on_gui_click (event)
	if not event.element.valid then return end
	if event.element.name ~= "bb_toggle" then return end

	local player = game.players[event.player_index]
	local panel = player.gui.screen[const.panel_name]
	panel.visible = not panel.visible
end

Event.add(defines.events.on_player_joined_game, on_player_joined_game)
Event.add(defines.events.on_gui_click, on_gui_click)

return {
	get_panel = function (player) return player.gui.screen[const.panel_name] end
}
