local event = require 'utils.event'
local Server = require 'utils.server'

local gui = require "maps.biter_battles_v2.gui"
local ai = require "maps.biter_battles_v2.ai"
local chunk_pregen = require "maps.biter_battles_v2.pregenerate_chunks"
local mirror_tick_routine = require "maps.biter_battles_v2.mirror_terrain"
local server_restart = require "maps.biter_battles_v2.game_won"

local spy_forces = {{"north", "south"},{"south", "north"}}
local function spy_fish()
	for _, f in pairs(spy_forces) do
		if global.spy_fish_timeout[f[1]] - game.tick > 0 then
			local r = 96
			local surface = game.surfaces["biter_battles"]
			for _, player in pairs(game.forces[f[2]].connected_players) do
				game.forces[f[1]].chart(surface, {{player.position.x - r, player.position.y - r}, {player.position.x + r, player.position.y + r}})
			end
		else
			global.spy_fish_timeout[f[1]] = 0
		end
	end
end

local function reveal_map()
	for _, f in pairs({"north", "south", "player", "spectator"}) do
		local r = 768
		game.forces[f].chart(game.surfaces["biter_battles"], {{r * -1, r * -1}, {r, r}})
	end
end

local function clear_corpses()
	local corpses = game.surfaces["biter_battles"].find_entities_filtered({type = "corpse"})
	if #corpses < 1024 then return end
	for _, e in pairs(corpses) do
		if math.random(1, 3) == 1 then
			e.destroy()
		end
	end
end

local function restart_idle_map()
	if game.tick < 432000 then return end
	if #game.connected_players ~= 0 then global.restart_idle_map_countdown = 2 return end
	if not global.restart_idle_map_countdown then global.restart_idle_map_countdown = 2 end
	global.restart_idle_map_countdown = global.restart_idle_map_countdown - 1
	if global.restart_idle_map_countdown ~= 0 then return end
	Server.start_scenario('Biter_Battles')
end

local function on_tick(event)

	if game.tick % 300 ~= 0 then return end
	spy_fish()
	if global.bb_game_won_by_team then
		reveal_map()
		server_restart()
		return
	end

end

event.add(defines.events.on_tick, on_tick)
