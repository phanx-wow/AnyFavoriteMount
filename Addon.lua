--[[--------------------------------------------------------------------
	Any Favorite Mount
	Set any mount as a favorite, even if the default UI doesn't approve.
	Copyright (c) 2014-2015 Phanx <addons@phanx.net>. All rights reserved.
	https://github.com/Phanx/AnyFavoriteMount
	http://www.curse.com/addons/wow/anyfavoritemount
	http://www.wowinterface.com/downloads/info23261-AnyFavoriteMount.html
----------------------------------------------------------------------]]

local _, ns = ...
local isFake, playerFaction = {}

local MACRO_NAME, MACRO_BODY = "Mount", "# Macro created by Any Favorite Mount\n/run C_MountJournal.Summon(0)"

local GetNumMounts  = C_MountJournal.GetNumMounts  -- simple upvalue for speed
local GetIsFavorite = C_MountJournal.GetIsFavorite -- replaced
local SetIsFavorite = C_MountJournal.SetIsFavorite -- replaced
local GetMountInfo  = C_MountJournal.GetMountInfo  -- replaced
local Summon        = C_MountJournal.Summon        -- replaced

AFM_Favorites = {}

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

local GROUND, FLYING, SWIMMING = 1, 2, 3

local mountTypeInfo = {
	[230] = {100,99,0},  -- * ground -- 99 flying to use in flying areas if the player doesn't have any flying mounts as favorites
	[231] = {0,0,300},  -- Riding Turtle / Sea Turtle
	[232] = {0,0,450},  -- Abyssal Seahorse, usable only in Vashj'ir
	[241] = {101,0,0},  -- Qiraji Battle Tanks, usable only in AQ40
	[247] = {99,310,0}, -- Red Flying Cloud
	[248] = {99,310,0}, -- * flying
	[254] = {0,0,300},  -- Subdued Seahorse
	[269] = {100,0,0},  -- Azure/Crimson Water Strider
	[284] = {70,10,67}, -- Heirloom Hoarder Mount
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
	[98727]  = true, -- Winged Guardian - despite having wings it's OK!
}

local randoms = {}

local function FillMountList(targetType)
	--print("Looking for:", targetType == SWIMMING and "SWIMMING" or targetType == FLYING and "FLYING" or "GROUND")
	wipe(randoms)
	local bestSpeed = 0
	for i = 1, GetNumMounts() do
		local name, spellID, _, _, isUsable, _, isFavorite = C_MountJournal.GetMountInfo(i)
		if isUsable and isFavorite then
			local _, _, _, _, mountType = C_MountJournal.GetMountInfoExtra(i)
			local speed = mountTypeInfo[mountType][targetType]
			if speed == 99 and flexMounts[spellID] then
				speed = 100
			end
			--print("Checking:", name, mountType, "@", speed, "VS", bestSpeed)
			if speed > 0 and speed >= bestSpeed then
				if speed > bestSpeed then
					bestSpeed = speed
					wipe(randoms)
				end
				tinsert(randoms, i)
			end
		end
	end
	return randoms
end

function C_MountJournal.Summon(index)
	if index == 0 and not IsMounted() then
		local targetType = IsSubmerged() and SWIMMING or ns.CanFly() and FLYING or GROUND
		FillMountList(targetType)
		local numRandoms = #randoms
		if numRandoms == 0 and targetType == SWIMMING then
			-- Fall back to non-swimming mounts
			targetType = ns.CanFly() and FLYING or GROUND
			FillMountList(targetType)
			numRandoms = #randoms
		end
		if numRandoms > 0 then
			index = randoms[random(numRandoms)]
		end
	end
	if index > 0 then
		Summon(index)
	end
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

	local function getMacroIndex()
		local macroIndex = GetMacroIndexByName(MACRO_NAME)
		if macroIndex == 0 and not InCombatLockdown() then
			return CreateMacro(MACRO_NAME, "ACHIEVEMENT_GUILDPERK_MOUNTUP", MACRO_BODY)
		end
		return macroIndex
	end

	local CMJ_Pickup = C_MountJournal.Pickup
	function C_MountJournal.Pickup(mountIndex)
		if mountIndex == 0 then
			return PickupMacro(getMacroIndex())
		end
		return CMJ_Pickup(mountIndex)
	end

	hooksecurefunc(GameTooltip, "SetAction", function(self, i)
		local actionType, actionID = GetActionInfo(i)
		if actionType == "macro" then
			local macroName, _, macroBody = GetMacroInfo(actionID)
			if macroName == MACRO_NAME and strtrim(macroBody) == MACRO_BODY then
				self:SetMountBySpellID(150544)
			end
		end
	end)

	for i = 1, 120 do
		local actionType, actionID = GetActionInfo(i)
		if actionType == "summonmount" and not C_MountJournal.GetMountInfo(actionID) then
			PickupMacro(getMacroIndex())
			PlaceAction(i)
			ClearCursor()
		end
	end
end)
