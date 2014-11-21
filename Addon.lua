--[[--------------------------------------------------------------------
	Any Favorite Mount
	Set any mount as a favorite, even if the default UI doesn't approve.
	Copyright (c) 2014 Phanx <addons@phanx.net>. All rights reserved.
	https://github.com/Phanx/AnyFavoriteMount
	http://www.curse.com/addons/wow/anyfavoritemount
	http://www.wowinterface.com/downloads/info23261-AnyFavoriteMount.html
----------------------------------------------------------------------]]

AFM_Favorites = {}

local isFake, playerFaction = {}

local GetIsFavorite = C_MountJournal.GetIsFavorite -- replaced
local SetIsFavorite = C_MountJournal.SetIsFavorite -- replaced
local GetMountInfo  = C_MountJournal.GetMountInfo  -- replaced
local GetNumMounts  = C_MountJournal.GetNumMounts  -- simple upvalue for speed
local Summon        = C_MountJournal.Summon        -- replaced

------------------------------------------------------------------------

function C_MountJournal.GetIsFavorite(index)
	local isFavorite, canFavorite = GetIsFavorite(index)
	if not canFavorite then
		--print("GetIsFavorite", (GetMountInfo(index)), index, isFake[index])
		return not not isFake[index], true
	end
	return isFavorite, true
end

function C_MountJournal.SetIsFavorite(index, value)
	local isFavorite, canFavorite = GetIsFavorite(index)
	if not canFavorite then
		local name, spellID = GetMountInfo(index)
		--print("SetIsFavorite", name, index, value)
		AFM_Favorites[spellID] = value or nil
		isFake[index] = value or nil -- remove instead of setting to false
	else
		SetIsFavorite(index, value)
	end
end

function C_MountJournal.GetMountInfo(index)
	local creatureName, spellID, icon, active, isUsable, sourceType, isFavorite, isFactionSpecific, faction, hideOnChar, isCollected = GetMountInfo(index)
	local isFavorite, canFavorite = GetIsFavorite(index)
	if not canFavorite then
		--print("GetMountInfo", creatureName, "favorite?", isFake[index])
		isFavorite = not not isFake[index]
	end
	if (isFactionSpecific and faction ~= playerFaction) then
		--print("GetMountInfo", creatureName, "wrong faction")
		hideOnChar = true
	end
	return creatureName, spellID, icon, active, isUsable, sourceType, isFavorite, isFactionSpecific, faction, hideOnChar, isCollected
end

------------------------------------------------------------------------

local mountTypeInfo = {
	[230] = {100,99,0},  -- * ground -- 99 flying to use in flying areas if the player doesn't have any flying mounts as favorites
	[231] = {0,0,300},  -- Riding Turtle / Sea Turtle
	[232] = {0,0,450},  -- Abyssal Seahorse, usable only in Vashj'ir
	[241] = {101,0,0},  -- Qiraji Battle Tanks, usable only in AQ40
	[247] = {99,310,0}, -- Red Flying Cloud
	[248] = {99,310,0}, -- * flying
	[254] = {0,0,300},  -- Subdued Seahorse
	[269] = {100,0,0},  -- Azure/Crimson Water Strider
}

local flexMounts = { -- flying mounts that look OK on the ground
	[75614]  = true, -- Celestial Steed
	[136505] = true, -- Ghastly Charger
	[163025] = true, -- Grinning Reaver
	[48025]  = true, -- Headless Horseman's Mount
	[142073] = true, -- Hearthsteed
	[124659] = true, -- Imperial Quilen
	[72286]  = true, -- Invincible
	[121837] = true, -- Jade Panther
	[120043] = true, -- Jeweled Onyx Panther
	[121820] = true, -- Obsidian Panther
	[121838] = true, -- Ruby Panther
	[121836] = true, -- Sapphire Panther
	[134359] = true, -- Sky Golem
	[121839] = true, -- Sunstone Panther
	[134573] = true, -- Swift Windsteed
	[107203] = true, -- Tyrael's Charger
	[163024] = true, -- Warforged Nightmare
}

local flyingSpell = {
	[0]   = 90267,  -- Eastern Kingdoms = Flight Master's License
	[1]   = 90267,  -- Kalimdor = Flight Master's License
	[646] = 90267,  -- Deepholm = Flight Master's License
	[571] = 54197,  -- Northrend = Cold Weather Flying
	[870] = 115913, -- Pandaria = Wisdom of the Four Winds
	[1116] = -1, -- Draenor
	[1265] = -1, -- Tanaan Jungle Intro
	[1153] = -1, -- FW Horde Garrison Level 3
	[1158] = -1, -- SMV Alliance Garrison Level 1
	[1159] = -1, -- SMV Alliance Garrison Level 3
}

local function CanFly() -- because IsFlyableArea is a fucking liar
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

local randoms = {}

function C_MountJournal.Summon(index)
	if index == 0 and not IsMounted() then
		local bestSpeed = 0
		local targetType = IsSubmerged() and 3 or CanFly() and 2 or 1
		--print("Looking for:", IsSubmerged() and "SWIMMING" or CanFly() and "FLYING" or "GROUND")
		for i = 1, GetNumMounts() do
			local name, spellID, _, _, isUsable, _, isFavorite = C_MountJournal.GetMountInfo(i)
			if isUsable and isFavorite then
				local _, _, _, _, mountType = C_MountJournal.GetMountInfoExtra(i)
				local speed = mountTypeInfo[mountType][targetType]
				if speed == 99 and flexMounts[spellID] then
					speed = 100
				end
				--print("Checking:", name, "@", speed, "VS", bestSpeed)
				if speed > bestSpeed then
					bestSpeed = speed
					wipe(randoms)
					tinsert(randoms, i)
				elseif speed == bestSpeed then
					tinsert(randoms, i)
				end
			end
		end
		if bestSpeed > 0 then
			index = randoms[random(#randoms)]
		end
	end
	Summon(index)
end

------------------------------------------------------------------------

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(f, event)
	playerFaction = UnitFactionGroup("player")
	playerFaction = playerFaction == "Horde" and 0 or playerFaction == "Alliance" and 1 or nil

	for index = 1, GetNumMounts() do
		local name, spellID, _, _, _, _, isFavorite, isFactionSpecific, faction, isHidden, isCollected = GetMountInfo(index)
		if isCollected and (not isFactionSpecific or faction == playerFaction) and AFM_Favorites[spellID] then
			--print("Restoring favorite:", name, spellID, "=>", index)
			isFake[index] = true
		end
	end
end)