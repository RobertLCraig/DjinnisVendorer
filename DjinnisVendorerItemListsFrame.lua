------------------------------------------------------------
-- DjinnisVendorer by Djinni, Originally created by Sonaza (https://sonaza.com) as "Vendorer"
-- Licensed under MIT License
-- See attached license text in file LICENSE
------------------------------------------------------------

local ADDON_NAME, Addon = ...;
local _;

-- UIPanelWindows["DjinnisVendorerItemListsFrame"] = { area = "left", pushable = 0 };
tinsert(UIChildWindows, "DjinnisVendorerItemListsFrame");
tinsert(UISpecialFrames, "DjinnisVendorerItemListsFrame");

function DjinnisVendorerItemListsFrameItems_Update()
	local scrollFrame = DjinnisVendorerItemListsFrameItems;
	local offset = HybridScrollFrame_GetOffset(scrollFrame);
	local buttons = scrollFrame.buttons;
	local numButtons = #buttons;
	
	local numItems = #DjinnisVendorerItemListsFrame.itemList;
	
	local button, index;
	for i = 1, numButtons do
		button = buttons[i];
		index = offset + i;
		
		button:Hide();
		
		local itemID = DjinnisVendorerItemListsFrame.itemList[index];
		
		if(itemID) then
			local name, link, rarity, iLevel, reqLevel, class, subclass, maxStack, equipSlot, texture, vendorPrice = GetItemInfo(itemID);
			
			if(name) then
				local r, g, b = GetItemQualityColor(rarity);
				local hexcolor = string.format("%02x%02x%02x", r * 255, g * 255, b * 255);
				
				button.name:SetText(("|cff%s%s|r"):format(hexcolor, name));
				button.icon.texture:SetTexture(texture);
				
				local a = 0.9;
				if(rarity == 1) then a = 0.75 end
				button.icon.rarityBorder.border:SetVertexColor(r, g, b, a);
				button.icon.rarityBorder.highlight:SetVertexColor(r, g, b);
				button.icon.rarityBorder:Show();
				
				button:Show();
				
				button.index = index;
			end
		end
	end
	
	local totalHeight = numItems * 33;
	local displayedHeight = numButtons * 33;
	HybridScrollFrame_Update(scrollFrame, totalHeight, displayedHeight);
end

function DjinnisVendorerItemListsFrame_OnLoad(self)
	local portrait = self.portrait
		or (self.PortraitContainer and self.PortraitContainer.portrait)
		or _G[self:GetName() .. "Portrait"];
	if portrait and portrait.SetTexture then
		portrait:SetTexture("Interface\\Icons\\INV_Artifact_tome02");
	end
	
	DjinnisVendorerItemListsFrame.itemList = {};
	
	DjinnisVendorerItemListsFrameItems.update = DjinnisVendorerItemListsFrameItems_Update;
	HybridScrollFrame_CreateButtons(DjinnisVendorerItemListsFrameItems, "DjinnisVendorerItemListItemButtonTemplate", 1, 0);
	DjinnisVendorerItemListsFrameItemsScrollBar.doNotHide = true;
end

function DjinnisVendorerItemListsFrame_Reanchor()
	if(DjinnisVendorerItemListsFrame.anchorframe == MerchantFrame) then
		HideUIPanel(DjinnisVendorerItemListsFrame);
	
		DjinnisVendorerItemListsFrame:ClearAllPoints();
		if(MerchantFrame:IsVisible()) then
			DjinnisVendorerItemListsFrame:SetPoint("TOPLEFT", MerchantFrame, "TOPRIGHT", 20, 0);
		else
			DjinnisVendorerItemListsFrame:SetPoint("TOP", UIParent, "CENTER", 0, 260);
		end
		
		ShowUIPanel(DjinnisVendorerItemListsFrame);
	end
end

function DjinnisVendorerItemListsFrame_OnShow(self)
	HideUIPanel(GetUIPanel("right"));
			
	if(self.titleText) then
		DjinnisVendorerItemListsFrameTitle:SetText(self.titleText);
	end
	
	if(self.itemList) then
		self.itemCount:SetText(("|cffffffff%d|r items"):format(#self.itemList));
	end
	
	self.anchorframe = MerchantFrame;
end

function DjinnisVendorerItemListItemButton_OnEnter(self)
	if(not self.index) then return end
	
	local itemID = DjinnisVendorerItemListsFrame.itemList[self.index];
	
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
	GameTooltip:SetItemByID(itemID);
	GameTooltip:Show();
	
	ShoppingTooltip1:Hide();
	ShoppingTooltip2:Hide();
end

function Addon:UpdateDjinnisVendorerItemLists()
	DjinnisVendorerItemListsFrame_ReindexItems();
	DjinnisVendorerItemListsFrameItems_Update();
end

function DjinnisVendorerItemListsFrame_ReindexItems()
	if(not DjinnisVendorerItemListsFrame.itemListOriginal) then return end
	
	local indexedItems = {};
	for itemID, status in pairs(DjinnisVendorerItemListsFrame.itemListOriginal) do
		local name = GetItemInfo(itemID);
		if(name) then -- only add found items
			if((type(status) == "number" and status > 0) or (type(status) == "boolean" and status == true)) then
				tinsert(indexedItems, itemID)
			end
		end
	end
	DjinnisVendorerItemListsFrame.itemList = indexedItems;
end

function Addon:OpenDjinnisVendorerItemListsFrame(index, title, items)
	if(DjinnisVendorerItemListsFrame:IsVisible()) then HideUIPanel(DjinnisVendorerItemListsFrame) end
	
	DjinnisVendorerItemListsFrame.index = index;
	DjinnisVendorerItemListsFrame.titleText = title;
	
	DjinnisVendorerItemListsFrame.itemListOriginal = items;
	DjinnisVendorerItemListsFrame_ReindexItems();
	
	HybridScrollFrame_SetOffset(DjinnisVendorerItemListsFrameItems, 0);
	DjinnisVendorerItemListsFrameItemsScrollBar:SetValue(0);
	DjinnisVendorerItemListsFrameItems_Update();
	
	DjinnisVendorerItemListsFrame:ClearAllPoints();
	if(MerchantFrame:IsVisible()) then
		DjinnisVendorerItemListsFrame:SetPoint("TOPLEFT", MerchantFrame, "TOPRIGHT", 20, 0);
	else
		DjinnisVendorerItemListsFrame:SetPoint("TOP", UIParent, "CENTER", 0, 260);
	end
	
	ShowUIPanel(DjinnisVendorerItemListsFrame);
end

function DjinnisVendorerItemListItemButtonRemove_OnClick(itembutton)
	local itemID = DjinnisVendorerItemListsFrame.itemList[itembutton.index];
	
	if(DjinnisVendorerItemListsFrame.index == 1) then
		DjinnisVendorerItemListsFrame.itemListOriginal[itemID] = 0;
	else
		DjinnisVendorerItemListsFrame.itemListOriginal[itemID] = nil;
	end
	
	local _, itemLink = GetItemInfo(itemID);
	Addon:AddMessage(string.format("%s removed from the list.", itemLink));
	
	Addon:UpdateDjinnisVendorerItemLists()
end

function DjinnisVendorerItemListsDragReceiver_OnShow(self)
	self.hovering = false;
	self:RegisterForClicks("LeftButtonUp");
end

function DjinnisVendorerItemListsDragReceiver_OnEnter(self)
	if(IsMouseButtonDown("LeftButton")) then
		self.hovering = true;
	end
end

function DjinnisVendorerItemListsDragReceiver_OnLeave(self)
	self.hovering = false;
end

function DjinnisVendorerItemListsDragReceiver_OnClick(self, button)
	if(button == "LeftButton") then
		if(DjinnisVendorerItemListsFrame.addItemFunction) then
			DjinnisVendorerItemListsFrame.addItemFunction();
		end
		
		DjinnisVendorerItemListsDragReceiver:Hide();
	end
end

function DjinnisVendorerItemListsDragReceiver_OnUpdate(self)
	if(not self.hovering) then return end
	
	if(not IsMouseButtonDown("LeftButton")) then
		if(DjinnisVendorerItemListsFrame.addItemFunction) then
			DjinnisVendorerItemListsFrame.addItemFunction();
		end
		
		DjinnisVendorerItemListsDragReceiver:Hide();
	end
end

