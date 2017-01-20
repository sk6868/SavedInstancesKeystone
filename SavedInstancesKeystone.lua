local addonName, vars = ...
SavedInstancesKeystone = vars
local addon = vars

LibStub("AceHook-3.0"):Embed(vars)

local QTip = LibStub("LibQTip-1.0")
local maxdiff = 23 -- max number of instance difficulties
local maxcol = 4 -- max columns per player+instance
local FONTEND = FONT_COLOR_CODE_CLOSE
local YELLOWFONT = LIGHTYELLOW_FONT_COLOR_CODE
local SI -- SavedInstances.core
local thisToon = UnitName("player") .. " - " .. GetRealmName()
local KeystoneId = 138019

-- sorted traversal function for character table
local cpairs
do
	local cnext_list = {}
	local cnext_pos
	local cnext_ekey
	local function cnext(t,i)
		local e = cnext_list[cnext_pos]
		if not e then
			return nil
		else
			cnext_pos = cnext_pos + 1
			local n = e[cnext_ekey]
			return n, t[n]
		end
	end

	local function cpairs_sort(a,b)
		-- generic multi-key sort
		for k,av in ipairs(a) do
			local bv = b[k]
			if av ~= bv then
				return av < bv
			end
		end
		return false -- required for sort stability when a==a
	end

	cpairs = function(t, usecache)
		local settings = SavedInstances.db.Tooltip
		local realmgroup_key
		local realmgroup_min
		if not usecache then
			local thisrealm = GetRealmName()
			if settings.ConnectedRealms ~= "ignore" then
				local group = SI:getRealmGroup(thisrealm) 
				thisrealm = group or thisrealm
			end
			wipe(cnext_list)
			cnext_pos = 1
			for n,_ in pairs(t) do
				local t = SavedInstances.db.Toons[n]
				local tn, tr = n:match('^(.*) [-] (.*)$')
				if t and 
					(t.Show ~= "never" or (n == thisToon and settings.SelfAlways))  and
					(not settings.ServerOnly 
					or thisrealm == tr
					or thisrealm == SI:getRealmGroup(tr))	then
					local e = {}
					cnext_ekey = 1
					if settings.SelfFirst then
						if n == thisToon then
							e[cnext_ekey] = 1
						else
							e[cnext_ekey] = 2
						end
						cnext_ekey = cnext_ekey + 1
					end

					if settings.ServerSort then
						if settings.ConnectedRealms == "ignore" then
							e[cnext_ekey] = tr
							cnext_ekey = cnext_ekey + 1
						else
							local rgroup = SI:getRealmGroup(tr)
							if rgroup then -- connected realm
								realmgroup_min = realmgroup_min or {}
								if not realmgroup_min[rgroup] or tr < realmgroup_min[rgroup] then
									realmgroup_min[rgroup] = tr -- lowest active realm in group
								end
							else
								rgroup = tr
							end
							realmgroup_key = cnext_ekey
							e[cnext_ekey] = rgroup
							cnext_ekey = cnext_ekey + 1

							if settings.ConnectedRealms == "group" then
								e[cnext_ekey] = tr
								cnext_ekey = cnext_ekey + 1
							end
						end
					end

					e[cnext_ekey] = t.Order
					cnext_ekey = cnext_ekey + 1
			
					e[cnext_ekey] = n
					cnext_list[cnext_pos] = e
					cnext_pos = cnext_pos + 1
				end
			end
			if realmgroup_key then -- second pass, convert group id to min name
				for _,e in ipairs(cnext_list) do
					local id = e[realmgroup_key]
					if type(id) == "number" then
						e[realmgroup_key] = realmgroup_min[id]
					end
				end
			end
			table.sort(cnext_list, cpairs_sort)
			--myprint(cnext_list)
		end
		cnext_pos = 1
		return cnext, t, nil
	end
end

local function EventHandler(event, ...)
	if addon[event] then
		addon[event](addon, ...)
	end
end

local function FrameOnEvent(frame, event, ...)
	if event == 'ADDON_LOADED' and ... == addonName then
		frame:RegisterEvent("PLAYER_LOGIN")
		frame:RegisterEvent("PLAYER_LOGOUT")
		frame:UnregisterEvent("ADDON_LOADED")
	elseif event == "PLAYER_LOGIN" then
		--print("SIK: PLAYER_LOGIN")
		SI = LibStub("AceAddon-3.0"):GetAddon("SavedInstances")
		if SI then
			--print("success", SavedInstancesKeystoneDB)
			if not addon:IsHooked(SI, 'ShowTooltip') then
				addon:SecureHook(SI, 'ShowTooltip', addon.Inject)
			end
			SavedInstancesKeystoneDB = SavedInstancesKeystoneDB or {}
			local kname = GetItemInfo(KeystoneId) -- try to get the cache to store keystone itemid
		end
	elseif event == "PLAYER_LOGOUT" then
		if addon:IsHooked(SI, 'ShowTooltip') then
			addon:Unhook(SI, 'ShowTooltip')
			frame:UnregisterAllEvents()
		end
	else
		EventHandler(event, ...)
	end
end

hooksecurefunc("Logout", function() addon:FindKeystones() end)
hooksecurefunc("ForceQuit", function() addon:FindKeystones() end)
hooksecurefunc("Quit", function() addon:FindKeystones() end)

local a1 = 0x080000
local a2 = 0x100000
local a3 = 0x200000
local ready = 0x400000

local function getModifierText(flags, modifierNum, modifierID)
	local txt = ""
	if (modifierID == nil or modifierID == "") then return txt end -- rare bug, don't know what the cause is
	modifierID = tonumber(modifierID)
	if (bit.band(flags,modifierNum) == modifierNum and (modifierID >= 1 and modifierID <= 10)) then
		local modifierName = C_ChallengeMode.GetAffixInfo(modifierID)
		if (modifierName ~= nil) then
			txt = " "..modifierName
		end
	end
	return txt
end

local function decodeKeystone(itemLink)
	local itemString = string.match(itemLink, "item[%-?%d:]+")
	local itemName = string.match(itemLink, "\124h.-\124h"):gsub("%[","%%[)("):gsub("%]",")(%%]")
	local _,itemid,_,_,_,_,_,_,_,_,_,flags,_,_,mapid,mlvl,modifier1,modifier2,modifier3 = strsplit(":", itemString)

	local A1 = getModifierText(flags, a1, modifier1)
	local A2 = getModifierText(flags, a2, modifier2)
	local A3 = getModifierText(flags, a3, modifier3)
	local dung = GetRealZoneText(mapid)
	local txt = string.format(CHALLENGE_MODE_KEYSTONE_NAME, dung)

	local color = select(4, GetItemQualityColor(4))
	if (bit.band(flags,ready) ~= ready) then
		color = select(4, GetItemQualityColor(0))
	end
	return txt, string.format(CHALLENGE_MODE_ITEM_POWER_LEVEL, mlvl), A1..A2..A3, color
end

local keystonetip

local function openIndicator(...)
  keystonetip = QTip:Acquire("SavedInstancesKeystoneTooltip", ...)
  keystonetip:Clear()
  keystonetip:SetHeaderFont(SI:HeaderFont())
  keystonetip:SetScale(SavedInstances.db.Tooltip.Scale)
end

local function finishIndicator(parent)
  keystonetip:SetAutoHideDelay(0.1, parent)
  keystonetip.OnRelease = function() keystonetip = nil end -- extra-safety: update our variable on auto-release
  keystonetip:SmartAnchorTo(parent)
  keystonetip:SetFrameLevel(150) -- ensure visibility when forced to overlap main tooltip
  SavedInstances:SkinFrame(keystonetip,"SavedInstancesKeystoneTooltip")
  keystonetip:Show()
end

local function ShowKeystoneTooltip(cell, arg, ...)
	openIndicator(1, "LEFT")
	local name, mlvl, mods, color = decodeKeystone(arg)
	local nameline = keystonetip:AddHeader()
	keystonetip:SetCell(nameline, 1, "|c"..color..name)
	keystonetip:SetCell(keystonetip:AddLine(), 1, YELLOWFONT..mlvl)
	keystonetip:SetCell(keystonetip:AddLine(), 1, CHALLENGE_MODE_DUNGEON_MODIFIERS..mods)
	finishIndicator(cell)
end

local function CloseTooltips()
	GameTooltip:Hide()
	if keystonetip then
		keystonetip:Hide()
		QTip:Release(keystonetip)
	end
end

local function addColumns(columns, toon, tooltip)
	for c = 1, maxcol do
		columns[toon..c] = columns[toon..c] or tooltip:AddColumn("CENTER")
	end
	--columnCache[ShowAll()][toon] = true
end

local firstpass = true
local linenum = 0
local function tooltip_OnHide(tooltip)
	--print("tooltip_OnHide")
	-- Release the tooltip
	QTip:Release(tooltip)
	tooltip = nil
	firstpass = true
end

local function tooltip_OnRelease()
	--print("tooltip_OnRelease")
	firstpass = true
end

-- line 3523 in SavedInstances.lua they do a tooltip:Clear()
-- We don't have the luxury to do it here.  So we do our stuff in OnHide...
function addon:Inject(anchorframe)
	--print("Inject!!!!", QTip:IsAcquired("SavedInstancesTooltip"))
	if QTip:IsAcquired("SavedInstancesTooltip") then
		local tooltip = QTip:Acquire("SavedInstancesTooltip", 1, "LEFT")
		local name = "columns"
		local columns = SI["localarr#"..name]
		if not columns then return end
		
		local usecache = true
		-- find and update keystones
		if firstpass then
			addon:FindKeystones()
			usecache = false
		end
		
		for toon, t in cpairs(SavedInstances.db.Toons, usecache) do
			if SavedInstancesKeystoneDB[toon] then
				addColumns(columns, toon, tooltip)
			end
			usecache = true
		end

		if firstpass then
			tooltip:AddSeparator()
			local kname = GetItemInfo(KeystoneId)
			local keystonestr = string.format(" \124T%s:0\124t%s", 525134, kname or "")
			linenum = tooltip:AddLine(YELLOWFONT .. keystonestr .. FONTEND)
			firstpass = false
			tooltip:SetScript('OnHide', tooltip_OnHide)
			tooltip.OnRelease = tooltip_OnRelease
		end
		for toon, t in cpairs(SavedInstances.db.Toons, usecache) do
			local klink = SavedInstancesKeystoneDB[toon]
			if klink then
				--print("keystone found for toon", toon)
				local col = columns[toon..1]
				--tooltip:SetCell(linenum, col, klink, "CENTER", maxcol)
				tooltip:SetCell(linenum, col, "\124T"..READY_CHECK_READY_TEXTURE..":0|t", "CENTER", maxcol) -- checkmark
				tooltip:SetCellScript(linenum, col, "OnEnter", ShowKeystoneTooltip, klink)
				tooltip:SetCellScript(linenum, col, "OnLeave", CloseTooltips)
			end
		end
	end
end

local slots = {0, 0, 0, 0, 0}
function addon:FindKeystones()
	-- Prepare...
	slots[1] = GetContainerNumSlots(0)
	slots[2] = GetContainerNumSlots(1)
	slots[3] = GetContainerNumSlots(2)
	slots[4] = GetContainerNumSlots(3)
	slots[5] = GetContainerNumSlots(4)
	-- Loop through every bag slot...
	for i = 1, #slots do
		for j = 1, slots[i] do
			-- Load Item info...
			local _, _, _, _, _, _, link, _, _, itemId = GetContainerItemInfo(i - 1, j)

			-- Check...
			if itemId and itemId == KeystoneId then
				--print("FOUND KEYSTONE", decodeKeystone(link))
				SavedInstancesKeystoneDB[thisToon] = link
				return
			end
		end
	end
	SavedInstancesKeystoneDB[thisToon] = nil
end

local f = CreateFrame('Frame','SIKFrame')
f:SetScript("OnEvent", FrameOnEvent)
f:RegisterEvent("ADDON_LOADED")