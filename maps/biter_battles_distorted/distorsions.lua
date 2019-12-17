local Global = require "utils.global"
local Event = require "utils.event"
local bb = require "maps.biter_battles_distorted.game"
local Queue = require "data_structures.queue"

local math_random = math.random

local this = {
	queue = nil,
	last_start = nil,
}

Global.register(this, function (t) this = t end)

local const = {
	default_behaviour = require "maps.biter_battles_distorted.distorsions.default",
	default_distorsion_id = 1, -- refer to all_distorsions
	distorsion_length = 60*60*15, -- 15 min
	types = {
		none = 0,
		user = 1
	},
	distorsions = require "maps.biter_battles_distorted.all_distorsions",
	min_queue_size = 3
}


-- local function remove (index)
--
-- end


local function remove_all ()
	this.queue = Queue.new()
end


local function add_default ()
	this.queue:add{
		distorsion_id = const.default_distorsion_id,
		type = const.types.none
	}
end


local function add (index)
	this.queue:add{
		distorsion_id = index,
		type = const.types.user
	}
end


local function list ()
	return this.queue
end


local function shadow_events ()
	for k, v in pairs(bb.events) do
		Event.add(v,
			function (event)
				local current = this.queue:peek()
				-- Sometimes, people make the queue empty
				if not current then return end
				local handler
				if current.type == const.types.user then
					handler = const.distorsions[current.distorsion_id].distorsion[k]
				else
					handler = const.default_behaviour[k]
				end
				if handler then
					handler(event)
				end
			end
		)
	end
end


local function queue_new_distorsion (queue)
	local idx = math_random(#const.distorsions)
	local distorsion = const.distorsions[idx]
	if distorsion.name == "default" then
		add_default()
	else
		add(idx)
	end
end


local function skip ()
	local prev = this.queue:pop()
	script.raise_event(bb.events.on_distorsion_finished, {
		distorsion_id = prev.distorsion_id
	})
	queue_new_distorsion(this.queue)
	this.last_start = game.tick
	local next = this.queue:last_added()
	script.raise_event(bb.events.on_distorsion_started, {
		distorsion_id = next.distorsion_id
	})
end


local function on_game_started ()
	this.last_start = game.tick

	while this.queue:size() < const.min_queue_size do
		queue_new_distorsion(this.queue)
	end
end


local function on_tick ()
	if bb.get_state() ~= bb.states.RUNNING then return end
	local time = game.tick - this.last_start

	if time > const.distorsion_length then
		local prev = this.queue:pop()

		if this.queue:size() < const.min_queue_size then
			queue_new_distorsion(this.queue)
		end

		script.raise_event(bb.events.on_distorsion_finished, {
			distorsion_id = prev.distorsion_id
		})

		local next = this.queue:peek()
		if next.type == const.types.user then
			this.last_start = game.tick
			script.raise_event(bb.events.on_distorsion_started, {
				distorsion_id = next.distorsion_id
			})
		end
	end
end


local function on_init ()
	shadow_events ()
	this.queue = Queue.new()
	this.queue:add({
		distorsion_id = const.default_distorsion_id,
		type = const.types.none
	})
end


local function on_load ()
	shadow_events ()
	Queue.on_load(this.queue)
end


Event.on_init(on_init)
Event.on_load(on_load)
Event.add(defines.events.on_tick, on_tick)
Event.add(bb.events.on_game_started, on_game_started)


local export = {
	skip = skip,
	add = add,
	remove_all = remove_all,
	list = list,
}

setmetatable(export, {
	__index = function (_, k)
		local r
		if this[k] then
			r = this[k]
		else
			r = const[k]
		end
		return r
	end
})

return export
