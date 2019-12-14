local Global = require "utils.global"
local Event = require "utils.event"
local bb = require "maps.biter_battles_distorted.game"

local math_ceil = math.ceil

local this = {
	-- map force <> tick
	timeout = {}
}

Global.register(this, function (t) this = t end)

local const = {
	duration_per_unit = 2700,
	-- Spying radius around opposite players
	radius = 96,

	-- it seems Factorio keeps a chart active for 5 seconds..
	chart_active_time = 60*5 -- 5 sec
}


Event.on_init(function ()
	for _, side in pairs(bb.sides) do
		this.timeout[side] = 0
	end
end)


local function chart_map ()
	local surface = game.surfaces[bb.surface_name]
	local r = const.radius
	for _, side in pairs(bb.sides) do
		local opposite = bb.other_side(side)
		if this.timeout[side] - game.tick > 0 then
			for _, player in pairs(game.forces[opposite].connected_players) do
				game.forces[side].chart(surface, {
					{player.position.x - r, player.position.y - r},
					{player.position.x + r, player.position.y + r}
				})
			end
		else
			this.timeout[side] = 0
		end
	end
end


local function spy_fish (player)
	if not player.character then return end

	local inv = player.get_inventory(defines.inventory.character_main)
	if not inv then return end

	local owned_fishes = inv.get_item_count("raw-fish")
	if owned_fishes == 0 then
		player.print("You have no fish in your inventory.",{ r=0.98, g=0.66, b=0.22})
	else
		inv.remove({name="raw-fish", count=1})
		local side = player.force.name

		if this.timeout[side] - game.tick > 0 then
			this.timeout[side] = this.timeout[side] + const.duration_per_unit
			player.print(math_ceil((this.timeout[side] - game.tick) / 60) .. " seconds of enemy vision left.", { r=0.98, g=0.66, b=0.22})
		else
			local opposite = bb.other_side(side)
			game.print(player.name .. " sent a fish to spy on " .. opposite .. " team!", {r=0.98, g=0.66, b=0.22})
			this.timeout[side] = game.tick + const.duration_per_unit
		end
	end
end


local function on_gui_click (event)
	if bb.get_state() ~= bb.states.RUNNING then return end
	if not event.element.valid then return end
	if event.element.name ~= "send_fish" then return end

	local player = game.players[event.player_index]
	spy_fish(player)
end


Event.add(defines.events.on_gui_click, on_gui_click)
Event.on_nth_tick(const.chart_active_time, chart_map)


local export = {
	spy_fish = spy_fish
}

setmetatable(export, { __index =
	function (_, k)
		return this[k] or const[k]
	end
})

return export
