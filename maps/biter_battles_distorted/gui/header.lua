local Event = require "utils.event"

local bb = require "maps.biter_battles_distorted.game"
local Distorsions = require "maps.biter_battles_distorted.distorsions"

-- local Panel = require "maps.biter_battles_distorted.gui.panel"


-- Dear reader, you might want to know what header and shadow are.
-- * header is the actual flow containing the things to display
-- * shadow is the frame equivalent of header
-- Everything done on header should be done on shadow, in order to keep
-- consistency.
-- The only exception is create_header, which is the entry point of this thing.
-- shadow is there to track the center of the screen of the player, and allows
-- the effective header to be positionned in the middle top of the screen.
-- The thing is, auto_center only applies to frames, and nothing else,
-- but a frame has an opaque background, and I don't want that, so that's the
-- workaround (Factorio 0.17.79)
-- ... yes, this is awful.


local function color(r, g, b, a)
	return {r=r/255, g=g/255, b=b/255, a=a}
end

local const = {
	header_margin_top = 16,
	-- first_distorsion_color = color(0, 255, 0, 0.7), -- green
	first_distorsion_color = color(255, 190, 0, 1), -- orange
	other_distorsion_color = color(204, 231, 252, 0.75), -- blue'd white
	tournament_color = color(255, 0, 0, 1),
	public_color = color(14, 210, 240, 1),
}


local function to_hms (ticks)
	local seconds = ticks / 60
	local left = seconds
	local h = math.floor(left / 3600)
	left = left - 3600*h
	local m = math.floor(left / 60)
	left = left - 60*m
	local s = left
	return h,m,s
end


local function time_caption (ticks)
	local h, m, s = to_hms(ticks)
	return string.format("%02d:%02d:%05.2f", h, m, s)
end


local function get_header (player)
	return player.gui.screen.bb_header
end


local function get_shadow (player)
	return player.gui.screen.bb_shadow_header
end


local function update_timer (header)
	local state = bb.get_state()

	if state == bb.states.WAITING then
		header.timer.caption = "Game has not started yet"
	elseif state == bb.states.RUNNING then
		header.timer.caption = time_caption(game.tick - bb.get_time_start())
	else
		header.timer.caption = time_caption(bb.get_time_stop() - bb.get_time_start())
	end
end


local function create_timer (header)
	local timer = header.add{
		type = "label",
		name = "timer",
		caption = "Timer initializing..."
	}
	timer.style.font = "heading-1"
end


local function update_distorsion_list (header)
	if bb.get_state() ~= bb.states.RUNNING then return end
	local elem = header.distorsion.list
	elem.clear()
	local start = Distorsions.last_start
	local first = true
	for k, entry in Distorsions.list():iterator() do
		local dis = entry.distorsion
		local f = elem.add{
			type = "flow",
			name = k,
			direction = "horizontal"
		}
		f.style.horizontal_align = "center"

		-- Remaining time before start
		local h, m, s
		if not first then
			h, m, s = to_hms(start + (k-1)*Distorsions.distorsion_length - game.tick)
		else
			h, m, s = to_hms(start + k*Distorsions.distorsion_length - game.tick)
		end
		local timer = nil
		if not first then
			timer = f.add{
				type = "label",
				name = "time",
				caption = (h == 0 and string.format("%2d:%02d", m, s))
					or string.format("%d:%2d:%02d", h, m, s)
			}
		end
		local name = f.add{
			type = "label",
			name = "title",
			caption = dis.name
		}
		local desc = f.add{
			type = "label",
			name = "short_description",
			caption =
				dis.short_description
					and {"", "(", dis.short_description, ")"}
				or "(more info)",
			tooltip = dis.description
		}

		for _, e in pairs({f, timer, name, desc}) do
			if e then
				if first then
					e.style.font_color = const.first_distorsion_color
					e.style.font = "heading-2"
				else
					e.style.font_color = const.other_distorsion_color
					e.style.font = "heading-3"
				end
			end
		end

		first = false
	end
end


local function create_distorsion_list (header)
	local distorsion = header.add{
		type = "flow",
		name = "distorsion",
		direction = "vertical"
	}
	distorsion.visible = false
	distorsion.style.horizontal_align = "center"
	local title = distorsion.add{
		type = "label",
		name = "title",
		caption = "Distorsion"
	}
	title.style.font = "heading-1"
	title.style.font_color = const.first_distorsion_color
	local list = distorsion.add{
		type = "flow",
		name = "list",
		direction = "vertical"
	}
	list.style.horizontal_align = "center"
end


local function update_header_location (header)
	local player = header.gui.player
	local shadow = get_shadow(player)
	if header == shadow then return end
	shadow.force_auto_center()
	header.location = {
		shadow.location.x,
		-- player.display_resolution.width / 2,
		const.header_margin_top
	}
end


local function create_game_type (header)
	local game_type = header.add{
		type = "label",
		name = "game_type",
	}
	game_type.style.font = "heading-1"
	if bb.get_tournament() then
		game_type.caption = "Tournament match"
		game_type.style.font_color = const.tournament_color
	else
		game_type.caption = "Public match"
		game_type.style.font_color = const.public_color
	end
end


local function create_header (player)
	local header = player.gui.screen.add{
		type = "flow",
		name = "bb_header",
		direction = "vertical"
	}

	local shadow = player.gui.screen.add{
		type = "frame",
		name = "bb_shadow_header",
		direction = "vertical"
	}
	shadow.visible = false
	shadow.auto_center = true

	header.style.horizontal_align = "center"
	shadow.style.horizontal_align = "center"

	update_header_location(header)
	update_header_location(shadow)

	create_game_type(header)
	create_game_type(shadow)
	create_timer(header)
	create_timer(shadow)
	create_distorsion_list(header)
	create_distorsion_list(shadow)
end


local function on_player_joined_game (event)
	local player = game.players[event.player_index]
	if player.online_time == 0 then
		create_header(player)
		if bb.get_state() ~= bb.states.WAITING then
			local header = get_header(player)
			local shadow = get_shadow(player)
			header.distorsion.visible = true
			shadow.distorsion.visible = true
		end
	end
end


local function on_tick ()
	for pid, player in pairs(game.players) do
		local header = get_header(player)
		local shadow = get_shadow(player)
		update_timer(header)
		update_timer(shadow)
		update_header_location(header)
		update_header_location(shadow)
		update_distorsion_list(header)
		update_distorsion_list(shadow)
	end
end

local function on_player_display_resolution_changed (event)
	local player = game.players[event.player_index]
	local header = get_header(player)
	local shadow = get_shadow(player)
	update_header_location(header)
	update_header_location(shadow)
end

local function on_game_started ()
	for pid, player in pairs(game.players) do
		local header = get_header(player)
		local shadow = get_shadow(player)
		header.distorsion.visible = true
		shadow.distorsion.visible = true
	end
end

Event.add(defines.events.on_player_display_resolution_changed, on_player_display_resolution_changed)
Event.add(defines.events.on_player_joined_game, on_player_joined_game)
Event.add(defines.events.on_tick, on_tick)
Event.add(bb.events.on_game_started, on_game_started)
