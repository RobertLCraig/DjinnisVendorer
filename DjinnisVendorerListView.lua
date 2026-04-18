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
-- Bind type + reputation discount helpers
------------------------------------------------------------

-- Mirrors the BT_* constants in core.lua; ScanBindType returns these.
local BIND_TYPE_LABEL = {
	[1] = "BoP",
	[2] = "BoE",
	[3] = "BoA",
	[4] = "BoU",
	[5] = "Quest",
};

local function GetBindTypeLabel(link)
	if(not link or not Addon.GetItemTooltipInfo) then return nil end
	local bindType = Addon:GetItemTooltipInfo(link);
	return BIND_TYPE_LABEL[bindType];
end

-- Standing -> discount %, matching Blizzard's reputation-discount table.
-- Standing IDs: 5=Friendly, 6=Honored, 7=Revered, 8=Exalted.
local STANDING_DISCOUNT = { [5] = 5, [6] = 10, [7] = 15, [8] = 20 };

local function CollectPlayerFactionStandings()
	local map = {};
	local count;
	if(C_Reputation and C_Reputation.GetNumFactions) then
		count = C_Reputation.GetNumFactions();
	elseif(GetNumFactions) then
		count = GetNumFactions();
	end
	if(not count or count == 0) then return map end

	for i = 1, count do
		local name, standingID;
		if(C_Reputation and C_Reputation.GetFactionDataByIndex) then
			local data = C_Reputation.GetFactionDataByIndex(i);
			if(data and not data.isHeader) then
				name = data.name;
				standingID = data.reaction;
			end
		else
			local n, _, sID, _, _, _, _, _, isHeader = GetFactionInfo(i);
			if(not isHeader) then
				name, standingID = n, sID;
			end
		end
		if(name and standingID) then
			map[name] = standingID;
		end
	end
	return map;
end

local function ComputeMerchantDiscount()
	if(not UnitExists("npc")) then return nil end
	local standings = CollectPlayerFactionStandings();
	if(not next(standings)) then return nil end

	DjinnisVendorerTooltip:ClearLines();
	DjinnisVendorerTooltip:SetOwner(UIParent, "ANCHOR_NONE");
	DjinnisVendorerTooltip:SetUnit("npc");
	local discount;
	for line = 1, DjinnisVendorerTooltip:NumLines() do
		local left = _G["DjinnisVendorerTooltipTextLeft" .. line];
		local text = left and left:GetText();
		if(text) then
			local standing = standings[text];
			if(standing and STANDING_DISCOUNT[standing]) then
				discount = STANDING_DISCOUNT[standing];
				break;
			end
		end
	end
	DjinnisVendorerTooltip:Hide();
	return discount;
end

local function GetMerchantDiscount()
	if(Addon.MerchantDiscount ~= nil) then
		return Addon.MerchantDiscount or nil;
	end
	local discount = ComputeMerchantDiscount();
	Addon.MerchantDiscount = discount or false;
	return discount;
end

------------------------------------------------------------
-- Cost text
------------------------------------------------------------

local function PopulateMoneyColumns(row, copper)
	if(not copper or copper <= 0) then
		row.goldText:SetText("");
		row.silverText:SetText("");
		row.copperText:SetText("");
		return;
	end
	local g = math.floor(copper / 10000);
	local s = math.floor((copper % 10000) / 100);
	local c = copper % 100;
	-- BreakUpLargeNumbers adds locale-appropriate digit separators so 8-figure
	-- gold prices (10,000,000+) stay legible instead of running together.
	local goldStr = (g > 0) and (BreakUpLargeNumbers(g) .. "|cffffd700g|r") or "";
	row.goldText:SetText(goldStr);
	row.silverText:SetText(s > 0 and (s .. "|cffc7c7cfs|r") or "");
	row.copperText:SetText(c > 0 and (c .. "|cffeda55fc|r") or "");
end

local function FormatExtendedCost(rawIndex)
	local segments = {};
	local numCost = rawGetCostInfo(rawIndex) or 0;
	for i = 1, numCost do
		local texture, value, link, currencyName = rawGetCostItem(rawIndex, i);
		if(value and value > 0 and texture) then
			tinsert(segments, string.format("%d|T%s:14:14:0:0|t", value, texture));
		end
	end
	return table.concat(segments, " ");
end

local function PopulateStackText(row, stack)
	if(Addon.db.global.ListViewShowStackSize and stack and stack > 1) then
		row.stackText:SetText("|cff808080x" .. stack .. "|r");
	else
		row.stackText:SetText("");
	end
end

local function ClearCostColumns(row)
	row.goldText:SetText("");
	row.silverText:SetText("");
	row.copperText:SetText("");
	row.costText:SetText("");
	row.stackText:SetText("");
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
	SetCursor("BUY_CURSOR");
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
	ResetCursor();
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

	-- Subtext: type + slot + iLvl + optional bind type + optional rep discount
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
	if(Addon.db.global.ListViewShowBindType) then
		local bindLabel = GetBindTypeLabel(link);
		if(bindLabel) then
			tinsert(infoBits, bindLabel);
		end
	end
	if(Addon.db.global.ListViewShowRepDiscount and data.price and data.price > 0) then
		local discount = GetMerchantDiscount();
		if(discount and discount > 0) then
			tinsert(infoBits, "|cff73ce2f-" .. discount .. "%|r");
		end
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
		ClearCostColumns(row);
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

	-- Cost: gold-priced items use the g/s/c columns; extended-cost items
	-- (currency tokens) use costText, which overlays the same area.
	PopulateStackText(row, data.stack);
	if(data.hasExtendedCost) then
		row.goldText:SetText("");
		row.silverText:SetText("");
		row.copperText:SetText("");
		row.costText:SetText(FormatExtendedCost(data.rawIndex));
	else
		row.costText:SetText("");
		PopulateMoneyColumns(row, data.price);
	end

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
