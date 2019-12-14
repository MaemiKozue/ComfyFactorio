local Event = require "utils.event"
local bb = require "maps.biter_battles_distorted.game"
local Spectate = require "maps.biter_battles_distorted.spectate"

local const = {
	afk_timeout = 60*60*10, -- 10 minutes
}

local function move_afk_to_spectate ()
	if bb.get_state() ~= bb.states.RUNNING then return end

	for pid, player in pairs(game.connected_players) do
		if not player.spectator and player.afk_time > const.afk_timeout then
			Spectate.set_spectator(pid)
			script.raise_event(bb.events.on_player_afk_spectate, {
				player_id = pid
			})
		end
	end
end

Event.on_nth_tick(60, move_afk_to_spectate)
