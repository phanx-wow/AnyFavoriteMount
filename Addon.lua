--[[--------------------------------------------------------------------
	Any Favorite Mount
	Set any mount as a favorite, even if the default UI doesn't approve.
	Copyright (c) 2014-2016 Phanx <addons@phanx.net>. All rights reserved.
	https://github.com/Phanx/AnyFavoriteMount
	http://www.curse.com/addons/wow/anyfavoritemount
	http://www.wowinterface.com/downloads/info23261-AnyFavoriteMount.html
----------------------------------------------------------------------]]

local _, ns = ...

AFM_Favorites = {}
local isFake = AFM_Favorites

local MACRO_NAME, MACRO_BODY = "Mount", "# Macro created by Any Favorite Mount\n/click MountJournalSummonRandomFavoriteButton"

-- Upvalues for speed
local GetMountIDs = C_MountJournal.GetMountIDs
local GetMountInfoExtraByID = C_MountJournal.GetMountInfoExtraByID
local GetNumDisplayedMounts = C_MountJournal.GetNumDisplayedMounts

-- Replaced functions
local GetDisplayedMountInfo = C_MountJournal.GetDisplayedMountInfo
local GetMountInfoByID = C_MountJournal.GetMountInfoByID
local GetIsFavorite = C_MountJournal.GetIsFavorite
local SetIsFavorite = C_MountJournal.SetIsFavorite
local SummonByID = C_MountJournal.SummonByID

------------------------------------------------------------------------

function C_MountJournal.GetIsFavorite(index)
	local creatureName, spellID, icon, active, isUsable, sourceType, isFavorite, isFactionSpecific, faction, isFiltered, isCollected, mountID = GetDisplayedMountInfo(index)
	--print("GetIsFavorite", creatureName, index, isFavorite or isFake[spellID])
	return isFavorite or isFake[spellID], true
end

function C_MountJournal.SetIsFavorite(index, value)
	local isFavorite, canFavorite = GetIsFavorite(index)
	if canFavorite then
		--print("SetIsFavorite", "(default)", index, value)
		return SetIsFavorite(index, value)
	end
	local creatureName, spellID, icon, active, isUsable, sourceType, isFavorite, isFactionSpecific, faction, isFiltered, isCollected, mountID = GetDisplayedMountInfo(index)
	--print("SetIsFavorite", creatureName, index, value)
	isFake[spellID] = value or nil
end

function C_MountJournal.GetDisplayedMountInfo(index)
	local creatureName, spellID, icon, active, isUsable, sourceType, isFavorite, isFactionSpecific, faction, isFiltered, isCollected, mountID = GetDisplayedMountInfo(index)
	--print("GetDisplayedMountInfo", creatureName, isFavorite or isFake[spellID])
	return creatureName, spellID, icon, active, isUsable, sourceType, isFavorite or isFake[spellID], isFactionSpecific, faction, isFiltered, isCollected, mountID
end

function C_MountJournal.GetMountInfoByID(id)
	local creatureName, spellID, icon, active, isUsable, sourceType, isFavorite, isFactionSpecific, faction, isFiltered, isCollected, mountID = GetMountInfoByID(id)
	--print("GetMountInfoByID", creatureName, isFavorite or isFake[spellID])
	return creatureName, spellID, icon, active, isUsable, sourceType, isFavorite or isFake[spellID], isFactionSpecific, faction, isFiltered, isCollected, mountID
end

------------------------------------------------------------------------

local GROUND, FLYING, SWIMMING = 1, 2, 3

local mountTypeInfo = {
	[230] = {100,99,0}, -- * ground -- 99 flying to use in flying areas if the player doesn't have any flying mounts as favorites
	[231] = {0,0,60},   -- Riding Turtle / Sea Turtle
	[232] = {0,0,450},  -- Abyssal Seahorse -- only in Vashj'ir
	[241] = {101,0,0},  -- Qiraji Battle Tanks -- only in Temple of Ahn'Qiraj
	[247] = {99,310,0}, -- Red Flying Cloud
	[248] = {99,310,0}, -- * flying -- 99 ground to deprioritize in non-flying zones if any non-flying mounts are favorites
	[254] = {0,0,60},   -- Subdued Seahorse -- +300% swim speed in Vashj'ir, +60% swim speed elsewhere
	[269] = {100,0,0},  -- Azure/Crimson Water Strider
	[284] = {60,0,0},   -- Chauffeured Chopper
}

local flexMounts = { -- flying mounts that look OK on the ground
	[376] = true, -- Celestial Steed
	[532] = true, -- Ghastly Charger
	[594] = true, -- Grinning Reaver
	[219] = true, -- Headless Horseman's Mount
	[547] = true, -- Hearthsteed
	[468] = true, -- Imperial Quilen
	[363] = true, -- Invincible
	[457] = true, -- Jade Panther
	[451] = true, -- Jeweled Onyx Panther
	[455] = true, -- Obsidian Panther
	[458] = true, -- Ruby Panther
	[456] = true, -- Sapphire Panther
	[522] = true, -- Sky Golem
	[459] = true, -- Sunstone Panther
	[523] = true, -- Swift Windsteed
	[439] = true, -- Tyrael's Charger
	[593] = true, -- Warforged Nightmare
	[421] = true, -- Winged Guardian
}

local zoneMounts = { -- zone-specific mounts that don't need to be favorites
	[312] = true, -- Sea Turtle
	[420] = true, -- Subdued Seahorse
	[373] = true, -- Vashj'ir Seahorse
	[117] = true, -- Blue Qiraji Battle Tank
	[120] = true, -- Green Qiraji Battle Tank
	[118] = true, -- Red Qiraji Battle Tank
	[119] = true, -- Yellow Qiraji Battle Tank
}

local isVashjir = {
	[614] = true, -- Abyssal Depths
	[610] = true, -- Kelp'thar Forest
	[615] = true, -- Shimmering Expanse
	[613] = true, -- Vashj'ir
}

local randoms = {}

local function FillMountList(targetType)
	--print("Looking for:", targetType == SWIMMING and "SWIMMING" or targetType == FLYING and "FLYING" or "GROUND")
	wipe(randoms)

	local bestSpeed = 0
	local mounts = GetMountIDs() -- TODO: find out if this can change during gameplay; if not, just call it once at runtime
	for i = 1, #mounts do
		local creatureName, spellID, icon, active, isUsable, sourceType, isFavorite, isFactionSpecific, faction, isFiltered, isCollected, mountID = GetMountInfoByID(mounts[i])
		if isUsable and (isFavorite or isFake[spellID] or zoneMounts[mountID]) then
			local creatureDisplayID, descriptionText, sourceText, isSelfMount, mountType = GetMountInfoExtraByID(mounts[i])
			local speed = mountTypeInfo[mountType][targetType]
			if speed == 99 and flexMounts[mountID] then -- some ground mounts
				speed = 100
			elseif mountType == 254 and isVashjir[GetCurrentMapAreaID()] then -- Subdued Seahorse is faster in Vashj'ir
				speed = 300
			end
			--print("Checking:", creatureName, mountType, "@", speed, "VS", bestSpeed)
			if speed > 0 and speed >= bestSpeed then
				if speed > bestSpeed then
					bestSpeed = speed
					wipe(randoms)
				end
				tinsert(randoms, mountID)
			end
		end
	end
	--print("Found", #randoms, "possibilities")
	return randoms
end

function C_MountJournal.SummonByID(id)
	if id == 0 and not IsMounted() then
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
			id = randoms[random(numRandoms)]
		end
	end
	if id > 0 then
		SummonByID(id)
	end
end

------------------------------------------------------------------------

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(self, event, arg)
	if event == "ADDON_LOADED" then
		if arg == "AnyFavoriteMount" then
			self:UnregisterEvent(event)
			isFake = AFM_Favorites
		end
	return end

	if not MountJournalSummonRandomFavoriteButton then
		CollectionsJournal_LoadUI()
	end

	local function getMacroIndex()
		local index = GetMacroIndexByName(MACRO_NAME)
		if index == 0 and not InCombatLockdown() then
			return CreateMacro(MACRO_NAME, "ACHIEVEMENT_GUILDPERK_MOUNTUP", MACRO_BODY)
		end
		return index
	end

	local macroIndex = getMacroIndex()
	if macroIndex then
		local name, icon, body = GetMacroInfo(macroIndex)
		if not body:find("MountJournalSummonRandomFavoriteButton") then
			EditMacro(macro, MACRO_NAME, "ACHIEVEMENT_GUILDPERK_MOUNTUP", MACRO_BODY)
		end
	end

	local CMJ_Pickup = C_MountJournal.Pickup
	function C_MountJournal.Pickup(index)
		if i == 0 then
			return PickupMacro(getMacroIndex())
		end
		return CMJ_Pickup(index)
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
		if actionType == "summonmount" and not GetMountInfoByID(actionID) then
			PickupMacro(getMacroIndex())
			PlaceAction(i)
			ClearCursor()
		end
	end
end)
