--[[--------------------------------------------------------------------
	Any Favorite Mount
	Lets you set any mount as a favorite, even if the default UI doesn't approve.
	Copyright (c) 2014 Phanx. All rights reserved.
	See the accompanying README and LICENSE files for more information.
	http://www.wowinterface.com/downloads/info23261-AnyFavoriteMount.html
	http://www.curse.com/addons/wow/anyfavoritemount
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

local randoms = {}

function C_MountJournal.Summon(index)
	if index == 0 and not IsMounted() and next(isFake) then
		wipe(randoms)
		for index = 1, GetNumMounts() do
			local _, _, _, _, isUsable, _, isFavorite = C_MountJournal.GetMountInfo(index)
			if isUsable and isFavorite then
				tinsert(randoms, index)
			end
		end
		index = randoms[random(#randoms)]
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