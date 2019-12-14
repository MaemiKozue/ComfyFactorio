local Global = require "utils.global"

local this = {}

Global.register(this, function (t) this = t end)

local modules = {
	"game",
	"teams",
	"science",
	"units",
	"distorsions",
	"inactivity"
}

for _, m in pairs(modules) do
	require("maps.biter_battles_distorted."..m)
end
