local Event = require "utils.event"

local bb = require "maps.biter_battles_distorted.game"
local Teams = require "maps.biter_battles_distorted.teams"
local Spectate = require "maps.biter_battles_distorted.spectate"


local const = {
	spectate_cooldown = 60*60,
	teleport_radius = 8,
	teleport_precision = 1
}


local function set_north_name (name)
	Teams.set_team_name(bb.teams.north, name)
end


local function set_south_name (name)
	Teams.set_team_name(bb.teams.south, name)
end


local function can_join (pid, side)
	local a = bb.teams[side]
	local b = bb.teams[bb.other_side(side)]
	local p = table_size(Teams.connected_players(a))
	local q = table_size(Teams.connected_players(b))

	return p <= q
end


local function set_player_team (pid, side)
	local team = bb.teams[side]
	Teams.add_player(team, pid)
end


local function move_player (pid, side)
	set_player_team (pid, side)

	local player = game.players[pid]
	local force = game.forces[side]

	local pos = player.surface.find_non_colliding_position("character", force.get_spawn_position(player.surface), const.teleport_radius, const.teleport_precision)
	if not pos then
		player.print("It is not possible to spectate at the moment, could not find a suitable place for you")
		return false
	end

	player.teleport(pos)
	player.force = force
	player.character.destructible = true
	player.spectator = false
	game.permissions.get_group("Default").add_player(player)
end


local function team_join (pid, side)
	local team = bb.teams[side]
	local player = game.players[pid]

	if bb.get_state() == bb.states.FINISHED then
		player.print("The match has ended")
		return false
	elseif bb.tournament then
		-- Tournament mode
		player.print("This is a tournament, joining team is disabled")
		return false
	elseif bb.teams_locked then
		-- Teams locked
		player.print("Teams are locked")
		return false
	elseif bb.team_balancing and not can_join(pid, side) then
		-- Team balancing
		player.print("Cannot join team "..team.name.." : too many players difference")
		return false
	else
		local previous_team = Teams.team_of(pid)

		-- Cannot join a team if already have one
		if previous_team then
			error("Trying to join a team while already having one : "
				..player.name.."->"
				..previous_team.name.."("..previous_team.id..")"
			)
			return false
		end

		if bb.get_state() == bb.states.WAITING then
			bb.start_match()
		end

		set_player_team(pid, side)
		move_player(pid, side)

		game.print({
			"biter_battles.joined_team",
			player.name,
			team.name
		})

		script.raise_event(bb.events.on_team_joined, {
			player_id = pid,
			team = team,
			previous = previous_team -- nil
		})
	end
end


local function try_join (event)
	if not event.element.valid then return end
	local side = nil
	local element = event.element
	for s in pairs(bb.teams) do
		if s.."join" == element.name then
			side = s
			break
		end
	end
	if not side then return end
	team_join(event.player_index, side)
end


local function rejoin (pid)
	local player = game.players[pid]
	if Spectate.cooldown[pid] then
		local remaining_time = const.spectate_cooldown - (game.tick - Spectate.cooldown[pid])
		if remaining_time > 0 then
			local str = string.format("%.0f", remaining_time / 60)
			player.print("You cannot rejoin your team this fast! Please wait "..str.." sec")
			return false
		end
	end

	local team = Teams.team_of(player)
	local side = bb.side_of_team(team)
	move_player(pid, side)

	game.print(player.name .. " ("..team.name..") is back in the field!")

	script.raise_event(bb.events.on_rejoin, {
		player_id = pid
	})
end


local function try_rejoin (event)
	if not event.element.valid then return end
	if event.element.name ~= "rejoin" then return end

	rejoin (event.player_index)
end


Event.add(defines.events.on_gui_click, try_join)
Event.add(defines.events.on_gui_click, try_rejoin)

return {
	team_join = team_join,
	set_player_team = set_player_team,
	move_player = move_player,
	set_north_name = set_north_name,
	set_south_name = set_south_name
}
