local Global = require "utils.global"

local Module = {}

-- Team structure
-- team = {
-- 	id : int, the identifier of the team
-- 	name : string, the name of the team
-- 	players : map pid <> true, the list of players in the team
-- }


local this = {
	-- map player_id <> team_id
	players = {},
	-- map team_id <> team
	teams = {},
	uniqid = nil,
}

Global.register(this, function (t) this = t end)


local function uniqid ()
	this.uniqid = this.uniqid or 0
	this.uniqid = this.uniqid + 1
	return this.uniqid
end


local error = function (msg)
	error("module team: " .. msg)
end


local function is_player (player)
	return (type(player) == "number" and game.players[player])
		or (type(player) == "table" and player.index)
end


local function pid_of (player)
	if not is_player(player) then
		error("Player must be an index or a LuaPlayer")
		-- return nil
	elseif type(player) == "number" then
		return player
	else
		return player.index
	end
end


local function player_object_of (player)
	if not is_player(player) then
		error("Player must be an index or a LuaPlayer")
		-- return nil
	elseif type(player) == "number" then
		return game.players[player]
	else
		return player
	end
end


function Module.is_team (team)
	return type(team) == "table"
		and type(team.id) == "number"
		and type(team.players) == "table"
end


function Module.team_of (player)
	if not is_player(player) then
		error("Player must be an index or a LuaPlayer")
	end
	return this.players[pid_of(player)]
end


function Module.in_team (team, player)
	return this.players[pid_of(player)].id == team.id
end


function Module.connected_players (team)
	if not Module.is_team(team) then
		error("First argument must be a team")
	end
	local list = {}
	for pid, _ in pairs(team.players) do
		local player = game.players[pid]
		if player.connected then
			list[pid] = player
		end
	end
	return list
end


function Module.create_team (name)
	if type(name) ~= "string" then
		error("Team name must be a string")
	end
	local team = {
		id = uniqid(),
		name = name,
		players = {}
	}
	this.teams[team.id] = team
	return team
end


function Module.set_team_name (team, name)
	if not Module.is_team(team) then
		error("First argument must be a team")
	end
	if type(name) ~= "string" then
		error("Team name must be a string")
	end
	team.name = name
end


function Module.add_player (team, player)
	if not Module.is_team(team) then
		error("First argument must be a team")
	end
	if not is_player(player) then
		error("Player must be an index or a LuaPlayer")
	end

	local pid = pid_of(player)
	local p_team = Module.team_of(pid)

	-- If the player already has a team, removes from the old team
	if p_team then
		-- Player already in the right team
		if p_team.id == team.id then
			return true
		else
			p_team.players[pid] = nil
		end
	end

	team.players[pid] = true
	this.players[pid] = team

	return true
end


function Module.remove_player (team, player)
	if not Module.is_team(team) then
		error("First argument must be a team")
	end
	if not is_player(player) then
		error("Player must be an index or a LuaPlayer")
	end

	local pid = pid_of(player)
	if Module.in_team (team, pid) then
		team.players[pid] = nil
		this.players[pid] = nil
	else
		return false
	end
end

return Module
