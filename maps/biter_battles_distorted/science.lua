local Event = require "utils.event"
local bb = require "maps.biter_battles_distorted.game"
local Teams = require "maps.biter_battles_distorted.teams"


local const = {
	science = {
		["automation-science-pack"] = "automation-science-pack",
		["logistic-science-pack"] = "logistic-science-pack",
		["military-science-pack"] = "military-science-pack",
		["chemical-science-pack"] = "chemical-science-pack",
		["production-science-pack"] = "production-science-pack",
		["utility-science-pack"] = "utility-science-pack",
		["space-science-pack"] = "space-science-pack",
	}
}


local function button_to_science (elem)
	local match = elem.name:match("send_science_(.+)")
	return const.science[match]
end


local function on_gui_click (event)
	if bb.get_state() ~= bb.states.RUNNING then return end
	if not event.element.valid then return end
	local science = button_to_science(event.element)
	if not science then return end

	local player = game.players[event.player_index]
	local inv = player.get_main_inventory()
	local amount = inv.get_item_count(science)
	if amount == 0 then
		player.print({"", "You have no " , {"item-name."..science}, " [img=item/"..const.science[science].."] your inventory."})
		return
	end

	inv.remove({name = science, count = amount})

	local team = Teams.team_of(player)
	local other_team = bb.teams[bb.other_side(bb.side_of_team(team))]
	game.print({
		"",
		player.name.." ("..team.name..") sent "..amount.." ",
		{"item-name."..science},
		"[img=item/"..science.."]".."to "..other_team.name
	})

	script.raise_event(bb.events.on_science_sent, {
		player_id = player.index,
		type = science,
		count = amount
	})
end

Event.add(defines.events.on_gui_click, on_gui_click)
