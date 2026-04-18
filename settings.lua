------------------------------------------------------------
-- DjinnisVendorer by Djinni, Originally created by Sonaza (https://sonaza.com) as "Vendorer"
-- Licensed under MIT License
-- See attached license text in file LICENSE
------------------------------------------------------------

local ADDON_NAME, Addon = ...;
local _;

SLASH_DJINNISVENDORER1 = "/djinnisvendorer";
SLASH_DJINNISVENDORER2 = "/djv";
SlashCmdList["DJINNISVENDORER"] = function(params)
	Addon:HandleConsole(params, strsplit(" ", strtrim(params)));
end

function Addon:HandleConsole(params, action, ...)
	if(action == "ignore") then
		local _, item = strsplit(" ", strtrim(params), 2);
		if(item) then
			local _, itemLink = GetItemInfo(item);
			if(itemLink) then
				Addon:AddItemToIgnoreList(itemLink);
			else
				Addon:AddMessage("Unable to find item \"%s\".", item);
			end
		else
			Addon:OpenIgnoredItemsListsFrame();
		end
	elseif(action == "junk") then
		local _, item = strsplit(" ", strtrim(params), 2);
		if(item) then
			local _, itemLink = GetItemInfo(item);
			if(itemLink) then
				Addon:AddItemToJunkList(itemLink);
			else
				Addon:AddMessage("Unable to find item \"%s\".", item);
			end
		else
			Addon:OpenJunkItemsListsFrame();
		end
	elseif(action == "autosell") then
		Addon.db.global.AutoSellJunk = not Addon.db.global.AutoSellJunk;
		Addon:AddMessage("Auto sell is now %s.", Addon:GetToggleStatusText(Addon.db.global.AutoSellJunk));
	elseif(action == "autorepair") then
		Addon.db.global.AutoRepair = not Addon.db.global.AutoRepair;
		Addon:AddMessage("Auto repair is now %s.", Addon:GetToggleStatusText(Addon.db.global.AutoRepair));
	elseif(action == "smartrepair") then
		Addon.db.global.SmartAutoRepair = not Addon.db.global.SmartAutoRepair;
		Addon:AddMessage("Smart auto repair is now %s.", Addon:GetToggleStatusText(Addon.db.global.SmartAutoRepair));
		if(Addon.db.global.SmartAutoRepair and not Addon.db.global.AutoRepair) then
			Addon:AddMessage("|cffffd200Note:|r While auto repair is not enabled, smart auto repair does nothing.");
		end
	elseif(action == "eqolwarn") then
		Addon.db.global.EQoLMerchantConflictAck = false;
		Addon.EQoLConflictNoticedThisSession = nil;
		Addon:AddMessage("EnhanceQoL Merchant conflict warning re-enabled. The popup will appear next time you open a merchant if the submodule is active.");
	else
		Addon:AddMessage("|cffffd200Usage|r");
		Addon:AddShortMessage("You can access DjinnisVendorer slash commands by typing |cffffd200/djinnisvendorer|r or |cffffd200/vd|r.");
		Addon:AddShortMessage("|cffffd200/djinnisvendorer|r ignore |cffaaaaaa[item]|r");
		Addon:AddShortMessage("  Opens ignored items window or add/remove item from the ignore list.");
		Addon:AddShortMessage("|cffffd200/djinnisvendorer|r junk |cffaaaaaa[item]|r");
		Addon:AddShortMessage("  Opens junk items window or add/remove item from the junk list.");
		Addon:AddShortMessage("|cffffd200/djinnisvendorer|r autosell|r");
		Addon:AddShortMessage("  Toggles auto sell. Currently %s.", Addon:GetToggleStatusText(Addon.db.global.AutoSellJunk));
		Addon:AddShortMessage("|cffffd200/djinnisvendorer|r autorepair|r");
		Addon:AddShortMessage("  Toggles auto repair. Currently %s.", Addon:GetToggleStatusText(Addon.db.global.AutoRepair));
		Addon:AddShortMessage("|cffffd200/djinnisvendorer|r smartrepair|r");
		Addon:AddShortMessage("  Toggles smart auto repair. Currently %s. Only works when auto repair is enabled.", Addon:GetToggleStatusText(Addon.db.global.SmartAutoRepair));
	end
	
	Addon:RestoreSavedSettings();
end

function Addon:GetToggleStatusText(status)
	if(status) then
		return "|cff43ef00enabled|r";
	else
		return "|cffef0000disabled|r";
	end
end

function Addon:OpenSettingsMenu(anchor)
	if MenuUtil and MenuUtil.CreateContextMenu then
		MenuUtil.CreateContextMenu(anchor, function(owner, rootDescription)
			Addon:PopulateSettingsMenu(rootDescription);
		end);
		return;
	end

	-- Legacy fallback (pre-11.0)
	if(not Addon._legacyDropDownFrame) then
		Addon._legacyDropDownFrame = CreateFrame("Frame", "DjinnisVendorerSettingsContextMenuFrame", anchor, "UIDropDownMenuTemplate");
	end
	Addon._legacyDropDownFrame:SetPoint("BOTTOM", anchor, "CENTER", 0, 5);
	EasyMenu(Addon:GetMenuData(), Addon._legacyDropDownFrame, "cursor", 0, 0, "MENU", 2.5);
	if DropDownList1 then
		DropDownList1:ClearAllPoints();
		DropDownList1:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", -1, -2);
		DropDownList1:SetClampedToScreen(true);
	end
end

function Addon:PopulateSettingsMenu(rootDescription)
	local self = Addon;
	local data = Addon:GetMenuData();
	Addon:AddMenuEntries(rootDescription, data);
end

function Addon:AddMenuEntries(parentDescription, entries)
	for _, entry in ipairs(entries) do
		Addon:AddMenuEntry(parentDescription, entry);
	end
end

function Addon:AddMenuEntry(parentDescription, entry)
	if entry.isTitle then
		if entry.text and entry.text ~= " " then
			parentDescription:CreateTitle(entry.text);
		else
			parentDescription:CreateDivider();
		end
		return;
	end

	if entry.hasArrow and entry.menuList then
		local subDesc = parentDescription:CreateButton(entry.text or "");
		Addon:AddMenuEntries(subDesc, entry.menuList);
		return;
	end

	if entry.isRadio then
		local checkedFn = entry.checked;
		if type(checkedFn) ~= "function" then
			local v = checkedFn;
			checkedFn = function() return v end;
		end
		parentDescription:CreateRadio(
			entry.text or "",
			checkedFn,
			function()
				if entry.func then entry.func() end
				return MenuResponse.Refresh;
			end
		);
		return;
	end

	if entry.notCheckable then
		if entry.func then
			parentDescription:CreateButton(entry.text or "", entry.func);
		else
			parentDescription:CreateTitle(entry.text or "");
		end
		return;
	end

	local checkedFn = entry.checked;
	if type(checkedFn) ~= "function" then
		local v = checkedFn;
		checkedFn = function() return v end;
	end
	local element = parentDescription:CreateCheckbox(
		entry.text or "",
		checkedFn,
		function()
			if entry.func then entry.func() end
			return MenuResponse.Refresh;
		end
	);
	if entry.disabled and element and element.SetEnabled then
		element:SetEnabled(false);
	end
	if (entry.tooltipTitle or entry.tooltipText) and element and element.SetTooltip then
		element:SetTooltip(function(tooltip, elementDescription)
			if entry.tooltipTitle then
				GameTooltip_SetTitle(tooltip, entry.tooltipTitle);
			end
			if entry.tooltipText then
				GameTooltip_AddNormalLine(tooltip, entry.tooltipText, true);
			end
		end);
	end
end

local NEW_FEATURE_ICON = "|TInterface\\OptionsFrame\\UI-OptionsFrame-NewFeatureIcon:0:0:0:-1|t";
function Addon:GetMenuData()
	local transmogTooltipText = "Adds an asterisk to the item icon if you are missing the item skin.";
	if(not CanIMogIt) then
		transmogTooltipText = transmogTooltipText .. "|n|nTo enable this feature install the optional dependency |cffffffffCan I Mog It|r first.";
	else
		transmogTooltipText = transmogTooltipText .. "|n|nNote: enabling this option will hide the default icons provided by |cffffffffCan I Mog It|r.";
	end
	
	local data = {
		{
			text = "DjinnisVendorer Options", isTitle = true, notCheckable = true,
		},
		{
			text = "Highlight own armor types",
			func = function()
				self.db.global.PaintArmorTypes = not self.db.global.PaintArmorTypes;
				MerchantFrame_UpdateMerchantInfo();
			end,
			checked = function() return self.db.global.PaintArmorTypes; end,
			isNotRadio = true,
			tooltipTitle = "Highlight Own Armor Types",
			tooltipText = "Paints armor types not used by your current class red.",
			tooltipOnButton = 1,
			keepShownOnClick = 1,
		},
		{
			text = "Paint known items",
			func = function()
				self.db.global.PaintKnownItems = not self.db.global.PaintKnownItems;
				MerchantFrame_UpdateMerchantInfo();
			end,
			checked = function() return self.db.global.PaintKnownItems; end,
			isNotRadio = true,
			tooltipTitle = "Paint Known Items",
			tooltipText = "Paints known items and pets to make unknown items easier to distinguish. You can change the color by clicking the color picker square.",
			tooltipOnButton = 1,
			keepShownOnClick = 1,
			swatchFunc = function()
				self.db.global.PaintKnownItems = true;
				
				local r, g, b = ColorPickerFrame:GetColorRGB();
				self.db.global.PaintColor.r = r;
				self.db.global.PaintColor.g = g;
				self.db.global.PaintColor.b = b;
				MerchantFrame_UpdateMerchantInfo();
			end,
			cancelFunc = function(values)
				self.db.global.PaintColor.r = values.r;
				self.db.global.PaintColor.g = values.g;
				self.db.global.PaintColor.b = values.b;
				MerchantFrame_UpdateMerchantInfo();
			end,
			hasColorSwatch = true,
			r = self.db.global.PaintColor.r,
			g = self.db.global.PaintColor.g,
			b = self.db.global.PaintColor.b,
		},
		{
			text = "Enable search from tooltip text",
			func = function()
				self.db.global.UseTooltipSearch = not self.db.global.UseTooltipSearch;
				Addon:RefreshFilter();
			end,
			checked = function() return self.db.global.UseTooltipSearch; end,
			isNotRadio = true,
			tooltipTitle = "Enable search from tooltip text",
			tooltipText = "Allow DjinnisVendorer to search item tooltip text. This allows for very powerful filtering but is also very resource intensive and may cause problems.",
			tooltipOnButton = 1,
			keepShownOnClick = 1,
		},
		{
			text = "Show on tooltip if item is ignored or junked",
			func = function()
				self.db.global.ShowTooltipInfo = not self.db.global.ShowTooltipInfo;
			end,
			checked = function() return self.db.global.ShowTooltipInfo; end,
			isNotRadio = true,
			tooltipTitle = "Show on tooltip if item is ignored or junked",
			tooltipText = "Adds a line on item tooltips to display whether the item is on ignore or junk lists.",
			tooltipOnButton = 1,
			keepShownOnClick = 1,
		},
		{
			text = "Show icon for missing transmogs" .. (not CanIMogIt and " (disabled)" or ""),
			func = function()
				self.db.global.ShowTransmogAsterisk = not self.db.global.ShowTransmogAsterisk;
				MerchantFrame_UpdateMerchantInfo();
			end,
			checked = function() return self.db.global.ShowTransmogAsterisk; end,
			isNotRadio = true,
			tooltipTitle = "Show icon for missing transmogs",
			tooltipText = transmogTooltipText,
			tooltipOnButton = 1,
			tooltipWhileDisabled = true,
			disabled = (CanIMogIt == nil),
			keepShownOnClick = 1,
		},
		{
			text = "Default merchant filter to All",
			func = function()
				self.db.global.DefaultFilterAll = not self.db.global.DefaultFilterAll;
				if self.db.global.DefaultFilterAll and MerchantFrame and MerchantFrame:IsShown()
					and SetMerchantFilter and LE_LOOT_FILTER_ALL then
					SetMerchantFilter(LE_LOOT_FILTER_ALL);
					if MerchantFrame.FilterDropdown and MerchantFrame.FilterDropdown.Update then
						MerchantFrame.FilterDropdown:Update();
					end
				end
			end,
			checked = function() return self.db.global.DefaultFilterAll; end,
			isNotRadio = true,
			tooltipTitle = "Default merchant filter to All",
			tooltipText = "When a merchant window opens, automatically switch the filter from Class to All so every item is shown.",
			tooltipOnButton = 1,
			keepShownOnClick = 1,
		},
		{
			text = "Vertical list view",
			func = function()
				self.db.global.ListViewEnabled = not self.db.global.ListViewEnabled;
				self:UpdateExtensionPanel();
				if(MerchantFrame and MerchantFrame:IsShown() and MerchantFrame.selectedTab == 1) then
					MerchantFrame_Update();
				end
			end,
			checked = function() return self.db.global.ListViewEnabled; end,
			isNotRadio = true,
			tooltipTitle = "Vertical list view",
			tooltipText = "Replaces the merchant grid with a scrollable list of every item the merchant offers.",
			tooltipOnButton = 1,
			keepShownOnClick = 1,
		},
		{
			text = "List filter behaviour",
			notCheckable = true,
			hasArrow = true,
			menuList = {
				{
					text = "Grey out non-matches",
					isRadio = true,
					checked = function() return not self.db.global.ListViewHideNonMatches; end,
					func = function()
						self.db.global.ListViewHideNonMatches = false;
						if(Addon.RefreshListView) then Addon:RefreshListView() end
					end,
				},
				{
					text = "Hide non-matches",
					isRadio = true,
					checked = function() return self.db.global.ListViewHideNonMatches; end,
					func = function()
						self.db.global.ListViewHideNonMatches = true;
						if(Addon.RefreshListView) then Addon:RefreshListView() end
					end,
				},
			},
		},
		{
			text = "List row info",
			notCheckable = true,
			hasArrow = true,
			menuList = {
				{
					text = "Show stack size",
					isNotRadio = true,
					checked = function() return self.db.global.ListViewShowStackSize; end,
					func = function()
						self.db.global.ListViewShowStackSize = not self.db.global.ListViewShowStackSize;
						if(Addon.RefreshListView) then Addon:RefreshListView() end
					end,
					tooltipTitle = "Show stack size",
					tooltipText = "Display the merchant stack size (e.g. x5) on the right side of each row.",
					tooltipOnButton = 1,
					keepShownOnClick = 1,
				},
				{
					text = "Show bind type",
					isNotRadio = true,
					checked = function() return self.db.global.ListViewShowBindType; end,
					func = function()
						self.db.global.ListViewShowBindType = not self.db.global.ListViewShowBindType;
						if(Addon.RefreshListView) then Addon:RefreshListView() end
					end,
					tooltipTitle = "Show bind type",
					tooltipText = "Append BoP, BoE, BoA, BoU or Quest to each row's subtitle when known.",
					tooltipOnButton = 1,
					keepShownOnClick = 1,
				},
				{
					text = "Show reputation discount",
					isNotRadio = true,
					checked = function() return self.db.global.ListViewShowRepDiscount; end,
					func = function()
						self.db.global.ListViewShowRepDiscount = not self.db.global.ListViewShowRepDiscount;
						if(Addon.RefreshListView) then Addon:RefreshListView() end
					end,
					tooltipTitle = "Show reputation discount",
					tooltipText = "Show the reputation discount applied at this merchant (e.g. -10%) on each gold-priced row. Detection relies on the merchant's faction appearing in your reputation panel.",
					tooltipOnButton = 1,
					keepShownOnClick = 1,
				},
			},
		},
		{
			text = "List sort order",
			notCheckable = true,
			hasArrow = true,
			menuList = (function()
				local options = {
					{ key = "default", label = "Merchant order" },
					{ key = "name",    label = "Name (A-Z)" },
					{ key = "price",   label = "Price (low to high)" },
					{ key = "quality", label = "Quality (high to low)" },
				};
				local items = {};
				for _, opt in ipairs(options) do
					local key, label = opt.key, opt.label;
					tinsert(items, {
						text = label,
						isRadio = true,
						checked = function() return (self.db.global.ListViewSortKey or "default") == key; end,
						func = function()
							self.db.global.ListViewSortKey = key;
							if(Addon.RefreshListView) then Addon:RefreshListView() end
						end,
					});
				end
				return items;
			end)(),
		},
		{
			text = "Remember search text",
			notCheckable = true,
			hasArrow = true,
			menuList = {
				{
					text = "Don't remember",
					isRadio = true,
					checked = function() return self.db.global.SearchPersistence == "off"; end,
					func = function()
						self.db.global.SearchPersistence = "off";
						self.db.global.SavedSearchText = "";
						Addon.SessionFilterText = "";
					end,
				},
				{
					text = "Until reload",
					isRadio = true,
					checked = function() return self.db.global.SearchPersistence == "session"; end,
					func = function()
						self.db.global.SearchPersistence = "session";
						self.db.global.SavedSearchText = "";
						-- seed session from current edit box so it sticks immediately
						if DjinnisVendorerFilterEditBox then
							Addon.SessionFilterText = string.trim(string.lower(DjinnisVendorerFilterEditBox:GetText() or ""));
						end
					end,
				},
				{
					text = "Across sessions",
					isRadio = true,
					checked = function() return self.db.global.SearchPersistence == "account"; end,
					func = function()
						self.db.global.SearchPersistence = "account";
						if DjinnisVendorerFilterEditBox then
							self.db.global.SavedSearchText = string.trim(string.lower(DjinnisVendorerFilterEditBox:GetText() or ""));
						end
					end,
				},
			},
		},
		{
			text = "Verbose chat output",
			func = function()
				self.db.global.VerboseChat = not self.db.global.VerboseChat;
			end,
			checked = function() return self.db.global.VerboseChat; end,
			isNotRadio = true,
			tooltipTitle = "Verbose chat output",
			tooltipText = "If disabled chat output will be kept minimal, only listing gold changes and repair costs.",
			tooltipOnButton = 1,
		},
		{
			text = " ", isTitle = true, notCheckable = true,
		},
		{
			text = "Use improved stack purchasing",
			func = function()
				self.db.global.UseImprovedStackSplit = not self.db.global.UseImprovedStackSplit;
				-- Close both split frames just in case
				DjinnisVendorerStackSplitFrame:Cancel();
				if StackSplitFrame and StackSplitFrame:IsShown() then StackSplitFrame:Hide(); end
			end,
			checked = function() return self.db.global.UseImprovedStackSplit; end,
			isNotRadio = true,
			tooltipTitle = "Use improved stack purchasing",
			tooltipText = "When buying in bulk use DjinnisVendorer's replacement window which allows buying several stacks at once among other things.",
			tooltipOnButton = 1,
			keepShownOnClick = 1,
		},
		{
			text = "Throttle purchases to a safe interval",
			func = function()
				self.db.global.UseSafePurchase = not self.db.global.UseSafePurchase;
			end,
			checked = function() return self.db.global.UseSafePurchase; end,
			isNotRadio = true,
			tooltipTitle = "Throttle purchases to a safe interval",
			tooltipText = "If you encounter errors when trying to purchase items more than one stack at a time try enabling this option. DjinnisVendorer will throttle item purchases to a slower rate.",
			tooltipOnButton = 1,
			keepShownOnClick = 1,
		},
		{
			text = " ", isTitle = true, notCheckable = true,
		},
		{
			text = "Also destroy unsellable items",
			func = function()
				self.db.global.DestroyUnsellables = not self.db.global.DestroyUnsellables;
				if(not self.db.global.DestroyUnsellables) then
					DjinnisVendorerSellJunkButton:SetText(_G["DJINNISVENDORER_SELL_JUNK_ITEMS_TEXT"]);
					DjinnisVendorerSellUnusablesButton:SetText(_G["DJINNISVENDORER_SELL_UNUSABLE_ITEMS_TEXT"]);
				else
					DjinnisVendorerSellJunkButton:SetText(_G["DJINNISVENDORER_SELL_JUNK_ITEMS_TEXT2"]);
					DjinnisVendorerSellUnusablesButton:SetText(_G["DJINNISVENDORER_SELL_UNUSABLE_ITEMS_TEXT2"]);
				end
			end,
			checked = function() return self.db.global.DestroyUnsellables; end,
			isNotRadio = true,
			tooltipTitle = "Also destroy unsellable items",
			tooltipText = "When enabled pressing the sell buttons will also destroy all unsellable valueless items related to button.|n|n" ..
			              "Sell Junk Items button will destroy unsellable poor quality items or items marked as junk. Auto selling junk |cffff1111will not|r destroy anything.|n|n" ..
			              "Sell Unusables will destroy unusable unsellable soulbound equipment or tokens.|n|n" ..
			              "|cffff1111DANGER ALERT!|r Always double check what items will be destroyed and if you do not wish item to be destroyed add it to the ignore list instead.",
			tooltipOnButton = 1,
			keepShownOnClick = 1,
		},
		{
			text = " ", isTitle = true, notCheckable = true,
		},
		{
			text = "Use global ignore list on " .. UnitName("player"),
			func = function()
				self.db.char.UsingPersonalIgnoreList = not self.db.char.UsingPersonalIgnoreList or IsControlKeyDown();
				
				if(self.db.char.UsingPersonalIgnoreList and (self.db.char.ItemIgnoreList == nil or IsControlKeyDown())) then
					if(not IsControlKeyDown() or self.db.char.ItemIgnoreList == nil) then
						Addon:AddMessage("Missing ignore list for %s. Copying the global list.", UnitName("player"));
					else
						Addon:AddMessage("Re-copying the global ignore list for %s.", UnitName("player"));
					end
					
					self.db.char.ItemIgnoreList = {};
					for itemID, status in pairs(self.db.global.ItemIgnoreList) do
						self.db.char.ItemIgnoreList[itemID] = status;
					end
				end
				
				if(DjinnisVendorerItemListsFrame:IsVisible() and DjinnisVendorerItemListsFrame.index == 1) then
					Addon:OpenIgnoredItemsListsFrame();
				end
			end,
			checked = function() return not self.db.char.UsingPersonalIgnoreList; end,
			isNotRadio = true,
			tooltipTitle = "Use global ignore list",
			tooltipText = "You may disable this setting to use character's personal ignore list instead.|n|nIf you wish to re-copy global list to personal list hold down ctrl when clicking this option.",
			tooltipOnButton = 1,
			keepShownOnClick = 1,
		},
		{
			text = "Use global junk list on " .. UnitName("player"),
			func = function()
				self.db.char.UsingPersonalJunkList = not self.db.char.UsingPersonalJunkList or IsControlKeyDown();
				
				if(self.db.char.UsingPersonalJunkList and (self.db.char.ItemJunkList == nil or IsControlKeyDown())) then
					if(not IsControlKeyDown() or self.db.char.ItemJunkList == nil) then
						Addon:AddMessage("Missing junk list for %s. Copying the global list.", UnitName("player"));
					else
						Addon:AddMessage("Re-copying the global junk list for %s.", UnitName("player"));
					end
					
					self.db.char.ItemJunkList = {};
					for item, _ in pairs(self.db.global.ItemJunkList) do
						self.db.char.ItemJunkList[item] = true;
					end
				end
				
				if(DjinnisVendorerItemListsFrame:IsVisible() and DjinnisVendorerItemListsFrame.index == 2) then
					Addon:OpenJunkItemsListsFrame();
				end
			end,
			checked = function() return not self.db.char.UsingPersonalJunkList; end,
			isNotRadio = true,
			tooltipTitle = "Use global junk list",
			tooltipText = "You may disable this setting to use character's personal junk list instead.|n|nIf you wish to re-copy global list to personal list hold down ctrl when clicking this option.",
			tooltipOnButton = 1,
			keepShownOnClick = 1,
		},
		{
			text = " ", isTitle = true, notCheckable = true,
		},
		{
			text = "Close",
			func = function() CloseMenus(); end,
			notCheckable = true,
		},
	};
	
	return data;
end

function DjinnisVendorerSettingsButton_OnClick(self)
	if MenuUtil and MenuUtil.CreateContextMenu then
		Addon:OpenSettingsMenu(self);
		return;
	end
	if(DropDownList1 and DropDownList1:IsVisible() and select(2, DropDownList1:GetPoint()) == self) then
		CloseMenus();
	else
		Addon:OpenSettingsMenu(self);
	end
end
