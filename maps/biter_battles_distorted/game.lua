local Global = require "utils.global"
local Event = require "utils.event"

local Config = require "maps.biter_battles_distorted.config"

local Teams = require "maps.biter_battles_distorted.teams"
local Mapgen = require "maps.biter_battles_distorted.mapgen"


local this = {
	-- Game state
	state = nil,
	teams = {
		north = nil,
		south = nil
	},
	tournament = nil,
	teams_locked = nil,
	team_balancing = nil,
	training_mode = nil,
	time_start = nil,
	time_stop = nil,

	rocket_silos = {},

	winner_side = nil,
	loser_side = nil,
	reveal_map = nil,
}

Global.register(this, function (t) this = t end)

local const = {
	states = {
		WAITING = 0,
		RUNNING = 1,
		FINISHED = 2
	},
	sides = {
		north = "north",
		south = "south"
	},
	spawn_position = {
		north = {0, -32},
		south = {0,  32}
	},
	surface_name = "biter_battles",
	map_reveal_interval = 60*5, -- every 5 sec
}


local events = {
	-- When a player joins a team
	on_team_joined = script.generate_event_name(),
	-- event = {
	-- 	player_id : the player joining the team
	-- 	team : the team they joined
	-- 	previous : the team they were previously if any, or nil
	-- }

	-- When the game starts
	on_game_started = script.generate_event_name(),
	-- event = {}

	-- When the game finishes
	on_game_finished = script.generate_event_name(),
	-- event = {
	-- 	winner : side who won the game
	-- 	loser : side who lost the game
	-- }

	-- When a player spectates
	on_spectate = script.generate_event_name(),
	-- event = {
	-- 	player_id : the player spectating,
	-- }

	-- When the player goes back to playing
	on_rejoin = script.generate_event_name(),
	-- event = {
	-- 	player_id : the player rejoining
	-- }

	-- When a player sends science
	on_science_sent = script.generate_event_name(),
	-- event = {
	-- 	player_id : the player who sent the science
	-- 	type : the prototype name of the science
	-- 	count : the amount of science sent
	-- }

	-- When a player sends a fish
	on_fish_sent = script.generate_event_name(),
	-- event = {
	-- 	player_id : the player who sent the fish
	-- }

	-- When a distorsion starts
	on_distorsion_started = script.generate_event_name(),
	-- event = {
	-- 	distorsion : the distorsion that started
	-- }

	-- When a distorsion finishes
	on_distorsion_finished = script.generate_event_name(),
	-- event = {
	-- 	distorsion : the distorsion that finished
	-- }

	-- When a chunk has been mirrored
	on_chunk_mirrored = script.generate_event_name(),
	-- event = {
	-- 	chunk : the mirrorred chunk
	-- }

	-- When a player is switched to spectate for being AFK
	on_player_afk_spectate = script.generate_event_name(),
	-- event = {
	-- 	player_id : the player who AFK'd
	-- }

	-- When the threat or evolution changes
	on_stats_changed = script.generate_event_name(),
	-- event = {}
}


-- Link with attributes / constants
local function create_forces ()
	local forces = {"north", "south", "north_biters", "south_biters"}

	local cease_fire = {
		["north"] = {"player", "south", "south_biters"},
		["south"] = {"player", "north", "north_biters"},
		["north_biters"] = {"player", "south", "south_biters"},
		["south_biters"] = {"player", "north", "north_biters"},
	}

	-- Create forces
	for _, force_name in pairs(forces) do
		game.create_force(force_name)
	end

	-- Setup the auto-shoot preferences
	for force_name, list in pairs(cease_fire) do
		local force = game.forces[force_name]
		for _, other in pairs(list) do
			force.set_cease_fire(other, true)
		end
	end

	-- Setup spawn position for north and south
	local player_force = game.forces["player"]
	for _, v in pairs(const.sides) do
		local force = game.forces[v]
		force.share_chart = true
		force.set_friend("player", true)
		player_force.set_friend(force, true)
		force.set_spawn_position(const.spawn_position[v], const.surface_name)
	end

end

local function setup_spectator_permissions ()
	local perm = game.permissions.create_group("spectator")

	-- Clear all
	for action, _ in pairs(defines.input_action) do
		perm.set_allows_action(defines.input_action[action], false)
	end

	-- Whitelist
	local whitelist = {
		defines.input_action.activate_copy,
		defines.input_action.activate_cut,
		defines.input_action.activate_paste,
		defines.input_action.clean_cursor_stack,
		defines.input_action.edit_permission_group,
		defines.input_action.gui_click,
		defines.input_action.gui_confirmed,
		defines.input_action.gui_elem_changed,
		defines.input_action.gui_location_changed,
		defines.input_action.gui_selected_tab_changed,
		defines.input_action.gui_selection_state_changed,
		defines.input_action.gui_switch_state_changed,
		defines.input_action.gui_text_changed,
		defines.input_action.gui_value_changed,
		defines.input_action.open_character_gui,
		defines.input_action.open_kills_gui,
		defines.input_action.start_walking,
		defines.input_action.toggle_show_entity_info,
		defines.input_action.write_to_console,
	}

	for _, action in pairs(whitelist) do
		perm.set_allows_action(action, true)
	end
end


local function setup_permissions ()
	-- TODO : setup default permissions
	setup_spectator_permissions()

	if not Config.blueprint_library_importing then
		game.permissions.get_group("Default").set_allows_action(defines.input_action.grab_blueprint_record, false)
	end
	if not Config.blueprint_string_importing then
		game.permissions.get_group("Default").set_allows_action(defines.input_action.import_blueprint_string, false)
		game.permissions.get_group("Default").set_allows_action(defines.input_action.import_blueprint, false)
	end

end


local function on_init ()
	this.state = const.states.WAITING
	this.tournament = false
	this.teams_locked = false
	this.team_balancing = true
	this.training_mode = false
	this.reveal_map = false


	log("Mapgen setup")
	Mapgen.setup(const.surface_name)

	log("Creating teams")
	this.teams.north = Teams.create_team("North")
	this.teams.south = Teams.create_team("South")

	log("Creating forces")
	create_forces()

	log("Setting up permissions")
	setup_permissions()

	log("Mapgen...")
	Mapgen.post_setup(this.rocket_silos) -- rewrite this please

	log("Initialization done!")
end


local function start_match ()
	if this.state ~= const.states.WAITING then
		return
	end

	this.state = const.states.RUNNING
	this.time_start = game.tick

	game.print("Match has started")
	script.raise_event(events.on_game_started, {})
end


local function end_match (winner, loser)
	if this.state ~= const.states.RUNNING then
		return
	end

	this.state = const.states.FINISHED
	this.time_stop = game.tick

	this.winner_side = winner
	this.loser_side = loser

	for _, player in pairs(game.connected_players) do
		player.play_sound{ path = "utility/game_won", volume_modifier = 1 }
		game.print(this.teams[winner].name.." has won the game!")
	end

	game.forces.north.set_friend("north_biters", true)
	game.forces.south.set_friend("south_biters", true)
	game.forces.north_biters.set_friend("north", true)
	game.forces.south_biters.set_friend("south", true)

	this.reveal_map = true

	script.raise_event(events.on_game_finished, {
		winner = winner,
		loser = loser
	})

	--
	-- 	global.spy_fish_timeout["north"] = game.tick + 999999
	-- 	global.spy_fish_timeout["south"] = game.tick + 999999
	--
end


local function other_side (side)
	return (side == const.sides.north and const.sides.south)
			or (side == const.sides.south and const.sides.north)
			or error("unknown side")
end


local function side_of_team (team)
	if team.id == this.teams.north.id then
		return "north"
	elseif team.id == this.teams.south.id then
		return "south"
	else
		error("no side associated with team "..team.name.." ("..team.id..")")
	end
end


local function time ()
	if this.state == const.states.WAITING then
		return nil
	elseif this.state == const.states.RUNNING then
		return game.tick - this.time_start + 1
	else
		return this.time_stop - this.time_start + 1
	end
end


local function on_entity_died (event)
	if this.state ~= const.states.RUNNING then return end
	if not event.entity.valid then return end
	if event.entity.name ~= "rocket-silo" then return end

	local winner = nil
	local loser = nil
	for side, silo in pairs(this.rocket_silos) do
		if event.entity == silo then
			loser = side
			winner = other_side(loser)
			break
		end
	end

	if not winner then return end

	end_match (winner, loser)
end



local function on_player_joined_game (event)
	local player = game.players[event.player_index]
	if player.online_time == 0 then
		local surface = game.surfaces[const.surface_name]
		player.teleport({0,0}, surface)
	end
end


local function reveal_map ()
	if not this.reveal_map then return end

	game.forces.player.chart_all()
end


Event.on_init(on_init)
Event.add(defines.events.on_player_joined_game, on_player_joined_game)
Event.add(defines.events.on_entity_died, on_entity_died)
Event.on_nth_tick(const.map_reveal_interval, reveal_map)



local export = {
	events = events,
	states = const.states,
	get_state = function () return this.state end,
	-- teams = this.teams,
	sides = const.sides,
	other_side = other_side,
	side_of_team = side_of_team,
	start_match = start_match,
	end_match = end_match,
	get_tournament = function () return this.tournament end,
	get_teams_locked = function () return this.teams_locked end,
	get_balancing = function () return this.team_balancing end,
	get_time_start = function () return this.time_start end,
	get_time_stop = function () return this.time_stop end,
	get_elapsed_time = function () return game.tick - this.time_start end,
	surface_name = const.surface_name,
	time = time
}

setmetatable(export, {
	__index = function (t, k)
		-- log("Accessing bb."..k..":\n"..serpent.block(this[k]))
		return this[k]
	end
})

return export
