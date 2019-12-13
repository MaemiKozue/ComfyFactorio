local Event = require "utils.event"

local Global = require "utils.global"

local bb = require "maps.biter_battles_distorted.game"

local this = {
	-- map pid <> tick : last time when the player successfully entered spectate
	cooldown = {}
}

Global.register(this, function (t) this = t end)


local const = {
	spectate_range = 12000,
	center_position = {0,0},
	teleport_radius = 4,
	teleport_precision = 1
}


local function reset_cooldown (pid)
	this.cooldown[pid] = nil
end


local function in_range (player)
	local pos = player.position
	local d_square = pos.x * pos.x + pos.y * pos.y
	return d_square < const.spectate_range
end


local function set_spectator (pid)
	local player = game.players[pid]
	local pos = game.surfaces[bb.surface_name].find_non_colliding_position("character", const.center_position, const.teleport_radius, const.teleport_precision)
	if not pos then
		player.print("It is not possible to spectate at the moment, could not find a suitable place for you")
		return false
	end
	player.teleport(pos)
	player.force = game.forces.player
	player.character.destructible = false
	game.permissions.get_group("spectator").add_player(player)
	player.spectator = true
	reset_cooldown(pid)
end


local function spectate (pid)
	-- Allow spectating while running, and on finished game, because why not
	if bb.get_state() ~= bb.states.RUNNING
		and bb.get_state() ~= bb.states.FINISHED
	then
		return false
	end


	local player = game.players[pid]
	if bb.get_tournament() then
		player.print("Spectating is not allowed during tournament")
	elseif not in_range(player) then
		player.print("You are too far to the center to be spectating")
	elseif not player.character then
		player.print("Wait until you respawn before spectating")
	else
		set_spectator(pid)
		this.cooldown[pid] = game.tick

		game.print(player.name .. " is now spectating")

		script.raise_event(bb.events.on_spectate, {
			player_id = player.index
		})
	end
end

local function try_spectate (event)
	if not event.element.valid then return end
	if event.element.name ~= "spectate" then return end

	spectate(event.player_index)
end


local function on_player_joined_game (event)
	local player = game.players[event.player_index]
	if player.online_time == 0 then
		set_spectator(event.player_index)
	end
end


Event.add(defines.events.on_gui_click, try_spectate)
Event.add(defines.events.on_player_joined_game, on_player_joined_game)

local export = {
	set_spectator = set_spectator,
	reset_cooldown = reset_cooldown
}

setmetatable(export, {
	__index = function (t, k)
		-- log("Accessing Spectate."..k..":\n"..serpent.block(this[k]))
		return this[k]
	end
})

return export
