------------------------------------------------------------
-- DjinnisVendorer by Djinni, Originally created by Sonaza (https://sonaza.com) as "Vendorer"
-- Licensed under MIT License
-- See attached license text in file LICENSE
------------------------------------------------------------

local ADDON_NAME, Addon = ...;
local _;

local FilteredMerchantItems = {};

Addon.BlizzFunctions = {
	BuyMerchantItem                 = _G.BuyMerchantItem,
	PickupMerchantItem              = _G.PickupMerchantItem,
	ShowMerchantSellCursor          = _G.ShowMerchantSellCursor,
	GetMerchantItemCostInfo         = _G.GetMerchantItemCostInfo,
	GetMerchantItemCostItem         = _G.GetMerchantItemCostItem,
	GetMerchantItemLink             = _G.GetMerchantItemLink,
	GetMerchantItemMaxStack         = _G.GetMerchantItemMaxStack,
	GetMerchantNumItems             = _G.GetMerchantNumItems,
	C_MerchantFrame_GetItemInfo     = C_MerchantFrame and C_MerchantFrame.GetItemInfo,
	C_MerchantFrame_GetNumItems     = C_MerchantFrame and C_MerchantFrame.GetNumItems,
	GameTooltip_SetMerchantItem     = GameTooltip.SetMerchantItem,
	GameTooltip_SetMerchantCostItem = GameTooltip.SetMerchantCostItem,
};

local _BuyMerchantItem 			= _G.BuyMerchantItem;
local _PickupMerchantItem		= _G.PickupMerchantItem;
local _ShowMerchantSellCursor	= _G.ShowMerchantSellCursor;
local _GetMerchantItemCostInfo 	= _G.GetMerchantItemCostInfo;
local _GetMerchantItemCostItem 	= _G.GetMerchantItemCostItem;
local _GetMerchantItemLink 		= _G.GetMerchantItemLink;
local _GetMerchantItemMaxStack 	= _G.GetMerchantItemMaxStack;
local _GetMerchantNumItems 		= _G.GetMerchantNumItems;

-- Capture the raw C_MerchantFrame.GetItemInfo before we wrap it below. This is
-- the source of truth that our filter evaluation uses, so it must not go
-- through the filter redirect (which operates on display indices).
local _C_MerchantFrame_GetItemInfo = C_MerchantFrame and C_MerchantFrame.GetItemInfo;

local function _GetMerchantItemInfo(index)
	if not _C_MerchantFrame_GetItemInfo then
		return;
	end
	local info = _C_MerchantFrame_GetItemInfo(index);
	if not info then return end
	return info.name, info.texture, info.price, info.stackCount,
		info.numAvailable, info.isPurchasable, info.isUsable,
		info.hasExtendedCost, info.currencyID,
		info.showNonrefundablePrompt;
end

local _GameTooltip_SetMerchantItem = GameTooltip.SetMerchantItem;
local _GameTooltip_SetMerchantCostItem = GameTooltip.SetMerchantCostItem;

GameTooltip.SetMerchantItem = function(self, index)
	if(not index) then return end
	
	if(FilteredMerchantItems[index]) then
		local value = _GameTooltip_SetMerchantItem(self, FilteredMerchantItems[index]);
		if(Addon.db.global.UseImprovedStackSplit) then
			local itemLink = _GetMerchantItemLink(FilteredMerchantItems[index]);
			if(itemLink) then
				local name, _, _, _, _, _, _, stack = C_Item.GetItemInfo(itemLink)
				if(name and stack <= 1 or Addon:IsCurrencyItem(itemLink)) then
					GameTooltip:AddLine(ITEM_VENDOR_STACK_BUY, 0, 1, 0);
				end
			end
		end
		return value;
	end
end

GameTooltip.SetMerchantCostItem = function(self, index, item)
	if(not index) then return end
	
	if(FilteredMerchantItems[index]) then
		return _GameTooltip_SetMerchantCostItem(self, FilteredMerchantItems[index], item);
	end
end

_G.BuyMerchantItem = function(index, amount)
	if(not index) then return end
	
	if(not FilteredMerchantItems[index]) then Addon:RefreshFilteredItems(); end
	if(#FilteredMerchantItems == 0) then return end
	
	return _BuyMerchantItem(FilteredMerchantItems[index], amount);
end

_G.PickupMerchantItem = function(index)
	if(not index) then
		_PickupMerchantItem(index);
	end
	
	if(not FilteredMerchantItems[index]) then Addon:RefreshFilteredItems(); end
	if(FilteredMerchantItems[index]) then
		return _PickupMerchantItem(FilteredMerchantItems[index]);
	else
		return _PickupMerchantItem(index);
	end
end

_G.ShowMerchantSellCursor = function(index)
	if(not index) then return end
	
	if(not FilteredMerchantItems[index]) then Addon:RefreshFilteredItems(); end
	if(FilteredMerchantItems[index]) then
		return _ShowMerchantSellCursor(FilteredMerchantItems[index]);
	end
end

_G.GetMerchantItemCostInfo = function(index)
	if(not index) then return end
	
	if(not FilteredMerchantItems[index]) then Addon:RefreshFilteredItems(); end
	if(#FilteredMerchantItems == 0) then return end
	
	return _GetMerchantItemCostInfo(FilteredMerchantItems[index]);
end

_G.GetMerchantItemCostItem = function(index, itemIndex)
	if(not index) then return end
	
	if(not FilteredMerchantItems[index]) then Addon:RefreshFilteredItems(); end
	if(#FilteredMerchantItems == 0) then return end
	
	return _GetMerchantItemCostItem(FilteredMerchantItems[index], itemIndex);
end

-- Midnight's MerchantFrame_UpdateMerchantInfo / MerchantItemButton_OnClick
-- call C_MerchantFrame.GetItemInfo(index) directly instead of the _G global,
-- so the button visuals and click handler bypass our _G override. Redirect
-- the C_API too so display, tooltip, and purchase all see filtered items.
if _C_MerchantFrame_GetItemInfo then
	C_MerchantFrame.GetItemInfo = function(index)
		if(not index) then return end

		if(not FilteredMerchantItems[index]) then Addon:RefreshFilteredItems(); end
		if(#FilteredMerchantItems == 0) then return end
		if(not FilteredMerchantItems[index]) then return end

		return _C_MerchantFrame_GetItemInfo(FilteredMerchantItems[index]);
	end
end

-- C_MerchantFrame.IsMerchantItemRefundable is also called with display index
-- (MerchantFrame.lua:345) and needs the same redirect so refund prompts match
-- the visible item.
if C_MerchantFrame and C_MerchantFrame.IsMerchantItemRefundable then
	local _IsMerchantItemRefundable = C_MerchantFrame.IsMerchantItemRefundable;
	C_MerchantFrame.IsMerchantItemRefundable = function(index)
		if(not index) then return end
		if(not FilteredMerchantItems[index]) then Addon:RefreshFilteredItems(); end
		if(not FilteredMerchantItems[index]) then return _IsMerchantItemRefundable(index); end
		return _IsMerchantItemRefundable(FilteredMerchantItems[index]);
	end
end

_G.GetMerchantItemLink = function(index)
	if(not index) then return end
	
	if(not FilteredMerchantItems[index]) then Addon:RefreshFilteredItems(); end
	if(FilteredMerchantItems[index]) then
		return _GetMerchantItemLink(FilteredMerchantItems[index]);
	end
end

_G.GetMerchantItemMaxStack = function(index)
	if(not index) then return end
	
	if(not FilteredMerchantItems[index]) then Addon:RefreshFilteredItems(); end
	if(#FilteredMerchantItems == 0) then return end
	
	return _GetMerchantItemMaxStack(FilteredMerchantItems[index]);
end

_G.GetMerchantNumItems = function()
	if(not FilteredMerchantItems or #FilteredMerchantItems == 0) then Addon:RefreshFilteredItems(); end
	return #FilteredMerchantItems;
end

-- Midnight's MerchantFrame_UpdateMerchantInfo calls C_MerchantFrame.GetNumItems()
-- directly instead of the _G global, bypassing our override above. Wrap it so
-- Blizzard only shows as many buttons as the filter reports.
if C_MerchantFrame and C_MerchantFrame.GetNumItems then
	C_MerchantFrame.GetNumItems = function()
		if(not FilteredMerchantItems or #FilteredMerchantItems == 0) then Addon:RefreshFilteredItems(); end
		return #FilteredMerchantItems;
	end
end

local GOLD_PRICE_PATTERN = "(%d+)g";
local SILVER_PRICE_PATTERN = "(%d?%d)s";
local COPPER_PRICE_PATTERN = "(%d?%d)c";

function Addon:ParseGoldString(str)
	local money = str;
	
	local gold = strmatch(money, GOLD_PRICE_PATTERN);
	gold = gold and tonumber((gsub(gold, "%D", "")));
	
	local silver = strmatch(money, SILVER_PRICE_PATTERN);
	silver = silver and tonumber((gsub(silver, "%D", "")));
	
	local copper = strmatch(money, COPPER_PRICE_PATTERN);
	copper = copper and tonumber((gsub(copper, "%D", "")));
	
	if(not gold and not silver and not copper) then return nil; end
	
	local total = (gold or 0) * 10000 + 
				  math.min(99, silver or 0) * 100 +
				  math.min(99, copper or 0);
	
	return total, gold, silver, copper;
end

local ITEM_LINK_TYPE_ITEM        = 0x1;
local ITEM_LINK_TYPE_CURRENCY    = 0x2;
local ITEM_LINK_TYPE_BATTLEPET   = 0x3;
local ITEM_LINK_TYPE_UNKNOWN     = 0xF;

local ITEM_LINK_TYPES = {
	["item"]        = ITEM_LINK_TYPE_ITEM,
	["currency"]    = ITEM_LINK_TYPE_CURRENCY,
	["battlepet"]   = ITEM_LINK_TYPE_BATTLEPET,
	[0]             = ITEM_LINK_TYPE_UNKNOWN,
}

function Addon:GetItemLinkInfo(itemLink)
	if(not itemLink) then return end
	local itemType, itemID = itemLink:match("|H(.-):(%d+)");
	return ITEM_LINK_TYPES[itemType or 0] or ITEM_LINK_TYPE_UNKNOWN, tonumber(itemID), itemType;
end

local GT_PATTERN = ">";
local GTE_PATTERN = ">=";
local LT_PATTERN = "<";
local LTE_PATTERN = "<=";

local MONEY_EQ_PATTERN = "(.+)g?s?c?";
local MONEY_GT_PATTERN  = GT_PATTERN .. MONEY_EQ_PATTERN;
local MONEY_GTE_PATTERN = GTE_PATTERN .. MONEY_EQ_PATTERN;
local MONEY_LT_PATTERN  = LT_PATTERN .. MONEY_EQ_PATTERN;
local MONEY_LTE_PATTERN = LTE_PATTERN .. MONEY_EQ_PATTERN;

local ILVL_EQ_PATTERN  = "i(%d+)";
local ILVL_GT_PATTERN  = GT_PATTERN .. ILVL_EQ_PATTERN;
local ILVL_GTE_PATTERN = GTE_PATTERN .. ILVL_EQ_PATTERN;
local ILVL_LT_PATTERN  = LT_PATTERN .. ILVL_EQ_PATTERN;
local ILVL_LTE_PATTERN = LTE_PATTERN .. ILVL_EQ_PATTERN;

local RLVL_EQ_PATTERN  = "r(%d+)";
local RLVL_GT_PATTERN  = GT_PATTERN .. RLVL_EQ_PATTERN;
local RLVL_GTE_PATTERN = GTE_PATTERN .. RLVL_EQ_PATTERN;
local RLVL_LT_PATTERN  = LT_PATTERN .. RLVL_EQ_PATTERN;
local RLVL_LTE_PATTERN = LTE_PATTERN .. RLVL_EQ_PATTERN;

local ITEMID_PATTERN  = "id(%d+)";

local COMPARISONS = {
	GT  = function(a, b) return a > b end,
	GTE = function(a, b) return a >= b end,
	LT  = function(a, b) return a < b end,
	LTE = function(a, b) return a <= b end,
	EQ  = function(a, b) return a == b end,
};

local VALUE_TYPE_ITEM_ID 	= 1;
local VALUE_TYPE_RLVL 		= 2;
local VALUE_TYPE_ILVL 		= 3;
local VALUE_TYPE_MONEY 		= 4;

local VALUE_FILTERS = {
	{ type = VALUE_TYPE_ITEM_ID, pattern = ITEMID_PATTERN, func = COMPARISONS.EQ },

	{ type = VALUE_TYPE_RLVL, pattern = RLVL_GTE_PATTERN, func = COMPARISONS.GTE },
	{ type = VALUE_TYPE_RLVL, pattern = RLVL_LTE_PATTERN, func = COMPARISONS.LTE },
	{ type = VALUE_TYPE_RLVL, pattern = RLVL_GT_PATTERN,  func = COMPARISONS.GT },
	{ type = VALUE_TYPE_RLVL, pattern = RLVL_LT_PATTERN,  func = COMPARISONS.LT },
	{ type = VALUE_TYPE_RLVL, pattern = RLVL_EQ_PATTERN,  func = COMPARISONS.EQ },
	
	{ type = VALUE_TYPE_ILVL, pattern = ILVL_GTE_PATTERN, func = COMPARISONS.GTE },
	{ type = VALUE_TYPE_ILVL, pattern = ILVL_LTE_PATTERN, func = COMPARISONS.LTE },
	{ type = VALUE_TYPE_ILVL, pattern = ILVL_GT_PATTERN,  func = COMPARISONS.GT },
	{ type = VALUE_TYPE_ILVL, pattern = ILVL_LT_PATTERN,  func = COMPARISONS.LT },
	{ type = VALUE_TYPE_ILVL, pattern = ILVL_EQ_PATTERN,  func = COMPARISONS.EQ },
	
	{ type = VALUE_TYPE_MONEY, pattern = MONEY_GTE_PATTERN, func = COMPARISONS.GTE },
	{ type = VALUE_TYPE_MONEY, pattern = MONEY_LTE_PATTERN, func = COMPARISONS.LTE },
	{ type = VALUE_TYPE_MONEY, pattern = MONEY_GT_PATTERN,  func = COMPARISONS.GT },
	{ type = VALUE_TYPE_MONEY, pattern = MONEY_LT_PATTERN,  func = COMPARISONS.LT },
	{ type = VALUE_TYPE_MONEY, pattern = MONEY_EQ_PATTERN,  func = COMPARISONS.EQ },
};

function Addon:GetQualityIndex(token)
	local token = string.lower(token);
	
	for quality = 0, 7 do
		local qualityString = string.lower(_G["ITEM_QUALITY" .. quality .. "_DESC"]);
		if(token == qualityString) then
			return quality;
		end
	end
	
	return nil;
end

local cachedStrings = {};
function Addon:MakeTooltipString(itemLink)
	if(not itemLink) then return "" end
	if(cachedStrings[itemLink]) then return cachedStrings[itemLink] end
	
	DjinnisVendorerTooltip:Hide();
	DjinnisVendorerTooltip:SetOwner(UIParent, "ANCHOR_NONE", 99999, 0);
	DjinnisVendorerTooltip:SetHyperlink(itemLink);
	local numLines = DjinnisVendorerTooltip:NumLines();
	
	local string = "";
	
	for line = 2, numLines do
		local left = _G["DjinnisVendorerTooltipTextLeft" .. line];
		local right = _G["DjinnisVendorerTooltipTextRight" .. line];
		
		if(left and left:GetText()) then
			string = string .. " " .. strtrim(left:GetText());
		end
		
		if(right and right:GetText()) then
			string = string .. " " .. strtrim(right:GetText());
		end
	end
	
	cachedStrings[itemLink] = strtrim(string.lower(string));
	return cachedStrings[itemLink];
end

local TOKEN_OPERATORS = {
	{
		key = "gte",
		pattern = "^(" .. GTE_PATTERN .. ")(.*)",
		func = COMPARISONS.GTE,
	},
	{
		key = "gt",
		pattern = "^(" .. GT_PATTERN .. ")(.*)",
		func = COMPARISONS.GT,
	},
	{
		key = "lte",
		pattern = "^(" .. LTE_PATTERN .. ")(.*)",
		func = COMPARISONS.LTE,
	},
	{
		key = "lt",
		pattern = "^(" .. LT_PATTERN .. ")(.*)",
		func = COMPARISONS.LT,
	},
	{
		key = "exact",
		pattern = "^(%+)(.*)",
	},
	{
		key = "negated",
		pattern = "^(%!)(.*)",
	},
	{
		key = "negated",
		pattern = "^(%-)(.*)",
	},
};

function Addon:GenerateTokens(text)
	local tokens = {};
	
	local openQuote = false;
	for _, rawtoken in pairs({ strsplit(" ", text) }) do
		local operator, token, tokendata;
		for _, data in ipairs(TOKEN_OPERATORS) do
			operator, token = string.match(rawtoken, data.pattern);
			if(operator and token) then
				tokendata = data;
				break;
			end
		end
		
		if(not tokendata) then
			token = rawtoken;
		end
		
		if(token and token ~= "") then
			if(not openQuote and string.match(token, "%b\"\"")) then
				tinsert(tokens, {
					token = string.sub(token, 2, -2),
				});
			elseif(not openQuote and string.sub(token, 1, 1) == "\"") then
				openQuote = true;
				tinsert(tokens, {
					token = string.sub(token, 2),
				});
			elseif(openQuote and string.sub(token, -1) == "\"") then
				openQuote = false;
				tokens[#tokens].token = tokens[#tokens].token .. " " .. string.sub(token, 0, -2);
			elseif(openQuote) then
				tokens[#tokens].token = tokens[#tokens].token .. " " .. token;
			else
				tinsert(tokens, {
					token = token,
				});
			end
			
			if(tokendata) then
				tokens[#tokens].operator = operator;
				
				tokens[#tokens].pattern = tokendata.key;
				tokens[#tokens][tokendata.key] = true;
				
				if(tokendata.func) then
					tokens[#tokens].func = tokendata.func;
				end
			end
		end
	end
	
	return tokens;
end

function Addon:StringFind(str, search, exact)
	if(not str or not search) then return end
	
	local str = string.lower(str);
	local search = string.lower(search);
	
	if(exact) then
		return str == search;
	end
	
	-- Escape the search token so it doesn't do regex queries
	search = string.gsub(search, "[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%1");
	return strfind(str, search) ~= nil;
end

local ITEM_FILTER_CACHED = {};
Addon.FilterText = "";
function Addon:FilterItem(index)
	if(Addon.FilterText == "") then return true end
	
	local itemLink = _GetMerchantItemLink(index);
	if(not itemLink) then return true end
	
	if(ITEM_FILTER_CACHED[itemLink] and ITEM_FILTER_CACHED[itemLink][Addon.FilterText] ~= nil) then
		return ITEM_FILTER_CACHED[itemLink][Addon.FilterText];
	end
	
	local filter = true;
	
	local itemLinkTypeID, itemID, itemLinkType = Addon:GetItemLinkInfo(itemLink);
	local itemName, texture, price, quantity, numAvailable, isPurchasable, isUsable, extendedCost = _GetMerchantItemInfo(index);
	local equippable = C_Item.IsEquippableItem(itemLink);
	local _, _, itemRarity, itemLevel, itemMinLevel, itemType, itemSubType, _, itemEquipLoc = C_Item.GetItemInfo(itemLink);
	local qualityText = string.lower(_G["ITEM_QUALITY" .. (itemRarity or 1) .. "_DESC"]);
	
	local equipSlot = nil;
	if(itemEquipLoc and itemEquipLoc ~= "") then
		equipSlot = string.lower(_G[itemEquipLoc]);
	end
	
	if(price == 0 and extendedCost) then price = nil; end
	
	local canAfford, numCanAfford = Addon:CanAffordMerchantItem(index, true);
	
	local isItemKnown = Addon:IsItemKnown(itemLink);
	local transmogable, isKnownTransmog, transmogForAnotherCharacter = Addon:GetKnownTransmogInfo(itemLink);
	
	local tokens = Addon:GenerateTokens(Addon.FilterText);
	for _, tokenData in pairs(tokens) do
		local token = tokenData.token;
		local negated = tokenData.negated;
		
		local matchFound = false;
		local result = false;
		
		-- Magic words, check them first so there is no false matches
		result = result or (token == "usable" and isUsable);
		result = result or (token == "unusable" and not isUsable);
		result = result or (token == "equippable" and equippable);
		result = result or (token == "purchasable" and isPurchasable);
		result = result or (token == "unequippable" and not equippable);
		result = result or (token == "available" and numAvailable ~= 0);
		
		result = result or (token == "canafford" and canAfford);
		
		result = result or (token == "known" and isItemKnown);
		result = result or (token == "unknown" and not isItemKnown);
		
		if(not result and CanIMogIt) then
			result = result or (token == "transmogable" and transmogable);
			
			if(not negated) then
				result = result or (token == "unknowntransmog" and transmogable and not isKnownTransmog and not transmogForAnotherCharacter);
			else
				local negatedUnknown = token == "unknowntransmog" and transmogable and isKnownTransmog and not transmogForAnotherCharacter;
				if(negatedUnknown) then negated = false end
				result = result or negatedUnknown;
			end
		end
		
		if(not result) then
			local totalCoppers = Addon:ParseGoldString(token);
			for _, comparison in ipairs(VALUE_FILTERS) do
				local value = string.match((tokenData.operator or "") .. token, comparison.pattern);
				if(value ~= nil) then
					value = tonumber(value);
					
					if(comparison.type == VALUE_TYPE_ITEM_ID and value and itemID) then
						matchFound = true;
						result = comparison.func(itemID, value);
						
					elseif(comparison.type == VALUE_TYPE_RLVL and value and itemMinLevel) then
						matchFound = true;
						result = comparison.func(itemMinLevel, value);
						
					elseif(comparison.type == VALUE_TYPE_ILVL and value and itemLevel) then
						matchFound = true;
						result = comparison.func(itemLevel, value);
						
					elseif(comparison.type == VALUE_TYPE_MONEY and totalCoppers) then
						matchFound = true;
						if(price) then
							result = comparison.func(price, totalCoppers);
						else
							result = false;
						end
					end
				end
				
				if(matchFound) then break end
			end
			
			if(not matchFound) then
				local quality = Addon:GetQualityIndex(token);
				if(quality and tokenData.func) then
					result = tokenData.func(itemRarity, quality);
					matchFound = true;
				end
			end
				
			if(not matchFound) then
				result = Addon:StringFind(itemName, token, tokenData.exact);
				result = result or Addon:StringFind(qualityText, token, tokenData.exact);
				
				result = result or Addon:StringFind(itemLinkType, token, tokenData.exact);
				
				result = result or Addon:StringFind(itemType, token, tokenData.exact);
				result = result or Addon:StringFind(itemSubType, token, tokenData.exact);
				result = result or Addon:StringFind(equipSlot, token, tokenData.exact);
				
				if(not result and extendedCost) then
					local numCostItems = _GetMerchantItemCostInfo(index);
					for costItemIndex = 1, numCostItems do
						local _, costItemValue, costItemLink, currencyName = _GetMerchantItemCostItem(index, costItemIndex);
						if(costItemLink) then
							result = result or Addon:StringFind(costItemLink, token, tokenData.exact);
						elseif(currencyName) then
							result = result or Addon:StringFind(currencyName, token, tokenData.exact);
						end
					end
				end
				
				-- Tooltip search only if nothing has been matched yet
				if(not result and Addon.db.global.UseTooltipSearch and not tokenData.exact) then
					local tooltipString = Addon:MakeTooltipString(itemLink);
					result = Addon:StringFind(tooltipString, token);
				end
			end
		end
		
		if(not negated) then
			filter = filter and result;
		else
			filter = filter and not result;
		end
	end
	
	ITEM_FILTER_CACHED[itemLink] = ITEM_FILTER_CACHED[itemLink] or {};
	ITEM_FILTER_CACHED[itemLink][Addon.FilterText] = filter;
	
	return filter;
end

function Addon:GetUnfilteredMerchantNumItems()
	return _GetMerchantNumItems();
end

function Addon:GetUnfilteredMerchantItemLink(index)
	if(not index) then return end
	return _GetMerchantItemLink(index);
end

function Addon:GetUnfilteredMerchantItemInfo(index)
	if(not index) then return end
	return _GetMerchantItemInfo(index);
end

function Addon:GetUnfilteredMerchantCostInfo(index)
	if(not index) then return end
	return _GetMerchantItemCostInfo(index);
end

function Addon:GetUnfilteredMerchantCostItem(index, costIndex)
	if(not index) then return end
	return _GetMerchantItemCostItem(index, costIndex);
end

function Addon:GetUnfilteredMerchantItemMaxStack(index)
	if(not index) then return end
	return _GetMerchantItemMaxStack(index);
end

function Addon:RawBuyMerchantItem(index, amount)
	if(not index) then return end
	return _BuyMerchantItem(index, amount);
end

function Addon:RawSetTooltipMerchantItem(tooltip, index)
	if(not index or not tooltip) then return end
	return _GameTooltip_SetMerchantItem(tooltip, index);
end

-- The list view walks raw merchant indices, so it must not go through the
-- GameTooltip.SetMerchantCostItem wrapper above: that one maps a FILTERED index
-- to a raw one, and handing it a raw index maps it a second time.
function Addon:RawSetTooltipMerchantCostItem(tooltip, index, costIndex)
	if(not index or not costIndex or not tooltip) then return end
	return _GameTooltip_SetMerchantCostItem(tooltip, index, costIndex);
end

function Addon:ResetFilteredItems()
	FilteredMerchantItems = {};
end

function Addon:RefreshFilteredItems()
	Addon:ResetFilteredItems();
	
	local merchantItems = Addon:GetUnfilteredMerchantNumItems();
	for index = 1, merchantItems do 
		if(Addon.FilterText == "" or Addon:FilterItem(index)) then
			tinsert(FilteredMerchantItems, index);
		end
	end
end

function Addon:UpdateMerchantItems()
	Addon:RefreshFilteredItems();
	MerchantFrame_Update();
end

function Addon:ResetFilter(prefill)
	DjinnisVendorerFilterEditBox:SetText(prefill or "");
	SearchBoxTemplate_OnTextChanged(DjinnisVendorerFilterEditBox);
	Addon:RefreshFilter();
end

function Addon:SetFilter(text)
	if(IsControlKeyDown()) then
		Addon:ResetFilter(strtrim(DjinnisVendorerFilterEditBox:GetText() .. " " .. text));
	else
		Addon:ResetFilter(text);
	end
end

function Addon:ResetAllFilters()
	Addon.FilterText = "";
	FilteredMerchantItems = {};
end

function DjinnisVendorer_OnSearchTextChanged(self)
	SearchBoxTemplate_OnTextChanged(self);
	Addon:RefreshFilter();
end

function Addon:RefreshFilter(purge_cache)
	if(purge_cache) then
		ITEM_FILTER_CACHED = {};
		collectgarbage("collect");
	end
	
	if(DjinnisVendorerStackSplitFrame:IsPurchasing()) then
		DjinnisVendorerStackSplitFrame:CancelPurchase();
		Addon:AddMessage("Pending bulk purchase canceled due to filtering change.");
	end
	
	local oldfilter = Addon.FilterText;
	Addon.FilterText = string.trim(string.lower(DjinnisVendorerFilterEditBox:GetText()));

	if(Addon.FilterText ~= "" or oldfilter ~= "") then
		Addon.UpdatedFilteringTime = GetTime();
	end

	Addon:SavePersistedFilterText(Addon.FilterText);

	MerchantFrame.page = 1;
	Addon:UpdateMerchantItems();
end

hooksecurefunc("SetMerchantFilter", function()
	if(DjinnisVendorerStackSplitFrame:IsPurchasing()) then
		DjinnisVendorerStackSplitFrame:CancelPurchase();
		Addon:AddMessage("Pending bulk purchase canceled due to filtering change.");
	end

	Addon:UpdateMerchantItems();
end);

local function GetMerchantFilterDropdown()
	return MerchantFrame and MerchantFrame.FilterDropdown or _G.MerchantFrameLootFilter;
end

hooksecurefunc("MerchantFrame_Update", function()
	local filterDropdown = GetMerchantFilterDropdown();
	if(MerchantFrame.selectedTab == 1) then
		Addon:UpdateExtensionPanel();
		if filterDropdown then
			filterDropdown:SetPoint("TOPRIGHT", MerchantFrame, "TOPRIGHT", -35, -28);
		end
		-- ShowExtensionPanel hides these in list view; don't undo that here.
		local listOn = Addon.db and Addon.db.global and Addon.db.global.ListViewEnabled;
		if(not listOn) then
			DjinnisVendorerToggleExtensionFrameButtons:Show();
		end
		if(Addon.ApplyListViewVisibility) then Addon:ApplyListViewVisibility() end
	else
		-- Buyback tab. With list view on, keep the extension width so the
		-- buyback list view fills the same pane as the merchant list view.
		-- Without list view, revert to Blizzard's default buyback grid width.
		local listOn = Addon.db and Addon.db.global and Addon.db.global.ListViewEnabled;
		if(listOn) then
			Addon:UpdateExtensionPanel();
		else
			MerchantFrame_UpdateBuybackInfo();
			Addon:HideExtensionPanel();
		end
		if filterDropdown then
			filterDropdown:SetPoint("TOPRIGHT", MerchantFrame, "TOPRIGHT", 0, -28);
		end
		DjinnisVendorerToggleExtensionFrameButtons:Hide();
		DjinnisVendorerStackSplitFrame:Cancel();
		if(Addon.ApplyListViewVisibility) then Addon:ApplyListViewVisibility() end
	end
end);

function DjinnisVendorerFilterEditBox_OnEnter(self)
	self.hovering = true;
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
	GameTooltip:AddLine("Filter Merchant Items");
	GameTooltip:AddLine("Enter query to filter merchant goods.", 1, 1, 1);
	GameTooltip:Show();
end

function DjinnisVendorerFilterEditBox_OnLeave(self)
	GameTooltip:Hide();
	self.hovering = false;
end

local NEW_FEATURE_ICON = "|TInterface\\OptionsFrame\\UI-OptionsFrame-NewFeatureIcon:12:12:0:0:|t";
function DjinnisVendorerFilteringButton_OnEnter()
	if(DropDownList1:IsVisible()) then return end
	
	DjinnisVendorerHintTooltip:ClearLines();
	
	DjinnisVendorerHintTooltip:SetPoint("TOPLEFT", DjinnisVendorerFilteringButton, "TOPRIGHT", -7, 70);
	DjinnisVendorerHintTooltip:SetOwner(DjinnisVendorerFilteringButton, "ANCHOR_PRESERVE");
	
	DjinnisVendorerHintTooltip:AddLine("|cffffffffDjinnisVendorer Filtering Tips|r");
	if(Addon.db.global.UseTooltipSearch) then
		DjinnisVendorerHintTooltip:AddLine("You can search by item name, rarity, type, slot, required currency or tooltip text.", nil, nil, nil, true);
	else
		DjinnisVendorerHintTooltip:AddLine("You can search by item name, rarity, type, slot or required currency. Searching by tooltip text is currently disabled.", nil, nil, nil, true);
	end
	DjinnisVendorerHintTooltip:AddLine(" ");
	DjinnisVendorerHintTooltip:AddLine("You can also search for phrases by putting the words in quotes. The results will only include items with the words in the same order as the ones inside the quotes.", nil, nil, nil, true);
	DjinnisVendorerHintTooltip:AddLine(" ");
	DjinnisVendorerHintTooltip:AddLine("Any and all filters can also be negated by prefixing the query word or phrase with |cffffffff! (an exclamation mark)|r.", nil, nil, nil, true);
	DjinnisVendorerHintTooltip:AddLine(" ");
	DjinnisVendorerHintTooltip:AddLine("By prefixing a word or a phrase with |cffffffff+ (a plus)|r you can search for exact matches.", nil, nil, nil, true);
	DjinnisVendorerHintTooltip:AddLine(" ");
	
	DjinnisVendorerHintTooltip:AddLine("|cffffffffMagic words|r");
	if(not CanIMogIt) then
		DjinnisVendorerHintTooltip:AddLine("Predefined filters: |cffffffffusable, equippable, purchasable, unknown, available, canafford|r. Additional transmog filters exist if the dependency |cffffffffCan I Mog It|r is installed.", nil, nil, nil, true);
	else
		DjinnisVendorerHintTooltip:AddLine("Predefined filters: |cffffffffusable, equippable, purchasable, unknown, available, canafford, transmogable, unknowntransmog|r.", nil, nil, nil, true);
	end
	
	DjinnisVendorerHintTooltip:AddLine(" ");
	DjinnisVendorerHintTooltip:AddLine("|cffffffffBy Item ID|r");
	DjinnisVendorerHintTooltip:AddLine("Prefix a number with letters |cffffffffid|r. For example |cffffffffid|cfff361946948|r.", nil, nil, nil, true); 
	DjinnisVendorerHintTooltip:AddLine(" ");
	DjinnisVendorerHintTooltip:AddLine("|cffffffffBy Required Level|r");
	DjinnisVendorerHintTooltip:AddLine("Prefix a number with the letter |cffffffffr|r. For example |cffffffffr|cfff3619492|r.", nil, nil, nil, true);
	DjinnisVendorerHintTooltip:AddLine(" ");
	DjinnisVendorerHintTooltip:AddLine("|cffffffffBy Item Level|r");
	DjinnisVendorerHintTooltip:AddLine("Prefix a number with the letter |cffffffffi|r. For example |cffffffffi|cfff36194200|r.", nil, nil, nil, true);
	DjinnisVendorerHintTooltip:AddLine(" ");
	DjinnisVendorerHintTooltip:AddLine("|cffffffffBy Price|r");
	DjinnisVendorerHintTooltip:AddLine("Enter a price value formatted like |cffffffff12|rg|cffffffff34|rs|cffffffff56|rc.", nil, nil, nil, true);
	DjinnisVendorerHintTooltip:AddLine(" ");
	DjinnisVendorerHintTooltip:AddLine("|cffffffffSearching for Ranges of Values|r");
	DjinnisVendorerHintTooltip:AddLine("Search values can be prefixed with |cffffffff>, >=, <|r and |cffffffff<=|r to search for ranges of values.", nil, nil, nil, true);
	DjinnisVendorerHintTooltip:AddLine(" ");
	DjinnisVendorerHintTooltip:AddLine("|cffffffffFiltering Examples|r");
	DjinnisVendorerHintTooltip:AddLine("|cffffffff>=r|cfff3619490|r would find all items that require level higher than or equal to 90.", nil, nil, nil, true);
	DjinnisVendorerHintTooltip:AddLine(" ");
	DjinnisVendorerHintTooltip:AddLine("|cffffffff>=|cfff36194250g|r |cffffffff<=|cfff36194500g|r would find all items that cost between 250 and 500 gold.", nil, nil, nil, true);
	DjinnisVendorerHintTooltip:AddLine(" ");
	DjinnisVendorerHintTooltip:AddLine("|cffffffff>=|cfff36194rare|r would find all items that are rare or better.", nil, nil, nil, true);
	
	DjinnisVendorerHintTooltip:SetClampedToScreen(true);
	DjinnisVendorerHintTooltip:SetMinimumWidth(270);
	DjinnisVendorerHintTooltip:SetWidth(270);
	DjinnisVendorerHintTooltip:SetScale(0.9);
	DjinnisVendorerHintTooltip:Show();
end

function DjinnisVendorerFilteringButton_OnLeave()
	DjinnisVendorerHintTooltip:Hide();
end

function DjinnisVendorerFilteringButton_OnClick(self, button)
	DjinnisVendorerHintTooltip:Hide();
	Addon:OpenQuickFiltersMenu(self);
	
	DjinnisVendorerFilteringButtonAlert:Hide();
	Addon.db.global.FilteringButtonAlertShown = true;
end

function Addon:OpenQuickFiltersMenu(anchor)
	MenuUtil.CreateContextMenu(anchor or UIParent, function(owner, rootDescription)
		Addon:AddMenuEntries(rootDescription, Addon:GetQuickFiltersMenuData());
	end);
end

function Addon:WrapMultipleWords(words)
	if(#({strsplit(" ", words)}) > 1) then
		return "\"" .. words .. "\"";
	end
	
	return words;
end

function Addon:GetQualityString(quality)
	local color = select(4, C_Item.GetItemQualityColor(quality));
	return string.format("|c%s%s|r", color, _G["ITEM_QUALITY" .. (quality or 1) .. "_DESC"]);
end


function Addon:GetQuickFiltersMenuData()
	local data = {
		{
			text = "DjinnisVendorer Quick Filters", isTitle = true, notCheckable = true,
		},
		{
			text = "Magic Words",
			notCheckable = true,
			hasArrow = true,
			menuList = {
				{
					text = "Magic Words", isTitle = true, notCheckable = true,
				},
				{
					text = "Usable",
					notCheckable = true,
					func = function(self)
						Addon:SetFilter(string.lower(self.value));
					end,
				},
				{
					text = "Unusable",
					notCheckable = true,
					func = function(self)
						Addon:SetFilter(string.lower(self.value));
					end,
				},
				{
					text = "Equippable",
					notCheckable = true,
					func = function(self)
						Addon:SetFilter(string.lower(self.value));
					end,
				},
				{
					text = "Purchasable",
					notCheckable = true,
					func = function(self)
						Addon:SetFilter(string.lower(self.value));
					end,
				},
				{
					text = "Unequippable",
					notCheckable = true,
					func = function(self)
						Addon:SetFilter(string.lower(self.value));
					end,
				},
				{
					text = "Unknown",
					notCheckable = true,
					func = function(self)
						Addon:SetFilter(string.lower(self.value));
					end,
				},
				{
					text = "Known",
					notCheckable = true,
					func = function(self)
						Addon:SetFilter(string.lower(self.value));
					end,
				},
				{
					text = "Available",
					notCheckable = true,
					func = function(self)
						Addon:SetFilter(string.lower(self.value));
					end,
				},
				{
					text = "Can Afford",
					notCheckable = true,
					func = function(self)
						Addon:SetFilter("canafford");
					end,
				},
				{
					text = " ", isTitle = true, notCheckable = true,
				},
				{
					text = "Transmogable",
					notCheckable = true,
					func = function(self)
						Addon:SetFilter(string.lower(self.value));
					end,
					tooltipTitle = not CanIMogIt and "Requires dependency |cfffffd00Can I Mog It|r",
					tooltipOnButton = 1,
					tooltipWhileDisabled = true,
					disabled = (CanIMogIt == nil),
				},
				{
					text = "Unknown Transmog",
					notCheckable = true,
					func = function(self)
						Addon:SetFilter("unknowntransmog");
					end,
					tooltipTitle = not CanIMogIt and "Requires dependency |cfffffd00Can I Mog It|r",
					tooltipOnButton = 1,
					tooltipWhileDisabled = true,
					disabled = (CanIMogIt == nil),
				},
			},
		},
		{
			text = "Quality (exact)",
			notCheckable = true,
			hasArrow = true,
			menuList = {
				{
					text = "Quality (exact)", isTitle = true, notCheckable = true,
				},
				{
					text = Addon:GetQualityString(6),
					notCheckable = true,
					func = function(self)
						local value = Addon:WrapMultipleWords(_G["ITEM_QUALITY6_DESC"]);
						Addon:SetFilter(string.format("+%s", value));
					end,
				},
				{
					text = Addon:GetQualityString(5),
					notCheckable = true,
					func = function(self)
						local value = Addon:WrapMultipleWords(_G["ITEM_QUALITY5_DESC"]);
						Addon:SetFilter(string.format("+%s", value));
					end,
				},
				{
					text = Addon:GetQualityString(4),
					notCheckable = true,
					func = function(self)
						local value = Addon:WrapMultipleWords(_G["ITEM_QUALITY4_DESC"]);
						Addon:SetFilter(string.format("+%s", value));
					end,
				},
				{
					text = Addon:GetQualityString(3),
					notCheckable = true,
					func = function(self)
						local value = Addon:WrapMultipleWords(_G["ITEM_QUALITY3_DESC"]);
						Addon:SetFilter(string.format("+%s", value));
					end,
				},
				{
					text = Addon:GetQualityString(2),
					notCheckable = true,
					func = function(self)
						local value = Addon:WrapMultipleWords(_G["ITEM_QUALITY2_DESC"]);
						Addon:SetFilter(string.format("+%s", value));
					end,
				},
				{
					text = Addon:GetQualityString(1),
					notCheckable = true,
					func = function(self)
						local value = Addon:WrapMultipleWords(_G["ITEM_QUALITY1_DESC"]);
						Addon:SetFilter(string.format("+%s", value));
					end,
				},
				{
					text = Addon:GetQualityString(7),
					notCheckable = true,
					func = function(self)
						local value = Addon:WrapMultipleWords(_G["ITEM_QUALITY7_DESC"]);
						Addon:SetFilter(string.format("+%s", value));
					end,
				},
			},
		},
		{
			text = "Quality (minimum)",
			notCheckable = true,
			hasArrow = true,
			menuList = {
				{
					text = "Quality (minimum)", isTitle = true, notCheckable = true,
				},
				{
					text = Addon:GetQualityString(6),
					notCheckable = true,
					func = function(self)
						local value = Addon:WrapMultipleWords(_G["ITEM_QUALITY6_DESC"]);
						Addon:SetFilter(string.format(">=%s", value));
					end,
				},
				{
					text = Addon:GetQualityString(5),
					notCheckable = true,
					func = function(self)
						local value = Addon:WrapMultipleWords(_G["ITEM_QUALITY5_DESC"]);
						Addon:SetFilter(string.format(">=%s", value));
					end,
				},
				{
					text = Addon:GetQualityString(4),
					notCheckable = true,
					func = function(self)
						local value = Addon:WrapMultipleWords(_G["ITEM_QUALITY4_DESC"]);
						Addon:SetFilter(string.format(">=%s", value));
					end,
				},
				{
					text = Addon:GetQualityString(3),
					notCheckable = true,
					func = function(self)
						local value = Addon:WrapMultipleWords(_G["ITEM_QUALITY3_DESC"]);
						Addon:SetFilter(string.format(">=%s", value));
					end,
				},
				{
					text = Addon:GetQualityString(2),
					notCheckable = true,
					func = function(self)
						local value = Addon:WrapMultipleWords(_G["ITEM_QUALITY2_DESC"]);
						Addon:SetFilter(string.format(">=%s", value));
					end,
				},
				{
					text = Addon:GetQualityString(1),
					notCheckable = true,
					func = function(self)
						local value = Addon:WrapMultipleWords(_G["ITEM_QUALITY1_DESC"]);
						Addon:SetFilter(string.format(">=%s", value));
					end,
				},
			},
		},
		{
			text = "Item Slot",
			notCheckable = true,
			hasArrow = true,
			menuList = {
				{
					text = "Weapons and Off-Hand", isTitle = true, notCheckable = true,
				},
				{
					text = INVTYPE_WEAPON,
					notCheckable = true,
					func = function(self)
						local value = Addon:WrapMultipleWords(self.value);
						Addon:SetFilter(string.format("+%s", value));
					end,
				},
				{
					text = INVTYPE_2HWEAPON,
					notCheckable = true,
					func = function(self)
						local value = Addon:WrapMultipleWords(self.value);
						Addon:SetFilter(string.format("+%s", value));
					end,
				},
				{
					text = INVTYPE_WEAPONMAINHAND,
					notCheckable = true,
					func = function(self)
						local value = Addon:WrapMultipleWords(self.value);
						Addon:SetFilter(string.format("+%s", value));
					end,
				},
				{
					text = INVTYPE_WEAPONOFFHAND,
					notCheckable = true,
					func = function(self)
						local value = Addon:WrapMultipleWords(self.value);
						Addon:SetFilter(string.format("+%s", value));
					end,
				},
				{
					text = INVTYPE_RANGED,
					notCheckable = true,
					func = function(self)
						local value = Addon:WrapMultipleWords(self.value);
						Addon:SetFilter(string.format("+%s", value));
					end,
				},
				{
					text = INVTYPE_HOLDABLE,
					notCheckable = true,
					func = function(self)
						local value = Addon:WrapMultipleWords(self.value);
						Addon:SetFilter(string.format("+%s", value));
					end,
				},
				{
					text = " ", isTitle = true, notCheckable = true,
				},
				{
					text = "Armor", isTitle = true, notCheckable = true,
				},
				{
					text = INVTYPE_HEAD,
					notCheckable = true,
					func = function(self)
						local value = Addon:WrapMultipleWords(self.value);
						Addon:SetFilter(string.format("+%s", value));
					end,
				},
				{
					text = INVTYPE_SHOULDER,
					notCheckable = true,
					func = function(self)
						local value = Addon:WrapMultipleWords(self.value);
						Addon:SetFilter(string.format("+%s", value));
					end,
				},
				{
					text = INVTYPE_BACK,
					notCheckable = true,
					func = function(self)
						local value = Addon:WrapMultipleWords(self.value);
						Addon:SetFilter(string.format("+%s", value));
					end,
				},
				{
					text = INVTYPE_CHEST,
					notCheckable = true,
					func = function(self)
						local value = Addon:WrapMultipleWords(self.value);
						Addon:SetFilter(string.format("+%s", value));
					end,
				},
				{
					text = INVTYPE_WRIST,
					notCheckable = true,
					func = function(self)
						local value = Addon:WrapMultipleWords(self.value);
						Addon:SetFilter(string.format("+%s", value));
					end,
				},
				{
					text = INVTYPE_HAND,
					notCheckable = true,
					func = function(self)
						local value = Addon:WrapMultipleWords(self.value);
						Addon:SetFilter(string.format("+%s", value));
					end,
				},
				{
					text = INVTYPE_WAIST,
					notCheckable = true,
					func = function(self)
						local value = Addon:WrapMultipleWords(self.value);
						Addon:SetFilter(string.format("+%s", value));
					end,
				},
				{
					text = INVTYPE_LEGS,
					notCheckable = true,
					func = function(self)
						local value = Addon:WrapMultipleWords(self.value);
						Addon:SetFilter(string.format("+%s", value));
					end,
				},
				{
					text = INVTYPE_FEET,
					notCheckable = true,
					func = function(self)
						local value = Addon:WrapMultipleWords(self.value);
						Addon:SetFilter(string.format("+%s", value));
					end,
				},
				{
					text = " ", isTitle = true, notCheckable = true,
				},
				{
					text = "Accessories", isTitle = true, notCheckable = true,
				},
				{
					text = INVTYPE_NECK,
					notCheckable = true,
					func = function(self)
						local value = Addon:WrapMultipleWords(self.value);
						Addon:SetFilter(string.format("+%s", value));
					end,
				},
				{
					text = INVTYPE_FINGER,
					notCheckable = true,
					func = function(self)
						local value = Addon:WrapMultipleWords(self.value);
						Addon:SetFilter(string.format("+%s", value));
					end,
				},
				{
					text = INVTYPE_TRINKET,
					notCheckable = true,
					func = function(self)
						local value = Addon:WrapMultipleWords(self.value);
						Addon:SetFilter(string.format("+%s", value));
					end,
				},
				{
					text = " ", isTitle = true, notCheckable = true,
				},
				{
					text = "Other", isTitle = true, notCheckable = true,
				},
				{
					text = INVTYPE_BODY,
					notCheckable = true,
					func = function(self)
						local value = Addon:WrapMultipleWords(self.value);
						Addon:SetFilter(string.format("+%s", value));
					end,
				},
				{
					text = INVTYPE_TABARD,
					notCheckable = true,
					func = function(self)
						local value = Addon:WrapMultipleWords(self.value);
						Addon:SetFilter(string.format("+%s", value));
					end,
				},
			},
		},
		{
			text = " ", isTitle = true, notCheckable = true,
		},
		{
			text = "|cff00ff00Tip: |cffffffffCtrl click to append.|r",
			disabled = true,
			notCheckable = true,
		},
	};
	
	return data;
end
