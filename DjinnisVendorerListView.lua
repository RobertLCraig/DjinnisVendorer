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

-- Tooltip line text in 12.0 can be a "secret string" that throws when used
-- as a regular table key. pcall the scan so a tainted line just fails the
-- discount detection silently instead of warn-spamming once per row.
local function ScanTooltipForDiscount(standings)
	for line = 1, DjinnisVendorerTooltip:NumLines() do
		local left = _G["DjinnisVendorerTooltipTextLeft" .. line];
		local text = left and left:GetText();
		if(text) then
			local standing = standings[text];
			if(standing and STANDING_DISCOUNT[standing]) then
				return STANDING_DISCOUNT[standing];
			end
		end
	end
	return nil;
end

local function ComputeMerchantDiscount()
	if(not UnitExists("npc")) then return nil end
	local standings = CollectPlayerFactionStandings();
	if(not next(standings)) then return nil end

	DjinnisVendorerTooltip:ClearLines();
	DjinnisVendorerTooltip:SetOwner(UIParent, "ANCHOR_NONE");
	DjinnisVendorerTooltip:SetUnit("npc");
	local ok, discount = pcall(ScanTooltipForDiscount, standings);
	DjinnisVendorerTooltip:Hide();
	if(not ok) then return nil end
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

-- Compact, single-line money string for embedding in the info subtitle row.
-- Uses smaller letter suffixes than PopulateMoneyColumns since the info line
-- is GameFontDisableSmall and short on horizontal room.
local function FormatCopperInline(copper)
	if(not copper or copper <= 0) then return "" end
	local g = math.floor(copper / 10000);
	local s = math.floor((copper % 10000) / 100);
	local c = copper % 100;
	local parts = {};
	if(g > 0) then tinsert(parts, BreakUpLargeNumbers(g) .. "|cffffd700g|r") end
	if(s > 0) then tinsert(parts, s .. "|cffc7c7cfs|r") end
	if(c > 0) then tinsert(parts, c .. "|cffeda55fc|r") end
	return table.concat(parts, " ");
end

local function FormatExtendedCostInline(rawIndex, divisor)
	local segments = {};
	local numCost = rawGetCostInfo(rawIndex) or 0;
	local d = divisor or 1;
	for i = 1, numCost do
		local texture, value = rawGetCostItem(rawIndex, i);
		if(value and value > 0 and texture) then
			local v = math.floor(value / d);
			if(v > 0) then
				tinsert(segments, string.format("%d|T%s:10:10:0:0|t", v, texture));
			end
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
	row.unitPriceText:SetText("");
end

local function PopulateUnitPrice(row, data)
	if(not Addon.db.global.ListViewShowUnitPrice or not data.stack or data.stack <= 1) then
		row.unitPriceText:SetText("");
		return;
	end
	local unitText;
	if(data.hasExtendedCost and not data.isBuyback) then
		unitText = FormatExtendedCostInline(data.rawIndex, data.stack);
	elseif(data.price and data.price > 0) then
		unitText = FormatCopperInline(math.floor(data.price / data.stack));
	end
	if(unitText and unitText ~= "") then
		row.unitPriceText:SetText(unitText .. " ea");
	else
		row.unitPriceText:SetText("");
	end
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
			local qa = select(3, C_Item.GetItemInfo(a.link or "")) or 0;
			local qb = select(3, C_Item.GetItemInfo(b.link or "")) or 0;
			if(qa == qb) then return (a.name or "") < (b.name or "") end
			return qa > qb;
		end;
	end
	return nil;
end

local function GatherMerchantItems()
	local matches, nonMatches = {}, {};
	local total = rawGetNumItems();
	local hasFilter = Addon.FilterText and Addon.FilterText ~= "";

	for rawIndex = 1, total do
		local link = rawGetItemLink(rawIndex);
		if(link) then
			local name, texture, price, stack, numAvailable, isPurchasable, isUsable,
			      hasExtendedCost, currencyID, showNonrefundablePrompt = rawGetItemInfo(rawIndex);
			-- maxStack is the inventory stack ceiling (e.g. 200 for potions),
			-- distinct from `stack` which is the merchant's per-purchase quantity.
			local maxStack = select(8, C_Item.GetItemInfo(link)) or 0;
			local entry = {
				kind = KIND_ITEM,
				rawIndex = rawIndex,
				link = link,
				name = name,
				texture = texture,
				price = price,
				stack = stack,
				maxStack = maxStack,
				numAvailable = numAvailable,
				isPurchasable = isPurchasable,
				isUsable = isUsable,
				hasExtendedCost = hasExtendedCost,
				currencyID = currencyID,
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

-- Buyback uses Blizzard's GetBuybackItem* family (slot indices 1..GetNumBuybackItems).
-- No filter applies; cost is always plain gold (price returned by GetBuybackItemInfo).
local function GatherBuybackItems()
	local entries = {};
	local total = GetNumBuybackItems() or 0;
	for slotIndex = 1, total do
		local link = GetBuybackItemLink(slotIndex);
		if(link) then
			local name, texture, price, stack, numAvailable, isUsable = GetBuybackItemInfo(slotIndex);
			local maxStack = select(8, C_Item.GetItemInfo(link)) or 0;
			tinsert(entries, {
				kind = KIND_ITEM,
				rawIndex = slotIndex,
				link = link,
				name = name,
				texture = texture,
				price = price,
				stack = stack,
				maxStack = maxStack,
				numAvailable = numAvailable,
				isPurchasable = true,
				isUsable = isUsable,
				hasExtendedCost = false,
				currencyID = nil,
				showNonrefundablePrompt = false,
				matched = true,
				isBuyback = true,
			});
		end
	end
	return entries;
end

local function GatherItems()
	if(MerchantFrame and MerchantFrame.selectedTab == 2) then
		return GatherBuybackItems();
	end
	return GatherMerchantItems();
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

	if(self.data.isBuyback) then
		GameTooltip:SetBuybackItem(self.data.rawIndex);
		if(GameTooltip_ShowCompareItem) then
			pcall(GameTooltip_ShowCompareItem, GameTooltip);
		end
		GameTooltip:Show();
		return;
	end

	-- Currency-token rows route through SetCurrencyByID so the tooltip shows
	-- "You have N" feedback, the way the merchant-token buttons do. Plain
	-- SetMerchantItem on a currency line item omits that line.
	local link = self.data.link;
	local currencyID;
	if(link and Addon:IsCurrencyItem(link)) then
		currencyID = Addon:GetCurrencyInfo(link);
	end

	if(currencyID) then
		GameTooltip:SetCurrencyByID(currencyID);
	else
		rawSetTooltipMerchantItem(GameTooltip, self.data.rawIndex);
		-- Show comparison tooltips for equippable items (held by default; ALT
		-- forces show via the standard Blizzard helper). Wrapped in pcall so
		-- API drift on this helper can't break the tooltip flow.
		if(GameTooltip_ShowCompareItem) then
			pcall(GameTooltip_ShowCompareItem, GameTooltip);
		end
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

	-- SPLITSTACK and CHATLINK / EXPANDITEM share the shift modifier by default,
	-- and HandleModifiedItemClick can consume the shift-click before
	-- IsModifiedClick("SPLITSTACK") gets a chance. Resolve the conflict
	-- explicitly: if a chat editbox is focused the user wants chat-link, so let
	-- HandleModifiedItemClick run first; otherwise prefer stack split.
	if(not self.data.isBuyback and not ChatFrameUtil.GetActiveWindow()
	   and IsModifiedClick("SPLITSTACK")
	   and Addon.db.global.UseImprovedStackSplit
	   and DjinnisVendorerStackSplitFrame) then
		DjinnisVendorerStackSplitFrame:Open(rawIndex, self, nil, true);
		return;
	end

	-- HandleModifiedItemClick covers shift = chat-link (when chat is focused),
	-- ctrl = dressup/preview, alt = compare, and returns true when consumed.
	if(link and HandleModifiedItemClick(link)) then
		return;
	end

	if(self.data.isBuyback) then
		BuybackItem(rawIndex);
		return;
	end

	rawBuyItem(rawIndex, 1);
end

------------------------------------------------------------
-- Container
------------------------------------------------------------

local function ApplyDecorations(row, data)
	local link = data.link;
	local _, _, rarity, _, _, itemType, itemSubType, _, itemEquipLoc = C_Item.GetItemInfo(link);

	local r, g, b = 1, 1, 1;
	if(rarity and rarity >= 1) then
		r, g, b = C_Item.GetItemQualityColor(rarity);
	elseif(link and Addon:IsCurrencyItem(link)) then
		local _, info = Addon:GetCurrencyInfo(link);
		local currencyRarity = info and info.quality;
		if(currencyRarity) then
			r, g, b = C_Item.GetItemQualityColor(currencyRarity);
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
	local _, _, _, itemLevel = C_Item.GetItemInfo(link);
	if(itemLevel and itemLevel > 1) then
		tinsert(infoBits, "iLvl " .. itemLevel);
	end
	if(Addon.db.global.ListViewShowBindType) then
		local bindLabel = GetBindTypeLabel(link);
		if(bindLabel) then
			tinsert(infoBits, bindLabel);
		end
	end
	-- Rep discount only applies to merchant purchases, not buyback prices.
	if(Addon.db.global.ListViewShowRepDiscount and not data.isBuyback and data.price and data.price > 0) then
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
	-- Stack column shows inventory max stack, not merchant purchase qty.
	PopulateStackText(row, data.maxStack);
	if(data.hasExtendedCost) then
		row.goldText:SetText("");
		row.silverText:SetText("");
		row.copperText:SetText("");
		row.costText:SetText(FormatExtendedCost(data.rawIndex));
	else
		row.costText:SetText("");
		PopulateMoneyColumns(row, data.price);
	end
	PopulateUnitPrice(row, data);

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
	if not (Addon.db and Addon.db.global and Addon.db.global.ListViewEnabled) then return false end
	if not (MerchantFrame and MerchantFrame:IsShown()) then return false end
	local tab = MerchantFrame.selectedTab;
	return tab == 1 or tab == 2;
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

-- Buyback chrome reuses the MerchantItem1-12 buttons, plus BuybackBG. Page
-- buttons + MerchantBuyBackItem are already hidden by Blizzard on buyback so
-- we don't touch them here.
local function HideBuybackChrome()
	HideMerchantGrid();
	if(BuybackBG) then BuybackBG:Hide() end
end

local function RestoreBuybackChrome()
	ShowMerchantGrid();
	if(BuybackBG) then BuybackBG:Show() end
end

-- The MerchantBuyBackItem ("last item sold" preview slot) and its decoration
-- frames stay visible while list view is active; Addon:LayoutBottomLeftChrome
-- in core.lua relocates them into the right-hand decorative inset so they
-- don't collide with the repair-button row that's parked in the left inset.

local gridWasHidden = false;
local buybackChromeHidden = false;

function Addon:ApplyListViewVisibility()
	if(Addon:IsListViewActive()) then
		if(MerchantFrame.selectedTab == 1) then
			HideMerchantGrid();
			HidePageButtons();
			gridWasHidden = true;
			-- Buyback chrome doesn't apply on this tab.
			buybackChromeHidden = false;
		else
			-- Buyback tab. Page buttons are already hidden by Blizzard's
			-- UpdateBuybackInfo, so no need to call HidePageButtons.
			HideBuybackChrome();
			buybackChromeHidden = true;
			pageButtonsHidden = false;
			gridWasHidden = false;
		end

		if(DjinnisVendorerListViewFrame and not DjinnisVendorerListViewFrame:IsShown()) then
			DjinnisVendorerListViewFrame:Show();
		else
			Addon:RefreshListView();
		end
	else
		if(DjinnisVendorerListViewFrame and DjinnisVendorerListViewFrame:IsShown()) then
			DjinnisVendorerListViewFrame:Hide();
		end
		local tab = MerchantFrame and MerchantFrame.selectedTab;
		if(tab == 1) then
			RestorePageButtons();
			if(gridWasHidden) then
				ShowMerchantGrid();
				gridWasHidden = false;
				MerchantFrame_UpdateMerchantInfo();
			end
			-- We can't be carrying buyback state into a merchant-tab restore
			-- (Blizzard's tab switch already ran UpdateMerchantInfo), so drop
			-- the flag without doing any DOM work.
			buybackChromeHidden = false;
		elseif(tab == 2) then
			-- Returning to buyback chrome after a list-view-off toggle.
			-- gridWasHidden / pageButtonsHidden carry over from the merchant
			-- tab and don't apply here; reset them so a later merchant-tab
			-- visit takes the proper "hide" path.
			pageButtonsHidden = false;
			gridWasHidden = false;
			if(buybackChromeHidden) then
				RestoreBuybackChrome();
				buybackChromeHidden = false;
				MerchantFrame_UpdateBuybackInfo();
			end
		end
	end
end
