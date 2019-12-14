local Global = require "utils.global"
local Event = require "utils.event"
local Terrain = require "maps.biter_battles_distorted.terrain"
local MirrorTerrain = require "maps.biter_battles_distorted.mirror_terrain"

local math_random = math.random

local this = {
	-- Name of the game surface
	surface_name = nil
}

Global.register(this, function (t) this = t end)

local const = {}


local function init_surface (surface_name)
	local map_gen_settings = {}
	map_gen_settings.water = math_random(15, 65) * 0.01
	map_gen_settings.starting_area = 2.5
	map_gen_settings.terrain_segmentation = math_random(30, 40) * 0.1
	map_gen_settings.cliff_settings = {
		cliff_elevation_interval = 0,
		cliff_elevation_0 = 0
	}
	map_gen_settings.autoplace_controls = {
		["coal"] 				= { frequency = 2.5, size = 0.65, richness = 0.5  },
		["stone"] 			= { frequency = 2.5, size = 0.65, richness = 0.5  },
		["copper-ore"] 	= { frequency = 3.5, size = 0.65, richness = 0.5  },
		["iron-ore"] 		= { frequency = 3.5, size = 0.65, richness = 0.5  },
		["uranium-ore"] = { frequency = 2,   size = 1,    richness = 1    },
		["crude-oil"] 	= { frequency = 3,   size = 1,    richness = 0.75 },
		["enemy-base"] 	= { frequency = 256, size = 0.61, richness = 1    },
		["trees"] = {
			frequency = math_random(8, 16) * 0.1,
			size = math_random(8, 16) * 0.1,
			richness = math_random(2, 10) * 0.1
		}
	}
	game.create_surface(surface_name, map_gen_settings)

	game.map_settings.enemy_evolution.time_factor = 0
	game.map_settings.enemy_evolution.destroy_factor = 0
	game.map_settings.enemy_evolution.pollution_factor = 0
	game.map_settings.pollution.enabled = false
	game.map_settings.enemy_expansion.enabled = false
end


local function generate_starter_area (surface_name)
	local surface = game.surfaces[surface_name]
	surface.request_to_generate_chunks({0,0})
	surface.force_generate_chunk_requests()
end


local function setup (surface_name)
	this.surface_name = surface_name
	init_surface (surface_name)
	-- generate_starter_area (surface_name)
end


local function post_setup (silos)
	Terrain.setup(this.surface_name, silos)
	MirrorTerrain.force_mirror(silos)
end

local function is_chunk_north (pos)
	return pos.y < 0
end


local function on_chunk_generated (event)
	if event.surface.name ~= this.surface_name then return end
	-- local chunk = event.position
	-- if not is_chunk_north (chunk) then
	--
	-- end
end


Event.add(defines.events.on_chunk_generated, on_chunk_generated)
Event.add(defines.events.on_tick, MirrorTerrain.on_tick)


return {
	setup = setup,
	post_setup = post_setup,
}
