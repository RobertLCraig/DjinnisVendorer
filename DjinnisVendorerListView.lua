------------------------------------------------------------
-- DjinnisVendorer Vertical List View
-- Replaces the merchant grid with a scrollable list of every
-- item the merchant offers. Iterates raw indices via
-- Addon.BlizzFunctions to bypass the filter wrapper, so it
-- can show greyed-out non-matches alongside matches.
------------------------------------------------------------

local ADDON_NAME, Addon = ...;

local ROW_HEIGHT = 40;
local SEPARATOR_HEIGHT = 4;

local KIND_ITEM = "item";
local KIND_SEPARATOR = "separator";

local function rawGetNumItems()
	return Addon:GetUnfilteredMerchantNumItems() or 0;
end

local function rawGetItemInfo(index)
	-- Returns: name, texture, price, stackCount, numAvailable, isPurchasable,
	--          isUsable, hasExtendedCost, currencyID, showNonrefundablePrompt
	return Addon:GetUnfilteredMerchantItemInfo(index);
end

local function rawGetItemLink(index)
	return Addon:GetUnfilteredMerchantItemLink(index);
end

local function rawBuyItem(index, amount)
	Addon:RawBuyMerchantItem(index, amount);
end

local function rawSetTooltipMerchantItem(tooltip, index)
	Addon:RawSetTooltipMerchantItem(tooltip, index);
end

local function rawGetCostInfo(index)
	return Addon:GetUnfilteredMerchantCostInfo(index);
end

local function rawGetCostItem(index, costIndex)
	return Addon:GetUnfilteredMerchantCostItem(index, costIndex);
end

------------------------------------------------------------
-- Cost text
------------------------------------------------------------

local function FormatMoneyShort(copper)
	if(not copper or copper <= 0) then return "" end
	local g = math.floor(copper / 10000);
	local s = math.floor((copper % 10000) / 100);
	local c = copper % 100;
	local parts = {};
	if(g > 0) then tinsert(parts, g .. "|cffffd700g|r") end
	if(s > 0) then tinsert(parts, s .. "|cffc7c7cfs|r") end
	if(c > 0 and g == 0) then tinsert(parts, c .. "|cffeda55fc|r") end
	return table.concat(parts, " ");
end

local function BuildCostText(rawIndex, price, hasExtendedCost)
	local segments = {};

	if(price and price > 0) then
		tinsert(segments, FormatMoneyShort(price));
	end

	if(hasExtendedCost) then
		local numCost = rawGetCostInfo(rawIndex) or 0;
		for i = 1, numCost do
			local texture, value, link, currencyName = rawGetCostItem(rawIndex, i);
			if(value and value > 0 and texture) then
				tinsert(segments, string.format("%d|T%s:14:14:0:0|t", value, texture));
			end
		end
	end

	if(#segments == 0) then return "" end
	return table.concat(segments, "  ");
end

------------------------------------------------------------
-- Data assembly
------------------------------------------------------------

local function GetSortComparator()
	local key = (Addon.db and Addon.db.global and Addon.db.global.ListViewSortKey) or "default";
	if(key == "default") then return nil end
	if(key == "name") then
		return function(a, b)
			return (a.name or "") < (b.name or "");
		end;
	end
	if(key == "price") then
		return function(a, b)
			-- Items with extended cost (currencies) go after gold-priced.
			local pa = (a.hasExtendedCost and math.huge) or (a.price or 0);
			local pb = (b.hasExtendedCost and math.huge) or (b.price or 0);
			if(pa == pb) then return (a.name or "") < (b.name or "") end
			return pa < pb;
		end;
	end
	if(key == "quality") then
		return function(a, b)
			local qa = select(3, GetItemInfo(a.link or "")) or 0;
			local qb = select(3, GetItemInfo(b.link or "")) or 0;
			if(qa == qb) then return (a.name or "") < (b.name or "") end
			return qa > qb;
		end;
	end
	return nil;
end

local function GatherItems()
	local matches, nonMatches = {}, {};
	local total = rawGetNumItems();
	local hasFilter = Addon.FilterText and Addon.FilterText ~= "";

	for rawIndex = 1, total do
		local link = rawGetItemLink(rawIndex);
		if(link) then
			local name, texture, price, stack, numAvailable, isPurchasable, isUsable,
			      hasExtendedCost, currencyID, showNonrefundablePrompt = rawGetItemInfo(rawIndex);
			local entry = {
				kind = KIND_ITEM,
				rawIndex = rawIndex,
				link = link,
				name = name,
				texture = texture,
				price = price,
				stack = stack,
				numAvailable = numAvailable,
				isPurchasable = isPurchasable,
				isUsable = isUsable,
				hasExtendedCost = hasExtendedCost,
				showNonrefundablePrompt = showNonrefundablePrompt,
				matched = (not hasFilter) or Addon:FilterItem(rawIndex),
			};
			if(entry.matched) then
				tinsert(matches, entry);
			else
				tinsert(nonMatches, entry);
			end
		end
	end

	local cmp = GetSortComparator();
	if(cmp) then
		table.sort(matches, cmp);
		table.sort(nonMatches, cmp);
	end

	if(not hasFilter) then return matches end

	if(Addon.db.global.ListViewHideNonMatches) then
		return matches;
	end

	if(#nonMatches == 0) then return matches end

	local combined = {};
	for _, e in ipairs(matches) do tinsert(combined, e) end
	if(#matches > 0) then
		tinsert(combined, { kind = KIND_SEPARATOR });
	end
	for _, e in ipairs(nonMatches) do tinsert(combined, e) end
	return combined;
end

------------------------------------------------------------
-- Row scripts (referenced from XML)
------------------------------------------------------------

function DjinnisVendorerListRow_OnLoad(self)
	-- nothing to do; widgets all wired via parentKey
end

function DjinnisVendorerListRow_OnEnter(self)
	if(not self.data or self.data.kind ~= KIND_ITEM) then return end
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
	rawSetTooltipMerchantItem(GameTooltip, self.data.rawIndex);
	-- Show comparison tooltips for equippable items (held by default; ALT
	-- forces show via the standard Blizzard helper). Wrapped in pcall so
	-- API drift on this helper can't break the tooltip flow.
	if(GameTooltip_ShowCompareItem) then
		pcall(GameTooltip_ShowCompareItem, GameTooltip);
	end
	GameTooltip:Show();
end

function DjinnisVendorerListRow_OnLeave(self)
	GameTooltip:Hide();
	if(ShoppingTooltip1) then ShoppingTooltip1:Hide() end
	if(ShoppingTooltip2) then ShoppingTooltip2:Hide() end
end

function DjinnisVendorerListRow_OnClick(self, button)
	if(not self.data or self.data.kind ~= KIND_ITEM) then return end
	local rawIndex = self.data.rawIndex;
	local link = self.data.link;

	if(IsModifiedClick("CHATLINK") and link) then
		HandleModifiedItemClick(link);
		return;
	end

	if(IsModifiedClick("SPLITSTACK") and Addon.db.global.UseImprovedStackSplit and DjinnisVendorerStackSplitFrame) then
		DjinnisVendorerStackSplitFrame:Open(rawIndex, self, nil, true);
		return;
	end

	rawBuyItem(rawIndex, 1);
end

------------------------------------------------------------
-- Container
------------------------------------------------------------

local function ApplyDecorations(row, data)
	local link = data.link;
	local _, _, rarity, _, _, itemType, itemSubType, _, itemEquipLoc = GetItemInfo(link);

	local r, g, b = 1, 1, 1;
	if(rarity and rarity >= 1) then
		r, g, b = GetItemQualityColor(rarity);
	elseif(link and Addon:IsCurrencyItem(link)) then
		local currencyRarity = select(9, Addon:GetCurrencyInfo(link));
		if(currencyRarity) then
			r, g, b = GetItemQualityColor(currencyRarity);
		end
	end
	row.iconButton.border:SetVertexColor(r, g, b, 0.95);
	row.nameText:SetTextColor(r, g, b);

	-- Subtext: type + slot + iLvl
	local infoBits = {};
	if(itemEquipLoc and itemEquipLoc ~= "" and _G[itemEquipLoc]) then
		tinsert(infoBits, _G[itemEquipLoc]);
	end
	if(itemSubType and itemSubType ~= "") then
		tinsert(infoBits, itemSubType);
	end
	local _, _, _, itemLevel = GetItemInfo(link);
	if(itemLevel and itemLevel > 1) then
		tinsert(infoBits, "iLvl " .. itemLevel);
	end
	row.info:SetText(table.concat(infoBits, "  "));

	-- Armor type / known item paint via name colour override
	local override;
	if(Addon.db.global.PaintArmorTypes and data.isUsable and itemType == LOCALIZED_ARMOR
	   and Addon:IsArmorItemSlot(itemEquipLoc)
	   and itemSubType ~= LOCALIZED_COSMETIC and not Addon:IsValidClassArmorType(itemSubType)) then
		override = { 0.6, 0.0, 0.0 };
	end
	if(Addon.db.global.PaintKnownItems and Addon:IsItemKnown(link)) then
		override = {
			Addon.db.global.PaintColor.r,
			Addon.db.global.PaintColor.g,
			Addon.db.global.PaintColor.b,
		};
	end
	if(override) then
		row.bg:SetColorTexture(override[1], override[2], override[3], 0.25);
	else
		row.bg:SetColorTexture(1, 1, 1, 0.04);
	end

	-- Transmog asterisk
	if(Addon.db.global.ShowTransmogAsterisk and CanIMogIt) then
		local isTransmogable, isKnown, anotherCharacter = Addon:GetKnownTransmogInfo(link);
		if(isTransmogable and not isKnown) then
			row.iconButton.transmogAsterisk:Show();
			if(anotherCharacter) then
				row.iconButton.transmogAsterisk:SetTexCoord(0.5, 1, 0, 1);
			else
				row.iconButton.transmogAsterisk:SetTexCoord(0, 0.5, 0, 1);
			end
		else
			row.iconButton.transmogAsterisk:Hide();
		end
	else
		row.iconButton.transmogAsterisk:Hide();
	end
end

local function InitializeRow(row, data)
	row.data = data;

	if(data.kind == KIND_SEPARATOR) then
		row.bg:Hide();
		row.separator:Show();
		row.nameText:SetText("");
		row.info:SetText("");
		row.costText:SetText("");
		row.iconButton:Hide();
		row:Disable();
		row:SetAlpha(1);
		return;
	end

	row.bg:Show();
	row.separator:Hide();
	row.iconButton:Show();
	row:Enable();

	row.iconButton.icon:SetTexture(data.texture);
	if(data.stack and data.stack > 1) then
		row.iconButton.count:SetText(data.stack);
		row.iconButton.count:Show();
	else
		row.iconButton.count:Hide();
	end

	row.nameText:SetText(data.name or "");
	row.costText:SetText(BuildCostText(data.rawIndex, data.price, data.hasExtendedCost));

	ApplyDecorations(row, data);

	row:SetAlpha(data.matched and 1.0 or 0.35);

	-- Surface merchant-button-shaped fields so DjinnisVendorerStackSplitFrame can
	-- consume the row directly as its itemButton parent.
	row:SetID(data.rawIndex or 0);
	row.link = data.link;
	row.texture = data.texture;
	row.name = data.name;
	row.count = data.stack;
	row.price = data.price;
	row.extendedCost = data.hasExtendedCost;
	row.showNonrefundablePrompt = data.showNonrefundablePrompt;
end

local function GetView()
	if(not DjinnisVendorerListViewFrame.view) then
		local view = CreateScrollBoxListLinearView();
		view:SetElementInitializer("DjinnisVendorerListRowTemplate", InitializeRow);
		view:SetElementExtentCalculator(function(_, data)
			if(data and data.kind == KIND_SEPARATOR) then return SEPARATOR_HEIGHT end
			return ROW_HEIGHT;
		end);
		view:SetPadding(0, 0, 0, 0, 1);
		ScrollUtil.InitScrollBoxListWithScrollBar(DjinnisVendorerListViewFrame.scrollBox, DjinnisVendorerListViewFrame.scrollBar, view);
		DjinnisVendorerListViewFrame.view = view;
	end
	return DjinnisVendorerListViewFrame.view;
end

function DjinnisVendorerListViewFrame_OnLoad(self)
	-- Defer view creation until first show so ScrollUtil/MerchantFrame are ready.
end

function DjinnisVendorerListViewFrame_OnShow(self)
	GetView();
	Addon:RefreshListView();
end

function Addon:RefreshListView()
	if(not DjinnisVendorerListViewFrame or not DjinnisVendorerListViewFrame:IsShown()) then return end
	GetView();
	local entries = GatherItems();
	local provider = CreateDataProvider();
	for _, entry in ipairs(entries) do provider:Insert(entry) end
	DjinnisVendorerListViewFrame.scrollBox:SetDataProvider(provider, ScrollBoxConstants.RetainScrollPosition);

	if(#entries == 0) then
		DjinnisVendorerListViewFrame.emptyText:Show();
	else
		DjinnisVendorerListViewFrame.emptyText:Hide();
	end
end

------------------------------------------------------------
-- Show/hide integration
------------------------------------------------------------

function Addon:IsListViewActive()
	return Addon.db and Addon.db.global and Addon.db.global.ListViewEnabled
		and MerchantFrame and MerchantFrame:IsShown() and MerchantFrame.selectedTab == 1;
end

local pageButtonsHidden = false;
local function HidePageButtons()
	if(MerchantPrevPageButton) then MerchantPrevPageButton:Hide() end
	if(MerchantNextPageButton) then MerchantNextPageButton:Hide() end
	if(MerchantPageText) then MerchantPageText:Hide() end
	pageButtonsHidden = true;
end
local function RestorePageButtons()
	if(not pageButtonsHidden) then return end
	if(MerchantPrevPageButton) then MerchantPrevPageButton:Show() end
	if(MerchantNextPageButton) then MerchantNextPageButton:Show() end
	pageButtonsHidden = false;
	-- MerchantPageText visibility is managed by Addon:UpdateMerchantInfo.
end

local function HideMerchantGrid()
	for i = 1, 12 do
		local frame = _G["MerchantItem"..i];
		if(frame) then frame:Hide() end
	end
end

local function ShowMerchantGrid()
	for i = 1, 12 do
		local frame = _G["MerchantItem"..i];
		if(frame) then frame:Show() end
	end
end

local gridWasHidden = false;

function Addon:ApplyListViewVisibility()
	if(Addon:IsListViewActive()) then
		HideMerchantGrid();
		HidePageButtons();
		gridWasHidden = true;
		if(DjinnisVendorerListViewFrame and not DjinnisVendorerListViewFrame:IsShown()) then
			DjinnisVendorerListViewFrame:Show();
		else
			Addon:RefreshListView();
		end
	else
		if(DjinnisVendorerListViewFrame and DjinnisVendorerListViewFrame:IsShown()) then
			DjinnisVendorerListViewFrame:Hide();
		end
		RestorePageButtons();
		if(gridWasHidden) then
			ShowMerchantGrid();
			gridWasHidden = false;
			if(MerchantFrame and MerchantFrame:IsShown() and MerchantFrame.selectedTab == 1) then
				MerchantFrame_UpdateMerchantInfo();
			end
		end
	end
end
