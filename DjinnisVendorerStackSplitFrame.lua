------------------------------------------------------------
-- DjinnisVendorer by Djinni, Originally created by Sonaza (https://sonaza.com) as "Vendorer"
-- Licensed under MIT License
-- See attached license text in file LICENSE
------------------------------------------------------------

local ADDON_NAME, Addon = ...;
local _;

local MAX_STACK_SIZE = 1000000;

------------------------------------------------------------
-- Filtered/raw API dispatchers. Stack split is invoked from
-- both the merchant grid (display index, filter wrapper OK)
-- and the list view (raw index, must bypass the wrapper).
------------------------------------------------------------

local function api_GetMerchantItemInfo(rawMode, index)
	if(rawMode) then return Addon:GetUnfilteredMerchantItemInfo(index) end
	return GetMerchantItemInfo(index);
end

local function api_GetMerchantItemLink(rawMode, index)
	if(rawMode) then return Addon:GetUnfilteredMerchantItemLink(index) end
	return GetMerchantItemLink(index);
end

local function api_GetMerchantItemMaxStack(rawMode, index)
	if(rawMode) then return Addon:GetUnfilteredMerchantItemMaxStack(index) end
	return GetMerchantItemMaxStack(index);
end

local function api_GetMerchantItemCostInfo(rawMode, index)
	if(rawMode) then return Addon:GetUnfilteredMerchantCostInfo(index) end
	return GetMerchantItemCostInfo(index);
end

local function api_GetMerchantItemCostItem(rawMode, index, costIndex)
	if(rawMode) then return Addon:GetUnfilteredMerchantCostItem(index, costIndex) end
	return GetMerchantItemCostItem(index, costIndex);
end

local function api_BuyMerchantItem(rawMode, index, amount)
	if(rawMode) then return Addon:RawBuyMerchantItem(index, amount) end
	return BuyMerchantItem(index, amount);
end

-- Apparently some currencies can't be used to buy anything other than the specified stack size
local CURRENCY_CANT_SPLIT = {
	[1220] = true, -- Order Resources
};

local cachedCurrencies = nil;
local function CacheCurrencies()
	if(cachedCurrencies) then return end
	cachedCurrencies = {};
	
	-- Super dirty indexing for currencies
	for currencyIndex = 1, 20000 do
		local info = C_CurrencyInfo.GetCurrencyInfo(currencyIndex);
		if (info and strlen(info.name) > 0) then
			cachedCurrencies[info.name] = currencyIndex;
		end
	end
end

DjinnisVendorerStackSplitMixin = {
	split = 1,
};

-- DjinnisVendorerStackSplitFrame uses enableKeyboard + OnKeyDown to capture digits /
-- arrows without propagation. Release keyboard while a confirmation popup is
-- up so DialogKey (and the popup's own ESC/hideOnEscape handling) can see keys.
local function OnConfirmPopupShow()
	DjinnisVendorerStackSplitFrame.okayButton:Disable();
	DjinnisVendorerStackSplitFrame:EnableKeyboard(false);
end

local function OnConfirmPopupHide()
	DjinnisVendorerStackSplitFrame.okayButton:Enable();
	DjinnisVendorerStackSplitFrame:EnableKeyboard(true);
end

StaticPopupDialogs["DJINNISVENDORER_CONFIRM_PURCHASE_TOKEN_ITEM"] = {
	text = CONFIRM_PURCHASE_TOKEN_ITEM,
	button1 = YES,
	button2 = NO,
	OnAccept = function()
		DjinnisVendorerStackSplitFrame:DoPurchase();
	end,
	OnCancel = function()
		DjinnisVendorerStackSplitFrame.waiting:Hide();
	end,
	OnShow = OnConfirmPopupShow,
	OnHide = OnConfirmPopupHide,
	timeout = 0,
	hideOnEscape = 1,
	hasItemFrame = 1,
}

StaticPopupDialogs["DJINNISVENDORER_CONFIRM_PURCHASE_NONREFUNDABLE_ITEM"] = {
	text = CONFIRM_PURCHASE_NONREFUNDABLE_ITEM,
	button1 = YES,
	button2 = NO,
	OnAccept = function()
		DjinnisVendorerStackSplitFrame:DoPurchase();
	end,
	OnCancel = function()
		DjinnisVendorerStackSplitFrame.waiting:Hide();
	end,
	OnShow = OnConfirmPopupShow,
	OnHide = OnConfirmPopupHide,
	timeout = 0,
	hideOnEscape = 1,
	hasItemFrame = 1,
}

StaticPopupDialogs["DJINNISVENDORER_CONFIRM_HIGH_COST_ITEM"] = {
	text = CONFIRM_HIGH_COST_ITEM,
	button1 = YES,
	button2 = NO,
	OnAccept = function()
		DjinnisVendorerStackSplitFrame:DoPurchase();
	end,
	OnCancel = function()
		DjinnisVendorerStackSplitFrame.waiting:Hide();
	end,
	OnShow = function(self)
		-- Mainline StaticPopup may not auto-create the money frame for this
		-- dialog any more; defensively look it up under both casings.
		local moneyFrame = self.moneyFrame or self.MoneyFrame;
		if(moneyFrame) then
			MoneyFrame_Update(moneyFrame, MerchantFrame.price * MerchantFrame.count);
		end
		OnConfirmPopupShow();
	end,
	OnHide = OnConfirmPopupHide,
	timeout = 0,
	hideOnEscape = 1,
	hasMoneyFrame = 1,
	hasItemFrame = 1,
};

function DjinnisVendorerStackSplitMixin:OnHide()
	self.itemButton.hasStackSplit = 0;

	if(self.dialog and self.dialog:IsVisible()) then
		self.dialog:Hide();
	end
	self.dialog = nil;

	self.waiting:Hide();

	-- Defensive: clear purchasing state so the next Open() isn't dead-in-the-water
	-- if a prior purchase never received its completion events (merchant closed
	-- mid-buy, API changed, etc).
	self.purchasing = false;
	self.purchaseInfo = nil;
	self:UnregisterEvent("BAG_UPDATE_DELAYED");
	self:UnregisterEvent("CURRENCY_DISPLAY_UPDATE");
end

function DjinnisVendorerStackSplitMixin:Decrement()
	if(self.purchasing) then return end
	self.split = math.max(self.minSplit, self.split - self.minSplit);
	self:Update();
end

function DjinnisVendorerStackSplitMixin:Increment()
	if(self.purchasing) then return end
	self.split = math.min(self.maxPurchase, self.split + self.minSplit);
	self:Update();
end

function DjinnisVendorerStackSplitMixin:Update()
	self.split = math.max(self.minSplit, math.min(self.maxPurchase, self.split));
	
	if(self.split == self.minSplit) then
		self.leftButton:Disable();
	else
		self.leftButton:Enable();
	end
	
	if(self.split == self.maxPurchase) then
		self.rightButton:Disable();
	else
		self.rightButton:Enable();
	end
	
	if(self.canAfford == 1) then
		self.setMax:Disable();
	else
		self.setMax:Enable();
	end
	
	local numItems = self.split;
	if(self.maxStack > 1) then
		self.splitNumber:SetText(("%s |cff777777/ %d|r"):format(BreakUpLargeNumbers(numItems), self.maxStack));
	else
		self.splitNumber:SetText(BreakUpLargeNumbers(numItems));
	end
	
	self.totalCost:SetText(self:GetTotalPriceString());
end

local ICON_PATTERN = "|T%s:12:12:0:0|t";
function DjinnisVendorerStackSplitMixin:GetTotalPriceString(index, quantity)
	index = index or self.merchantItemIndex;
	quantity = quantity or self.split;
	local rawMode = self.rawMode;

	local text = "";

	local _, _, price, stackCount, _, _, _, extendedCost = api_GetMerchantItemInfo(rawMode, index);
	if(price and price > 0) then
		local totalPrice = math.ceil((price / stackCount) * quantity);
		text = ("%s %s "):format(text, GetCoinTextureString(totalPrice, 12));
	end

	if(extendedCost) then
		local currencyCount = api_GetMerchantItemCostInfo(rawMode, index);
		for currencyIndex = 1, currencyCount do
			local itemTexture, requiredCurrency = api_GetMerchantItemCostItem(rawMode, index, currencyIndex);
			local totalPrice = (requiredCurrency / stackCount) * quantity;
			text = ("%s %s%s"):format(text, BreakUpLargeNumbers(totalPrice), ICON_PATTERN:format(itemTexture));
		end
	end

	return strtrim(text);
end

function DjinnisVendorerStackSplitMixin:Okay()
	if(self.purchasing) then return end

	self.waiting:Show();

	if(self.itemButton.extendedCost) then
		self:ConfirmExtendedItemCost(self.itemButton, self.split);
	elseif(self.itemButton.showNonrefundablePrompt) then
		self:ConfirmExtendedItemCost(self.itemButton, self.split);
	elseif(self.split > 0) then
		if(self.split > self.maxStack) then
			self:ConfirmHighCostItem(self.itemButton, self.split);
		else
			api_BuyMerchantItem(self.rawMode, self.merchantItemIndex, self.split);
			self:Cancel();
		end
	end
end

function DjinnisVendorerStackSplitMixin:ConfirmExtendedItemCost(itemButton, numToPurchase)
	local stackCount = itemButton.count or 1;
	numToPurchase = numToPurchase or stackCount;
	local rawMode = self.rawMode;

	local index = itemButton:GetID();
	local buyingMultipleStacks = numToPurchase > self.maxStack;

	if(api_GetMerchantItemCostInfo(rawMode, index) == 0 and not itemButton.showNonrefundablePrompt) then
		if(buyingMultipleStacks) then
			self:ConfirmHighCostItem(itemButton, numToPurchase);
		else
			api_BuyMerchantItem(rawMode, index, numToPurchase);
		end
		return;
	end
	
	self.purchaseInfo = {
		remaining = numToPurchase,
		itemIndex = index,
		stackSize = self.maxStack,
	};
	MerchantFrame.itemIndex = index;
	MerchantFrame.count = numToPurchase;
	
	local itemsString = self:GetTotalPriceString(index, numToPurchase);
	
	local itemName;
	local itemQuality = 1;
	local _;
	local r, g, b = 1, 1, 1;
	local specs = {};
	if(itemButton.link) then
		itemName, _, itemQuality = GetItemInfo(itemButton.link);
	end

	if ( itemName ) then
		--It's an item
		r, g, b = GetItemQualityColor(itemQuality); 
		specs = GetItemSpecInfo(itemButton.link, specs);
	else
		--Not an item. Could be currency or something. Just use what's on the button.
		itemName = itemButton.name;
		r, g, b = GetItemQualityColor(1); 
	end
	
	local specText;
	if (specs and #specs > 0) then
		local specName, specIcon;
		specText = "\n\n";
		for i=1, #specs do
			_, specName, _, specIcon = GetSpecializationInfoByID(specs[i], UnitSex("player"));
			specText = specText.." |T"..specIcon..":0:0:0:-1|t "..NORMAL_FONT_COLOR_CODE..specName..FONT_COLOR_CODE_CLOSE;
			if (i < #specs) then
				specText = specText..PLAYER_LIST_DELIMITER
			end
		end
	else
		specText = "";
	end
	
	local itemInfo = {
		["texture"] = itemButton.texture, ["name"] = itemName, ["color"] = {r, g, b, 1}, 
		["link"] = itemButton.link, ["index"] = index, ["count"] = numToPurchase
	};
	
	if (itemButton.showNonrefundablePrompt) then
		self.dialog = StaticPopup_Show("DJINNISVENDORER_CONFIRM_PURCHASE_NONREFUNDABLE_ITEM", itemsString, specText, itemInfo);
	else
		self.dialog = StaticPopup_Show("DJINNISVENDORER_CONFIRM_PURCHASE_TOKEN_ITEM", itemsString, specText, itemInfo);
	end
end

function DjinnisVendorerStackSplitMixin:ConfirmHighCostItem(itemButton, quantity)
	local stackCount = itemButton.count or 1;
	
	quantity = (quantity or 1);
	local index = itemButton:GetID();
	local itemName, _, quality = GetItemInfo(itemButton.link);
	
	local r, g, b = GetItemQualityColor(quality);
	
	self.purchaseInfo = {
		remaining = quantity,
		itemIndex = index,
		stackSize = self.maxStack,
	};
	MerchantFrame.itemIndex = index;
	MerchantFrame.count = quantity;
	MerchantFrame.price = itemButton.price / stackCount;
	
	self.dialog = StaticPopup_Show("DJINNISVENDORER_CONFIRM_HIGH_COST_ITEM",
		itemButton.link, nil, 
		{
			["texture"] = itemButton.texture, ["name"] = itemName, ["color"] = {r, g, b, 1}, 
			["link"] = itemButton.link, ["index"] = index, ["count"] = quantity
		}
	);
end

function DjinnisVendorerStackSplitMixin:DoPurchase()
	if(self.purchasing) then return end
	if(not self.purchaseInfo) then
		error("Purchase info is missing", 2);
	end
	
	if(self.purchaseInfo.remaining > 0) then
		self.purchasing = true;
		self.purchaseIterations = 0;
		
		self:SetScript("OnChar", nil);
		self:SetScript("OnKeyDown", nil);
		
		self:RegisterEvent("BAG_UPDATE_DELAYED");
		self:RegisterEvent("CURRENCY_DISPLAY_UPDATE");
		local remaining = self:PurchaseNext();
	else
		self:Cancel();
	end
end

function DjinnisVendorerStackSplitMixin:PurchaseNext()
	if(not self.purchasing) then return -1 end
	
	-- Number of stacks safe to purchase at a time (without causing "item is busy" errors)
	local maximumStacksToPurchase = 10;
	if(Addon.db.global.UseSafePurchase) then
		maximumStacksToPurchase = 1;
	end
	
	local remaining = math.min(self.purchaseInfo.remaining, maximumStacksToPurchase * self.purchaseInfo.stackSize);
	while(remaining > 0) do
		local quantity = math.min(remaining, self.purchaseInfo.stackSize);
		api_BuyMerchantItem(self.rawMode, self.merchantItemIndex, quantity);

		remaining = remaining - quantity;
		self.purchaseInfo.remaining = self.purchaseInfo.remaining - quantity;
	end
	
	self.purchaseIterations = self.purchaseIterations + 1;
	
	return self.purchaseInfo.remaining;
end

function DjinnisVendorerStackSplitMixin:IsPurchasing()
	return self.purchasing;
end

function DjinnisVendorerStackSplitMixin:CancelPurchase()
	self.waiting:Hide();
	self.purchasing = false;
	self.purchaseInfo = nil;
	self:UnregisterEvent("BAG_UPDATE_DELAYED");
	self:UnregisterEvent("CURRENCY_DISPLAY_UPDATE");
	self:Cancel();
end

function DjinnisVendorerStackSplitMixin:OnEvent(event, ...)
	if(self.purchaseInfo.remaining > 0) then
		local remaining = self:PurchaseNext();
		
		if(remaining <= 0) then
			self:CancelPurchase();
			
			if(self.purchaseIterations > 1) then
				C_Timer.After(0.5, function()
					Addon:AddMessage("Purchase finished.");
				end);
			end
		end
	else
		self:CancelPurchase();
	end
end

function DjinnisVendorerStackSplitMixin:Cancel()
	self.waiting:Hide();
	self:Hide();
end

hooksecurefunc("MerchantPrevPageButton_OnClick", function() DjinnisVendorerStackSplitFrame:Cancel() end);
hooksecurefunc("MerchantNextPageButton_OnClick", function() DjinnisVendorerStackSplitFrame:Cancel() end);

function DjinnisVendorerStackSplitFrameStackButton_OnClick(self, button)
	local threshold = DjinnisVendorerStackSplitFrame.maxStack;
	if(IsControlKeyDown()) then
		threshold = math.floor(threshold * 0.25);
	end
	DjinnisVendorerStackSplitFrame:Stack(button, threshold);
end

function DjinnisVendorerStackSplitMixin:Stack(button_or_delta, threshold)
	if(self.purchasing) then return end
	
	threshold = math.max(1, math.min(self.maxStack, threshold or self.maxStack));
	
	if(button_or_delta == "LeftButton" or button_or_delta == 1) then
		self.split = math.ceil((self.split + self.minSplit) / threshold) * threshold;
	elseif(button_or_delta == "RightButton" or button_or_delta == -1) then
		self.split = math.floor((self.split - self.minSplit) / threshold) * threshold;
	end
	
	self:Update();
end

function DjinnisVendorerStackSplitFrameStackButton_OnEnter(self)
	GameTooltip:SetOwner(DjinnisVendorerStackSplitFrame, "ANCHOR_NONE");
	GameTooltip:SetPoint("TOPLEFT", DjinnisVendorerStackSplitFrame, "TOPRIGHT", 5, 0);
	
	GameTooltip:AddLine("Stack");
	GameTooltip:AddLine("Increases or decreases current number of items a full stack at a time.", 1, 1, 1, true);
	GameTooltip:AddLine(" ");
	GameTooltip:AddLine("You can also do the same by holding down shift and using the mouse wheel. Holding down control instead uses quarter stack increments.", 1, 1, 1, true);
	GameTooltip:AddLine(" ");
	GameTooltip:AddLine("|cff00ff00Left-click|r  Increase by a full stack", 1, 1, 1, true);
	GameTooltip:AddLine("|cff00ff00Right-click|r  Decrease by a full stack", 1, 1, 1, true);
	GameTooltip:AddLine("|cff00ff00Hold Ctrl with either|r  By a quarter stack instead", 1, 1, 1, true);
	
	GameTooltip:Show();
end

function DjinnisVendorerStackSplitMixin:SetMax(button)
	if(self.purchasing) then return end
	
	if(button == "LeftButton") then
		self.split = self.maxPurchase;
		if(IsControlKeyDown()) then
			self.split = math.floor(self.maxPurchase * 0.5);
		end
	elseif(button == "RightButton") then
		self.split = 1;
	end
	
	self:Update();
end

function DjinnisVendorerStackSplitFrameSetMaxButton_OnEnter(self)
	GameTooltip:SetOwner(DjinnisVendorerStackSplitFrame, "ANCHOR_NONE");
	GameTooltip:SetPoint("TOPLEFT", DjinnisVendorerStackSplitFrame, "TOPRIGHT", 5, 0);
	
	local frame = DjinnisVendorerStackSplitFrame;
	
	GameTooltip:AddLine("Set Max");
	GameTooltip:AddLine("Quickly set the number of items to the maximum you can fit, afford or are available.", 1, 1, 1, true);
	GameTooltip:AddLine(" ");
	if(frame.maxPurchase ~= MAX_STACK_SIZE) then
		if(frame.maxPurchase == frame.canFitItems) then
			GameTooltip:AddLine(("You can currently fit at most |cffffd200%s|r stacks or |cffffd200%s|r items."):format(frame.canFitStacks, BreakUpLargeNumbers(frame.canFitItems)), 1, 1, 1, true);
		elseif(frame.maxPurchase == frame.canAfford) then
			GameTooltip:AddLine(("You can currently afford at most |cffffd200%s|r items."):format(BreakUpLargeNumbers(frame.canAfford)), 1, 1, 1, true);
		elseif(frame.maxPurchase == frame.numCanBuyMore) then
			GameTooltip:AddLine(("You can currently hold at most |cffffd200%s|r items more."):format(BreakUpLargeNumbers(frame.numCanBuyMore)), 1, 1, 1, true);
		elseif(frame.maxPurchase == frame.numAvailable) then
			GameTooltip:AddLine(("There is up to |cffffd200%s|r items available."):format(BreakUpLargeNumbers(frame.numAvailable)), 1, 1, 1, true);
		end
		GameTooltip:AddLine(" ");
	end
	GameTooltip:AddLine("|cff00ff00Left-click|r  Set to maximum", 1, 1, 1, true);
	GameTooltip:AddLine("|cff00ff00Ctrl Left-click|r  Set to half", 1, 1, 1, true);
	GameTooltip:AddLine("|cff00ff00Right-click|r  Set to minimum", 1, 1, 1, true);
	
	GameTooltip:Show();
end

function DjinnisVendorerStackSplitMixin:OnMouseWheel(delta)
	if(self.purchasing) then return end
	
	if(IsShiftKeyDown()) then
		self:Stack(delta);
	elseif(IsControlKeyDown()) then
		self:Stack(delta, self.maxStack * 0.25);
	else
		self.split = self.split + delta * self.minSplit;
		self:Update();
	end
end

function Addon:GetProperItemCount(item)
	if(not item) then return 0 end
	
	local _, itemLink = GetItemInfo(item);
	local itemCount = GetItemCount(itemLink);
	
	if REAGENTBANK_CONTAINER then
		local numSlots = GetContainerNumSlots(REAGENTBANK_CONTAINER) or 0;
		for slotIndex = 1, numSlots do
			local _, containerItemCount, _, _, _, _, containerItemLink = GetContainerItemInfo(REAGENTBANK_CONTAINER, slotIndex);
			if(itemLink and containerItemLink == itemLink) then
				itemCount = itemCount + containerItemCount;
			end
		end
	end
	
	return itemCount;
end

function DjinnisVendorerStackSplitMixin:Open(merchantItemIndex, parent, anchor, rawMode)
	-- Hard reset: if a prior purchase left us in a zombie state, don't refuse to open.
	self.purchasing = false;
	self.purchaseInfo = nil;

	self:SetScript("OnChar", self.OnChar);
	self:SetScript("OnKeyDown", self.OnKeyDown);

	CacheCurrencies();

	self.rawMode = rawMode and true or false;
	self.merchantItemIndex = merchantItemIndex;
	self.split = 1;

	local maxStack = api_GetMerchantItemMaxStack(self.rawMode, merchantItemIndex);
	local _, _, price, stackCount, numAvailable, isPurchasable, _, extendedCost = api_GetMerchantItemInfo(self.rawMode, merchantItemIndex);
	if(not isPurchasable) then return end

	local itemLink = api_GetMerchantItemLink(self.rawMode, merchantItemIndex);

	self.minSplit = Addon:GetMinimumSplitSize(merchantItemIndex, self.rawMode);
	self.split = stackCount or 1;

	if(numAvailable < 0) then numAvailable = MAX_STACK_SIZE end

	local isUnique = select(8, Addon:GetItemTooltipInfo(itemLink));
	if(isUnique) then return end

	local _, canAfford = Addon:CanAffordMerchantItem(merchantItemIndex, self.rawMode);
	if(canAfford == 0) then return end

	self.numCanBuyMore = MAX_STACK_SIZE;

	local itemlink = api_GetMerchantItemLink(self.rawMode, merchantItemIndex);
	if(Addon:IsCurrencyItem(itemlink)) then
		local _, info = Addon:GetCurrencyInfo(itemlink);
		if(info and info.maxQuantity > 0) then
			self.numCanBuyMore = info.maxQuantity - info.quantity;
		end
		if(info and info.maxWeeklyQuantity > 0) then
			self.numCanBuyMore = math.min(self.numCanBuyMore, info.maxWeeklyQuantity - info.quantityEarnedThisWeek);
		end
	end

	parent.hasStackSplit = 1;
	
	self.purchaseInfo   = nil;
	
	self.itemButton     = parent;
	self.canAfford      = canAfford;
	self.maxStack       = maxStack;
	self.canFitItems, self.canFitStacks = Addon:GetBagSpaceForItem(itemLink, maxStack);
	self.numAvailable   = numAvailable;
	self.maxPurchase    = math.min(canAfford, self.canFitItems, numAvailable, self.numCanBuyMore, MAX_STACK_SIZE);
	self.maxPurchase    = self.maxPurchase - (self.maxPurchase % self.minSplit);
	self.typing         = false;
	
	self.hasExtendedCost = extendedCost;
	
	self:Update();
	
	self.okayButton:Enable();
	
	self:ClearAllPoints();
	self:SetPoint("BOTTOMLEFT", parent, "TOPLEFT", 0, 0);
	self:Show();
end

local _MerchantItemButton_OnModifiedClick = MerchantItemButton_OnModifiedClick;
function MerchantItemButton_OnModifiedClick(self, button)
	if(Addon.db.global.UseImprovedStackSplit) then
		local merchantItemIndex = self:GetID();
		if(MerchantFrame.selectedTab == 1) then
			-- Is merchant frame
			if(HandleModifiedItemClick(GetMerchantItemLink(merchantItemIndex))) then
				return;
			end
			if(IsModifiedClick("SPLITSTACK")) then
				local maxStack = GetMerchantItemMaxStack(merchantItemIndex);
				local _, _, price, stackCount, _, _, _, extendedCost = GetMerchantItemInfo(merchantItemIndex);
				
				DjinnisVendorerStackSplitFrame:Open(merchantItemIndex, self);
				return;
			end
		else
			HandleModifiedItemClick(GetBuybackItemLink(merchantItemIndex));
		end
	else
		_MerchantItemButton_OnModifiedClick(self, button);
	end
end

function DjinnisVendorerStackSplitMixin:OnChar(text)
	if(self.purchasing) then return end
	if(text < "0" or text > "9") then return end

	if(not self.typing) then
		self.typing = true;
		self.split = 0;
	end

	local split = (self.split * 10) + tonumber(text);
	if(split <= self.maxPurchase) then
		self.split = split;
	end
	
	self:Update();
end

function DjinnisVendorerStackSplitMixin:OnKeyDown(key)
	if(key == "BACKSPACE" or key == "DELETE") then
		if(not self.typing or self.split == 1) then
			return;
		end

		self.split = floor(self.split / 10);
		if(self.split <= 1) then
			self.split = 1;
			self.typing = false;
		end
	elseif(key == "ENTER") then
		self:Okay();
	elseif(GetBindingFromClick(key) == "TOGGLEGAMEMENU") then
		self:Cancel();
	elseif(key == "LEFT" or key == "DOWN") then
		self:Decrement();
	elseif(key == "RIGHT" or key == "UP") then
		self:Increment();
	elseif(key == "PRINTSCREEN") then
		Screenshot();
	end
	
	self:Update();
end

function Addon:GetBagSpaceForItem(item, stackSize)
	if(not item) then return 0, 0 end

	local _, itemLink = GetItemInfo(item);
	if(not itemLink) then return 0, 0 end

	stackSize = stackSize or 1;
	if(stackSize < 1) then stackSize = 1; end

	local itemID = tonumber(itemLink:match("item:(%d+)"));

	local getFamily = GetItemFamily or (C_Item and C_Item.GetItemFamily);
	local itemFamily = (getFamily and getFamily(itemLink)) or 0;

	local totalFit = 0;
	local emptySlots = 0;
	local lastBag = (NUM_BAG_SLOTS or 4);
	for bagID = 0, lastBag do
		local bagFree, bagFamily = GetContainerNumFreeSlots(bagID);
		bagFree = bagFree or 0;
		bagFamily = bagFamily or 0;

		-- Bag accepts the item if: it's a general-purpose bag (family 0),
		-- exactly matches the item's family, or shares a family bit with it.
		if(bagFamily == 0 or bagFamily == itemFamily or bit.band(itemFamily, bagFamily) > 0) then
			emptySlots = emptySlots + bagFree;
			totalFit = totalFit + (bagFree * stackSize);

			-- Top-off room: count unused capacity in partial stacks of the same item.
			if(itemID and stackSize > 1) then
				local numSlots = GetContainerNumSlots(bagID) or 0;
				for slotIndex = 1, numSlots do
					local _, stackCount, _, _, _, _, _, _, _, slotItemID = GetContainerItemInfo(bagID, slotIndex);
					if(slotItemID == itemID and stackCount and stackCount < stackSize) then
						totalFit = totalFit + (stackSize - stackCount);
					end
				end
			end
		end
	end

	return totalFit, emptySlots;
end

function Addon:GetCurrencyInfo(currencyItemLink, currencyName)
	local currencyID = nil;
	if(currencyName) then
		CacheCurrencies();
		currencyID = cachedCurrencies[currencyName];
	elseif(currencyItemLink) then
		currencyID = strmatch(currencyItemLink, "currency:(%d+)");
	end
	if(currencyID) then
		local info = C_CurrencyInfo.GetCurrencyInfo(currencyID);
		if (info) then
			return tonumber(currencyID), info;
		end
	end
	return nil;
end

function Addon:CanAffordMerchantItem(merchantItemIndex, unfiltered)
	if(not merchantItemIndex) then return false end

	local GetMerchantItemInfo     = function(idx) return api_GetMerchantItemInfo(unfiltered, idx) end;
	local GetMerchantItemCostItem = function(idx, c) return api_GetMerchantItemCostItem(unfiltered, idx, c) end;
	local GetMerchantItemCostInfo = function(idx) return api_GetMerchantItemCostInfo(unfiltered, idx) end;

	local name, _, price, stackCount, numAvailable, isPurchasable, _, hasExtendedCost = GetMerchantItemInfo(merchantItemIndex);
	if(not name) then return false end
	
	stackCount = stackCount or 1;
	
	local numCanAfford = MAX_STACK_SIZE;
	
	if (price and price > 0) then
		numCanAfford = floor(GetMoney() / (price / stackCount));
	end
	
	local costsUnsplittable = false;
	if(hasExtendedCost) then
		local extendedCanAfford = MAX_STACK_SIZE;
		local currencyCount = GetMerchantItemCostInfo(merchantItemIndex);
		for index = 1, currencyCount do
			local itemTexture, requiredCurrency, currencyItemLink, currencyName = GetMerchantItemCostItem(merchantItemIndex, index);
			local currencyPerUnit = requiredCurrency and requiredCurrency / stackCount or 1;
			
			local currencyID, info = Addon:GetCurrencyInfo(currencyItemLink, currencyName);
			if(currencyID and info.quantity) then
				costsUnsplittable = CURRENCY_CANT_SPLIT[currencyID] == true;
				extendedCanAfford = min(extendedCanAfford, floor(info.quantity / currencyPerUnit));
			else
				local ownedCurrencyItems = Addon:GetProperItemCount(currencyItemLink);
				extendedCanAfford = min(extendedCanAfford, floor(ownedCurrencyItems / currencyPerUnit));
			end
		end
		
		numCanAfford = min(numCanAfford, extendedCanAfford);
	end
	
	if(costsUnsplittable) then
		numCanAfford = numCanAfford - (numCanAfford % stackCount);
	end
	
	return numCanAfford > 0, numCanAfford, hasExtendedCost;
end

local function gcd(m, n)
    while n ~= 0 do
        local q = m;
        m = n;
        n = q % n;
    end
    return m;
end

function Addon:GetMinimumSplitSize(merchantItemIndex, unfiltered)
	if(not merchantItemIndex) then return 1 end

	local GetMerchantItemInfo     = function(idx) return api_GetMerchantItemInfo(unfiltered, idx) end;
	local GetMerchantItemCostItem = function(idx, c) return api_GetMerchantItemCostItem(unfiltered, idx, c) end;
	local GetMerchantItemCostInfo = function(idx) return api_GetMerchantItemCostInfo(unfiltered, idx) end;

	local name, _, price, stackCount, _, _, _, hasExtendedCost = GetMerchantItemInfo(merchantItemIndex);
	if(not name) then return 1 end

	stackCount = stackCount or 1;
	if(stackCount <= 1) then return 1 end

	-- Items that only cost gold can be always split to 1 unit
	if(not hasExtendedCost and price) then return 1 end

	local minimumCurrencyAmount = 1;
	local currencyCount = GetMerchantItemCostInfo(merchantItemIndex);
	for index = 1, currencyCount do
		local _, requiredCurrency, currencyItemLink, currencyName = GetMerchantItemCostItem(merchantItemIndex, index);
		
		local currencyID = Addon:GetCurrencyInfo(currencyItemLink, currencyName);
		if(currencyID and CURRENCY_CANT_SPLIT[currencyID]) then
			return stackCount;
		end
		
		minimumCurrencyAmount = math.max(minimumCurrencyAmount, requiredCurrency);
	end
	
	return stackCount / gcd(stackCount, minimumCurrencyAmount);
end
