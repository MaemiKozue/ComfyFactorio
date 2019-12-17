require "on_tick_schedule" -- make it better and avoid this module

local Event = require "utils.event"
local bb = require "maps.biter_battles_distorted.game"


local math_random = math.random


local function create_kaboom(surface, pos)
	surface.create_entity({
		name = "explosive-cannon-projectile",
		position = pos,
		force = "enemy",
		target = pos,
		speed = 1
	})
end


local function annihilate_base(surface, center_pos)
	-- Generates positions around a center, packed by squared distance
	local positions = {}
	local radius = 35
	local squared_radius = radius*radius
	local density = 1/7
	for x = -radius, radius, 1 do
		for y = -radius, radius, 1 do
			local squared_distance = x*x + y*y
			if squared_distance <= squared_radius and math_random() <= density then
				if not positions[squared_distance] then positions[squared_distance] = {} end
				positions[squared_distance][#positions[squared_distance] + 1] = {
					x = center_pos.x + x,
					y = center_pos.y + y
				}
			end
		end
	end

	if #positions == 0 then return end

	-- Creates explosions outwards from the center over time
	local t = 1
	for _, pos_list in pairs(positions) do
		for _, pos in pairs(pos_list) do
			if not global.on_tick_schedule[game.tick + t] then global.on_tick_schedule[game.tick + t] = {} end
			global.on_tick_schedule[game.tick + t][#global.on_tick_schedule[game.tick + t] + 1] = {
				func = create_kaboom,
				args = {surface, pos}
			}
		end
		t = t + 1
	end
end


local function create_fireworks_rocket(surface, position)
	local math_random = math.random -- quickfix for desync
	local particles = {"coal-particle", "copper-ore-particle", "iron-ore-particle", "stone-particle"}
	local particle = particles[math_random(1, #particles)]
	local m = math_random(16, 36)
	local m2 = m * 0.005

	for i = 1, 60, 1 do
		surface.create_entity({
			name = particle,
			position = position,
			frame_speed = 0.1,
			vertical_speed = 0.1,
			height = 0.1,
			movement = {
				m2 - (math_random(0, m) * 0.01),
				m2 - (math_random(0, m) * 0.01)
			}
		})
	end

	if math_random(1,10) ~= 1 then return end
	surface.create_entity({name = "explosion", position = position})
end


local function fireworks(surface, center_pos)
	local radius = 48
	local squared_radius = radius * radius
	local positions = {}
	for x = -radius, radius, 1 do
		for y = -radius, radius, 1 do
			local squared_distance = x*x + y*y
			if squared_distance <= squared_radius then
				positions[#positions + 1] = {
					x = center_pos.x + x,
					y = center_pos.y + y
				}
			end
		end
	end
	if #positions == 0 then return end

	local duration = 7200
	for t = 2, duration, 2 do
		local date = game.tick + t
		if not global.on_tick_schedule[date] then global.on_tick_schedule[date] = {} end
		local pos = positions[math_random(1, #positions)]
		global.on_tick_schedule[date][#global.on_tick_schedule[date] + 1] = {
			func = create_fireworks_rocket,
			args = {
				surface,
				{x = pos.x, y = pos.y}
			}
		}
	end
end


local function on_game_finished (event)
	local surface = game.surfaces[bb.surface_name]
	local winner_center = bb.rocket_silos[event.winner].position
	local loser_center = bb.rocket_silos[event.loser].position
	fireworks(surface, winner_center)
	annihilate_base(surface, loser_center)
end


Event.add(bb.events.on_game_finished, on_game_finished)
