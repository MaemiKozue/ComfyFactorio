local Global = require "utils.global"
local Event = require "utils.event"

local Config = require "maps.biter_battles_distorted.config"

local bb = require "maps.biter_battles_distorted.game"

local math_random = math.random
local math_ceil = math.ceil
local math_floor = math.floor

local this = {
	north_biters = {
		evo = nil, -- float
		threat = nil, -- float
		threat_income = nil, -- float
		evasion = nil, -- float
		active_biters = nil,
		-- {
		-- 	[unit_number] = {
		-- 		entity : LuaEntity,
		-- 		active_since : Tick
		-- 	}
		-- }
		biter_raffle = nil, -- array of biter names
	},
	south_biters = {
		evo = nil,
		threat = nil,
		threat_income = nil,
		evasion = nil,
		active_biters = nil,
		biter_raffle = nil,
	},
	debug = nil,
	next_attack = nil,
	evo_raise_counter = nil,
}

Global.register(this, function (t) this = t end)

local const = {
	threat_values = {
		["small-spitter"] = 2,
		["small-biter"] = 2,
		["medium-spitter"] = 4,
		["medium-biter"] = 4,
		["big-spitter"] = 8,
		["big-biter"] = 8,
		["behemoth-spitter"] = 24,
		["behemoth-biter"] = 24,
		["small-worm-turret"] = 8,
		["medium-worm-turret"] = 12,
		["big-worm-turret"] = 16,
		["behemoth-worm-turret"] = 16,
		["biter-spawner"] = 16,
		["spitter-spawner"] = 16
	},
	biter_forces = {
		north = "north_biters",
		south = "south_biters"
	},
	min_silo_hostility_time = 60*60*30, -- 30 min
	enemies = {
		north = "north_biters",
		south = "south_biters"
	},
	-- Feeding
	minimum_modifier = 125,
	maximum_modifier = 250,
	player_amount_for_maximum_threat_gain = 20,
	food_values = {
		["automation-science-pack"] = {value = 0.001  , name = "automation science", color = "255, 50, 50"},
		["logistic-science-pack"] 	= {value = 0.003  , name = "logistic science"  , color = "50, 255, 50"},
		["military-science-pack"] 	= {value = 0.00822, name = "military science"  , color = "105, 105, 105"},
		["chemical-science-pack"] 	= {value = 0.02271, name = "chemical science"  , color = "100, 200, 255"},
		["production-science-pack"] = {value = 0.09786, name = "production science", color = "150, 25, 255"},
		["utility-science-pack"] 		= {value = 0.10634, name = "utility science"   , color = "210, 210, 60"},
		["space-science-pack"] 			= {value = 0.41828, name = "space science"     , color = "255, 255, 255"},
	},
	-- Evasion
	evasion_random_max = 10000,
}


local function on_init ()
	for _, biter_force in pairs(const.enemies) do
		this[biter_force] = {
			evo = 0,
			threat = 0,
			threat_income = 0,
			evastion = 0,
			active_biters = {},
			biter_raffle = {}
		}
	end

	this.debug = false

	if math_random(1,2) == 1 then
		this.next_attack = bb.sides.north
	else
		this.next_attack = bb.sides.south
	end

	this.evo_raise_counter = 1
end


local function debug (arg)
	if this.debug or global.debug then
		game.print(arg)
	end
end


local function get_active_biter_count (biter_force_name)
	return table_size(this[biter_force_name].active_biters)
end


local function set_biter_raffle_table (surface, biter_force_name)
	local biters = surface.find_entities_filtered({
		type = "unit",
		force = biter_force_name
	})

	if not biters[1] then return end

	local raffle = {}
	local size = 0
	for _, e in pairs(biters) do
		if math_random(1,3) == 1 then
			size = size + 1
			raffle[size] = e.name
		end
	end
	this[biter_force_name].biter_raffle = raffle
end


local function get_threat_ratio (biter_force_name)
	local threat = this[biter_force_name].threat
	if threat <= 0 then return 0 end

	local a = this.north_biters.threat
	local b = this.south_biters.threat

	if a == b then return 0.5 end
	if a < 0 then a = 0 end
	if b < 0 then b = 0 end

	local total_threat = a + b
	local ratio = threat / total_threat
	return ratio
end


-- biter = {
--	entity = LuaEntity->Biter,
--	active_since = tick
-- }
local function is_biter_inactive (biter)
	if not biter.entity.valid then return true end

	if game.tick - biter.active_since < Config.biter_timeout then return false end

	local e = biter.entity
	local pos = e.position
	local player_entities_count = e.surface.count_entities_filtered({
		area = {
			{pos.x - 16, pos.y - 16},
			{pos.x + 16, pos.y + 16}
		},
		force = {bb.sides.north, bb.sides.south}
	})

	-- The biter is around player structures
	if player_entities_count ~= 0 then
		biter.active_since = game.tick
		return false
	end

	return true
end


local function destroy_old_age_biters ()
	local surface = game.surfaces[bb.surface_name]
	for _, e in pairs(surface.find_entities_filtered({type = "unit"})) do
		if not e.unit_group and math_random(1,8) == 1 then
			e.destroy()
		end
	end
end


local function destroy_inactive_biters ()
	for _, biter_force_name in pairs(const.biter_forces) do
		for unit_number, biter in pairs(this[biter_force_name].active_biters) do
			local inactive = is_biter_inactive(biter)
			if inactive then
				if biter.entity.valid then
					biter.entity.destroy()
					debug(biter_force_name .. " unit " .. unit_number .. " timed out at tick age " .. game.tick - biter.active_since)
				end
				this[biter_force_name].active_biters[unit_number] = nil
			end
		end
	end
end


local function send_near_biters_to_silo ()
	if bb.get_state() ~= bb.states.RUNNING then return end
	if bb.time() < const.min_silo_hostility_time then return end

	local surface = game.surfaces[bb.surface_name]

	for side, biter_force in pairs(const.enemies) do
		surface.set_multi_command({
			command = {
				type = defines.command.attack,
				target = bb.rocket_silos[side],
				distraction = defines.distraction.none
			},
			unit_count = 16,
			force = biter_force,
			unit_search_distance = 128
		})
	end
end


local function get_random_close_spawner (surface, biter_force_name)
	local spawners = surface.find_entities_filtered({
		type = "unit-spawner",
		force = biter_force_name
	})
	if not spawners[1] then return false end

	-- Distance to center
	local distance = function (pos)
		return pos.x * pos.x + pos.y * pos.y
	end

	local best_spawner = spawners[math_random(1,#spawners)]
	local best_dist = distance(best_spawner.position)
	-- Search for a closer spawner
	for i = 1, 5, 1 do
		local spawner = spawners[math_random(1,#spawners)]
		local dist = distance(spawner.position)

		if dist < best_dist then
			best_spawner = spawner
			best_dist = dist
		end
	end

	return best_spawner
end


local function select_units_around_spawner (spawner, force_name)
	local biter_force_name = const.enemies[force_name]
	local biters_data = this[biter_force_name]
	local biters = spawner.surface.find_enemy_units(spawner.position, 160, force_name)
	if not biters[1] then return false end

	local threat = biters_data.threat * math_random(11,22) * 0.01

	local max_unit_count = math_ceil(biters_data.threat * 0.25) + math_random(6,12)
	if max_unit_count > Config.max_group_size then
		max_unit_count = Config.max_group_size
	end

	local unit_count = 0
	local valid_biters = {}
	-- Constructs a list of inactive biters around spawners, and set them active
	-- Until threat is negative or until group size is reached
	for _, biter in pairs(biters) do
		if unit_count >= max_unit_count then break end

		if biter.force.name == biter_force_name
			and biters_data.active_biters[biter.unit_number] == nil
		then
			valid_biters[#valid_biters + 1] = biter
			biters_data.active_biters[biter.unit_number] = {
				entity = biter,
				active_since = game.tick
			}
			unit_count = unit_count + 1
			threat = threat - const.threat_values[biter.name]
		end

		if threat < 0 then break end
	end

	-- Manual spawning of additional units
	-- Fill the group with newly created biters
	local raffle = biters_data.biter_raffle
	local missing_biters_count = max_unit_count - unit_count
	for _ = 1, missing_biters_count, 1 do
		if threat < 0 then break end
		local biter_name = raffle[math_random(1, #raffle)]
		local pos = spawner.surface.find_non_colliding_position(biter_name, spawner.position, 128, 2)
		if not pos then break end

		local biter = spawner.surface.create_entity({
			name = biter_name,
			force = biter_force_name,
			position = pos
		})

		threat = threat - const.threat_values[biter.name]
		valid_biters[#valid_biters + 1] = biter
		biters_data.active_biters[biter.unit_number] = {
			entity = biter,
			active_since = game.tick
		}
	end

	debug(get_active_biter_count(biter_force_name) .. " active units for " .. biter_force_name)

	return valid_biters
end


local function send_group (unit_group, force_name, nearest_player_unit)
	local target = nearest_player_unit.position
	if math_random(1,2) == 1 then
		target = bb.rocket_silos[force_name].position
	end

	unit_group.set_command({
		type = defines.command.compound,
		structure_type = defines.compound_command.return_last,
		commands = {
			{
				type = defines.command.attack_area,
				destination = target,
				radius = 32,
				distraction = defines.distraction.by_enemy
			},
			{
				type = defines.command.attack,
				target = bb.rocket_silos[force_name],
				distraction = defines.distraction.by_enemy
			}
		}
	})

	return true
end


local function is_chunk_empty (surface, area)
	return surface.count_entities_filtered({type = {"unit-spawner", "unit"}, area = area}) ~= 0
		and surface.count_entities_filtered({force = {bb.sides.north, bb.sides.south}, area = area}) ~= 0
		and surface.count_tiles_filtered({name = {"water", "deepwater"}, area = area}) ~= 0
end


local function get_unit_group_position (surface, nearest_player_unit, spawner)
	-- 1/3 chance to pick a free chunk around the spawner, randomly
	if math_random(1,3) ~= 1 then
		local spawner_chunk_position = {
			x = math_floor(spawner.position.x / 32),
			y = math_floor(spawner.position.y / 32)
		}
		local valid_chunks = {}
		for x = -2, 2, 1 do
			for y = -2, 2, 1 do
				local chunk = {
					x = spawner_chunk_position.x + x,
					y = spawner_chunk_position.y + y
				}
				local area = {
					{chunk.x * 32     , chunk.y * 32     },
					{chunk.x * 32 + 32, chunk.y * 32 + 32}
				}
				if is_chunk_empty(surface, area) then
					valid_chunks[#valid_chunks + 1] = chunk
				end
			end
		end

		if #valid_chunks > 0 then
			local chunk = valid_chunks[math_random(1, #valid_chunks)]
			return {x = chunk.x * 32 + 16, y = chunk.y * 32 + 16}
		end
	end

	-- If no chunk was found free, or in the 2/3 chance cases
	local unit_group_position = {
		x = (spawner.position.x + nearest_player_unit.position.x) * 0.5,
		y = (spawner.position.y + nearest_player_unit.position.y) * 0.5
	}
	local pos = surface.find_non_colliding_position("rocket-silo", unit_group_position, 256, 1)
	if pos then
		unit_group_position = pos
	end

	return unit_group_position
end


local function create_attack_group (surface, force_name)
	local biter_force_name = const.enemies[force_name]
	if this[biter_force_name].threat <= 0 then return false end

	local free_biter_count = Config.max_active_biters - get_active_biter_count(biter_force_name)
	if free_biter_count < Config.max_group_size then
		debug("Not enough slots for biters for team " .. force_name .. ". Available slots: " .. free_biter_count)
		return false
	end

	local spawner = get_random_close_spawner(surface, biter_force_name)
	if not spawner then
		debug("No spawner found for team " .. force_name)
		return false
	end

	local nearest_player_unit = surface.find_nearest_enemy({
		position = spawner.position,
		max_distance = 2048,
		force = biter_force_name
	})
	if not nearest_player_unit then
		nearest_player_unit = bb.rocket_silos[force_name]
	end

	local unit_group_position = get_unit_group_position(surface, nearest_player_unit, spawner)

	local units = select_units_around_spawner(spawner, force_name)
	if not units then return false end

	local unit_group = surface.create_unit_group({
		position = unit_group_position,
		force = biter_force_name
	})

	for _, unit in pairs(units) do
		unit_group.add_member(unit)
	end
	send_group(unit_group, force_name, nearest_player_unit)
end


local function main_attack ()
	local surface = game.surfaces[bb.surface_name]
	local force_name = this.next_attack

	if not bb.training_mode or (bb.training_mode and #game.forces[force_name].connected_players > 0) then
		local biter_force_name = const.enemies[force_name]
		local wave_amount = math_ceil(get_threat_ratio(biter_force_name) * 7)

		set_biter_raffle_table(surface, biter_force_name)

		for _ = 1, wave_amount, 1 do
			create_attack_group(surface, force_name)
		end
		debug(wave_amount .. " unit groups designated for " .. force_name .. " biters.")
	end

	this.next_attack = bb.other_side(this.next_attack)
end


local function get_difficulty_modifier ()
	return global.difficulty_vote_value or 1
end


local function get_instant_threat_player_count_modifier ()
	local north_connected = #game.forces[bb.sides.north].connected_players
	local south_connected = #game.forces[bb.sides.south].connected_players
	local current_player_count = north_connected + south_connected
	local gain_per_player = (const.maximum_modifier - const.minimum_modifier) / const.player_amount_for_maximum_threat_gain
	local m = const.minimum_modifier + gain_per_player * current_player_count
	if m > const.maximum_modifier then
		m = const.maximum_modifier
	end
	return m
end


local function set_biter_endgame_modifiers (force)
	if force.evolution_factor ~= 1 then return end

	local damage_mod  = (this[force.name].evo - 1) * 3
	local evasion_mod = (this[force.name].evo - 1) * 3 + 1

	force.set_ammo_damage_modifier("melee", damage_mod)
	force.set_ammo_damage_modifier("biological", damage_mod)
	force.set_ammo_damage_modifier("artillery-shell", damage_mod)
	force.set_ammo_damage_modifier("flamethrower", damage_mod)
	force.set_ammo_damage_modifier("laser-turret", damage_mod)

	this[force.name].evasion = evasion_mod
end


local function set_evo_and_threat (flask_amount, food, biter_force_name)
	local decimals = 9
	local math_round = math.round

	local instant_threat_player_count_modifier = get_instant_threat_player_count_modifier()

	local food_value = const.food_values[food].value * get_difficulty_modifier()
	local force = game.forces[biter_force_name]

	for _ = 1, flask_amount, 1 do
		---SET EVOLUTION
		local e2 = (force.evolution_factor * 100) + 1
		local evo_diminishing_modifier = (1 / (10 ^ (e2 * 0.017))) / (e2 * 0.5)
		local evo_gain = food_value * evo_diminishing_modifier
		local evo = this[biter_force_name].evo
		evo = evo + evo_gain
		evo = math_round(evo, decimals)

		this[biter_force_name].evo = evo
		if evo <= 1 then
			force.evolution_factor = evo
		else
			force.evolution_factor = 1
		end

		--ADD INSTANT THREAT
		local threat_diminishing_modifier = 1 / (0.2 + (e2 * 0.018))
		local threat = this[biter_force_name].threat
		threat = threat + (food_value * instant_threat_player_count_modifier * threat_diminishing_modifier)
		threat = math_round(threat, decimals)
		this[biter_force_name].threat = threat
	end

	--SET THREAT INCOME
	this[biter_force_name].threat_income = this[biter_force_name].evo * 20

	set_biter_endgame_modifiers(force)

	script.raise_event(bb.events.on_stats_changed, {})
end



local function raise_evo ()
	-- if global.freeze_players then return end
	if bb.get_state() ~= bb.states.RUNNING then return end

	local north_connected = #game.forces[bb.sides.north].connected_players
	local south_connected = #game.forces[bb.sides.south].connected_players
	if not bb.training_mode
		and (north_connected == 0 or south_connected == 0)
	then
		return
	end

	local amount = math_ceil(get_difficulty_modifier() * this.evo_raise_counter)
	local a_team_has_players = false
	for pf, bf in pairs(const.enemies) do
		if #game.forces[pf].connected_players > 0 then
			set_evo_and_threat(amount, "automation-science-pack", bf)
			a_team_has_players = true
		end
	end
	if not a_team_has_players then return end
	this.evo_raise_counter = this.evo_raise_counter + (1 * 0.50)

	script.raise_event(bb.events.on_stats_changed, {})
end


local function get_evade_chance (force_name)
	return const.evasion_random_max - (const.evasion_random_max / this[force_name].evasion)
end


local function evade (event)
	if not event.entity.valid then return end

	local entity = event.entity
	local force_name = entity.force.name
	if not this[force_name] or not this[force_name].evasion then return end

	local evasion = this[force_name].evasion

	if event.final_damage_amount > entity.prototype.max_health * evasion then return end
	if math_random(1, const.evasion_random_max) > get_evade_chance(force_name) then return end

	entity.health = entity.health + event.final_damage_amount
end


local function natural_threat_increase ()
	-- natural threat increase
	for _, biter_force in pairs(const.enemies) do
		local data = this[biter_force]
		data.threat = data.threat + data.threat_income
	end

	script.raise_event(bb.events.on_stats_changed, {})
end


local function feed_biters (player, food, biter_force_name)
	local inv = player.get_main_inventory()
	local flask_amount = inv.get_item_count(food)
	if flask_amount == 0 then
		player.print("You have no " .. const.food_values[food].name .. " flask in your inventory.", {r = 0.98, g = 0.66, b = 0.22})
		return
	end

	inv.remove({name = food, count = flask_amount})
	set_evo_and_threat(flask_amount, food, biter_force_name)
end


-- Biter Threat Value Substraction
local function on_entity_died (event)
	if not event.entity.valid then return end
	if not const.threat_values[event.entity.name] then return end

	local entity = event.entity
	local force_name = entity.force.name
	if event.entity.type == "unit" then
		this[force_name].active_biters[entity.unit_number] = nil
	end
	this[force_name].threat = this[force_name].threat - const.threat_values[entity.name]

	script.raise_event(bb.events.on_stats_changed, {})
end


local function on_tick ()
	if bb.get_state() ~= bb.states.RUNNING then return end
	-- each second
	if game.tick % 60 ~= 0 then return end

	natural_threat_increase()

	-- each minute
	if game.tick % 3600 ~= 0 then return end
	raise_evo()
	destroy_inactive_biters()
	main_attack()
	send_near_biters_to_silo()
	destroy_old_age_biters()

end

Event.add(defines.events.on_entity_damaged, evade)
Event.add(defines.events.on_entity_died, on_entity_died)
Event.add(defines.events.on_tick, on_tick)
Event.on_init(on_init)


local export = {
	set_evo_and_threat = set_evo_and_threat,
	feed_biters = feed_biters
}

setmetatable(export, {
	__index = function (t, k)
		return const[k] or this[k]
	end
})

return export
