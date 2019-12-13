local Event = require "utils.event"

local bb = require "maps.biter_battles_distorted.game"

local Panel = require "maps.biter_battles_distorted.gui.panel"


local function state_to_text (state)
	for k, v in pairs(bb.states) do
		if state == v then
			return k
		end
	end
end


local function time_caption (ticks)
	local seconds = ticks / 60
	local left = seconds
	local h = math.floor(left / 3600)
	left = left - 3600*h
	local m = math.floor(left / 60)
	left = left - 60*m
	local s = left
	return "time: " .. string.format("%02d:%02d:%05.2f", h, m, s)
end


local function update ()
	for pid, player in pairs(game.players) do
		local panel = Panel.get_panel(player)
		local frame = panel.game_info
		frame.game_state.caption = "game_state: " .. state_to_text(bb.get_state())
		frame.tournament.caption = "tournament: " .. tostring(bb.get_tournament())
		frame.teams_locked.caption = "teams_locked: " .. tostring(bb.get_teams_locked())
		frame.balancing.caption = "balancing: " .. tostring(bb.get_balancing())
		if bb.get_state() ~= bb.states.WAITING then
			frame.start.caption = "start: " .. tostring(bb.get_time_start())
		else
			frame.start.caption = "start: " .. "not started"
		end

		if bb.get_state == bb.states.FINISHED then
			frame.stop.caption = "stop: " .. bb.get_time_stop()
		else
			frame.stop.caption = "stop: " .. "not stopped"
		end

		if bb.get_state() ~= bb.states.WAITING then
			local end_time
			if bb.get_state() == bb.states.FINISHED then
				end_time = bb.get_time_stop()
			else
				end_time = game.tick
			end
			frame.time.caption = time_caption(end_time - bb.get_time_start())
		else
			frame.time.caption = time_caption(0)
		end
	end
end

local function update_timer ()
	if bb.get_state() ~= bb.states.RUNNING then
		return false
	end

	for pid, player in pairs(game.players) do
		Panel.get_panel(player).game_info.time.caption = time_caption(game.tick - bb.get_time_start())
	end
end


local function create_game_info (panel)
	local frame = panel.add{
		type = "frame",
		name = "game_info",
		caption = "Game info",
		direction = "vertical"
	}
	for _, name in pairs({"game_state", "tournament", "teams_locked", "balancing", "start", "stop", "time"}) do
		frame.add{
			type = "label",
			name = name
		}
	end
	update()
end


local function on_player_joined_game (event)
	local player = game.players[event.player_index]

	if player.online_time == 0 then
		create_game_info (Panel.get_panel(player))
	end
end

Event.add(defines.events.on_player_joined_game, on_player_joined_game)
Event.add(bb.events.on_game_started, update)
Event.add(bb.events.on_game_finished, update)
Event.add(defines.events.on_tick, update_timer)
