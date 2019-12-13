local Global = require "utils.global"
local Event = require "utils.event"
local Server = require "utils.server"
local bb = require "maps.biter_battles_distorted.game"

local this = {
	-- When to restart (in ticks)
	target = nil,
}

local const = {
	timer = 60*60*3 -- 3 min
}

Global.register(this, function (t) this = t end)


local function do_restart()
	game.print("Map is restarting!", {r=0.22, g=0.88, b=0.22})
	local message = 'Map is restarting! '
	Server.to_discord_bold(table.concat{'*** ', message, ' ***'})
	Server.start_scenario('Biter_Battles_Distorted')
end

local function server_restart ()
	if not this.target then return end

	local remaining_time = this.target - game.tick

	-- Every 30 sec
	if remaining_time % 1800 == 0 then
		game.print("Map will restart in " .. remaining_time / 60 .. " seconds!", {r=0.22, g=0.88, b=0.22})
	end

	if remaining_time <= 0 then
		do_restart()
		this.target = nil
	end
end

local function schedule_server_restart ()
	this.target = game.tick + const.timer
end

Event.add(bb.events.on_game_finished, schedule_server_restart)
Event.add(defines.events.on_tick, server_restart)


return {
	restart = do_restart
}
