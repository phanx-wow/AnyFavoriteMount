--[[--------------------------------------------------------------------
	Any Favorite Mount
	Set any mount as a favorite, even if the default UI doesn't approve.
	Copyright (c) 2014-2016 Phanx <addons@phanx.net>. All rights reserved.
	https://github.com/Phanx/AnyFavoriteMount
	http://www.curse.com/addons/wow/anyfavoritemount
	http://www.wowinterface.com/downloads/info23261-AnyFavoriteMount.html
----------------------------------------------------------------------]]

local _, ns = ...

AFM_FavoriteIDs = {}
local isFake = AFM_FavoriteIDs

local MACRO_NAME, MACRO_BODY = "Mount", "# Macro created by Any Favorite Mount\n/click MountJournalSummonRandomFavoriteButton"

-- Replaced functions that take a display index
local GetNumDisplayedMounts = C_MountJournal.GetNumDisplayedMounts
local GetDisplayedMountInfo = C_MountJournal.GetDisplayedMountInfo
local GetDisplayedMountInfoExtra = C_MountJournal.GetDisplayedMountInfoExtra
local GetIsFavorite = C_MountJournal.GetIsFavorite
local SetIsFavorite = C_MountJournal.SetIsFavorite

-- Replaced functions that take a mountID
local GetMountInfoByID = C_MountJournal.GetMountInfoByID
local SummonByID = C_MountJournal.SummonByID

------------------------------------------------------------------------

local GetRealIndex, GetRealMountID, UpdateDisplayedMountList
do
	local indexFromName = {}
	local mountIDFromName = {}

	local displayedMounts = {}
	local sortOrder = {}
	local FAVORITE_USABLE, FAVORITE, COLLECTED_USABLE, COLLECTED, NONE = 1, 2, 3, 4, 5

	function GetRealIndex(index)
		return indexFromName[displayedMounts[index]]
	end

	function GetRealMountID(index)
		return mountIDFromName[displayedMounts[index]]
	end

	local function SortDisplayedMounts(a, b)
		local aOrder = sortOrder[a]
		local bOrder = sortOrder[b]
		if aOrder == bOrder then
			return a < b
		else
			return aOrder < bOrder
		end
	end

	function UpdateDisplayedMountList()
		wipe(displayedMounts)

		for i = 1, GetNumDisplayedMounts() do
			local creatureName, spellID, icon, active, isUsable, sourceType, isFavorite, isFactionSpecific, faction, isFiltered, isCollected, mountID = GetDisplayedMountInfo(i)
			tinsert(displayedMounts, creatureName)

			indexFromName[creatureName] = i
			mountIDFromName[creatureName] = mountID

			isFavorite = isFavorite or isFake[mountID]

			sortOrder[creatureName] = (isFavorite and isUsable) and FAVORITE_USABLE
				or isFavorite and FAVORITE
				--or (isCollected and isUsable) and COLLECTED_USABLE
				or isCollected and COLLECTED
				or NONE
		end

		sort(displayedMounts, SortDisplayedMounts)
		return #displayedMounts
	end
end

------------------------------------------------------------------------

function C_MountJournal.GetNumDisplayedMounts()
	local num = UpdateDisplayedMountList()
	--print("GetNumDisplayedMounts", num)
	return num
end

function C_MountJournal.GetDisplayedMountInfo(index)
	local realMountID = GetRealMountID(index)
	local creatureName, spellID, icon, active, isUsable, sourceType, isFavorite, isFactionSpecific, faction, isFiltered, isCollected, mountID = C_MountJournal.GetMountInfoByID(realMountID)
	--print("GetDisplayedMountInfo", creatureName, isFavorite or isFake[mountID])
	return creatureName, spellID, icon, active, isUsable, sourceType, isFavorite or isFake[mountID], isFactionSpecific, faction, isFiltered, isCollected, mountID
end

function C_MountJournal.GetDisplayedMountInfoExtra(index)
	local realMountID = GetRealMountID(index)
	return C_MountJournal.GetMountInfoExtraByID(realMountID)
end

function C_MountJournal.GetMountInfoByID(id)
	local creatureName, spellID, icon, active, isUsable, sourceType, isFavorite, isFactionSpecific, faction, isFiltered, isCollected, mountID = GetMountInfoByID(id)
	--print("GetMountInfoByID", creatureName, isFavorite or isFake[mountID])
	return creatureName, spellID, icon, active, isUsable, sourceType, isFavorite or isFake[mountID], isFactionSpecific, faction, isFiltered, isCollected, mountID
end

function C_MountJournal.GetIsFavorite(index)
	local realMountID = GetRealMountID(index)
	local creatureName, spellID, icon, active, isUsable, sourceType, isFavorite, isFactionSpecific, faction, isFiltered, isCollected, mountID = GetMountInfoByID(realMountID)
	--print("GetIsFavorite", GetMountInfoByID(realMountID), isFavorite, isFake[mountID])
	return isFavorite or isFake[mountID], true
end

function C_MountJournal.SetIsFavorite(index, value)
	local realIndex = GetRealIndex(index)
	local realMountID = GetRealMountID(index)
	local isFavorite, canFavorite = GetIsFavorite(realIndex)
	if canFavorite then
		--print("SetIsFavorite", "(real)", GetMountInfoByID(realMountID), value)
		SetIsFavorite(realIndex, value)
	else
		--print("SetIsFavorite", "(fake)", GetMountInfoByID(realMountID), value)
		isFake[realMountID] = value or nil
		if MountJournal and MountJournal:IsVisible() then
			MountJournal_UpdateMountList()
		end
	end
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
	[269] = {100,0,0},  -- Water Striders
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
	local mounts = C_MountJournal.GetMountIDs() -- TODO: find out if this can change during gameplay; if not, just call it once at runtime
	for i = 1, #mounts do
		local creatureName, spellID, icon, active, isUsable, sourceType, isFavorite, isFactionSpecific, faction, isFiltered, isCollected, mountID = GetMountInfoByID(mounts[i])
		if isUsable and (isFavorite or isFake[mountID] or zoneMounts[mountID]) then
			local creatureDisplayID, descriptionText, sourceText, isSelfMount, mountType = C_MountJournal.GetMountInfoExtraByID(mounts[i])
			local speed = mountTypeInfo[mountType][targetType]
			if speed == 99 and flexMounts[mountID] then -- some ground mounts
				speed = 100
			elseif mountType == 254 and isVashjir[GetCurrentMapAreaID()] then -- Subdued Seahorse is faster in Vashj'ir
				speed = 300
			elseif mountType == 264 then -- Water Strider, prioritize in water, deprioritize on land
				speed = IsSwimming() and 101 or 99
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
			isFake = AFM_FavoriteIDs
			-- Upgrade from old spellID-based list to new mountID-based list
			if AFM_Favorites then
				local mountIDs = C_MountJournal.GetMountIDs()
				for _, mountID in pairs(mountIDs) do
					local creatureName, spellID = GetMountInfoByID(mountID)
					if AFM_Favorites[spellID] then
						isFake[mountID] = true
					end
				end
			end
		end
	return end

	if event == "PLAYER_LOGIN" then
		if not MountJournalSummonRandomFavoriteButton then
			CollectionsJournal_LoadUI()
		end

		function self:GetMacroIndex(create)
			local macro = GetMacroIndexByName(MACRO_NAME)
			if macro == 0 and create and not InCombatLockdown() then
				macro = CreateMacro(MACRO_NAME, "ACHIEVEMENT_GUILDPERK_MOUNTUP", MACRO_BODY)
			end
			return macro or 0
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

		local PickupMount = C_MountJournal.Pickup
		function C_MountJournal.Pickup(i)
			if i == 0 then
				return PickupMacro(self:GetMacroIndex(true))
			end
			return PickupMount(i)
		end
	end

	if InCombatLockdown() then
		return self:RegisterEvent("PLAYER_REGEN_ENABLED")
	end

	self:UnregisterEvent("PLAYER_REGEN_ENABLED")

	local macro = self:GetMacroIndex()
	if macro > 0 then
		local name, icon, body = GetMacroInfo(macro)
		if not body:find("MountJournalSummonRandomFavoriteButton") then
			EditMacro(macro, MACRO_NAME, "ACHIEVEMENT_GUILDPERK_MOUNTUP", MACRO_BODY)
		end
	end

	for action = 1, 120 do
		local actionType, actionID = GetActionInfo(action)
		if actionType == "summonmount" and not GetMountInfoByID(actionID) then
			local macro = self:GetMacroIndex(true)
			if macro > 0 then
				PickupMacro(macro)
				PlaceAction(action)
				ClearCursor()
			end
		end
	end
end)
