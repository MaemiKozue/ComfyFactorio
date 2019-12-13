local prefix = "maps.biter_battles_distorted.distorsions"
local list = {
	"default",
	"boosted_red",
	"reversed_effect",
	"nerfed_military",
	"boosted_blue",
}

local distorsions = {}

for _, name in pairs(list) do
	local path = prefix .. "." .. name
	distorsions[#distorsions+1] = {
		name = name,
		distorsion = require(path)
	}
end

return distorsions
