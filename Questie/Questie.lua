---------------------------------------------------------------------------------------------------
-- Name: Questie for The Burning Crusade
-- Revision: 1.0
-- Authors: Aero/Schaka/Logon/Dyaxler/everyone else
-- Website: https://github.com/AeroScripts/QuestieDev
-- Description: Questie started out being a simple backport of QuestHelper but it has grown beyond
-- it's original design into something better. Questie will show you where quests are available and
-- only display the quests you're eligible for based on level, profession, class, race etc. Questie
-- will also assist you in where or what is needed to complete a quest. Map notes, an arrow, custom
-- tooltips, quest tracker are also some of the tools included with Questie to assist you.
---------------------------------------------------------------------------------------------------
--///////////////////////////////////////////////////////////////////////////////////////////////--
---------------------------------------------------------------------------------------------------
local Astrolabe = DongleStub("Astrolabe-0.4")
DEBUG_LEVEL = nil; --0 Low info --1 Medium info --2 very spammy
Questie = CreateFrame("Frame", "QuestieLua", UIParent, "ActionButtonTemplate");
QuestRewardCompleteButton = nil;
QuestAbandonOnAccept = nil;
QuestAbandonWithItemsOnAccept = nil;
QuestieVersion = 1.0;
---------------------------------------------------------------------------------------------------
-- WoW Functions --PERFORMANCE CHANGE--
---------------------------------------------------------------------------------------------------
local QGet_QuestLogTitle = GetQuestLogTitle;
local QGet_NumQuestLeaderBoards = GetNumQuestLeaderBoards;
local QSelect_QuestLogEntry = SelectQuestLogEntry;
local QGet_QuestLogLeaderBoard = GetQuestLogLeaderBoard;
local QGet_AbandonQuestName = GetAbandonQuestName;
local QGet_QuestLogQuestText = GetQuestLogQuestText;
local QGet_TitleText = GetTitleText;
---------------------------------------------------------------------------------------------------
function GetQuestLogTitle(index)
	return QGet_QuestLogTitle(index);
end
---------------------------------------------------------------------------------------------------
function GetQuestLogQuestText()
	Questie.needsUpdate = true;
	return QGet_QuestLogQuestText();
end
---------------------------------------------------------------------------------------------------
-- Setup Default Profile
---------------------------------------------------------------------------------------------------
function Questie:SetupDefaults()
	if not QuestieConfig then QuestieConfig = {
		["alwaysShowDistance"] = false,
		["alwaysShowLevel"] = true,
		["alwaysShowQuests"] = true,
		["arrowEnabled"] = true,
		["boldColors"] = false,
		["iconScale"] = 1.0,
		["maxLevelFilter"] = false,
		["maxShowLevel"] = 3,
		["minLevelFilter"] = false,
		["minShowLevel"] = 5,
		["showMapAids"] = true,
		["showProfessionQuests"] = false,
		["showTrackerHeader"] = true,
		["trackerEnabled"] = true,
		["trackerList"] = true,
		["resizeWorldmap"] = false,
		["getVersion"] = QuestieVersion,
	}
	end
	if not QuestieTrackerVariables then QuestieTrackerVariables = {
		["position"] = {
			["relativeTo"] = "UIParent",
			["point"] = "LEFT",
			["relativePoint"] = "LEFT",
			["yOfs"] = 0,
			["xOfs"] = 0,
		},
	}
	end
end
---------------------------------------------------------------------------------------------------
-- Setup Default Vars
---------------------------------------------------------------------------------------------------
function Questie:CheckDefaults()
	if QuestieConfig.alwaysShowDistance == nil then
		QuestieConfig.alwaysShowDistance = false;
	end
	if QuestieConfig.alwaysShowLevel == nil then
		QuestieConfig.alwaysShowLevel = true;
	end
	if QuestieConfig.alwaysShowQuests == nil then
		QuestieConfig.alwaysShowQuests = true;
	end
	if QuestieConfig.arrowEnabled == nil then
		QuestieConfig.arrowEnabled = true;
	end
	if QuestieConfig.boldColors == nil then
		QuestieConfig.boldColors = false;
	end
	if QuestieConfig.iconScale == nil then
		QuestieConfig.iconScale = 1.0;
	end
	if QuestieConfig.maxLevelFilter == nil then
		QuestieConfig.maxLevelFilter = false;
	end
	if QuestieConfig.maxShowLevel == nil then
		QuestieConfig.maxShowLevel = false;
		QuestieConfig.maxShowLevel = 3;
	end
	if QuestieConfig.minLevelFilter == nil then
		QuestieConfig.minLevelFilter = false;
	end
	if QuestieConfig.minShowLevel == nil then
		QuestieConfig.minShowLevel = false;
		QuestieConfig.minShowLevel = 5;
	end
	if QuestieConfig.showMapAids == nil then
		QuestieConfig.showMapAids = true;
	end
	if QuestieConfig.showProfessionQuests == nil then
		QuestieConfig.showProfessionQuests = false;
	end
	if QuestieConfig.showTrackerHeader == nil then
		QuestieConfig.showTrackerHeader = false;
	end
	if QuestieConfig.trackerEnabled == nil then
		QuestieConfig.trackerEnabled = true;
	end
	if QuestieConfig.trackerList == nil then
		QuestieConfig.trackerList = false;
	end
	if QuestieConfig.resizeWorldmap == nil then
		QuestieConfig.resizeWorldmap = false;
	end
	-- Version check
	if (not QuestieConfig.getVersion) or (QuestieConfig.getVersion < QuestieVersion) then
		Questie:ClearConfig("version");
	end
	-- Sets some EQL3 settings to keep it from conflicting with Questie fetures
	EQL3_Player = UnitName("player").."-"..GetRealmName();
	if IsAddOnLoaded("EQL3") then
		if(not QuestlogOptions) then return end
		QuestlogOptions[EQL3_Player].MobTooltip = 0;
		QuestlogOptions[EQL3_Player].ItemTooltip = 0;
		QuestlogOptions[EQL3_Player].RemoveCompletedObjectives = 0;
		QuestlogOptions[EQL3_Player].RemoveFinished = 0;
		QuestlogOptions[EQL3_Player].MinimizeFinished = 0;
		QuestlogOptions[EQL3_Player].AddUntracked = 1;
		QuestlogOptions[EQL3_Player].AddNew = 1;
	end
end
---------------------------------------------------------------------------------------------------
-- In Vanilla WoW there is no official Russian client so an addon was made to translate some of the
-- global strings. Two of the translated strings conflicted with Questie, displying the wrong info
-- on the World Map. This function simply over-rides those stings to force them back to english so
-- Questie can understand the returned sting in order to disply the correct locations and icons.
---------------------------------------------------------------------------------------------------
function Questie:BlockTranslations()
	if (IsAddOnLoaded("RuWoW") or IsAddOnLoaded("ProffBot")) or (IsAddOnLoaded("ruRU")) then
		QUEST_MONSTERS_KILLED = "%s slain: %d/%d"; -- Lists the monsters killed for the selected quest
		ERR_QUEST_ADD_KILL_SII = "%s slain: %d/%d"; -- %s is the monster name
	end
end
---------------------------------------------------------------------------------------------------
-- Cleans and resets the users Questie SavedVariables. Will also perform some quest and quest
-- tracker database clean up to purge stale/invalid entries. More notes below. Popup confirmation
-- of Yes or No - Popup has a 60 second timeout.
---------------------------------------------------------------------------------------------------
function Questie:ClearConfig(arg)
	if arg == "slash" then
		msg = "|cFFFFFF00You are about to clear your characters settings. This will NOT delete your quest database but it will clean it up a little. This will reset abandonded quests, and remove any finished or stale quest entries in the QuestTracker database. Your UI will be reloaded automatically to finalize the new settings.|n|nAre you sure you want to continue?|r";
	elseif arg == "version" then
		msg = "|cFFFFFF00VERSION CHECK!|n|nIt appears you have installed Questie for the very first time or you have recently upgraded to a new version. Your UI will automatically be reloaded and your QuestieConfig will be updated and cleaned of any stale entries. This will NOT clear your quest history.|n|nPlease click Yes to begin the update.|r";
	end
	StaticPopupDialogs["CLEAR_CONFIG"] = {
		text = TEXT(msg),
		button1 = TEXT(YES),
		button2 = TEXT(NO),
		OnAccept = function()
			-- Clears config
			QuestieConfig = {}
			-- Setup default settings
			QuestieConfig = {
				["alwaysShowDistance"] = false,
				["alwaysShowLevel"] = true,
				["alwaysShowQuests"] = true,
				["arrowEnabled"] = true,
				["boldColors"] = false,
				["iconScale"] = 1.0,
				["maxLevelFilter"] = false,
				["maxShowLevel"] = 3,
				["minLevelFilter"] = false,
				["minShowLevel"] = 5,
				["showMapAids"] = true,
				["showProfessionQuests"] = false,
				["showTrackerHeader"] = true,
				["trackerEnabled"] = true,
				["trackerList"] = true,
				["resizeWorldmap"] = false,
				["getVersion"] = QuestieVersion,
			}
			-- Clears tracker settings
			QuestieTrackerVariables = {}
			-- Setup default settings and repositions the QuestTracker against the left side of the screen.
			QuestieTrackerVariables = {
				["position"] = {
					["relativeTo"] = "UIParent",
					["point"] = "CENTER",
					["relativePoint"] = "CENTER",
					["yOfs"] = 0,
					["xOfs"] = 0,
				},
			}
			-- The following will clean up the Quest Database removing stale/invalid entries.
			-- The (== 0 in QuestieSeenQuests) flag usually means a quest has been picked up and the (== -1
			-- in QuestieSeenQuests) flag means the quest has been abandonded. Once we remove these flags
			-- Questie will readd the quests based on what is in your log. A refresh of sorts without
			-- touching or resetting your finished quests. When the quest log is crawled, Questie will
			-- check any prerequired quests and flag all those as complete upto the quest in your chain
			-- that you're currently on.
			local index = 0
			for i,v in pairs(QuestieSeenQuests) do
				if (v == 0) or (v == -1) then
					QuestieSeenQuests[i] = nil
				end
				index = index + 1
			end
			-- This wipes the QuestTracker database and forces a refresh of all tracked data.
			QuestieTrackedQuests = {}
			ReloadUI()
		end,
		timeout = 60,
		exclusive = 1,
		hideOnEscape = 1
	}
	StaticPopup_Show ("CLEAR_CONFIG")
end
---------------------------------------------------------------------------------------------------
-- OnLoad Handler
---------------------------------------------------------------------------------------------------
function Questie:OnLoad()
	this:RegisterEvent("QUEST_LOG_UPDATE");
	this:RegisterEvent("QUEST_PROGRESS");
	this:RegisterEvent("ZONE_CHANGED");
	this:RegisterEvent("UI_INFO_MESSAGE");
	this:RegisterEvent("CHAT_MSG_SYSTEM");
	this:RegisterEvent("QUEST_ITEM_UPDATE");
	this:RegisterEvent("UNIT_QUEST_LOG_CHANGED");
	this:RegisterEvent("PLAYER_ENTERING_WORLD");
	this:RegisterEvent("PLAYER_LOGIN");
	this:RegisterEvent("ADDON_LOADED");
	this:RegisterEvent("VARIABLES_LOADED");
	this:RegisterEvent("CHAT_MSG_LOOT");
	QuestAbandonOnAccept = StaticPopupDialogs["ABANDON_QUEST"].OnAccept;
	StaticPopupDialogs["ABANDON_QUEST"].OnAccept = function()
		local hash = Questie:GetHashFromName(QGet_AbandonQuestName());
		QuestieTrackedQuests[hash] = nil;
		QuestieSeenQuests[hash] = -1;
		if (TomTomCrazyArrow:IsVisible() ~= nil) and (arrow_objective == hash) then
			TomTomCrazyArrow:Hide()
		end
		Questie:AddEvent("CHECKLOG", 0.135);
		QuestAbandonOnAccept();
	end
	QuestAbandonWithItemsOnAccept = StaticPopupDialogs["ABANDON_QUEST_WITH_ITEMS"].OnAccept;
	StaticPopupDialogs["ABANDON_QUEST_WITH_ITEMS"].OnAccept = function()
		local hash = Questie:GetHashFromName(QGet_AbandonQuestName());
		QuestieTrackedQuests[hash] = nil;
		QuestieSeenQuests[hash] = -1;
		if (TomTomCrazyArrow:IsVisible() ~= nil) and (arrow_objective == hash) then
			TomTomCrazyArrow:Hide()
		end
		Questie:AddEvent("CHECKLOG", 0.135);
		QuestAbandonWithItemsOnAccept();
	end
	QuestRewardCompleteButton = QuestRewardCompleteButton_OnClick;
	QuestRewardCompleteButton_OnClick = function()
		if IsAddOnLoaded("EQL3") then
			local questTitle = QGet_TitleText();
			local _, _, level, qName = string.find(questTitle, "%[(.+)%] (.+)")
			if qName == nil then
				qName = QGet_TitleText();
			else
				qName = qName
			end
			local hash = Questie:GetHashFromName(qName);
			QuestieCompletedQuestMessages[qName] = 1;
			if(not QuestieSeenQuests[hash]) or (QuestieSeenQuests[hash] == 0) or (QuestieSeenQuests[hash] == -1) then
				Questie:finishAndRecurse(hash)
				if (TomTomCrazyArrow:IsVisible() ~= nil) and (arrow_objective == hash) then
					TomTomCrazyArrow:Hide()
				end
				QuestieTrackedQuests[hash] = nil;
				Questie:AddEvent("CHECKLOG", 0.135);
			end
		elseif (not IsAddOnLoaded("EQL3")) then
			local questTitle = QGet_TitleText();
			local _, _, level, qName = string.find(questTitle, "%[(.+)%] (.+)")
			if qName == nil then
				qName = QGet_TitleText();
			else
				qName = qName
			end
			local hash = Questie:GetHashFromName(qName);
			QuestieCompletedQuestMessages[qName] = 1;
			if(not QuestieSeenQuests[hash]) or (QuestieSeenQuests[hash] == 0) or (QuestieSeenQuests[hash] == -1) then
				Questie:finishAndRecurse(hash)
				if (TomTomCrazyArrow:IsVisible() ~= nil) and (arrow_objective == hash) then
					TomTomCrazyArrow:Hide()
				end
				QuestieTrackedQuests[hash] = nil;
				Questie:AddEvent("CHECKLOG", 0.135);
			end
		end
		QuestRewardCompleteButton();
	end
	Questie:NOTES_LOADED();
	SlashCmdList["QUESTIE"] = Questie_SlashHandler;
	SLASH_QUESTIE1 = "/questie";
end
---------------------------------------------------------------------------------------------------
-- Questie Worldmap Toggle Button
---------------------------------------------------------------------------------------------------
Active = true;
function Questie:Toggle()
	if (QuestieConfig.showMapAids == true) or (QuestieConfig.alwaysShowQuests == true) or ((QuestieConfig.showMapAids == true) and (QuestieConfig.alwaysShowQuests == false)) then
		if(Active == true) then
			Active = false;
			QuestieMapNotes = {};
			QuestieAvailableMapNotes = {};
			Questie:RedrawNotes();
			LastQuestLogHashes = nil;
			LastCount = 0;
		else
			Active = true;
			LastQuestLogHashes = nil;
			LastCount = 0;
			Questie:CheckQuestLog();
			Questie:SetAvailableQuests()
			Questie:RedrawNotes();
		end
	else
		QuestieMapNotes = {};
		QuestieAvailableMapNotes = {};
		Questie:RedrawNotes();
		LastQuestLogHashes = nil;
		LastCount = 0;
	end
end
---------------------------------------------------------------------------------------------------
-- Questie OnUpdate Handler
---------------------------------------------------------------------------------------------------
QUESTIE_EVENTQUEUE = {};
function Questie:OnUpdate(elapsed)
	Astrolabe:OnUpdate(nil, elapsed);
	Questie:NOTES_ON_UPDATE(elapsed);
	if(table.getn(QUESTIE_EVENTQUEUE) > 0) then
		for k, v in pairs(QUESTIE_EVENTQUEUE) do
			if(v.EVENT == "UPDATE" and GetTime()- v.TIME > v.DELAY) then
				while(true) do
					local d = Questie:UpdateQuests();
					if(not d) then
						table.remove(QUESTIE_EVENTQUEUE, 1);
						break;
					end
				end
				Astrolabe.ForceNextUpdate = true;
			elseif(v.EVENT == "CHECKLOG" and GetTime() - v.TIME > v.DELAY) then
				Questie:CheckQuestLog();
				table.remove(QUESTIE_EVENTQUEUE, 1);
				break;
			end
		end
	end
end
---------------------------------------------------------------------------------------------------
-- Questie Event Handlers
---------------------------------------------------------------------------------------------------
QuestieCompletedQuestMessages = {};
-- 1 means WE KNOW it's complete
-- 0 means We've seen it and it's probably in the questlog
-- -1 means we know its abandonnd
--Had to add a delay(Even if it's small)
function Questie:AddEvent(EVENT, DELAY)
	local evnt = {};
	evnt.EVENT = EVENT;
	evnt.TIME = GetTime();
	evnt.DELAY = DELAY;
	table.insert(QUESTIE_EVENTQUEUE, evnt);
end
---------------------------------------------------------------------------------------------------
QUESTIE_LAST_UPDATE = GetTime();
QUESTIE_LAST_CHECKLOG = GetTime();
---------------------------------------------------------------------------------------------------
function Questie:OnEvent(this, event, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10)
	if(event =="ADDON_LOADED" and arg1 == "Questie") then
	elseif(event == "QUEST_LOG_UPDATE" or event == "QUEST_ITEM_UPDATE") then
		if(GetTime() - QUESTIE_LAST_CHECKLOG > 0.1) then
			Questie:AddEvent("CHECKLOG", 0.135);
			QUESTIE_LAST_CHECKLOG = GetTime();
		else
			Questie:debug_Print("[QuestieEvent] ",event, "Spam Protection: Last checklog was:",GetTime() - QUESTIE_LAST_CHECKLOG, "ago skipping!");
			QUESTIE_LAST_CHECKLOG = GetTime();
		end
		if(GetTime() - QUESTIE_LAST_UPDATE > 0.1) then
			Questie:AddEvent("UPDATE", 0.15);--On my fast PC this seems like a good number
			QUESTIE_LAST_UPDATE = GetTime();
		else
			Questie:debug_Print("[QuestieEvent] ",event, "Spam Protection: Last update was:",GetTime() - QUESTIE_LAST_UPDATE, "ago skipping!");
			QUESTIE_LAST_UPDATE = GetTime();
		end
		Questie:BlockTranslations();
	elseif(event == "QUEST_PROGRESS") then
		if IsAddOnLoaded("EQL3") then
			if IsQuestCompletable() then
				local questTitle = QGet_TitleText();
				local _, _, level, qName = string.find(questTitle, "%[(.+)%] (.+)");
				if qName == nil then
					qName = QGet_TitleText();
				else
					qName = qName;
				end
				local hash = Questie:GetHashFromName(qName);
				QuestieCompletedQuestMessages[qName] = 1;
				if(not QuestieSeenQuests[hash]) or (QuestieSeenQuests[hash] == 0) or (QuestieSeenQuests[hash] == -1) then
					Questie:finishAndRecurse(hash);
					if (TomTomCrazyArrow:IsVisible() ~= nil) and (arrow_objective == hash) then
						TomTomCrazyArrow:Hide();
					end
					QuestieTrackedQuests[hash] = nil;
				end
				CompleteQuest();
				Questie:AddEvent("CHECKLOG", 0.135);
			end
		end
	elseif(event == "VARIABLES_LOADED") then
		Questie:debug_Print("VARIABLES_LOADED");
		if(not QuestieSeenQuests) then
			QuestieSeenQuests = {};
		end
		Questie:BlockTranslations();
		Questie:SetupDefaults();
		Questie:CheckDefaults();
		Questie:UpdateIconScale();
	elseif(event == "PLAYER_LOGIN") then
		Questie:CheckQuestLog();
		Questie:AddEvent("UPDATE", 1.15);
		local f = GameTooltip:GetScript("OnShow");
		if(f ~= nil) then
			--Proper tooltip hook!
			local Blizz_GameTooltip_Show = GameTooltip.Show
			GameTooltip.Show = function(self)
				Questie:Tooltip(self);
				Blizz_GameTooltip_Show(self);
			end
			local Bliz_GameTooltip_SetLootItem = GameTooltip.SetLootItem
			GameTooltip.SetLootItem = function(self, slot)
				Bliz_GameTooltip_SetLootItem(self, slot);
				Questie:Tooltip(self, true);
			end
		else
			Questie:hookTooltip();
		end
	elseif(event == "CHAT_MSG_LOOT") then
		local _, _, msg, item = string.find(arg1, "(You receive loot%:) (.+)");
		if msg then
			Questie:CheckQuestLog();
		end
	end
end
---------------------------------------------------------------------------------------------------
-- Questie Parsing Shortcuts
---------------------------------------------------------------------------------------------------
function findFirst(haystack, needle)
    local i=string.find(haystack, " ");
    if i==nil then return nil; else return i-1; end
end
---------------------------------------------------------------------------------------------------
function findLast(haystack, needle)
	local i=string.gmatch(haystack, ".*"..needle.."()")()
	if i==nil then return nil; else return i-1; end
end
---------------------------------------------------------------------------------------------------
-- Questie Slash Handler and Help Menu
---------------------------------------------------------------------------------------------------
QuestieFastSlash = {
	["color"] = function()
	-- Default: False
		QuestieConfig.boldColors = not QuestieConfig.boldColors;
		if QuestieConfig.boldColors then
			DEFAULT_CHAT_FRAME:AddMessage("QuestTracker Alternate Colors enabled");
			Questie:Toggle();
			Questie:Toggle();
		else
			DEFAULT_CHAT_FRAME:AddMessage("QuestTracker Alternate Colors disabled");
			Questie:Toggle();
			Questie:Toggle();
		end
	end,
	["listdirection"] = function()
	-- Default: False
		if (QuestieConfig.trackerList == false) then
			StaticPopupDialogs["BOTTOM_UP"] = {
				text = "|cFFFFFF00You are about to change the way quests are listed in the QuestTracker. They will grow from bottom --> up and sorted by distance from top --> down.|n|nYour UI will be automatically reloaded to apply the new settings.|n|nAre you sure you want to continue?|r",
				button1 = TEXT(YES),
				button2 = TEXT(NO),
				OnAccept = function()
					QuestieConfig.trackerList = true
					QuestieTrackerVariables = {};
					QuestieTrackerVariables["position"] = {
						["point"] = "CENTER",
						["relativePoint"] = "CENTER",
						["relativeTo"] = "UIParent",
						["yOfs"] = 0,
						["xOfs"] = 0,
					};
					ReloadUI()
				end,
				timeout = 120,
				exclusive = 1,
				hideOnEscape = 1
			}
			StaticPopup_Show ("BOTTOM_UP")
		elseif (QuestieConfig.trackerList == true) then
			StaticPopupDialogs["TOP_DOWN"] = {
				text = "|cFFFFFF00You are about to change the tracker back to it's default state. Quests will grow from top --> down and also sorted by distance from top --> down in the QuestTracker.|n|nYour UI will be reloaded to apply the new settings.|n|nAre you sure you want to continue?|r",
				button1 = TEXT(YES),
				button2 = TEXT(NO),
				OnAccept = function()
					QuestieConfig.trackerList = false
					QuestieTrackerVariables = {};
					QuestieTrackerVariables["position"] = {
						["point"] = "CENTER",
						["relativePoint"] = "CENTER",
						["relativeTo"] = "UIParent",
						["yOfs"] = 0,
						["xOfs"] = 0,
					};
					ReloadUI()
				end,
				timeout = 60,
				exclusive = 1,
				hideOnEscape = 1
			}
			StaticPopup_Show ("TOP_DOWN")
		end
	end,
	["showquests"] = function()
	-- Default: True
		QuestieConfig.alwaysShowQuests = not QuestieConfig.alwaysShowQuests;
		if QuestieConfig.alwaysShowQuests then
			DEFAULT_CHAT_FRAME:AddMessage("Quests and Objectives: Always show.");
			Questie:Toggle();
			Questie:Toggle();
		else
			DEFAULT_CHAT_FRAME:AddMessage("Quests and Objectives: Show only when tracking.");
			Questie:Toggle();
			Questie:Toggle();
		end
	end,
	["mapnotes"] = function()
	-- Default: True
		QuestieConfig.showMapAids = not QuestieConfig.showMapAids;
		if QuestieConfig.showMapAids then
			DEFAULT_CHAT_FRAME:AddMessage("Questie notes Active!");
			Questie:Toggle();
			Questie:Toggle();
		else
			DEFAULT_CHAT_FRAME:AddMessage("Questie notes removed!");
			Questie:Toggle();
			Questie:Toggle();
		end
	end,
	["arrow"] = function()
	-- Default: True
		QuestieConfig.arrowEnabled = not QuestieConfig.arrowEnabled;
		if QuestieConfig.arrowEnabled then
			DEFAULT_CHAT_FRAME:AddMessage("Quest Arrow will now be shown");
			Questie:Toggle();
			Questie:Toggle();
		else
			DEFAULT_CHAT_FRAME:AddMessage("Quest Arrow will now be hidden");
			Questie:Toggle();
			Questie:Toggle();
		end
	end,
	["tracker"] = function()
	-- Default: True
		QuestieConfig.trackerEnabled = not QuestieConfig.trackerEnabled;
		if QuestieConfig.trackerEnabled then
			DEFAULT_CHAT_FRAME:AddMessage("Quest Tracker will now be shown");
			QuestieTracker:Show();
		else
			DEFAULT_CHAT_FRAME:AddMessage("Quest Tracker will now be hidden");
			QuestieTracker:Hide()
			QuestieTracker.frame:Hide()
		end
	end,
	["header"] = function()
	-- Default: False
		if (QuestieConfig.trackerList == false) and (QuestieConfig.showTrackerHeader == false) then
			StaticPopupDialogs["TRACKER_HEADER_F"] = {
				text = "|cFFFFFF00Due to the way the QuestTracker frame is rendered, your UI will automatically be reloaded.|n|nAre you sure you want to continue?|r",
				button1 = TEXT(YES),
				button2 = TEXT(NO),
				OnAccept = function()
					QuestieConfig.showTrackerHeader = true;
					ReloadUI()
				end,
				timeout = 60,
				exclusive = 1,
				hideOnEscape = 1
			}
			StaticPopup_Show ("TRACKER_HEADER_F")
		end
		if (QuestieConfig.trackerList == false) and (QuestieConfig.showTrackerHeader == true) then
			StaticPopupDialogs["TRACKER_HEADER_T"] = {
				text = "|cFFFFFF00Due to the way the QuestTracker frame is rendered, your UI will automatically be reloaded.|n|nAre you sure you want to continue?|r",
				button1 = TEXT(YES),
				button2 = TEXT(NO),
				OnAccept = function()
					QuestieConfig.showTrackerHeader = false;
					ReloadUI()
				end,
				timeout = 60,
				exclusive = 1,
				hideOnEscape = 1
			}
			StaticPopup_Show ("TRACKER_HEADER_T")
		end
		if (QuestieConfig.trackerList == true) then
			QuestieConfig.showTrackerHeader = not QuestieConfig.showTrackerHeader;
			if QuestieConfig.showTrackerHeader then
				DEFAULT_CHAT_FRAME:AddMessage("Quest Tracker Header will now be shown");
				QuestieTrackerHeader:Show();
			else
				DEFAULT_CHAT_FRAME:AddMessage("Quest Tracker Header will now be hidden");
				QuestieTrackerHeader:Hide();
			end
		end
	end,
	["minlevel"] = function()
	-- Default: False
		QuestieConfig.minLevelFilter = not QuestieConfig.minLevelFilter;
		if QuestieConfig.minLevelFilter then
			DEFAULT_CHAT_FRAME:AddMessage("Min-level filter on");
			Questie:Toggle();
			Questie:Toggle();
		else
			DEFAULT_CHAT_FRAME:AddMessage("Min-level filter off");
			Questie:Toggle();
			Questie:Toggle();
		end
	end,
	["maxlevel"] = function()
	-- Default: False
		QuestieConfig.maxLevelFilter = not QuestieConfig.maxLevelFilter;
		if QuestieConfig.maxLevelFilter then
			DEFAULT_CHAT_FRAME:AddMessage("Max-level filter on");
			Questie:Toggle();
			Questie:Toggle();
		else
			DEFAULT_CHAT_FRAME:AddMessage("Max-level filter off");
			Questie:Toggle();
			Questie:Toggle();
		end
	end,
	["setminlevel"] = function(args)
	-- Default: 5 levels below current level - which is the Blizzard default
		if args then
			local val = tonumber(args);
			QuestieConfig.minShowLevel = val;
			Questie:Toggle();
			Questie:Toggle();
		else
			DEFAULT_CHAT_FRAME:AddMessage("|cFFFF2222Error: invalid number supplied!");
		end
	end,
	["setmaxlevel"] = function(args)
	-- Default: Quest will not appear until current level is 3 levels above Blizzards suggested level
		if args then
			local val = tonumber(args);
			QuestieConfig.maxShowLevel = val;
			Questie:Toggle();
			Questie:Toggle();
		else
			DEFAULT_CHAT_FRAME:AddMessage("|cFFFF2222Error: invalid number supplied!");
		end
	end,
	["professions"] = function()
	-- Default: False
		QuestieConfig.showProfessionQuests = not QuestieConfig.showProfessionQuests;
		if QuestieConfig.showProfessionQuests then
			DEFAULT_CHAT_FRAME:AddMessage("Profession quests will now be shown");
			Questie:Toggle();
			Questie:Toggle();
		else
			DEFAULT_CHAT_FRAME:AddMessage("Profession quests will now be hidden");
			Questie:Toggle();
			Questie:Toggle();
		end
	end,
	["resizemap"] = function()
	-- Default: False
		QuestieConfig.resizeWorldmap = not QuestieConfig.resizeWorldmap;
		if QuestieConfig.resizeWorldmap then
			ReloadUI();
		else
			ReloadUI();
		end
	end,
	["clearconfig"] = function()
		Questie:ClearConfig("slash")
	end,
	["NUKE"] = function()
	-- Default: None - Popup confirmation of Yes or No - Popup has a 60 second timeout.
		StaticPopupDialogs["NUKE_CONFIG"] = {
			text = "|cFFFFFF00You are about to compleatly wipe your characters saved variables. This includes all quests you've completed, settings and preferences, and QuestTracker location.|n|nAre you sure you want to continue?|r",
			button1 = TEXT(YES),
			button2 = TEXT(NO),
			OnAccept = function()
				-- Clears all quests
				QuestieSeenQuests = {}
				-- Clears all tracked quests
				QuestieTrackedQuests = {}
				-- Clears config
				QuestieConfig = {}
				-- Setup default settings
				QuestieConfig = {
					["alwaysShowDistance"] = false,
					["alwaysShowLevel"] = true,
					["alwaysShowQuests"] = true,
					["arrowEnabled"] = true,
					["boldColors"] = false,
					["iconScale"] = 1.0,
					["maxLevelFilter"] = false,
					["maxShowLevel"] = 3,
					["minLevelFilter"] = false,
					["minShowLevel"] = 5,
					["showMapAids"] = true,
					["showProfessionQuests"] = false,
					["showTrackerHeader"] = false,
					["trackerEnabled"] = true,
					["trackerList"] = false,
					["resizeWorldmap"] = false,
					["getVersion"] = QuestieVersion,
				}
				-- Clears tracker settings
				QuestieTrackerVariables = {}
				QuestieTrackerVariables = {
					["position"] = {
						["relativeTo"] = "UIParent",
						["point"] = "CENTER",
						["relativePoint"] = "CENTER",
						["yOfs"] = 0,
						["xOfs"] = 0,
					},
				}
				ReloadUI()
			end,
			timeout = 60,
			exclusive = 1,
			hideOnEscape = 1
		}
		StaticPopup_Show ("NUKE_CONFIG")
	end,
	["cleartracker"] = function()
	-- Default: None - Popup confirmation of Yes or No - Popup has a 60 second timeout.
		StaticPopupDialogs["CLEAR_TRACKER"] = {
			text = "|cFFFFFF00You are about to reset your QuestTracker. This will only reset it's saved location and place it in the center of your screen. Your UI will be reloaded automatically.|n|nAre you sure you want to continue?|r",
			button1 = TEXT(YES),
			button2 = TEXT(NO),
			OnAccept = function()
				-- Clears tracker settings
				QuestieTrackerVariables = {}
				-- Setup default settings and repositions the QuestTracker against the left side of the screen.
				QuestieTrackerVariables = {
					["position"] = {
						["relativeTo"] = "UIParent",
						["point"] = "CENTER",
						["relativePoint"] = "CENTER",
						["yOfs"] = 0,
						["xOfs"] = 0,
					},
				}
				ReloadUI()
			end,
			timeout = 60,
			exclusive = 1,
			hideOnEscape = 1
		}
		StaticPopup_Show ("CLEAR_TRACKER")
	end,
	["seticonscale"] = function(args)
	-- Default: 1.0
		if args then
			local val = tonumber(args);
			QuestieConfig.iconScale = val;
			Questie:UpdateIconScale();
			Questie:Toggle();
			Questie:Toggle();
		else
			DEFAULT_CHAT_FRAME:AddMessage("|cFFFF2222Error: invalid number supplied!");
		end
	end,
	["settings"] = function()
		Questie:CurrentUserToggles()
	end,
	["help"] = function()
		DEFAULT_CHAT_FRAME:AddMessage("Questie SlashCommand Help Menu:", 1, 0.75, 0);
		DEFAULT_CHAT_FRAME:AddMessage("|c0000c0ff  /questie arrow |r-- |c0000ffc0(toggle)|r QuestArrow", 0.75, 0.75, 0.75);
		DEFAULT_CHAT_FRAME:AddMessage("|c0000c0ff  /questie clearconfig |r-- Resets Questie settings. It does NOT delete your quest data.", 0.75, 0.75, 0.75);
		DEFAULT_CHAT_FRAME:AddMessage("|c0000c0ff  /questie cleartracker |r-- Relocates the QuestTracker to the center of your screen.", 0.75, 0.75, 0.75);
		DEFAULT_CHAT_FRAME:AddMessage("|c0000c0ff  /questie color |r-- Select from two different color schemes", 0.75, 0.75, 0.75);
		DEFAULT_CHAT_FRAME:AddMessage("|c0000c0ff  /questie header |r-- |c0000ffc0(toggle)|r QuestTracker log counter", 0.75, 0.75, 0.75);
		DEFAULT_CHAT_FRAME:AddMessage("|c0000c0ff  /questie listdirection |r-- Lists quests Top-->Down or Bottom-->Up", 0.75, 0.75, 0.75);
		DEFAULT_CHAT_FRAME:AddMessage("|c0000c0ff  /questie mapnotes |r-- |c0000ffc0(toggle)|r World/Minimap icons", 0.75, 0.75, 0.75);
		DEFAULT_CHAT_FRAME:AddMessage("|c0000c0ff  /questie maxlevel |r-- |c0000ffc0(toggle)|r Max-Level Filter", 0.75, 0.75, 0.75);
		DEFAULT_CHAT_FRAME:AddMessage("|c0000c0ff  /questie minlevel |r-- |c0000ffc0(toggle)|r Min-Level Filter", 0.75, 0.75, 0.75);
		DEFAULT_CHAT_FRAME:AddMessage("|c0000c0ff  /questie NUKE |r-- Resets ALL Questie data and settings", 0.75, 0.75, 0.75);
		DEFAULT_CHAT_FRAME:AddMessage("|c0000c0ff  /questie professions |r-- |c0000ffc0(toggle)|r Profession quests", 0.75, 0.75, 0.75);
		DEFAULT_CHAT_FRAME:AddMessage("|c0000c0ff  /questie seticonscale |r|c0000ffc0<number>|r -- Scales all icons by <X> (default=1.0)", 0.75, 0.75, 0.75);
		DEFAULT_CHAT_FRAME:AddMessage("|c0000c0ff  /questie setmaxlevel |r|c0000ffc0<number>|r -- Hides quests until <X> levels above players level (default=3)", 0.75, 0.75, 0.75);
		DEFAULT_CHAT_FRAME:AddMessage("|c0000c0ff  /questie setminlevel |r|c0000ffc0<number>|r -- Hides quests <X> levels below players level (default=5)", 0.75, 0.75, 0.75);
		DEFAULT_CHAT_FRAME:AddMessage("|c0000c0ff  /questie settings |r-- Displays your current toggles and settings.", 0.75, 0.75, 0.75);
		DEFAULT_CHAT_FRAME:AddMessage("|c0000c0ff  /questie showquests |r-- |c0000ffc0(toggle)|r Always show quests and objectives", 0.75, 0.75, 0.75);
		DEFAULT_CHAT_FRAME:AddMessage("|c0000c0ff  /questie tracker |r-- |c0000ffc0(toggle)|r QuestTracker", 0.75, 0.75, 0.75);
		if (IsAddOnLoaded("Cartographer")) or (IsAddOnLoaded("MetaMap")) then
			return
		elseif (not IsAddOnLoaded("Cartographer")) or (not IsAddOnLoaded("MetaMap")) then
			DEFAULT_CHAT_FRAME:AddMessage("|c0000c0ff  /questie resizemap |r-- |c0000ffc0(toggle)|r Resize Worldmap", 0.75, 0.75, 0.75);
		end
	end,
};
---------------------------------------------------------------------------------------------------
function Questie_SlashHandler(msgbase)
	local space = findFirst(msgbase, " ");
	local msg, args;
	if not space or space == 1 then
		msg = msgbase;
	else
		msg = string.sub(msgbase, 1, space);
		args = string.sub(msgbase, space+2);
	end
	if QuestieFastSlash[msg] ~= nil then
		QuestieFastSlash[msg](args);
	else
		if (not msg or msg=="") then
			QuestieFastSlash["help"]();
		else
			DEFAULT_CHAT_FRAME:AddMessage("Unknown operation: " .. msg .. " try /questie help");
		end
	end
end
---------------------------------------------------------------------------------------------------
-- Displays to the player all Questie vars
---------------------------------------------------------------------------------------------------
function Questie:CurrentUserToggles()
	DEFAULT_CHAT_FRAME:AddMessage("Questie Settings:", 0.5, 0.5, 1)
	local Vars = {
		[1] = { "alwaysShowLevel" },
		[2] = { "alwaysShowQuests" },
		[3] = { "arrowEnabled" },
		[4] = { "boldColors" },
		[5] = { "iconScale"},
		[6] = { "maxLevelFilter" },
		[7] = { "maxShowLevel" },
		[8] = { "minLevelFilter" },
		[9] = { "minShowLevel" },
		[10] = { "showMapAids" },
		[11] = { "showProfessionQuests" },
		[12] = { "showTrackerHeader" },
		[13] = { "trackerEnabled" },
		[14] = { "trackerList" },
		[15] = { "resizeWorldmap" },
		[16] = { "getVersion" },
	}
	if QuestieConfig then
		i = 1
		v = 1
		while Vars[i] and Vars[i][v]do
			curVar = Vars[i][v]
			DEFAULT_CHAT_FRAME:AddMessage("  "..curVar.." = "..(tostring(QuestieConfig[curVar])), 0.5, 0.5, 1)
			i = i + 1
		end
	end
end
---------------------------------------------------------------------------------------------------
-- Misc helper functions and short cuts
---------------------------------------------------------------------------------------------------
function Questie:LinkToID(link)
	if link then
		local _, _, id = string.find(link, "(%d+):")
		return tonumber(id)
	end
end
---------------------------------------------------------------------------------------------------
function GetCurrentMapID()
	local file = GetMapInfo()
	if file == nil then
		return -1
	end
	local zid = QuestieZones[file];
	if zid == nil then
		return -1
	else
		return zid[1];
	end
end
---------------------------------------------------------------------------------------------------
function Questie:MixString(mix, str)
	return Questie:MixInt(mix, Questie:HashString(str));
end
---------------------------------------------------------------------------------------------------
-- Computes an Adler-32 checksum.
function Questie:HashString(text)
	local a, b = 1, 0
	for i=1,string.len(text) do
		a = Questie:Modulo((a+string.byte(text,i)), 65521)
		b = Questie:Modulo((b+a), 65521)
	end
	return b*65536+a
end
---------------------------------------------------------------------------------------------------
-- Lua5 doesnt support mod math via the % operator
function Questie:Modulo(val, by)
	return val - math.floor(val/by)*by
end
---------------------------------------------------------------------------------------------------
function Questie:MixInt(hash, addval)
	return bit.lshift(hash, 6) + addval;
end
---------------------------------------------------------------------------------------------------
-- Returns the Levenshtein distance between the two given strings
-- credit to https://gist.github.com/Badgerati/3261142
function Questie:Levenshtein(str1, str2)
	local len1 = string.len(str1)
	local len2 = string.len(str2)
	local matrix = {}
	local cost = 0
	-- quick cut-offs to save time
	if (len1 == 0) then
		return len2
	elseif (len2 == 0) then
		return len1
	elseif (str1 == str2) then
		return 0
	end
	-- initialise the base matrix values
	for i = 0, len1, 1 do
		matrix[i] = {}
		matrix[i][0] = i
	end
	for j = 0, len2, 1 do
		matrix[0][j] = j
	end
	-- actual Levenshtein algorithm
	for i = 1, len1, 1 do
		for j = 1, len2, 1 do
			if (string.byte(str1,i) == string.byte(str2,j)) then
				cost = 0
			else
				cost = 1
			end
			matrix[i][j] = math.min(matrix[i-1][j] + 1, matrix[i][j-1] + 1, matrix[i-1][j-1] + cost)
		end
	end
	-- return the last value - this is the Levenshtein distance
	return matrix[len1][len2]
end
---------------------------------------------------------------------------------------------------
-- End of misc helper functions and short cuts
---------------------------------------------------------------------------------------------------
