local Event = require "utils.event"

local bb = require "maps.biter_battles_distorted.game"

-- Prevents players from damaging Rocket Silos
local function protect_silo (event)
	if event.cause and event.cause.type == "unit" then return end
	if event.entity.name ~= "rocket-silo" then return end
	event.entity.health = event.entity.health + event.final_damage_amount
end

--Prevents players from doing direct pvp combat
local function ignore_pvp (event)
	if not event.cause then return end
	if not event.entity.valid then return end
	if not bb.sides[event.entity.force.name] then return end
	if not bb.sides[event.cause.force.name] then return end

	if event.cause.force.name == bb.other_side(event.entity.force.name) then
		event.entity.health = event.entity.health + event.final_damage_amount
	end
end


local function on_entity_damaged(event)
	protect_silo(event)
	ignore_pvp(event)
end

Event.add(defines.events.on_entity_damaged, on_entity_damaged)
