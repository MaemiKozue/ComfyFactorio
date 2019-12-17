local prefix = "maps.biter_battles_distorted.distorsions"
local list = {
	"default",
	"boosted_red",
	"reversed_effect",
	"nerfed_military",
	"boosted_blue",
}

local distorsions = {}
local size = 0
for _, name in pairs(list) do
	size = size + 1
	local path = prefix .. "." .. name
	distorsions[size] = {
		name = name,
		distorsion = require(path)
	}
end

return distorsions
