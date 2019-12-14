local Event = require "utils.event"
local Global = require "utils.global"

local this = {
	-- map force_name <> damage
	flamethrower_damage = {}
}


--Flamethrower Turret Nerf
local function on_research_finished (event)
	local research = event.research
	local force = research.force
	local force_name = research.force.name

	if research.name == "flamethrower" then
		this.flamethrower_damage[force_name] = -0.6
		force.set_turret_attack_modifier("flamethrower-turret", this.flamethrower_damage[force_name])
		force.set_ammo_damage_modifier("flamethrower", this.flamethrower_damage[force_name])
	end

	if string.sub(research.name, 0, 18) == "refined-flammables" then
		this.flamethrower_damage[force_name] = this.flamethrower_damage[force_name] + 0.05
		force.set_turret_attack_modifier("flamethrower-turret", this.flamethrower_damage[force_name])
		force.set_ammo_damage_modifier("flamethrower", this.flamethrower_damage[force_name])
	end
end

Event.add(defines.events.on_research_finished, on_research_finished)
