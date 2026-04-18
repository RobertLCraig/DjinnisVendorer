-- Midnight (12.0) API compatibility shims.
-- Restores classic global names / signatures that DjinnisVendorer's original code uses.

if C_Item then
	GetItemInfo          = C_Item.GetItemInfo
	GetItemInfoInstant   = C_Item.GetItemInfoInstant
	GetItemQualityColor  = C_Item.GetItemQualityColor
	IsEquippableItem     = C_Item.IsEquippableItem
	GetItemSpell         = C_Item.GetItemSpell
	GetItemSpecInfo      = C_Item.GetItemSpecInfo
	GetItemCount         = C_Item.GetItemCount
	GetItemIcon          = C_Item.GetItemIconByID
	IsConsumableItem     = C_Item.IsConsumableItem
end

if C_Container then
	GetContainerNumSlots       = C_Container.GetContainerNumSlots
	GetContainerItemLink       = C_Container.GetContainerItemLink
	GetContainerItemID         = C_Container.GetContainerItemID
	PickupContainerItem        = C_Container.PickupContainerItem
	UseContainerItem           = C_Container.UseContainerItem
	SplitContainerItem         = C_Container.SplitContainerItem
	GetContainerNumFreeSlots   = C_Container.GetContainerNumFreeSlots
	GetContainerItemQuestInfo  = C_Container.GetContainerItemQuestInfo

	-- The new C_Container.GetContainerItemInfo returns a table; old callers expect
	-- multiple return values in classic order.
	GetContainerItemInfo = function(bag, slot)
		local info = C_Container.GetContainerItemInfo(bag, slot)
		if not info then return nil end
		return info.iconFileID, info.stackCount, info.isLocked, info.quality,
			info.isReadable, info.isLootable, info.hyperlink, info.isFiltered,
			info.hasNoValue, info.itemID, info.isBound
	end
end

if C_AddOns then
	IsAddOnLoaded     = IsAddOnLoaded     or C_AddOns.IsAddOnLoaded
	LoadAddOn         = LoadAddOn         or C_AddOns.LoadAddOn
	GetAddOnMetadata  = GetAddOnMetadata  or C_AddOns.GetAddOnMetadata
end

-- Reagent bank was removed/merged in Midnight; leave REAGENTBANK_CONTAINER nil
-- and let call sites guard on it.

-- GetMerchantItemInfo was removed in 12.0; C_MerchantFrame.GetItemInfo(index)
-- returns a table. Restore the classic multi-return shape.
if C_MerchantFrame and C_MerchantFrame.GetItemInfo then
	-- Capture the raw C_API now. vendorfilter.lua later wraps
	-- C_MerchantFrame.GetItemInfo to redirect display indices through the
	-- filter; this shim must stay pointed at the unfiltered function, or
	-- FilterItem → CanAffordMerchantItem → GetMerchantItemInfo recurses.
	local rawGetItemInfo = C_MerchantFrame.GetItemInfo
	GetMerchantItemInfo = function(index)
		local info = rawGetItemInfo(index)
		if not info then return end
		return info.name, info.texture, info.price, info.stackCount,
			info.numAvailable, info.isPurchasable, info.isUsable,
			info.hasExtendedCost, info.currencyID
	end
end

-- EasyMenu / UIDropDownMenu were removed in 11.0. Provide a shim
-- that walks the legacy menu-data table and emits a MenuUtil context menu.
if not EasyMenu and MenuUtil and MenuUtil.CreateContextMenu then
	local function ApplyTooltip(element, entry)
		if not element or not element.SetTooltip then return end
		if not (entry.tooltipTitle or entry.tooltipText) then return end
		element:SetTooltip(function(tooltip)
			if entry.tooltipTitle then
				GameTooltip_SetTitle(tooltip, entry.tooltipTitle)
			end
			if entry.tooltipText then
				GameTooltip_AddNormalLine(tooltip, entry.tooltipText, true)
			end
		end)
	end

	local PopulateRoot
	PopulateRoot = function(rootDescription, data)
		for _, entry in ipairs(data) do
			-- Fake `self` the legacy callbacks expect: legacy UIDropDownMenu
			-- auto-assigned `self.value = entry.value or entry.text`.
			local fakeSelf = { value = entry.value or entry.text }

			if entry.isTitle then
				if entry.text and entry.text ~= " " then
					rootDescription:CreateTitle(entry.text)
				else
					rootDescription:CreateDivider()
				end
			elseif entry.hasArrow and entry.menuList then
				local submenu = rootDescription:CreateButton(entry.text or "")
				PopulateRoot(submenu, entry.menuList)
				if entry.disabled and submenu and submenu.SetEnabled then
					submenu:SetEnabled(false)
				end
				ApplyTooltip(submenu, entry)
			elseif entry.notCheckable then
				local element
				if entry.func then
					element = rootDescription:CreateButton(entry.text or "", function()
						entry.func(fakeSelf)
					end)
				else
					element = rootDescription:CreateTitle(entry.text or "")
				end
				if entry.disabled and element and element.SetEnabled then
					element:SetEnabled(false)
				end
				ApplyTooltip(element, entry)
			else
				local isChecked = entry.checked
				if type(isChecked) ~= "function" then
					local v = isChecked
					isChecked = function() return v end
				end
				local element = rootDescription:CreateCheckbox(
					entry.text or "",
					isChecked,
					function()
						if entry.func then entry.func(fakeSelf) end
					end
				)
				if entry.disabled and element and element.SetEnabled then
					element:SetEnabled(false)
				end
				ApplyTooltip(element, entry)
			end
		end
	end

	EasyMenu = function(menuList, menuFrame, anchor, x, y, displayMode, autoHideDelay)
		MenuUtil.CreateContextMenu(menuFrame or UIParent, function(owner, rootDescription)
			PopulateRoot(rootDescription, menuList)
		end)
	end
end

-- Legacy helper used by quick-filter callbacks; safe no-op on Midnight because
-- MenuUtil context menus close themselves on selection.
if not CloseMenus then
	CloseMenus = function() end
end

-- UIDropDownMenuTemplate was removed with the menu refactor; avoid the
-- CreateFrame call in settings.lua exploding by leaving a dummy template.
if not _G["UIDropDownMenuTemplate"] then
	-- No-op; the OpenSettingsMenu call path below handles a nil template.
end
