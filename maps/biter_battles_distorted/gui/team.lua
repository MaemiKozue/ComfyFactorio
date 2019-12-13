local Event = require "utils.event"

local bb = require "maps.biter_battles_distorted.game"
local Teams = require "maps.biter_battles_distorted.teams"
local Enemies = require "maps.biter_battles_distorted.enemies"
local Panel = require "maps.biter_battles_distorted.gui.panel"


local function player_list_to_text (list)
	local members = table_size(list)
	local spectators = {}
	local effective_players = {}
	for pid, _ in pairs(list) do
		local player = game.players[pid]
		if player.spectator then
			spectators[pid] = player
		else
			effective_players[pid] = player
		end
	end
	local n_spec = table_size(spectators)
	local n_play = table_size(effective_players)
	local plist = "Players (".."[color=green]"..n_play.."[/color]".."|"..n_spec.."): "
	local first = true
	if members == 0 then
		plist = plist .. "None"
	else
		plist = plist .. "[color=green]"
		for pid, _ in pairs(effective_players) do
			local player = game.players[pid]

			if not first then
				first = false
				plist = plist .. ", "
			end

			local str = "[color=green]"..player.name.."[/color]"
			plist = plist .. str
		end
		plist = plist .. "[/color]"
		plist = plist .. "\n"
		first = true
		for pid, _ in pairs(spectators) do
			local player = game.players[pid]

			if not first then
				first = false
				plist = plist .. ", "
			end

			local str = player.name
			plist = plist .. str
		end
	end
	return plist
end


local function create_join_button (hook, side)
	local team = bb.teams[side]
	hook.add {
		type = "button",
		name = side.."join",
		caption = "Join "..team.name
	}
end


local function create_team_side (hook, side)
	local team = bb.teams[side]
	local team_ui = hook.add{
		type = "frame",
		name = side,
		caption = team.name,
		direction = "vertical"
	}
	-- Team ID
	-- team_ui.add {
	-- 	type = "label",
	-- 	name = side.."id",
	-- 	caption = "id: " .. team.id
	-- }

	-- Team name
	local name = team_ui.add {
		type = "label",
		name = side.."name",
		caption = team.name
	}
	name.style.font = "heading-2"


	local stats = team_ui.add{
		type = "flow",
		name = "stats",
	}

	local biters_data = Enemies[side.."_biters"]
	-- Evolution
	stats.add {
		type = "label",
		name = side.."evo",
		caption = string.format("Evo: %4.1f%%" ,biters_data.evo*100)
	}

	-- Threat
	stats.add {
		type = "label",
		name = side.."threat",
		caption = string.format("Threat: %d", biters_data.threat)
	}

	-- Team player list
	team_ui.add {
		type = "label",
		name = side.."playerlist",
		caption = player_list_to_text(team.players)
	}

	-- Join button
	if not Teams.team_of(hook.gui.player) then
		create_join_button (team_ui, side)
	end
end

local function create_team_ui (panel)
	local flow = panel.add{
		type = "flow",
		name = "teams",
		caption = "Teams",
		direction = "vertical"
	}

	create_team_side (flow, "north")
	flow.add{
		type = "line",
		name = "team_separator",
		direction = "horizontal"
	}
	create_team_side (flow, "south")
end


local function update_enemies_statistics (hook)
	for _, side in pairs(bb.sides) do
		local biters_data = Enemies[side.."_biters"]
		local elem = hook[side].stats
		elem[side.."evo"].caption = string.format("Evo: %4.1f%%" ,biters_data.evo*100)
		elem[side.."threat"].caption = string.format("Threat: %d", biters_data.threat)
	end
end


local function update_all_playerlists ()
	for _, player in pairs(game.players) do
		local panel = Panel.get_panel(player)
		local teams = panel.teams
		for s, team in pairs(bb.teams) do
			teams[s][s.."playerlist"].caption = player_list_to_text(team.players)
		end
	end
end


local function on_player_joined_game (event)
	local player = game.players[event.player_index]

	if player.online_time == 0 then
		create_team_ui (Panel.get_panel(player))
	end
end

local function on_team_joined (event)
	local p = game.players[event.player_id]
	local ppanel = Panel.get_panel(p)
	ppanel.teams.north.northjoin.destroy()
	ppanel.teams.south.southjoin.destroy()
	ppanel.teams.add {
		type = "button",
		name = "spectate",
		caption = "Spectate"
	}

	update_all_playerlists()
end


local function on_spectate (event)
	local p = game.players[event.player_id]
	local ppanel = Panel.get_panel(p)
	ppanel.teams.spectate.destroy()
	local team = Teams.team_of(p)
	ppanel.teams.add {
		type = "button",
		name = "rejoin",
		caption = "Rejoin "..team.name
	}

	update_all_playerlists()
end


local function on_rejoin (event)
	local pid = event.player_id
	local player = game.players[pid]
	local panel = Panel.get_panel(player)
	panel.teams.rejoin.destroy()
	panel.teams.add {
		type = "button",
		name = "spectate",
		caption = "Spectate"
	}

	update_all_playerlists()
end


local function on_stats_changed ()
	for _, player in pairs(game.players) do
		local panel = Panel.get_panel(player)
		local hook = panel.teams
		update_enemies_statistics(hook)
	end
end


Event.add(defines.events.on_player_joined_game, on_player_joined_game)
Event.add(bb.events.on_team_joined, on_team_joined)
Event.add(bb.events.on_spectate, on_spectate)
Event.add(bb.events.on_player_afk_spectate, on_spectate)
Event.add(bb.events.on_rejoin, on_rejoin)
Event.add(bb.events.on_stats_changed, on_stats_changed)
