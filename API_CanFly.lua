-- This file provides a single function addons can call to determine whether
-- flying mounts can really be used in the player's current location. The API
-- function IsFlyableArea is unusable for this purpose, as it not only reports
-- the area is flyable if there are *any* circumstances under which the zone
-- becomes flyable (eg. by reaching a higher level and buying an ability) but
-- it also reports Draenor is flyable when there is not currently any way for
-- players to gain the ability to fly there.
-- Written by Phanx <addons@phanx.net> and released into the public domain.
-- Feel free to use this file in your own addons!

local _, ns = ...
-- TODO: Find out when Wintergrasp isn't flyable? Or too old to bother with?

local flyingSpell = {
	[0]   = 90267,  -- Eastern Kingdoms = Flight Master's License
	[1]   = 90267,  -- Kalimdor = Flight Master's License
	[646] = 90267,  -- Deepholm = Flight Master's License
	[571] = 54197,  -- Northrend = Cold Weather Flying
	[870] = 115913, -- Pandaria = Wisdom of the Four Winds
	[1116] = -1, -- Draenor
	[1191] = -1, -- Ashran - World PvP
	[1265] = -1, -- Tanaan Jungle Intro
	[1152] = -1, -- FW Horde Garrison Level 1
	[1330] = -1, -- FW Horde Garrison Level 2
	[1153] = -1, -- FW Horde Garrison Level 3
	[1154] = -1, -- FW Horde Garrison Level 4
	[1158] = -1, -- SMV Alliance Garrison Level 1
	[1331] = -1, -- SMV Alliance Garrison Level 2
	[1159] = -1, -- SMV Alliance Garrison Level 3
	[1160] = -1, -- SMV Alliance Garrison Level 4
}

local GetInstanceInfo, IsFlyableArea, IsSpellKnown = GetInstanceInfo, IsFlyableArea, IsSpellKnown

function ns.CanFly()
	if IsFlyableArea() then
		local _, _, _, _, _, _, _, instanceMapID = GetInstanceInfo()
		local reqSpell = flyingSpell[instanceMapID]
		if reqSpell then
			return reqSpell > 0 and IsSpellKnown(reqSpell)
		else
			return IsSpellKnown(34090) or IsSpellKnown(34091) or IsSpellKnown(90265)
		end
	end
end
