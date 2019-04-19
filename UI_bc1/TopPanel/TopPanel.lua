-------------------------------
-- TopPanel.lua
-- coded by bc1 from Civ V 1.0.3.276 code
-- code is common using gk_mode and bnw_mode switches
-- compatible with Putmalk's Civ IV Diplomacy Features Mod v10
-- compatible with Gazebo's City-State Diplomacy Mod (CSD) for Brave New World v 23
-------------------------------
include( "EUI_utilities" )

Events.SequenceGameInitComplete.Add(function()
print( "Loading EUI top panel",ContextPtr,os.clock(), [[ 
 _____           ____                  _
|_   _|__  _ __ |  _ \ __ _ _ __   ___| |
  | |/ _ \| '_ \| |_) / _` | '_ \ / _ \ |
  | | (_) | |_) |  __/ (_| | | | |  __/ |
  |_|\___/| .__/|_|   \__,_|_| |_|\___|_|
          |_|
]])
local civ5_mode = InStrategicView ~= nil
local civBE_mode = not civ5_mode
local gk_mode = Game.GetReligionName ~= nil
local bnw_mode = Game.GetActiveLeague ~= nil
local civ5bnw_mode = civ5_mode and bnw_mode

-------------------------------
-- minor lua optimizations
-------------------------------
local math_ceil = math.ceil
local math_cos = math.cos
local math_floor = math.floor
local math_max = math.max
local math_min = math.min
local math_pi = math.pi
local math_sin = math.sin
local os_date = os.date
local os_time = os.time
local next = next
local pairs = pairs
local tonumber = tonumber
local format = string.format
local concat = table.concat
local insert = table.insert
local remove = table.remove

--EUI_utilities
local IconHookup = EUI.IconHookup
local CityPlots = EUI.CityPlots
local PopScratchDeal = EUI.PopScratchDeal
local PushScratchDeal = EUI.PushScratchDeal
local table = EUI.table
local GreatPeopleIcon = EUI.GreatPeopleIcon
local GameInfo = EUI.GameInfoCache -- warning! use iterator ONLY with table field conditions, NOT string SQL query
local GetHelpTextForAffinity
if civBE_mode then
	include( "EUI_tooltips" )
	GetHelpTextForAffinity = EUI.GetHelpTextForAffinity
end

local ButtonPopupTypes = ButtonPopupTypes
local ContextPtr = ContextPtr
local Controls = Controls
local DomainTypes = DomainTypes
local Events = Events
local FaithPurchaseTypes = FaithPurchaseTypes
local Game = Game
local GameDefines = GameDefines
local GameInfoTypes = GameInfoTypes
local GameOptionTypes = GameOptionTypes
local HexToWorld = HexToWorld
local L = Locale.ConvertTextKey
local Locale = Locale
local Map = Map
local Mouse = Mouse
local OptionsManager = OptionsManager
local OrderTypes = OrderTypes
local Players = Players
local PreGame = PreGame
local ResourceUsageTypes = ResourceUsageTypes
local ToGridFromHex = ToGridFromHex
local ToHexFromGrid = ToHexFromGrid
local Teams = Teams
local TradeableItems = TradeableItems
local UI = UI
local YieldTypes = YieldTypes

-------------------------------
-- Globals
-------------------------------

local g_activePlayerID, g_activePlayer, g_activeTeamID, g_activeTeam, g_activeCivilizationID, g_activeCivilization, g_activeTeamTechs

local g_isBasicHelp, g_isScienceEnabled, g_isPoliciesEnabled, g_isHappinessEnabled, g_isReligionEnabled, g_isHealthEnabled

local g_ScratchDeal = UI.GetScratchDeal()
local g_PlayerSettings = {}
local g_GoodyPlots = {}
local g_NaturalWonderPlots = {}
local g_NaturalWonder = {}
local g_NaturalWonderIndex

local g_ResourceIcons = {}
local g_isSmallScreen = UIManager:GetScreenSizeVal() < (civ5bnw_mode and 1900 or 1600)
local g_isPopupUp = false
local g_requestTopPanelUpdate
local g_toolTipHandler = {}

local g_options = Modding.OpenUserData( "Enhanced User Interface Options", 1)
local g_clockFormats = { "%H:%M", "%I:%M %p", "%X", "%c" }
local g_clockFormat, g_alarmTime
local g_startTurn = Game.GetStartTurn()

local g_scienceTextColor = civ5_mode and "[COLOR:33:190:247:255]" or "[COLOR_MENU_BLUE]"
local g_currencyIcon = civ5_mode and "[ICON_GOLD]" or "[ICON_ENERGY]"
local g_currencyString = civ5_mode and "GOLD" or "ENERGY"
--local g_happinessIcon = civ5_mode and "[ICON_HAPPY]" or "[ICON_HEALTH]"
local g_happinessString = civ5_mode and "HAPPINESS" or "HEALTH"

local textTipControls = {}
local tipControls = {}
TTManager:GetTypeControlTable( "TooltipTypeTopPanel", textTipControls )
TTManager:GetTypeControlTable( "EUI_TopPanelProgressTooltip", tipControls )
local g_luxuries = {}
for resource in GameInfo.Resources() do
	if Game.GetResourceUsageType(resource.ID) == ResourceUsageTypes.RESOURCEUSAGE_LUXURY then
		insert( g_luxuries, resource )
	end
end
-------------------------------
-- Utilities
-------------------------------
local GamePedia = Events.SearchForPediaEntry.Call
local GameMessagePopup = Events.SerialEventGameMessagePopup.Call
local function GamePopup( popupType, data2 )
	GameMessagePopup{ Type = popupType, Data1 = 1, Data2 = data2 }
end

local function Colorize( x )
	if x > 0 then
		return "[COLOR_POSITIVE_TEXT]" .. x .. "[ENDCOLOR]"
	elseif x < 0 then
		return "[COLOR_WARNING_TEXT]" .. x .. "[ENDCOLOR]"
	else
		return "0"
	end
end
local function ColorizeSigned( x )
	if x > 0 then
		return "[COLOR_POSITIVE_TEXT]+" .. x .. "[ENDCOLOR]"
	elseif x < 0 then
		return "[COLOR_WARNING_TEXT]" .. x .. "[ENDCOLOR]"
	else
		return "0"
	end
end
local function ColorizeAbs( x )
	if x > 0 then
		return "[COLOR_POSITIVE_TEXT]" .. x .. "[ENDCOLOR]"
	elseif x < 0 then
		return "[COLOR_WARNING_TEXT]" .. -x .. "[ENDCOLOR]"
	else
		return "0"
	end
end
local function setTextToolTip( tipText )
	textTipControls.TooltipLabel:SetText( tipText )
	return textTipControls.TopPanelMouseover:DoAutoSize()
end

-------------------------------------------------
-- Great People
-------------------------------------------------

-- TODO: optimize loop, add capability for several simultaneous gp's
local function ScanGP( player )
	local gp = nil
	for city in player:Cities() do

		for specialist in GameInfo.Specialists() do

			local gpuClass = specialist.GreatPeopleUnitClass	-- nil / UNITCLASS_ARTIST / UNITCLASS_SCIENTIST / UNITCLASS_MERCHANT / UNITCLASS_ENGINEER ...
			local unitClass = gpuClass and GameInfo.UnitClasses[gpuClass]
			if unitClass then
				local gpThreshold = city:GetSpecialistUpgradeThreshold(unitClass.ID)
				local gpProgress = city:GetSpecialistGreatPersonProgressTimes100(specialist.ID) / 100
				local gpChange = specialist.GreatPeopleRateChange * city:GetSpecialistCount( specialist.ID )
				for building in GameInfo.Buildings{ SpecialistType = specialist.Type } do
					if city:IsHasBuilding(building.ID) then
						gpChange = gpChange + building.GreatPeopleRateChange
					end
				end

				local gpChangePlayerMod = player:GetGreatPeopleRateModifier()
				local gpChangeCityMod = city:GetGreatPeopleRateModifier()
				local gpChangePolicyMod = 0
				local gpChangeWorldCongressMod = 0
				local gpChangeGoldenAgeMod = 0
				local isGoldenAge = player:GetGoldenAgeTurns() > 0

				if bnw_mode then
					-- Generic GP mods

					gpChangePolicyMod = player:GetPolicyGreatPeopleRateModifier()

					local worldCongress = (Game.GetNumActiveLeagues() > 0) and Game.GetActiveLeague()

					-- GP mods by type
					if specialist.GreatPeopleUnitClass == "UNITCLASS_WRITER" then
						gpChangePlayerMod = gpChangePlayerMod + player:GetGreatWriterRateModifier()
						gpChangePolicyMod = gpChangePolicyMod + player:GetPolicyGreatWriterRateModifier()
						if worldCongress then
							gpChangeWorldCongressMod = gpChangeWorldCongressMod + worldCongress:GetArtsyGreatPersonRateModifier()
						end
						if isGoldenAge and player:GetGoldenAgeGreatWriterRateModifier() > 0 then
							gpChangeGoldenAgeMod = gpChangeGoldenAgeMod + player:GetGoldenAgeGreatWriterRateModifier()
						end
					elseif specialist.GreatPeopleUnitClass == "UNITCLASS_ARTIST" then
						gpChangePlayerMod = gpChangePlayerMod + player:GetGreatArtistRateModifier()
						gpChangePolicyMod = gpChangePolicyMod + player:GetPolicyGreatArtistRateModifier()
						if worldCongress then
							gpChangeWorldCongressMod = gpChangeWorldCongressMod + worldCongress:GetArtsyGreatPersonRateModifier()
						end
						if isGoldenAge and player:GetGoldenAgeGreatArtistRateModifier() > 0 then
							gpChangeGoldenAgeMod = gpChangeGoldenAgeMod + player:GetGoldenAgeGreatArtistRateModifier()
						end
					elseif specialist.GreatPeopleUnitClass == "UNITCLASS_MUSICIAN" then
						gpChangePlayerMod = gpChangePlayerMod + player:GetGreatMusicianRateModifier()
						gpChangePolicyMod = gpChangePolicyMod + player:GetPolicyGreatMusicianRateModifier()
						if worldCongress then
							gpChangeWorldCongressMod = gpChangeWorldCongressMod + worldCongress:GetArtsyGreatPersonRateModifier()
						end
						if isGoldenAge and player:GetGoldenAgeGreatMusicianRateModifier() > 0 then
							gpChangeGoldenAgeMod = gpChangeGoldenAgeMod + player:GetGoldenAgeGreatMusicianRateModifier()
						end
					elseif specialist.GreatPeopleUnitClass == "UNITCLASS_SCIENTIST" then
						gpChangePlayerMod = gpChangePlayerMod + player:GetGreatScientistRateModifier()
						gpChangePolicyMod = gpChangePolicyMod + player:GetPolicyGreatScientistRateModifier()
						if worldCongress then
							gpChangeWorldCongressMod = gpChangeWorldCongressMod + worldCongress:GetScienceyGreatPersonRateModifier()
						end
					elseif specialist.GreatPeopleUnitClass == "UNITCLASS_MERCHANT" then
						gpChangePlayerMod = gpChangePlayerMod + player:GetGreatMerchantRateModifier()
						gpChangePolicyMod = gpChangePolicyMod + player:GetPolicyGreatMerchantRateModifier()
						if worldCongress then
							gpChangeWorldCongressMod = gpChangeWorldCongressMod + worldCongress:GetScienceyGreatPersonRateModifier()
						end
					elseif specialist.GreatPeopleUnitClass == "UNITCLASS_ENGINEER" then
						gpChangePlayerMod = gpChangePlayerMod + player:GetGreatEngineerRateModifier()
						gpChangePolicyMod = gpChangePolicyMod + player:GetPolicyGreatEngineerRateModifier()
						if worldCongress then
							gpChangeWorldCongressMod = gpChangeWorldCongressMod + worldCongress:GetScienceyGreatPersonRateModifier()
						end
					end

					-- Player mod actually includes policy mod and World Congress mod, so separate them for tooltip

					gpChangePlayerMod = gpChangePlayerMod - gpChangePolicyMod - gpChangeWorldCongressMod

				elseif gpuClass == "UNITCLASS_SCIENTIST" then

					gpChangePlayerMod = gpChangePlayerMod + player:GetTraitGreatScientistRateModifier()

				end

				gpChange = gpChange * (1 + (gpChangePlayerMod + gpChangePolicyMod + gpChangeWorldCongressMod + gpChangeCityMod + gpChangeGoldenAgeMod) / 100)

				if gpChange > 0 then
					local gpTurns = math_ceil( (gpThreshold - gpProgress) / gpChange )
					if not gp or gpTurns < gp.Turns then
						gp = {
							Turns = gpTurns,
							City = city,
							Class = unitClass,
							Progress = gpProgress,
							Threshold = gpThreshold,
							Change = gpChange,
						}
					end
				end

			end -- unitClass
		end -- specialist
	end -- city
	return gp
end

-------------------------------------------------
-- Top Panel Update
-------------------------------------------------

LuaEvents.EUI_UpdateTopPanel.Add( function()

	g_requestTopPanelUpdate = false
	local activePlayer = g_activePlayer
	local activeTeamTechs = g_activeTeamTechs
	local Controls = Controls
	-----------------------------
	-- Update science stats
	-----------------------------
	if g_isScienceEnabled then

		local sciencePerTurnTimes100 = activePlayer:GetScienceTimes100()

		local strSciencePerTurn = format( "+%.0f", sciencePerTurnTimes100 / 100 )

		-- Gold being deducted from our Science ?
		if activePlayer:GetScienceFromBudgetDeficitTimes100() == 0 then
			strSciencePerTurn = g_scienceTextColor .. strSciencePerTurn .. "[ENDCOLOR][ICON_RESEARCH]"	-- Normal Science state
		else
			strSciencePerTurn = "[COLOR:255:0:60:255]" .. strSciencePerTurn .. "[ENDCOLOR][ICON_RESEARCH]"	-- Science deductions
		end
		Controls.SciencePerTurn:SetText( strSciencePerTurn )

		if civ5_mode then
			local strScienceTurnsRemaining = ""
			local techID = activePlayer:GetCurrentResearch()

			if techID ~= -1 then
			-- research in progress

				local scienceProgress = activePlayer:GetResearchProgress(techID)
				local scienceNeeded = activePlayer:GetResearchCost(techID)

				if sciencePerTurnTimes100 > 0 then

					Controls.ScienceBar:SetPercent( scienceProgress / scienceNeeded )
					Controls.ScienceBarShadow:SetPercent( (scienceProgress*100 + sciencePerTurnTimes100) / scienceNeeded / 100 )
					if sciencePerTurnTimes100 > 0 then
						strScienceTurnsRemaining = activePlayer:GetResearchTurnsLeft(techID, true)
					end
					Controls.ScienceBox:SetHide( false )
				else
					Controls.ScienceBox:SetHide( true )
				end

			else
			-- not researching a tech

				Controls.ScienceBox:SetHide(true)
				techID = activeTeamTechs:GetLastTechAcquired()

			end

			-- if we have one, update the tech picture
			local techInfo = GameInfo.Technologies[ techID ]
			Controls.ScienceTurns:SetText( strScienceTurnsRemaining )
			Controls.TechIcon:SetHide(not (techInfo and IconHookup( techInfo.PortraitIndex, 45, techInfo.IconAtlas, Controls.TechIcon )) )
		end
	end

	-----------------------------
	-- Update Resources
	-----------------------------

	for resourceID, instance in pairs( g_ResourceIcons ) do
		if activePlayer:GetNumResourceTotal( resourceID, true ) > 0 or activeTeamTechs:HasTech( instance.TechRevealID ) then
			instance.Count:SetText( Colorize( activePlayer:GetNumResourceAvailable(resourceID, true) ) )
			instance.Image:SetHide( false )
		else
			instance.Image:SetHide( true )
		end
	end

	-----------------------------
	-- Update turn counter
	-----------------------------
	local gameTurn = Game.GetGameTurn()
	if g_startTurn > 0 then
		gameTurn = gameTurn .. "("..(gameTurn-g_startTurn)..")"
	end
	Controls.CurrentTurn:LocalizeAndSetText( "TXT_KEY_TP_TURN_COUNTER", gameTurn )

	local culturePerTurn, cultureProgress

	if civ5_mode then
		-- Clever Firaxis...
		culturePerTurn = activePlayer:GetTotalJONSCulturePerTurn()
		cultureProgress = activePlayer:GetJONSCulture()

		-----------------------------
		-- Update gold stats
		-----------------------------

		Controls.GoldPerTurn:LocalizeAndSetText( "TXT_KEY_TOP_PANEL_GOLD", activePlayer:GetGold(), activePlayer:CalculateGoldRate() )

		-----------------------------
		-- Update Happy & Golden Age
		-----------------------------

		local unhappyProductionModifier = 0
		local unhappyFoodModifier = 0
		local unhappyGoldModifier = 0

		if g_isHappinessEnabled then

			local happinessText
			local excessHappiness = activePlayer:GetExcessHappiness()
			local turnsRemaining = ""

			if not activePlayer:IsEmpireUnhappy() then

				happinessText = format("[COLOR:60:255:60:255]%i[ENDCOLOR][ICON_HAPPINESS_1]", excessHappiness)

			elseif activePlayer:IsEmpireVeryUnhappy() then

				happinessText = format("[COLOR:255:60:60:255]%i[ENDCOLOR][ICON_HAPPINESS_4]", -excessHappiness)
				unhappyFoodModifier = GameDefines.VERY_UNHAPPY_GROWTH_PENALTY
				if not bnw_mode then
					unhappyProductionModifier = GameDefines.VERY_UNHAPPY_PRODUCTION_PENALTY
				end

			else -- IsEmpireUnhappy

				happinessText = format("[COLOR:255:60:60:255]%i[ENDCOLOR][ICON_HAPPINESS_3]", -excessHappiness)
				unhappyFoodModifier = GameDefines.UNHAPPY_GROWTH_PENALTY
			end
			Controls.HappinessString:SetText(happinessText)

			if bnw_mode and excessHappiness < 0 then
				unhappyProductionModifier = math_max( -excessHappiness * GameDefines.VERY_UNHAPPY_PRODUCTION_PENALTY_PER_UNHAPPY, GameDefines.VERY_UNHAPPY_MAX_PRODUCTION_PENALTY )
				unhappyGoldModifier = math_max( -excessHappiness * GameDefines.VERY_UNHAPPY_GOLD_PENALTY_PER_UNHAPPY, GameDefines.VERY_UNHAPPY_MAX_GOLD_PENALTY )
			end

			local goldenAgeTurns = activePlayer:GetGoldenAgeTurns()
			local happyProgress = activePlayer:GetGoldenAgeProgressMeter()
			local happyNeeded = activePlayer:GetGoldenAgeProgressThreshold()
			local happyProgressNext = happyProgress + excessHappiness

			if goldenAgeTurns > 0 then
				Controls.GoldenAgeAnim:SetHide(false)
				Controls.HappyBox:SetHide(true)
				turnsRemaining = goldenAgeTurns
			else
				Controls.GoldenAgeAnim:SetHide(true)
				if happyNeeded > 0 then
					Controls.HappyBar:SetPercent( happyProgress / happyNeeded )
					Controls.HappyBarShadow:SetPercent( happyProgressNext / happyNeeded )
					if excessHappiness > 0 then
						turnsRemaining = math_ceil((happyNeeded - happyProgress) / excessHappiness)
					end
					Controls.HappyBox:SetHide(false)
				else
					Controls.HappyBox:SetHide(true)
				end
			end

			Controls.HappyTurns:SetText(turnsRemaining)
		end

		-----------------------------
		-- Update Faith
		-----------------------------
		if g_isReligionEnabled then
			local faithPerTurn = activePlayer:GetTotalFaithPerTurn()
			local faithProgress = activePlayer:GetFaith()
			local faithProgressNext = faithProgress + faithPerTurn

			local faithTarget, faithNeeded

			local iconSize = 45
			local faithPurchaseType = activePlayer:GetFaithPurchaseType()
			local faithPurchaseIndex = activePlayer:GetFaithPurchaseIndex()
			local capitalCity = activePlayer:GetCapitalCity()

			if faithPurchaseType == FaithPurchaseTypes.FAITH_PURCHASE_UNIT then

				faithTarget = GameInfo.Units[ faithPurchaseIndex ]
				faithNeeded = faithTarget and capitalCity and capitalCity:GetUnitFaithPurchaseCost(faithTarget.ID, true)

			elseif faithPurchaseType == FaithPurchaseTypes.FAITH_PURCHASE_BUILDING then

				faithTarget = GameInfo.Buildings[ faithPurchaseIndex ]
				faithNeeded = faithTarget and capitalCity and capitalCity:GetBuildingFaithPurchaseCost(faithTarget.ID, true)

			elseif faithPurchaseType == FaithPurchaseTypes.FAITH_PURCHASE_SAVE_PROPHET then

				faithTarget = GameInfo.Units.UNIT_PROPHET
				faithNeeded = activePlayer:GetMinimumFaithNextGreatProphet()

			elseif activePlayer:GetCurrentEra() < GameInfoTypes.ERA_INDUSTRIAL then
				if activePlayer:CanCreatePantheon(false) then

					faithTarget = GameInfo.Religions.RELIGION_PANTHEON
					iconSize = 48
					faithNeeded = Game.GetMinimumFaithNextPantheon()

				elseif Game.GetNumReligionsStillToFound() > 0 then

					faithTarget = GameInfo.Units.UNIT_PROPHET
					faithNeeded = activePlayer:GetMinimumFaithNextGreatProphet()
				end
			end

			local turnsRemaining = ""
			if faithNeeded and faithNeeded > 0 then
				Controls.FaithBar:SetPercent( faithProgress / faithNeeded )
				Controls.FaithBarShadow:SetPercent( faithProgressNext / faithNeeded )
				if faithPerTurn > 0 then
					turnsRemaining = math_ceil((faithNeeded - faithProgress) / faithPerTurn )
				end
				Controls.FaithBox:SetHide(false)
				Controls.FaithString:SetText( format("+%i[ICON_PEACE]", faithPerTurn ) )
			else
				Controls.FaithBox:SetHide(true)
				Controls.FaithString:SetText( format("[ICON_PEACE]%i(+%i)", faithProgress, faithPerTurn ) )
			end

			Controls.FaithTurns:SetText( turnsRemaining )

			Controls.FaithIcon:SetHide( not (faithTarget and IconHookup(faithTarget.PortraitIndex, iconSize, faithTarget.IconAtlas, Controls.FaithIcon) ) )
		end

		-----------------------------
		-- Update Great People
		-----------------------------
		local gp = ScanGP( activePlayer )

		if gp then
			Controls.GpBar:SetPercent( gp.Progress / gp.Threshold )
			Controls.GpBarShadow:SetPercent( (gp.Progress+gp.Change) / gp.Threshold )
			Controls.GpTurns:SetText(gp.Turns)
			Controls.GpBox:SetHide(false)
			local gpUnit = GameInfo.Units[ gp.Class.DefaultUnit ]
			Controls.GpIcon:SetHide(not (gpUnit and IconHookup(gpUnit.PortraitIndex, 45, gpUnit.IconAtlas, Controls.GpIcon)))
		else
			Controls.GpBox:SetHide(true)
			Controls.GpIcon:SetHide(true)
			Controls.GpTurns:SetText("")
		end

		-----------------------------
		-- Update Alerts
		-----------------------------

		local unitSupplyProductionModifier = activePlayer:GetUnitProductionMaintenanceMod()
		local globalProductionModifier = unhappyProductionModifier + unitSupplyProductionModifier

		if globalProductionModifier < 0
			or unhappyFoodModifier < 0
			or unhappyGoldModifier < 0
		then
			local tips = table()

			if activePlayer:IsEmpireVeryUnhappy() then
				insert( tips, L"TXT_KEY_TP_EMPIRE_VERY_UNHAPPY" )

			elseif activePlayer:IsEmpireUnhappy() then
				insert( tips, L"TXT_KEY_TP_EMPIRE_UNHAPPY" )
			end

			if unitSupplyProductionModifier < 0 then
				insert( tips, L("TXT_KEY_UNIT_SUPPLY_REACHED_TOOLTIP", activePlayer:GetNumUnitsSupplied(), activePlayer:GetNumUnitsOutOfSupply(), -unitSupplyProductionModifier ) )
			end

			local warningText = ""
			if unhappyFoodModifier < 0 then
				warningText = format("%+g%%[ICON_FOOD]", unhappyFoodModifier )
			end
			if globalProductionModifier < 0 then
				warningText = warningText .. format("%+g%%[ICON_PRODUCTION]", globalProductionModifier )
			end
			if unhappyGoldModifier < 0 then
				if globalProductionModifier == unhappyGoldModifier then
					warningText = warningText .. g_currencyIcon
				else
					warningText = warningText .. format("%+g%%%s", unhappyGoldModifier, g_currencyIcon )
				end
			end
			Controls.WarningString:SetText( " [COLOR:255:60:60:255]" .. warningText .. "[ENDCOLOR]" )

			Controls.WarningString:SetToolTipString( concat( tips, "[NEWLINE][NEWLINE]" ) )
			Controls.WarningString:SetHide(false)
			Controls.UnitSupplyString:SetHide(false)
		else
			Controls.WarningString:SetHide(true)
			Controls.UnitSupplyString:SetHide(true)
		end

		-----------------------------
		-- Update date
		-----------------------------
		local date = Game.GetTurnString()

		if gk_mode and activePlayer:IsUsingMayaCalendar() then
			Controls.CurrentDate:LocalizeAndSetToolTip( "TXT_KEY_MAYA_DATE_TOOLTIP", activePlayer:GetMayaCalendarLongString(), date )
			date = activePlayer:GetMayaCalendarString()
		end
		Controls.CurrentDate:SetText( date )

		-----------------------------
		-- Update Tourism and
		-- International Trade Routes
		-----------------------------
		if bnw_mode then
			Controls.InternationalTradeRoutes:SetText( format( "%i/%i[ICON_INTERNATIONAL_TRADE]", activePlayer:GetNumInternationalTradeRoutesUsed(), activePlayer:GetNumInternationalTradeRoutesAvailable() ) )
			Controls.TourismString:SetText( format( "%+i[ICON_TOURISM]", activePlayer:GetTourism() ) )
		end
	else
		-----------------------------
		-- Update affinity status
		-----------------------------
		Controls.Purity:LocalizeAndSetText( "TXT_KEY_AFFINITY_STATUS", GameInfo.Affinity_Types.AFFINITY_TYPE_PURITY.IconString, activePlayer:GetAffinityLevel( GameInfoTypes.AFFINITY_TYPE_PURITY ) )
		local percentToNextPurityLevel = activePlayer:GetAffinityPercentTowardsNextLevel( GameInfoTypes.AFFINITY_TYPE_PURITY )
		if activePlayer:GetAffinityPercentTowardsMaxLevel( GameInfoTypes.AFFINITY_TYPE_PURITY ) >= 100 then
			percentToNextPurityLevel = 100
		end
		Controls.PurityProgressBar:Resize(5, math_floor((percentToNextPurityLevel/100)*30))

		Controls.Harmony:LocalizeAndSetText( "TXT_KEY_AFFINITY_STATUS", GameInfo.Affinity_Types.AFFINITY_TYPE_HARMONY.IconString, activePlayer:GetAffinityLevel( GameInfoTypes.AFFINITY_TYPE_HARMONY ) )
		local percentToNextHarmonyLevel = activePlayer:GetAffinityPercentTowardsNextLevel( GameInfoTypes.AFFINITY_TYPE_HARMONY )
		if activePlayer:GetAffinityPercentTowardsMaxLevel( GameInfoTypes.AFFINITY_TYPE_HARMONY ) >= 100 then
			percentToNextHarmonyLevel = 100
		end
		Controls.HarmonyProgressBar:Resize(5, math_floor((percentToNextHarmonyLevel/100)*30))

		Controls.Supremacy:LocalizeAndSetText( "TXT_KEY_AFFINITY_STATUS", GameInfo.Affinity_Types.AFFINITY_TYPE_SUPREMACY.IconString, activePlayer:GetAffinityLevel( GameInfoTypes.AFFINITY_TYPE_SUPREMACY ) )
		local percentToNextSupremacyLevel = activePlayer:GetAffinityPercentTowardsNextLevel( GameInfoTypes.AFFINITY_TYPE_SUPREMACY )
		if activePlayer:GetAffinityPercentTowardsMaxLevel( GameInfoTypes.AFFINITY_TYPE_SUPREMACY ) >= 100 then
			percentToNextSupremacyLevel = 100
		end
		Controls.SupremacyProgressBar:Resize(5, math_floor((percentToNextSupremacyLevel/100)*30))

		-----------------------------
		-- Update energy stats
		-----------------------------

		Controls.GoldPerTurn:LocalizeAndSetText( "TXT_KEY_TOP_PANEL_ENERGY", activePlayer:GetEnergy(), activePlayer:CalculateGoldRate() )

		-----------------------------
		-- Update Health
		-----------------------------
		if g_isHealthEnabled then
			local excessHealth = activePlayer:GetExcessHealth()
			if excessHealth < 0 then
				Controls.HealthString:SetText( format("[COLOR_RED]%i[ENDCOLOR][ICON_HEALTH_3]", -excessHealth) )
			else
				Controls.HealthString:SetText( format("[COLOR_GREEN]%i[ENDCOLOR][ICON_HEALTH_1]", excessHealth) )
			end
--				SetAutoWidthGridButton( Controls.HealthString, strHealth, BUTTON_PADDING )
		end

		-- Clever Firaxis...
		culturePerTurn = activePlayer:GetTotalCulturePerTurn()
		cultureProgress = activePlayer:GetCulture()
	end

	-----------------------------
	-- Update Culture
	-----------------------------

	if g_isPoliciesEnabled then

		local cultureTheshold = activePlayer:GetNextPolicyCost()
		local cultureProgressNext = cultureProgress + culturePerTurn
		local turnsRemaining = ""

		if cultureTheshold > 0 then
			Controls.CultureBar:SetPercent( cultureProgress / cultureTheshold )
			Controls.CultureBarShadow:SetPercent( cultureProgressNext / cultureTheshold )
			if culturePerTurn > 0 then
				turnsRemaining = math_ceil((cultureTheshold - cultureProgress) / culturePerTurn )
			end
			Controls.CultureBox:SetHide(false)
		else
			Controls.CultureBox:SetHide(true)
		end

		Controls.CultureTurns:SetText(turnsRemaining)
		Controls.CultureString:SetText( format("[COLOR_MAGENTA]+%i[ENDCOLOR][ICON_CULTURE]", culturePerTurn ) )
	end

	Controls.TopPanelInfoStack:CalculateSize()
	Controls.TopPanelDiploStack:CalculateSize()
	Controls.TopPanelInfoStack:ReprocessAnchoring()
	Controls.TopPanelDiploStack:ReprocessAnchoring()
	Controls.TopPanelBarL:SetSizeX( Controls.TopPanelInfoStack:GetSizeX() + 15 )
	Controls.TopPanelBarR:SetSizeX( Controls.TopPanelDiploStack:GetSizeX() + 15 )
end)
local UpdateTopPanelNow = LuaEvents.EUI_UpdateTopPanel.Call

---------------
-- Civilopedia
---------------
Controls.CivilopediaButton:RegisterCallback( Mouse.eLClick, function() GamePedia( "" ) end )

---------------
-- Menu
---------------
Controls.MenuButton:RegisterCallback( Mouse.eLClick, function()
	return UIManager:QueuePopup( LookUpControl( "/InGame/GameMenu" ), PopupPriority.InGameMenu )
end)

Controls.ExitCityScreen:RegisterCallback( Mouse.eLClick, Events.SerialEventExitCityScreen.Call )

Events.SerialEventEnterCityScreen.Add( function()
	return Controls.ExitCityScreen:SetHide( false )
end)

Events.SerialEventExitCityScreen.Add( function()
	return Controls.ExitCityScreen:SetHide( true )
end)

-------------------------------------------------
-- Science Tooltip & Click Actions
-------------------------------------------------
local function OnTechLClick()
	GamePopup( ButtonPopupTypes.BUTTONPOPUP_TECH_TREE, -1 )
end
local function OnTechRClick()
	local techInfo = GameInfo.Technologies[ g_activePlayer:GetCurrentResearch() ] or GameInfo.Technologies[ g_activePlayer:GetCurrentResearch() ]
	GamePedia( techInfo and techInfo.Description or "TXT_KEY_TECH_HEADING1_TITLE" )	-- TXT_KEY_PEDIA_CATEGORY_3_LABEL
end

local function SetMark( line, size, percent, label, text )
	local r0 = size/2
	local r1 = size * 0.43
	local r2 = size * 0.47
	local angle = percent * math_pi * 2
	local x = math_sin( angle )
	local y = -math_cos( angle )
	line:SetEndVal( r1 * x + r0, r1 * y + r0 )
	label:SetOffsetVal( r2 * x, r2 * y )
	label:SetText( text )
end

g_toolTipHandler.SciencePerTurn = function()

	local tips = table()
	local tech, showLine1, showLine2, showBlankMeter, showLossMeter, showAnimMeter, showProgressMeter, showPortrait

	if not g_isScienceEnabled then
		insert( tips, L"TXT_KEY_TOP_PANEL_SCIENCE_OFF" .. ": " .. L"TXT_KEY_TOP_PANEL_SCIENCE_OFF_TOOLTIP" )
	else

		local sciencePerTurnTimes100 = g_activePlayer:GetScienceTimes100()
		local techID = g_activePlayer:GetCurrentResearch()
		local recentTechID = g_activeTeamTechs:GetLastTechAcquired()

		local size = 256

		if bnw_mode and g_activePlayer:IsAnarchy() then
			insert( tips, L( "TXT_KEY_TP_ANARCHY", g_activePlayer:GetAnarchyNumTurns() ) )
			insert( tips, "" )
		end

		if techID ~= -1 then
		-- Are we researching something right now?
			local researchTurnsLeft = g_activePlayer:GetResearchTurnsLeft( techID, true )
			tech = GameInfo.Technologies[ techID ]
			local researchCost = g_activePlayer:GetResearchCost( techID )
			local researchProgress = g_activePlayer:GetResearchProgress( techID )
			local tip = researchProgress .. "[ICON_RESEARCH]"
			if tech then
				tip = L( "TXT_KEY_PROGRESS_TOWARDS", g_scienceTextColor .. Locale.ToUpper( tech._Name ) .. "[ENDCOLOR]" ) .. " " .. tip .. "/ " .. researchCost .. "[ICON_RESEARCH]"
			end
			insert( tips, tip )

			if sciencePerTurnTimes100 > 0 then
				local scienceOverflowTimes100 = sciencePerTurnTimes100 * researchTurnsLeft + (researchProgress - researchCost) * 100
				local tip = g_scienceTextColor .. Locale.ToUpper( L( "TXT_KEY_STR_TURNS", researchTurnsLeft ) ) .. "[ENDCOLOR] " .. format( "%+g", scienceOverflowTimes100 / 100 ) .. "[ICON_RESEARCH]"
				if researchTurnsLeft > 1 then
					tip = L( "TXT_KEY_STR_TURNS", researchTurnsLeft -1 ) .. " " .. format( "%+g", (scienceOverflowTimes100 - sciencePerTurnTimes100) / 100 ) .. "[ICON_RESEARCH]  " .. tip
				end
				insert( tips, tip )
			end
-- todo: rationalize
			local cost = g_activePlayer:GetResearchCost(techID) * 100
			local progress = g_activePlayer:GetResearchProgress(techID) * 100
			local change = g_activePlayer:GetScienceTimes100()
			local loss = g_activePlayer:GetScienceFromBudgetDeficitTimes100()
			local turnsRemaining = g_activePlayer:GetResearchTurnsLeft(techID, true)

			local progressNext = progress + change

			if turnsRemaining < 2 then
				showAnimMeter = true
				if turnsRemaining > 0 then
					tipControls.ProgressMeter:SetPercents( progress / cost, 0 )
					showProgressMeter = true
				end
			else
				tipControls.ProgressMeter:SetPercents( math_min(1, progress / cost), progressNext / cost )
				showProgressMeter = true
			end

			-- Science LOSS from Budget Deficits
			if loss < 0 then
				showLossMeter = true
				showBlankMeter = true
				tipControls.BlankMeter:SetPercents( math_min(1, progressNext / cost ), 0 )
				tipControls.LossMeter:SetPercents( math_min(1, ( progressNext - loss ) / cost ), 0 )
			end

			if change ~= 0 then
				local overflow = change * turnsRemaining + progress - cost
				if turnsRemaining > 1 then
					SetMark( tipControls.Line1, size, ( overflow - change ) / cost, tipControls.Label1, turnsRemaining - 1 )
					showLine1 = true
				end
				if overflow < cost then
					SetMark( tipControls.Line2, size, overflow / cost, tipControls.Label2, turnsRemaining )
					showLine2 = true
				end
			end

		elseif recentTechID ~= -1 then
		-- maybe we just finished something
			showAnimMeter = true
			tech = GameInfo.Technologies[ recentTechID ]
			local tip = L"TXT_KEY_NOTIFICATION_SUMMARY_NEW_RESEARCH"
			if tech then
				tip = L"TXT_KEY_RESEARCH_FINISHED" .. " " .. g_scienceTextColor .. Locale.ToUpper( tech._Name ) .. "[ENDCOLOR], " .. tip
			end
			insert( tips, tip )
		end

		-- if we have one, update the tech picture
		showPortrait = tech and IconHookup( tech.PortraitIndex, size, tech.IconAtlas, tipControls.ItemPortrait )

		insert( tips, g_scienceTextColor )
		insert( tips, format( "%+g", sciencePerTurnTimes100 / 100 ) .. "[ENDCOLOR] " .. L"TXT_KEY_REPLAY_DATA_SCIENCEPERTURN" )

		-- Science LOSS from Budget Deficits
		tips:insertLocalizedIfNonZero( "TXT_KEY_TP_SCIENCE_FROM_BUDGET_DEFICIT", g_activePlayer:GetScienceFromBudgetDeficitTimes100() / 100 )

		-- Science from Cities
		tips:insertLocalizedIfNonZero( "TXT_KEY_TP_SCIENCE_FROM_CITIES", g_activePlayer:GetScienceFromCitiesTimes100(true) / 100 )

		-- Science from Trade Routes
		tips:insertLocalizedIfNonZero( "TXT_KEY_TP_SCIENCE_FROM_ITR", ( g_activePlayer:GetScienceFromCitiesTimes100(false) - g_activePlayer:GetScienceFromCitiesTimes100(true) ) / 100 )

		-- Science from Other Players
		tips:insertLocalizedIfNonZero( "TXT_KEY_TP_SCIENCE_FROM_MINORS", g_activePlayer:GetScienceFromOtherPlayersTimes100() / 100 )

		if civ5_mode then
			-- Science from Happiness
			tips:insertLocalizedIfNonZero( "TXT_KEY_TP_SCIENCE_FROM_HAPPINESS", g_activePlayer:GetScienceFromHappinessTimes100() / 100 )

			-- Science from Vassals / Compatibility with Putmalk's Civ IV Diplomacy Features Mod
			if g_activePlayer.GetScienceFromVassalTimes100 then
				tips:insertLocalizedIfNonZero( "TXT_KEY_TP_SCIENCE_VASSALS", g_activePlayer:GetScienceFromVassalTimes100() / 100 )
			end

			-- Compatibility with Gazebo's City-State Diplomacy Mod (CSD) for Brave New World v23
			if g_activePlayer.GetScienceRateFromMinorAllies and g_activePlayer.GetScienceRateFromLeagueAid then
				tips:insertLocalizedIfNonZero( "TXT_KEY_MINOR_SCIENCE_FROM_LEAGUE_ALLIES", g_activePlayer:GetScienceRateFromMinorAllies() )
				tips:insertLocalizedIfNonZero( "TXT_KEY_SCIENCE_FUNDING_FROM_LEAGUE", g_activePlayer:GetScienceRateFromLeagueAid() )
			end

			-- Science from Research Agreements
			tips:insertLocalizedIfNonZero( "TXT_KEY_TP_SCIENCE_FROM_RESEARCH_AGREEMENTS", g_activePlayer:GetScienceFromResearchAgreementsTimes100() / 100 )

			-- Show Research Agreements

			local itemType, duration, finalTurn, data1, data2, data3, flag1, fromPlayerID
			local gameTurn = Game.GetGameTurn() - 1
			local researchAgreementCounters = {}

			PushScratchDeal()
			for i = 0, UI.GetNumCurrentDeals( g_activePlayerID ) - 1 do
				UI.LoadCurrentDeal( g_activePlayerID, i )
				g_ScratchDeal:ResetIterator()
				repeat
					if bnw_mode then
						itemType, duration, finalTurn, data1, data2, data3, flag1, fromPlayerID = g_ScratchDeal:GetNextItem()
					else
						itemType, duration, finalTurn, data1, data2, fromPlayerID = g_ScratchDeal:GetNextItem()
					end
--local itemKey for k,v in pairs( TradeableItems ) do if itemType == v then itemKey = k break end end
--print( "Deal #", i, "item type", itemType, itemKey, "duration", duration, "finalTurn", finalTurn, "data1", data1, "data2", data2, "fromPlayerID", fromPlayerID)
					if itemType == TradeableItems.TRADE_ITEM_RESEARCH_AGREEMENT and fromPlayerID ~= g_activePlayerID then
						researchAgreementCounters[fromPlayerID] = finalTurn - gameTurn
						break
					end
				until not itemType
			end
			PopScratchDeal()

			local tipIndex = #tips

			for playerID = 0, GameDefines.MAX_MAJOR_CIVS-1 do

				local player = Players[playerID]
				local teamID = player:GetTeam()

				if playerID ~= g_activePlayerID and player:IsAlive() and g_activeTeam:IsHasMet(teamID) then

					-- has reseach agreement ?
					if g_activeTeam:IsHasResearchAgreement(teamID) then
						insert( tips, "[ICON_BULLET][COLOR_POSITIVE_TEXT]" .. player:GetName() .. "[ENDCOLOR]" )
						if researchAgreementCounters[playerID] then
							tips:append( " " .. g_scienceTextColor .. Locale.ToUpper( L( "TXT_KEY_STR_TURNS", researchAgreementCounters[playerID] ) ) .. "[ENDCOLOR]" )
						end
					else
						insert( tips, "[ICON_BULLET][COLOR_WARNING_TEXT]" .. player:GetName() .. "[ENDCOLOR]" )
					end
				end
			end

			if #tips > tipIndex then
				insert( tips, tipIndex+1, "" )
				insert( tips, tipIndex+2, L"TXT_KEY_DO_RESEARCH_AGREEMENT" )
			end
		else
			-- Science from Health
			tips:insertLocalizedIfNonZero( "TXT_KEY_TP_SCIENCE_FROM_HEALTH", g_activePlayer:GetScienceFromHealthTimes100() / 100 )

			-- Science from Culture Rate
			tips:insertLocalizedIfNonZero( "TXT_KEY_TP_SCIENCE_FROM_CULTURE", g_activePlayer:GetScienceFromCultureTimes100() / 100 )

			-- Science from Diplomacy Rate
			local scienceFromDiplomacy = g_activePlayer:GetScienceFromDiplomacyTimes100() / 100
			if scienceFromDiplomacy > 0 then
				insert( tips, L( "TXT_KEY_TP_SCIENCE_FROM_DIPLOMACY", scienceFromDiplomacy ) )
			elseif scienceFromDiplomacy < 0 then
				insert( tips, L( "TXT_KEY_TP_NEGATIVE_SCIENCE_FROM_DIPLOMACY", -scienceFromDiplomacy ) )
			end
		end

		-- Let people know that building more cities makes techs harder to get
		if bnw_mode and g_isBasicHelp then
			insert( tips, "" )
			insert( tips, L( "TXT_KEY_TP_TECH_CITY_COST", Game.GetNumCitiesTechCostMod() * ( 100 + ( civBE_mode and g_activePlayer:GetNumCitiesResearchCostDiscount() or 0 ) ) / 100 ) )
		end
	end

	tipControls.Text:SetText( concat( tips, "[NEWLINE]" ) )
	tipControls.Box:DoAutoSize()

	tipControls.Line1:SetHide( not showLine1 )
	tipControls.Label1:SetHide( not showLine1 )
	tipControls.Line2:SetHide( not showLine2 )
	tipControls.Label2:SetHide( not showLine2 )
	tipControls.BlankMeter:SetHide( not showBlankMeter )
	tipControls.LossMeter:SetHide( not showLossMeter )
	tipControls.AnimMeter:SetHide( not showAnimMeter )
	tipControls.ProgressMeter:SetHide( not showProgressMeter )
	tipControls.ItemPortrait:SetHide( not showPortrait )
end
Controls.SciencePerTurn:RegisterCallback( Mouse.eLClick, OnTechLClick )
Controls.SciencePerTurn:RegisterCallback( Mouse.eRClick, OnTechRClick )
if civ5_mode then
	g_toolTipHandler.TechIcon = g_toolTipHandler.SciencePerTurn
	Controls.TechIcon:RegisterCallback( Mouse.eLClick, OnTechLClick )
	Controls.TechIcon:RegisterCallback( Mouse.eRClick, OnTechRClick )
end

-------------------------------------------------
-- Gold Tooltip & Click Actions
-------------------------------------------------
g_toolTipHandler.GoldPerTurn = function()
	local tips = table()

	local goldPerTurnFromDiplomacy = g_activePlayer:GetGoldPerTurnFromDiplomacy()
	local goldPerTurnFromOtherPlayers = math_max(0,goldPerTurnFromDiplomacy) * 100
	local goldPerTurnToOtherPlayers = -math_min(0,goldPerTurnFromDiplomacy)

	local goldPerTurnFromReligion = gk_mode and g_activePlayer:GetGoldPerTurnFromReligion() * 100 or 0
	local goldPerTurnFromCities = g_activePlayer:GetGoldFromCitiesTimes100()
	local cityConnectionGold = g_activePlayer:GetCityConnectionGoldTimes100()
	local playerTraitGold = 0
	local tradeRouteGold = 0
	local goldPerTurnFromPolicies = 0

	local unitCost = g_activePlayer:CalculateUnitCost()
	local unitSupply = g_activePlayer:CalculateUnitSupply()
	local buildingMaintenance = g_activePlayer:GetBuildingGoldMaintenance()
	local improvementMaintenance = g_activePlayer:GetImprovementGoldMaintenance()
	local vassalMaintenance = g_activePlayer.GetVassalGoldMaintenance and g_activePlayer:GetVassalGoldMaintenance() or 0	-- Compatibility with Putmalk's Civ IV Diplomacy Features Mod
	local routeMaintenance = 0
	local beaconEnergyDelta = 0

	if bnw_mode then
		tradeRouteGold = g_activePlayer:GetGoldFromCitiesMinusTradeRoutesTimes100()
		goldPerTurnFromCities, tradeRouteGold = tradeRouteGold, goldPerTurnFromCities - tradeRouteGold
		playerTraitGold = g_activePlayer:GetGoldPerTurnFromTraits() * 100
		if g_activePlayer:IsAnarchy() then
			insert( tips, L("TXT_KEY_TP_ANARCHY", g_activePlayer:GetAnarchyNumTurns() ) )
			insert( tips, "" )
		end
	end

	-- Total gold
	local totalIncome, totalWealth
	local explicitIncome = goldPerTurnFromCities + goldPerTurnFromOtherPlayers + cityConnectionGold + goldPerTurnFromReligion + tradeRouteGold + playerTraitGold
	if civ5_mode then
		totalWealth = g_activePlayer:GetGold()
		totalIncome = explicitIncome
	else
		totalWealth = g_activePlayer:GetEnergy()
		totalIncome = g_activePlayer:CalculateGrossGoldTimes100() + goldPerTurnToOtherPlayers * 100
		goldPerTurnFromPolicies = g_activePlayer:GetGoldPerTurnFromPolicies()
		explicitIncome = explicitIncome + goldPerTurnFromPolicies
		routeMaintenance = g_activePlayer:GetRouteEnergyMaintenance()
		beaconEnergyDelta = g_activePlayer:GetBeaconEnergyCostPerTurn()
	end
	insert( tips, L( "TXT_KEY_TP_AVAILABLE_GOLD", totalWealth ) )
	local totalExpenses = unitCost + unitSupply + buildingMaintenance + improvementMaintenance + goldPerTurnToOtherPlayers + vassalMaintenance + routeMaintenance + beaconEnergyDelta
	insert( tips, "" )

	-- Gold per turn

	insert( tips, format( "[COLOR_YELLOW]%+g[ENDCOLOR] ", g_activePlayer:CalculateGoldRateTimes100() / 100 ) .. L(format("TXT_KEY_REPLAY_DATA_%sPERTURN", g_currencyString)) )

	-- Science LOSS from Budget Deficits

	tips:insertLocalizedIfNonZero( "TXT_KEY_TP_SCIENCE_FROM_BUDGET_DEFICIT", g_activePlayer:GetScienceFromBudgetDeficitTimes100() / 100 )

	-- Income

	insert( tips, "[COLOR_WHITE]" )
	insert( tips, L("TXT_KEY_TP_TOTAL_INCOME", totalIncome / 100 ) )
	tips:insertLocalizedBulletIfNonZero( "TXT_KEY_TP_CITY_OUTPUT", goldPerTurnFromCities / 100 )

	if bnw_mode then
		tips:insertLocalizedBulletIfNonZero( format("TXT_KEY_TP_%s_FROM_CITY_CONNECTIONS", g_currencyString), cityConnectionGold / 100 )
		tips:insertLocalizedBulletIfNonZero( civ5_mode and "TXT_KEY_TP_GOLD_FROM_ITR" or "TXT_KEY_TP_ENERGY_FROM_TRADE_ROUTES", tradeRouteGold / 100 )
		tips:insertLocalizedBulletIfNonZero( format("TXT_KEY_TP_%s_FROM_TRAITS", g_currencyString), playerTraitGold / 100 )
		tips:insertLocalizedBulletIfNonZero( "TXT_KEY_TP_ENERGY_FROM_POLICIES", goldPerTurnFromPolicies / 100 )
	else
		tips:insertLocalizedBulletIfNonZero( format("TXT_KEY_TP_%s_FROM_TR", g_currencyString), cityConnectionGold / 100 )
	end

	tips:insertLocalizedBulletIfNonZero( format("TXT_KEY_TP_%s_FROM_OTHERS", g_currencyString), goldPerTurnFromOtherPlayers / 100 )
	tips:insertLocalizedBulletIfNonZero( format("TXT_KEY_TP_%s_FROM_RELIGION", g_currencyString), goldPerTurnFromReligion / 100 )
	tips:insertLocalizedBulletIfNonZero( "TXT_KEY_TP_YIELD_FROM_UNCATEGORIZED", (totalIncome - explicitIncome) / 100 )
	insert( tips, "[ENDCOLOR]" )

	-- Spending

	insert( tips, "[COLOR:255:150:150:255]" .. L("TXT_KEY_TP_TOTAL_EXPENSES", totalExpenses ) )
	tips:insertLocalizedBulletIfNonZero( "TXT_KEY_TP_UNIT_MAINT", unitCost )
	tips:insertLocalizedBulletIfNonZero( format("TXT_KEY_TP_%s_UNIT_SUPPLY", g_currencyString), unitSupply )
	tips:insertLocalizedBulletIfNonZero( format("TXT_KEY_TP_%s_BUILDING_MAINT", g_currencyString), buildingMaintenance )
	tips:insertLocalizedBulletIfNonZero( format("TXT_KEY_TP_%s_TILE_MAINT", g_currencyString), improvementMaintenance )
	tips:insertLocalizedBulletIfNonZero( "TXT_KEY_TP_ENERGY_ROUTE_MAINT", routeMaintenance )
	tips:insertLocalizedBulletIfNonZero( "TXT_KEY_TP_GOLD_VASSAL_MAINT", vassalMaintenance )	-- Compatibility with Putmalk's Civ IV Diplomacy Features Mod
	tips:insertLocalizedBulletIfNonZero( format("TXT_KEY_TP_%s_TO_OTHERS", g_currencyString), goldPerTurnToOtherPlayers )
	tips:insertLocalizedBulletIfNonZero( "TXT_KEY_TP_ENERGY_TO_BEACON", beaconEnergyDelta )
	insert( tips, "[ENDCOLOR]" )

	-- show gold available for trade to the active player
	local tipIndex = #tips

	for playerID = 0, GameDefines.MAX_MAJOR_CIVS-1 do

		local player = Players[playerID]

		-- Valid player? - Can't be us, has to be alive, and has to be met
		if playerID ~= g_activePlayerID and player:IsAlive() and g_activeTeam:IsHasMet( player:GetTeam() ) then
			insert( tips, "[ICON_BULLET]" .. player:GetName() .. format("  %i%s(%+i)",
					g_ScratchDeal:GetGoldAvailable(playerID, -1), g_currencyIcon, player:CalculateGoldRate() ) )
		end
	end

	if #tips > tipIndex then
		insert( tips, tipIndex+1, "" )
		insert( tips, tipIndex+2, L"TXT_KEY_EO_RESOURCES_AVAILBLE" )
	end

	-- Basic explanation

	if g_isBasicHelp then
		insert( tips, "" )
		insert( tips, L( format("TXT_KEY_TP_%s_EXPLANATION", g_currencyString) ) )
	end

	return setTextToolTip( concat( tips, "[NEWLINE]" ) )
end
Controls.GoldPerTurn:RegisterCallback( Mouse.eLClick, function() GamePopup( ButtonPopupTypes.BUTTONPOPUP_ECONOMIC_OVERVIEW ) end )
Controls.GoldPerTurn:RegisterCallback( Mouse.eRClick, function() GamePedia( format("TXT_KEY_%s_HEADING1_TITLE", g_currencyString) ) end )

if civ5_mode then
	-------------------------------------------------
	-- Great People Tooltip & Click Actions
	-------------------------------------------------
	Controls.GpIcon:RegisterCallback( Mouse.eLClick,
	function()
		local gp = ScanGP( Players[Game.GetActivePlayer()] )
		if gp then
			return UI.DoSelectCityAtPlot( gp.City:Plot() )
		end
	end)
	Controls.GpIcon:RegisterCallback( Mouse.eRClick,
	function()
		local gp = ScanGP( Players[Game.GetActivePlayer()] )
		if gp then
			return GamePedia( GameInfo.Units[ gp.Class.DefaultUnit ].Description )
		end
	end)
	g_toolTipHandler.GpIcon = function()
		local tipText = ""
		local gp = ScanGP( Players[Game.GetActivePlayer()] )
		if gp then
			local icon = GreatPeopleIcon( gp.Class.Type )
			tipText = L( "TXT_KEY_PROGRESS_TOWARDS", "[COLOR_YIELD_FOOD]" .. Locale.ToUpper( gp.Class._Name ) .. "[ENDCOLOR]" )
				.. " " .. gp.Progress .. icon .. " / " .. gp.Threshold .. icon .. "[NEWLINE]"
				.. gp.City:GetName() .. format( " %+g", gp.Change ) .. icon .. " " .. L"TXT_KEY_GOLD_PERTURN_HEADING4_TITLE"
				.. " [COLOR_YIELD_FOOD]" .. Locale.ToUpper( L( "TXT_KEY_STR_TURNS", gp.Turns ) ) .. "[ENDCOLOR]"
		else
			tipText = "No GP..."
		end
		return setTextToolTip( tipText )
	end

	-------------------------------------------------
	-- Happiness Tooltip & Click Actions
	-------------------------------------------------
	g_toolTipHandler.HappinessString = function()

		if g_isHappinessEnabled then
			local tips = table()
			local excessHappiness = g_activePlayer:GetExcessHappiness()

			if not g_activePlayer:IsEmpireUnhappy() then
				insert( tips, L("TXT_KEY_TP_TOTAL_HAPPINESS", excessHappiness) )
			elseif g_activePlayer:IsEmpireVeryUnhappy() then
				insert( tips, L("TXT_KEY_TP_TOTAL_UNHAPPINESS", "[ICON_HAPPINESS_4]", -excessHappiness) )
			else
				insert( tips, L("TXT_KEY_TP_TOTAL_UNHAPPINESS", "[ICON_HAPPINESS_3]", -excessHappiness) )
			end

			local policiesHappiness = g_activePlayer:GetHappinessFromPolicies()
			local resourcesHappiness = g_activePlayer:GetHappinessFromResources()
			local happinessFromExtraResources = g_activePlayer:GetHappinessFromResourceVariety()
			local extraLuxuryHappiness = g_activePlayer:GetExtraHappinessPerLuxury()
			local buildingHappiness = g_activePlayer:GetHappinessFromBuildings()

			local cityHappiness = 0
			local garrisonedUnitsHappiness = 0
			local minorCivHappiness = 0
			local religionHappiness = 0
			if gk_mode then
				cityHappiness = g_activePlayer:GetHappinessFromCities()
				minorCivHappiness = g_activePlayer:GetHappinessFromMinorCivs()
				religionHappiness = g_activePlayer:GetHappinessFromReligion()
			else
				garrisonedUnitsHappiness = g_activePlayer:GetHappinessFromGarrisonedUnits()
				-- Loop through all the Minors the active player knows
				for minorPlayerID = GameDefines.MAX_MAJOR_CIVS, GameDefines.MAX_CIV_PLAYERS-1 do
					minorCivHappiness = minorCivHappiness + g_activePlayer:GetHappinessFromMinor(minorPlayerID)
				end
			end
			local tradeRouteHappiness = g_activePlayer:GetHappinessFromTradeRoutes()
			local naturalWonderHappiness = g_activePlayer:GetHappinessFromNaturalWonders()
			local extraHappinessPerCity = g_activePlayer:GetExtraHappinessPerCity() * g_activePlayer:GetNumCities()
			local leagueHappiness = bnw_mode and g_activePlayer:GetHappinessFromLeagues() or 0
			local totalHappiness = g_activePlayer:GetHappiness()
			local happinessFromVassals = g_activePlayer.GetHappinessFromVassals and g_activePlayer:GetHappinessFromVassals() or 0	-- Compatibility with Putmalk's Civ IV Diplomacy Features Mod
			local handicapHappiness = totalHappiness - policiesHappiness - resourcesHappiness - cityHappiness - buildingHappiness - garrisonedUnitsHappiness - minorCivHappiness - tradeRouteHappiness - religionHappiness - naturalWonderHappiness - extraHappinessPerCity - leagueHappiness - happinessFromVassals	-- Compatibility with Putmalk's Civ IV Diplomacy Features Mod

			if g_activePlayer:IsEmpireVeryUnhappy() then

				if g_activePlayer:IsEmpireSuperUnhappy() then
					insert( tips, "[COLOR:255:60:60:255]" .. L"TXT_KEY_TP_EMPIRE_SUPER_UNHAPPY" .. "[ENDCOLOR]" )
				else
					insert( tips, "[COLOR:255:60:60:255]" .. L"TXT_KEY_TP_EMPIRE_VERY_UNHAPPY" .. "[ENDCOLOR]" )
				end
			elseif g_activePlayer:IsEmpireUnhappy() then

				insert( tips, "[COLOR:255:60:60:255]" .. L"TXT_KEY_TP_EMPIRE_UNHAPPY" .. "[ENDCOLOR]" )
			end
			-- Basic explanation of Happiness

			if g_isBasicHelp then
				insert( tips, L"TXT_KEY_TP_HAPPINESS_EXPLANATION" )
				insert( tips, "" )
			end

			-- Individual Resource Info

			local baseHappinessFromResources = 0
			local numHappinessResources = 0
			local availableResources = ""
			local missingResources = ""

			for _, resource in pairs( g_luxuries ) do
				local resourceID = resource.ID

				local numResourceAvailable = g_activePlayer:GetNumResourceAvailable(resource.ID, true)
				if numResourceAvailable > 0 then
					local resourceHappiness = gk_mode and g_activePlayer:GetHappinessFromLuxury( resourceID ) or resource.Happiness	-- GetHappinessFromLuxury includes extra happiness
					if resourceHappiness > 0 then
						availableResources = availableResources
							.. " [COLOR_POSITIVE_TEXT]"
							.. numResourceAvailable
							.. "[ENDCOLOR]"
							.. resource.IconString
						numHappinessResources = numHappinessResources + 1
						baseHappinessFromResources = baseHappinessFromResources + resourceHappiness
					end
				elseif numResourceAvailable == 0 then
					missingResources = missingResources .. resource.IconString
				else
					missingResources = missingResources
						.. " [COLOR_WARNING_TEXT]"
						.. numResourceAvailable
						.. "[ENDCOLOR]"
						.. resource.IconString
				end
			end

			--------------
			-- Unhappiness
			local unhappinessFromPupetCities = g_activePlayer:GetUnhappinessFromPuppetCityPopulation()
			local unhappinessFromSpecialists = g_activePlayer:GetUnhappinessFromCitySpecialists()
			local unhappinessFromPop = g_activePlayer:GetUnhappinessFromCityPopulation() - unhappinessFromSpecialists - unhappinessFromPupetCities

			insert( tips, "[COLOR:255:150:150:255]" .. L( "TXT_KEY_TP_UNHAPPINESS_TOTAL", g_activePlayer:GetUnhappiness() ) )
			tips:insertLocalizedBulletIfNonZero( "TXT_KEY_TP_UNHAPPINESS_CITY_COUNT", g_activePlayer:GetUnhappinessFromCityCount() / 100 )
			tips:insertLocalizedBulletIfNonZero( "TXT_KEY_TP_UNHAPPINESS_CAPTURED_CITY_COUNT", g_activePlayer:GetUnhappinessFromCapturedCityCount() / 100 )
			tips:insertLocalizedBulletIfNonZero( "TXT_KEY_TP_UNHAPPINESS_POPULATION", unhappinessFromPop / 100 )
			tips:insertLocalizedBulletIfNonZero( "TXT_KEY_TP_UNHAPPINESS_PUPPET_CITIES", unhappinessFromPupetCities / 100 )
			tips:insertLocalizedBulletIfNonZero( "TXT_KEY_TP_UNHAPPINESS_SPECIALISTS", unhappinessFromSpecialists / 100 )
			tips:insertLocalizedBulletIfNonZero( "TXT_KEY_TP_UNHAPPINESS_OCCUPIED_POPULATION", g_activePlayer:GetUnhappinessFromOccupiedCities() / 100 )
			tips:insertLocalizedBulletIfNonZero( "TXT_KEY_TP_UNHAPPINESS_UNITS", g_activePlayer:GetUnhappinessFromUnits() / 100 )
			tips:insertLocalizedBulletIfNonZero( "TXT_KEY_TP_HAPPINESS_POLICIES", math_min(policiesHappiness,0) )
			tips:insertLocalizedBulletIfNonZero( "TXT_KEY_TP_UNHAPPINESS_PUBLIC_OPINION", bnw_mode and g_activePlayer:GetUnhappinessFromPublicOpinion() or 0 )

			------------
			-- Happiness
			insert( tips, "[ENDCOLOR][COLOR:150:255:150:255]" )
			insert( tips, L("TXT_KEY_TP_HAPPINESS_SOURCES", totalHappiness ) )
			tips:insertLocalizedBulletIfNonZero( "TXT_KEY_TP_HAPPINESS_DIFFICULTY_LEVEL", handicapHappiness )
			tips:insertLocalizedBulletIfNonZero( "TXT_KEY_TP_HAPPINESS_POLICIES", math_max(policiesHappiness,0) )
			tips:insertLocalizedBulletIfNonZero( "TXT_KEY_TP_HAPPINESS_BUILDINGS", buildingHappiness )
			tips:insertLocalizedBulletIfNonZero( "TXT_KEY_TP_HAPPINESS_CITIES", cityHappiness )
			tips:insertLocalizedBulletIfNonZero( "TXT_KEY_TP_HAPPINESS_GARRISONED_UNITS", garrisonedUnitsHappiness )
			tips:insertLocalizedBulletIfNonZero( "TXT_KEY_TP_HAPPINESS_CONNECTED_CITIES", tradeRouteHappiness )
			tips:insertLocalizedBulletIfNonZero( "TXT_KEY_TP_HAPPINESS_STATE_RELIGION", religionHappiness )
			tips:insertLocalizedBulletIfNonZero( "TXT_KEY_TP_HAPPINESS_NATURAL_WONDERS", naturalWonderHappiness )
			tips:insertLocalizedBulletIfNonZero( "TXT_KEY_TP_HAPPINESS_CITY_COUNT", extraHappinessPerCity )
			tips:insertLocalizedBulletIfNonZero( "TXT_KEY_TP_HAPPINESS_CITY_STATE_FRIENDSHIP", minorCivHappiness )
			tips:insertLocalizedBulletIfNonZero( "TXT_KEY_TP_HAPPINESS_LEAGUES", leagueHappiness )
			tips:insertLocalizedBulletIfNonZero( "TXT_KEY_TP_HAPPINESS_VASSALS", happinessFromVassals )	-- Compatibility with Putmalk's Civ IV Diplomacy Features Mod

			-- Happiness from Luxury Variety
			tips:insertLocalizedBulletIfNonZero( "          ", "TXT_KEY_TP_HAPPINESS_RESOURCE_VARIETY", happinessFromExtraResources )

			-- Extra Happiness from each Luxury
			tips:insertLocalizedBulletIfNonZero( "          ", "TXT_KEY_TP_HAPPINESS_EXTRA_PER_RESOURCE", extraLuxuryHappiness, numHappinessResources )

			-- Misc Happiness from Resources
			local miscHappiness = resourcesHappiness - baseHappinessFromResources - happinessFromExtraResources - (extraLuxuryHappiness * numHappinessResources)
			tips:insertLocalizedBulletIfNonZero( "          ", "TXT_KEY_TP_HAPPINESS_OTHER_SOURCES", miscHappiness )

			if #availableResources > 0 then
				insert( tips, "[ICON_BULLET]" .. L( "TXT_KEY_TP_HAPPINESS_FROM_RESOURCES", resourcesHappiness ) )
				insert( tips, "  " .. availableResources )
			end

			insert( tips, "[ENDCOLOR]" )


			----------------------------
			-- Local Resources in Cities
			----------------------------
			local tip = ""
			for _, resource in pairs( g_luxuries ) do
				local resourceID = resource.ID
				local quantity = g_activePlayer:GetNumResourceTotal( resourceID, false ) + g_activePlayer:GetResourceExport( resourceID )
				if quantity > 0 then
					tip = tip .. " " .. ColorizeAbs( quantity ) .. resource.IconString
				end
			end
			insert( tips, L"TXT_KEY_EO_LOCAL_RESOURCES" .. (#tip > 0 and tip or (" : "..L"TXT_KEY_TP_NO_RESOURCES_DISCOVERED")) )

			-- Resources from city terrain
			for city in g_activePlayer:Cities() do
				local numConnectedResource = {}
				local numUnconnectedResource = {}
				for plot in CityPlots( city ) do
					local resourceID = plot:GetResourceType( g_activeTeamID )
					local numResource = plot:GetNumResource()
					if numResource > 0
						and Game.GetResourceUsageType( resourceID ) == ResourceUsageTypes.RESOURCEUSAGE_LUXURY
					then
						if plot:IsCity() or (not plot:IsImprovementPillaged() and plot:IsResourceConnectedByImprovement( plot:GetImprovementType() )) then
							numConnectedResource[resourceID] = (numConnectedResource[resourceID] or 0) + numResource
						else
							numUnconnectedResource[resourceID] = (numUnconnectedResource[resourceID] or 0) + numResource
						end
					end
				end
				local tip = ""
				for _, resource in pairs( g_luxuries ) do
					local resourceID = resource.ID
					if (numConnectedResource[resourceID] or 0) > 0 then
						tip = tip .. " " .. ColorizeAbs( numConnectedResource[resourceID] ) .. resource.IconString
					end
					if (numUnconnectedResource[resourceID] or 0) > 0 then
						tip = tip .. " " .. ColorizeAbs( -numUnconnectedResource[resourceID] ) .. resource.IconString
					end
				end
				if #tip > 0 then
					insert( tips, "[ICON_BULLET]" .. city:GetName() .. tip )
				end
			end

			----------------------------
			-- Import & Export Breakdown
			----------------------------
			local itemType, duration, finalTurn, data1, data2, data3, flag1, fromPlayerID
			local gameTurn = Game.GetGameTurn()-1
			local Exports = {}
			local Imports = {}
			for playerID = 0, GameDefines.MAX_MAJOR_CIVS-1 do
				Exports[ playerID ] = {}
				Imports[ playerID ] = {}
			end
			PushScratchDeal()
			for i = 0, UI.GetNumCurrentDeals( g_activePlayerID ) - 1 do
				UI.LoadCurrentDeal( g_activePlayerID, i )
				local otherPlayerID = g_ScratchDeal:GetOtherPlayer( g_activePlayerID )
				g_ScratchDeal:ResetIterator()
				repeat
					if bnw_mode then
						itemType, duration, finalTurn, data1, data2, data3, flag1, fromPlayerID = g_ScratchDeal:GetNextItem()
					else
						itemType, duration, finalTurn, data1, data2, fromPlayerID = g_ScratchDeal:GetNextItem()
					end
					-- data1 is resourceID, data2 is quantity

					if data2 and itemType == TradeableItems.TRADE_ITEM_RESOURCES and Game.GetResourceUsageType( data1 ) == ResourceUsageTypes.RESOURCEUSAGE_LUXURY then
						local trade
						if fromPlayerID == g_activePlayerID then
							trade = Exports[otherPlayerID]
						else
							trade = Imports[fromPlayerID]
						end
						local resourceTrade = trade[ data1 ]
						if not resourceTrade then
							resourceTrade = {}
							trade[ data1 ] = resourceTrade
						end
						resourceTrade[finalTurn] = (resourceTrade[finalTurn] or 0) + data2
					end
				until not itemType
			end
			PopScratchDeal()

			----------------------------
			-- Imports
			----------------------------
			local tip = ""
			for _, resource in pairs( g_luxuries ) do
				local resourceID = resource.ID
				local quantity = g_activePlayer:GetResourceImport( resourceID ) + g_activePlayer:GetResourceFromMinors( resourceID )
				if quantity > 0 then
					tip = tip .. " " .. ColorizeAbs( quantity ) .. resource.IconString
				end
			end
			if #tip > 0 then
				insert( tips, "" )
				insert( tips, L"TXT_KEY_RESOURCES_IMPORTED" .. tip )
				for playerID, array in pairs( Imports ) do
					local tip = ""
					for resourceID, row in pairs( array ) do
						for turn, quantity in pairs(row) do
							if quantity > 0 then
								tip = tip .. " " .. quantity .. GameInfo.Resources[ resourceID ].IconString .. "(" .. turn - gameTurn .. ")"
							end
						end
					end
					if #tip > 0 then
						insert( tips, "[ICON_BULLET]" .. Players[ playerID ]:GetCivilizationShortDescription() .. tip )
					end
				end
				for minorID = GameDefines.MAX_MAJOR_CIVS, GameDefines.MAX_CIV_PLAYERS-1 do
					local minor = Players[ minorID ]
					if minor and minor:IsAlive() and minor:GetAlly() == g_activePlayerID then
						local tip = ""
						for _, resource in pairs( g_luxuries ) do
							local quantity = minor:GetResourceExport(resource.ID)
							if quantity > 0 then
								tip = tip .. " " .. quantity .. resource.IconString
							end
						end
						if #tip > 0 then
							insert( tips, "[ICON_BULLET]" .. minor:GetCivilizationShortDescription() .. tip )
						end
					end
				end
			end

			----------------------------
			-- Exports
			----------------------------
			local tip = ""
			for _, resource in pairs( g_luxuries ) do
				local resourceID = resource.ID
				local quantity = g_activePlayer:GetResourceExport( resourceID )
				if quantity > 0 then
					tip = tip .. " " .. ColorizeAbs( quantity ) .. resource.IconString
				end
			end
			if #tip > 0 then
				insert( tips, "" )
				insert( tips, L"TXT_KEY_RESOURCES_EXPORTED" .. tip )
				for playerID, array in pairs( Exports ) do
					local tip = ""
					for resourceID, row in pairs( array ) do
						for turn, quantity in pairs(row) do
							if quantity > 0 then
								tip = tip .. " " .. quantity .. GameInfo.Resources[ resourceID ].IconString .. "(" .. turn - gameTurn .. ")"
							end
						end
					end
					if #tip > 0 then
						insert( tips, "[ICON_BULLET]" .. Players[ playerID ]:GetCivilizationShortDescription() .. tip )
					end
				end
			end
			-- show resources available for trade to the active player

--			insert( tips, L"TXT_KEY_DIPLO_ITEMS_LUXURY_RESOURCES" )
--			insert( tips, missingResources )
			insert( tips, "" )
			insert( tips, L"TXT_KEY_EO_RESOURCES_AVAILBLE" )

			----------------------------
			-- Available for Import
			----------------------------
			for _, resource in pairs( g_luxuries ) do
				local resourceID = resource.ID
				local resources = {}
				for playerID = 0, GameDefines.MAX_CIV_PLAYERS - 1 do

					local player = Players[playerID]
					local isMinorCiv = player:IsMinorCiv()

					-- Valid player? - Can't be us, has to be alive and met, can't be allied city state
					if playerID ~= g_activePlayerID
						and player:IsAlive()
						and g_activeTeam:IsHasMet( player:GetTeam() )
						and not (isMinorCiv and player:IsAllies( g_activePlayerID ))
					then


						local numResource = ( isMinorCiv and player:GetNumResourceTotal(resourceID, false) + player:GetResourceExport( resourceID ) )
							or ( g_ScratchDeal:IsPossibleToTradeItem(playerID, g_activePlayerID, TradeableItems.TRADE_ITEM_RESOURCES, resourceID, 1) and player:GetNumResourceAvailable(resourceID, false) )
							or 0
						if numResource > 0 then
							insert( resources, player:GetCivilizationShortDescription() .. " " .. numResource .. resource.IconString )
						end
					end
				end
				if #resources > 0 then
					insert( tips, "[ICON_BULLET]" .. resource._Name .. ": " .. concat( resources, ", " ) )
				end
			end

			return setTextToolTip( concat( tips, "[NEWLINE]" ) )
		else
			return setTextToolTip( L"TXT_KEY_TOP_PANEL_HAPPINESS_OFF_TOOLTIP" )
		end
	end
	Controls.HappinessString:RegisterCallback( Mouse.eLClick, function() GamePopup( ButtonPopupTypes.BUTTONPOPUP_ECONOMIC_OVERVIEW, 2 ) end )
	Controls.HappinessString:RegisterCallback( Mouse.eRClick, function() GamePedia( "TXT_KEY_GOLD_HEADING1_TITLE" ) end )

	-------------------------------------------------
	-- Golden Age Tooltip
	-------------------------------------------------
	g_toolTipHandler.GoldenAgeString = function()

		if g_isHappinessEnabled then

			local tips = table()
			local goldenAgeTurns = g_activePlayer:GetGoldenAgeTurns()
			local happyProgress = g_activePlayer:GetGoldenAgeProgressMeter()
			local happyNeeded = g_activePlayer:GetGoldenAgeProgressThreshold()

			if goldenAgeTurns > 0 then
				if bnw_mode and g_activePlayer:GetGoldenAgeTourismModifier() > 0 then
					insert( tips, Locale.ToUpper"TXT_KEY_UNIQUE_GOLDEN_AGE_ANNOUNCE" )
				else
					insert( tips, Locale.ToUpper"TXT_KEY_GOLDEN_AGE_ANNOUNCE" )
				end
				insert( tips, L( "TXT_KEY_TP_GOLDEN_AGE_NOW", goldenAgeTurns ) )
			else
				local excessHappiness = g_activePlayer:GetExcessHappiness()
				insert( tips, L( "TXT_KEY_PROGRESS_TOWARDS", "[COLOR_YELLOW]"
					.. Locale.ToUpper( "TXT_KEY_SPECIALISTSANDGP_GOLDENAGE_HEADING4_TITLE" )
					.. "[ENDCOLOR]" ) .. " " .. happyProgress .. " / " .. happyNeeded )
				if excessHappiness > 0 then
					insert( tips, L"TXT_KEY_MISSION_START_GOLDENAGE" .. ": [COLOR_YELLOW]"
						.. Locale.ToUpper( L( "TXT_KEY_STR_TURNS", math_ceil((happyNeeded - happyProgress) / excessHappiness) ) )
						.. "[ENDCOLOR]"	.. "[NEWLINE][NEWLINE]" .. L("TXT_KEY_TP_GOLDEN_AGE_ADDITION", excessHappiness) )
				elseif excessHappiness < 0 then
					insert( tips, "[COLOR_WARNING_TEXT]" .. L("TXT_KEY_TP_GOLDEN_AGE_LOSS", -excessHappiness) .. "[ENDCOLOR]" )
				end
			end

			if g_isBasicHelp then
				insert( tips, "" )
				if gk_mode and g_activePlayer:IsGoldenAgeCultureBonusDisabled() then
					insert( tips, L"TXT_KEY_TP_GOLDEN_AGE_EFFECT_NO_CULTURE" )
				else
					insert( tips, L"TXT_KEY_TP_GOLDEN_AGE_EFFECT" )
				end
				if bnw_mode and g_activePlayer:GetGoldenAgeTurns() > 0 and g_activePlayer:GetGoldenAgeTourismModifier() > 0 then
					insert( tips, "" )
					insert( tips, L"TXT_KEY_TP_CARNIVAL_EFFECT" )
				end
			end

			return setTextToolTip( concat( tips, "[NEWLINE]" ) )
		else
			return setTextToolTip( L"TXT_KEY_TOP_PANEL_HAPPINESS_OFF_TOOLTIP" )
		end
	end

	-------------------------------------------------
	-- Tourism Tooltip & Click Actions
	-------------------------------------------------
	if bnw_mode then
		g_toolTipHandler.TourismString = function()

			local totalGreatWorks = g_activePlayer:GetNumGreatWorks()
			local totalSlots = g_activePlayer:GetNumGreatWorkSlots()

			local tipText = L( "TXT_KEY_TOP_PANEL_TOURISM_TOOLTIP_1", totalGreatWorks )
					.. "[NEWLINE]"
					.. L( "TXT_KEY_TOP_PANEL_TOURISM_TOOLTIP_2", totalSlots - totalGreatWorks )

			local cultureVictory = GameInfo.Victories.VICTORY_CULTURAL
			if cultureVictory and PreGame.IsVictory(cultureVictory.ID) then
				local numInfluential = g_activePlayer:GetNumCivsInfluentialOn()
				local numToBeInfluential = g_activePlayer:GetNumCivsToBeInfluentialOn()
				tipText = tipText .. "[NEWLINE][NEWLINE]"
					.. L( "TXT_KEY_TOP_PANEL_TOURISM_TOOLTIP_3", L("TXT_KEY_CO_VICTORY_INFLUENTIAL_OF", numInfluential, numToBeInfluential) )
			end
			return setTextToolTip( tipText )
		end
		Controls.TourismString:SetHide(false)
		Controls.TourismString:RegisterCallback( Mouse.eLClick, function() GamePopup( ButtonPopupTypes.BUTTONPOPUP_CULTURE_OVERVIEW, 4 ) end )
		Controls.TourismString:RegisterCallback( Mouse.eRClick, function() GamePedia( "TXT_KEY_CULTURE_TOURISM_HEADING2_TITLE" ) end )	-- TXT_KEY_CULTURE_TOURISM_AND_CULTURE_HEADING2_TITLE

		-------------------------------------------------
		-- International Trade Routes Tooltip & Click Actions
		-------------------------------------------------
		g_toolTipHandler.InternationalTradeRoutes = function()

			local tipText = ""

			local numAvailableTradeUnits = g_activePlayer:GetNumAvailableTradeUnits(DomainTypes.DOMAIN_LAND)
			if numAvailableTradeUnits > 0 then
				local tradeUnitType = g_activePlayer:GetTradeUnitType(DomainTypes.DOMAIN_LAND)
				tipText = tipText .. L("TXT_KEY_TOP_PANEL_INTERNATIONAL_TRADE_ROUTES_TT_UNASSIGNED", numAvailableTradeUnits, GameInfo.Units[ tradeUnitType ]._Name) .. "[NEWLINE]"
			end

			local numAvailableTradeUnits = g_activePlayer:GetNumAvailableTradeUnits(DomainTypes.DOMAIN_SEA)
			if numAvailableTradeUnits > 0 then
				local tradeUnitType = g_activePlayer:GetTradeUnitType(DomainTypes.DOMAIN_SEA)
				tipText = tipText .. L("TXT_KEY_TOP_PANEL_INTERNATIONAL_TRADE_ROUTES_TT_UNASSIGNED", numAvailableTradeUnits, GameInfo.Units[ tradeUnitType ]._Name) .. "[NEWLINE]"
			end

			local usedTradeRoutes = g_activePlayer:GetNumInternationalTradeRoutesUsed()
			local availableTradeRoutes = g_activePlayer:GetNumInternationalTradeRoutesAvailable()

			if #tipText > 0 then
				tipText = tipText .. "[NEWLINE]"
			end
			tipText = L("TXT_KEY_TOP_PANEL_INTERNATIONAL_TRADE_ROUTES_TT", usedTradeRoutes, availableTradeRoutes)

			local strYourTradeRoutes = g_activePlayer:GetTradeYourRoutesTTString()
			if #strYourTradeRoutes > 0 then
				tipText = tipText .. "[NEWLINE][NEWLINE]"
						.. L"TXT_KEY_TOP_PANEL_ITR_ESTABLISHED_BY_PLAYER_TT"
						.. "[NEWLINE]"
						.. strYourTradeRoutes
			end

			local strToYouTradeRoutes = g_activePlayer:GetTradeToYouRoutesTTString()
			if #strToYouTradeRoutes > 0 then
				tipText = tipText .. "[NEWLINE][NEWLINE]"
						.. L"TXT_KEY_TOP_PANEL_ITR_ESTABLISHED_BY_OTHER_TT"
						.. "[NEWLINE]"
						.. strToYouTradeRoutes
			end

			return setTextToolTip( tipText )
		end
		Controls.InternationalTradeRoutes:SetHide(false)
		Controls.InternationalTradeRoutes:RegisterCallback( Mouse.eLClick, function() GamePopup( ButtonPopupTypes.BUTTONPOPUP_TRADE_ROUTE_OVERVIEW ) end )
		Controls.InternationalTradeRoutes:RegisterCallback( Mouse.eRClick, function() GamePedia( "TXT_KEY_TRADE_ROUTES_HEADING2_TITLE" ) end )	-- TXT_KEY_TRADE_ROUTES_HEADING2_TITLE
	end
else
	-- ===========================================================================
	-- Health Tooltip
	-- ===========================================================================
	g_toolTipHandler.HealthString = function()
		if g_isHealthEnabled then

			local excessHealth = g_activePlayer:GetExcessHealth()
			local healthLevel = g_activePlayer:GetCurrentHealthLevel()
			local healthLevelInfo = GameInfo.HealthLevels[healthLevel]
			local colorPrefixText = "[COLOR_GREEN]"
			local iconStringText = "[ICON_HEALTH]"
			local rangeFactor = 1
			if excessHealth < 0 then
				colorPrefixText = "[COLOR_RED]"
				iconStringText = "[ICON_UNHEALTH]"
				rangeFactor = -1
			end
			local tips = table( L("TXT_KEY_TP_HEALTH_SUMMARY", iconStringText, colorPrefixText, excessHealth * rangeFactor) )
			if healthLevelInfo.Help then
				insert( tips, L( healthLevelInfo.Help ) )
			end
			insert( tips, g_activePlayer:IsEmpireUnhealthy() and "[COLOR_WARNING_TEXT]" or "[COLOR_POSITIVE_TEXT]" )
			local cityYieldMods = {}
			local combatMod = 0
			local cityGrowthMod = 0
			local outpostGrowthMod = 0
			local cityIntrigueMod = 0
			for info in GameInfo.HealthLevels() do
				local healthLevelID = info.ID
				if g_activePlayer:IsAffectedByHealthLevel(healthLevelID) then
					for yieldID = 0, YieldTypes.NUM_YIELD_TYPES-1 do
						cityYieldMods[yieldID] = (cityYieldMods[yieldID] or 0) + Game.GetHealthLevelCityYieldModifier(healthLevelID, excessHealth, yieldID)
					end
					combatMod = combatMod + (info.CombatModifier or 0)
					cityGrowthMod = cityGrowthMod + Game.GetHealthLevelCityGrowthModifier(healthLevelID, excessHealth)
					outpostGrowthMod = outpostGrowthMod + Game.GetHealthLevelCityGrowthModifier(healthLevelID, excessHealth)
					cityIntrigueMod = cityIntrigueMod + Game.GetHealthLevelCityIntrigueModifier(healthLevelID, excessHealth)
				end
			end
			tips:insertLocalizedBulletIfNonZero( "TXT_KEY_TP_HEALTH_LEVEL_EFFECT_COMBAT_MODIFIER", combatMod )
			tips:insertLocalizedBulletIfNonZero( "TXT_KEY_TP_HEALTH_LEVEL_EFFECT_CITY_GROWTH_MODIFIER", cityGrowthMod )
			tips:insertLocalizedBulletIfNonZero( "TXT_KEY_TP_HEALTH_LEVEL_EFFECT_OUTPOST_GROWTH_MODIFIER", outpostGrowthMod )
			tips:insertLocalizedBulletIfNonZero( "TXT_KEY_TP_HEALTH_LEVEL_EFFECT_CITY_INTRIGUE_MODIFIER", cityIntrigueMod )
			for yieldID = 0, YieldTypes.NUM_YIELD_TYPES-1 do
				local yieldInfo = GameInfo.Yields[ yieldID ]
				tips:insertLocalizedBulletIfNonZero( "TXT_KEY_TP_HEALTH_LEVEL_EFFECT_CITY_YIELD_MODIFIER", yieldInfo and cityYieldMods[yieldID] or 0, yieldInfo.IconString, yieldInfo._Name )
			end
--			insert( tips, "[ENDCOLOR]" )

			--*** HEALTH Breakdown ***--
			local totalHealth		= g_activePlayer:GetHealth()
			local handicapInfo		= GameInfo.HandicapInfos[g_activePlayer:GetHandicapType()]
			local handicapHealth		= handicapInfo.BaseHealthRate
			local healthFromCities		= g_activePlayer:GetHealthFromCities()
			local extraCityHealth		= g_activePlayer:GetExtraHealthPerCity() * g_activePlayer:GetNumCities()
			local healthFromPolicies	= g_activePlayer:GetHealthFromPolicies()
			local healthFromTradeRoutes	= g_activePlayer:GetHealthFromTradeRoutes()
			--local healthFromNationalSecurityProject	= g_activePlayer:GetHealthFromNationalSecurityProject(); WRM: Add this in when we have a text string for it

			insert( tips, "[COLOR_WHITE]" )
			insert( tips, L( "TXT_KEY_TP_HEALTH_SOURCES", totalHealth ) )
			tips:insertLocalizedBulletIfNonZero( "TXT_KEY_TP_HEALTH_CITIES", healthFromCities )
			tips:insertLocalizedBulletIfNonZero( "TXT_KEY_TP_HEALTH_POLICIES", healthFromPolicies )
			tips:insertLocalizedBulletIfNonZero( "TXT_KEY_TP_HEALTH_CONNECTED_CITIES", healthFromTradeRoutes )
			tips:insertLocalizedBulletIfNonZero( "TXT_KEY_TP_HEALTH_CITY_COUNT", extraCityHealth )
			tips:insertLocalizedBulletIfNonZero( "TXT_KEY_TP_HEALTH_DIFFICULTY_LEVEL", handicapHealth )
			tips:insertLocalizedBulletIfNonZero( "TXT_KEY_TP_HEALTH_OTHER_SOURCES", totalHealth - handicapHealth - healthFromPolicies - healthFromCities - healthFromTradeRoutes - extraCityHealth )
			insert( tips, "[ENDCOLOR]" )

			--*** UNHEALTH Breakdown ***--
			local totalUnhealth			= g_activePlayer:GetUnhealth()
			local unhealthFromCities		= g_activePlayer:GetUnhealthFromCities()
			local unhealthFromUnits			= g_activePlayer:GetUnhealthFromUnits()
			local unhealthFromCityCount		= g_activePlayer:GetUnhealthFromCityCount()
			local unhealthFromConqueredCityCount	= g_activePlayer:GetUnhealthFromConqueredCityCount()
			local unhealthFromPupetCities		= g_activePlayer:GetUnhealthFromPuppetCityPopulation()
			local unhealthFromSpecialists		= g_activePlayer:GetUnhealthFromCitySpecialists()
			local unhealthFromPop			= g_activePlayer:GetUnhealthFromCityPopulation() - unhealthFromSpecialists - unhealthFromPupetCities
			local unhealthFromConqueredCities	= g_activePlayer:GetUnhealthFromConqueredCities()

			insert( tips, "[COLOR:255:150:150:255]" )
			insert( tips, L( "TXT_KEY_TP_UNHEALTH_TOTAL", totalUnhealth ) )
			tips:insertLocalizedBulletIfNonZero( "TXT_KEY_TP_UNHEALTH_CITIES", unhealthFromCities / 100 )
			tips:insertLocalizedBulletIfNonZero( "TXT_KEY_TP_UNHEALTH_CITY_COUNT", unhealthFromCityCount / 100 )
			tips:insertLocalizedBulletIfNonZero( "TXT_KEY_TP_UNHEALTH_CAPTURED_CITY_COUNT", unhealthFromConqueredCityCount / 100 )
			tips:insertLocalizedBulletIfNonZero( "TXT_KEY_TP_UNHEALTH_POPULATION", unhealthFromPop / 100 )
			tips:insertLocalizedBulletIfNonZero( "TXT_KEY_TP_UNHEALTH_PUPPET_CITIES", unhealthFromPupetCities / 100 )
			tips:insertLocalizedBulletIfNonZero( "TXT_KEY_TP_UNHEALTH_SPECIALISTS", unhealthFromSpecialists / 100 )
			tips:insertLocalizedBulletIfNonZero( "TXT_KEY_TP_UNHEALTH_OCCUPIED_POPULATION", unhealthFromConqueredCities / 100 )
			tips:insertLocalizedBulletIfNonZero( "TXT_KEY_TP_UNHEALTH_UNITS", unhealthFromUnits / 100 )
			tips:insertLocalizedBulletIfNonZero( "TXT_KEY_TP_YIELD_FROM_UNCATEGORIZED", totalUnhealth - ( unhealthFromCities + unhealthFromCityCount + unhealthFromConqueredCityCount + unhealthFromPop + unhealthFromPupetCities + unhealthFromSpecialists + unhealthFromConqueredCities + unhealthFromUnits ) / 100 )
			insert( tips, "[ENDCOLOR]" )

			-- Overall Unhealth Mod
			local unhealthMod = g_activePlayer:GetUnhealthMod()
			if unhealthMod > 0 then -- Positive mod means more Unhealth - this is a bad thing!
				tips:append( "[COLOR:255:150:150:255]" )
			end
			tips:insertLocalizedBulletIfNonZero( "TXT_KEY_TP_UNHEALTH_MOD", unhealthMod )

			-- Basic explanation of Health
			insert( tips, "[ENDCOLOR]" )
			insert( tips, L( "TXT_KEY_TP_HEALTH_EXPLANATION", totalUnhealth ) )

			return setTextToolTip( concat( tips, "[NEWLINE]" ) )
		else
			return setTextToolTip( L"TXT_KEY_TOP_PANEL_HEALTH_OFF_TOOLTIP" )
		end
	end
	Controls.HealthString:RegisterCallback( Mouse.eLClick, function() GamePopup( ButtonPopupTypes.BUTTONPOPUP_ECONOMIC_OVERVIEW, 2 ) end )
	Controls.HealthString:RegisterCallback( Mouse.eRClick, function() GamePedia( "TXT_KEY_GOLD_HEADING1_TITLE" ) end )

	-- ===========================================================================
	-- Affinity Tooltips
	-- ===========================================================================

	g_toolTipHandler.Harmony = function() return setTextToolTip( GetHelpTextForAffinity( GameInfoTypes.AFFINITY_TYPE_HARMONY, g_activePlayer ) ) end
	g_toolTipHandler.Purity = function() return setTextToolTip( GetHelpTextForAffinity( GameInfoTypes.AFFINITY_TYPE_PURITY, g_activePlayer ) ) end
	g_toolTipHandler.Supremacy = function() return setTextToolTip( GetHelpTextForAffinity( GameInfoTypes.AFFINITY_TYPE_SUPREMACY, g_activePlayer ) ) end

	Controls.Harmony:RegisterCallback( Mouse.eLClick, function() GamePopup( ButtonPopupTypes.BUTTONPOPUP_ECONOMIC_OVERVIEW, 2 ) end )
	Controls.Harmony:RegisterCallback( Mouse.eRClick, function() GamePedia( GameInfo.Affinity_Types.AFFINITY_TYPE_HARMONY.Description ) end )
	Controls.Purity:RegisterCallback( Mouse.eLClick, function() GamePopup( ButtonPopupTypes.BUTTONPOPUP_ECONOMIC_OVERVIEW, 2 ) end )
	Controls.Purity:RegisterCallback( Mouse.eRClick, function() GamePedia( GameInfo.Affinity_Types.AFFINITY_TYPE_PURITY.Description ) end )
	Controls.Supremacy:RegisterCallback( Mouse.eLClick, function() GamePopup( ButtonPopupTypes.BUTTONPOPUP_ECONOMIC_OVERVIEW, 2 ) end )
	Controls.Supremacy:RegisterCallback( Mouse.eRClick, function() GamePedia( GameInfo.Affinity_Types.AFFINITY_TYPE_SUPREMACY.Description ) end )
end
-------------------------------------------------
-- Culture Tooltip & Click Actions
-------------------------------------------------
g_toolTipHandler.CultureString = function()

	local tips = table()

	if not g_isPoliciesEnabled then
		insert( tips, L"TXT_KEY_TOP_PANEL_POLICIES_OFF_TOOLTIP" )
	else
		local turnsRemaining = 1
		local cultureProgress, culturePerTurn, culturePerTurnForFree, culturePerTurnFromCities, culturePerTurnFromExcessHappiness, culturePerTurnFromTraits
		-- Firaxis Cleverness...
		if civ5_mode then
			cultureProgress = g_activePlayer:GetJONSCulture()
			culturePerTurn = g_activePlayer:GetTotalJONSCulturePerTurn()
			culturePerTurnForFree = g_activePlayer:GetJONSCulturePerTurnForFree()
			culturePerTurnFromCities = g_activePlayer:GetJONSCulturePerTurnFromCities()
			culturePerTurnFromExcessHappiness = g_activePlayer:GetJONSCulturePerTurnFromExcessHappiness()
			culturePerTurnFromTraits = bnw_mode and g_activePlayer:GetJONSCulturePerTurnFromTraits() or 0
		else
			cultureProgress = g_activePlayer:GetCulture()
			culturePerTurn = g_activePlayer:GetTotalCulturePerTurn()
			culturePerTurnForFree = g_activePlayer:GetCulturePerTurnForFree()
			culturePerTurnFromCities = g_activePlayer:GetCulturePerTurnFromCities()
			culturePerTurnFromExcessHappiness = g_activePlayer:GetCulturePerTurnFromExcessHealth()
			culturePerTurnFromTraits = g_activePlayer:GetCulturePerTurnFromTraits()
		end
		local cultureTheshold = g_activePlayer:GetNextPolicyCost()
		if cultureTheshold > cultureProgress then
			if culturePerTurn > 0 then
				turnsRemaining = math_ceil( (cultureTheshold - cultureProgress) / culturePerTurn)
			else
				turnsRemaining = "?"
			end
		end

		if bnw_mode and g_activePlayer:IsAnarchy() then
			insert( tips, L("TXT_KEY_TP_ANARCHY", g_activePlayer:GetAnarchyNumTurns()) )
			insert( tips, "" )
		end

		insert( tips, L( "TXT_KEY_PROGRESS_TOWARDS", "[COLOR_MAGENTA]" .. Locale.ToUpper"TXT_KEY_ADVISOR_SCREEN_SOCIAL_POLICY_DISPLAY" .. "[ENDCOLOR]" )
				.. " " .. cultureProgress .. "[ICON_CULTURE]/ " .. cultureTheshold .. "[ICON_CULTURE]" )

		if culturePerTurn > 0 then
			local cultureOverflow = culturePerTurn * turnsRemaining + cultureProgress - cultureTheshold
			local tip = "[COLOR_MAGENTA]" .. Locale.ToUpper( L( "TXT_KEY_STR_TURNS", turnsRemaining ) )
					.. "[ENDCOLOR]"	.. format( " %+g[ICON_CULTURE]", cultureOverflow )
			if turnsRemaining > 1 then
				tip = L( "TXT_KEY_STR_TURNS", turnsRemaining -1 )
					.. format( " %+g[ICON_CULTURE]  ", cultureOverflow - culturePerTurn )
					.. tip
			end
			insert( tips, tip )
		end

		insert( tips, "" )
		insert( tips, "[COLOR_MAGENTA]" .. format( "%+g", culturePerTurn )
				.. "[ENDCOLOR] " .. L"TXT_KEY_REPLAY_DATA_CULTUREPERTURN" )

		-- Culture for Free
		tips:insertLocalizedIfNonZero( "TXT_KEY_TP_CULTURE_FOR_FREE", culturePerTurnForFree )

		-- Culture from Cities
		tips:insertLocalizedIfNonZero( "TXT_KEY_TP_CULTURE_FROM_CITIES", culturePerTurnFromCities )

		-- Culture from Excess Happiness / Health
		tips:insertLocalizedIfNonZero( "TXT_KEY_TP_CULTURE_FROM_" .. g_happinessString, culturePerTurnFromExcessHappiness )

		-- Culture from Traits
		tips:insertLocalizedIfNonZero( "TXT_KEY_TP_CULTURE_FROM_TRAITS", culturePerTurnFromTraits )

		if civ5_mode then
			-- Culture from Minor Civs
			local culturePerTurnFromMinorCivs = g_activePlayer:GetJONSCulturePerTurnFromMinorCivs()
			tips:insertLocalizedIfNonZero( "TXT_KEY_TP_CULTURE_FROM_MINORS", culturePerTurnFromMinorCivs )

			-- Culture from Religion
			local culturePerTurnFromReligion = gk_mode and g_activePlayer:GetCulturePerTurnFromReligion() or 0
			tips:insertLocalizedIfNonZero( "TXT_KEY_TP_CULTURE_FROM_RELIGION", culturePerTurnFromReligion )

			-- Culture from bonus turns (League Project)
			local culturePerTurnFromBonusTurns = 0
			if bnw_mode then
				culturePerTurnFromBonusTurns = g_activePlayer:GetCulturePerTurnFromBonusTurns()
				tips:insertLocalizedIfNonZero( "TXT_KEY_TP_CULTURE_FROM_BONUS_TURNS", culturePerTurnFromBonusTurns, g_activePlayer:GetCultureBonusTurns() )
			end

			-- Culture from Vassals / Compatibility with Putmalk's Civ IV Diplomacy Features Mod
			local culturePerTurnFromVassals = g_activePlayer.GetJONSCulturePerTurnFromVassals and g_activePlayer:GetJONSCulturePerTurnFromVassals() or 0
			tips:insertLocalizedIfNonZero( "TXT_KEY_TP_CULTURE_VASSALS", culturePerTurnFromVassals )

			-- Culture from Golden Age
			tips:insertLocalizedIfNonZero( "TXT_KEY_TP_CULTURE_FROM_GOLDEN_AGE", culturePerTurn - culturePerTurnForFree - culturePerTurnFromCities - culturePerTurnFromExcessHappiness - culturePerTurnFromMinorCivs - culturePerTurnFromReligion - culturePerTurnFromTraits - culturePerTurnFromBonusTurns - culturePerTurnFromVassals )	-- Compatibility with Putmalk's Civ IV Diplomacy Features Mod
		else
			-- Uncategorized Culture
			tips:insertLocalizedIfNonZero( "TXT_KEY_TP_YIELD_FROM_UNCATEGORIZED", culturePerTurn - culturePerTurnForFree - culturePerTurnFromCities - culturePerTurnFromExcessHappiness - culturePerTurnFromTraits )
		end

		-- Let people know that building more cities makes policies harder to get

		if g_isBasicHelp then
			insert( tips, "" )
			insert( tips, L("TXT_KEY_TP_CULTURE_CITY_COST", Game.GetNumCitiesPolicyCostMod() * ( 100 + ( civBE_mode and g_activePlayer:GetNumCitiesPolicyCostDiscount() or 0 ) ) / 100 ) )
		end
	end

	return setTextToolTip( concat( tips, "[NEWLINE]" ) )
end
Controls.CultureString:RegisterCallback( Mouse.eLClick, function() GamePopup( ButtonPopupTypes.BUTTONPOPUP_CHOOSEPOLICY ) end )
Controls.CultureString:RegisterCallback( Mouse.eRClick, function() GamePedia( "TXT_KEY_CULTURE_HEADING1_TITLE" ) end )	-- TXT_KEY_PEDIA_CATEGORY_8_LABEL

-------------------------------------------------
-- Faith Tooltip & Click Actions
-------------------------------------------------
if civ5_mode and gk_mode then
	g_toolTipHandler.FaithString = function()

		if g_isReligionEnabled then
			local tips = table()
			local faithPerTurn = g_activePlayer:GetTotalFaithPerTurn()

			if bnw_mode and g_activePlayer:IsAnarchy() then
				insert( tips, L( "TXT_KEY_TP_ANARCHY", g_activePlayer:GetAnarchyNumTurns() ) )
				insert( tips, "" )
			end

			insert( tips, L("TXT_KEY_TP_FAITH_ACCUMULATED", g_activePlayer:GetFaith()) )
			insert( tips, "" )
			insert( tips, "[COLOR_WHITE]" .. format("%+g", faithPerTurn ) .. "[ENDCOLOR] "
				.. L"TXT_KEY_YIELD_FAITH" .. "[ICON_PEACE] " .. L"TXT_KEY_GOLD_PERTURN_HEADING4_TITLE" )

			-- Faith from Cities
			tips:insertLocalizedIfNonZero( "TXT_KEY_TP_FAITH_FROM_CITIES", g_activePlayer:GetFaithPerTurnFromCities() )

			-- Faith from Outposts
			tips:insertLocalizedIfNonZero( "TXT_KEY_TP_FAITH_FROM_OUTPOSTS", civBE_mode and g_activePlayer:GetFaithPerTurnFromOutposts() or 0 )

			-- Faith from Minor Civs
			tips:insertLocalizedIfNonZero( "TXT_KEY_TP_FAITH_FROM_MINORS", g_activePlayer:GetFaithPerTurnFromMinorCivs() )

			-- Faith from Religion
			tips:insertLocalizedIfNonZero( "TXT_KEY_TP_FAITH_FROM_RELIGION", g_activePlayer:GetFaithPerTurnFromReligion() )

			-- New World Deluxe Scenario ( you still need to delete TopPanel.lua from ...\Steam\SteamApps\common\sid meier's civilization v\assets\DLC\DLC_07\Scenarios\Conquest of the New World Deluxe\UI )
			if EUI.deluxe_scenario then
				insert( tips, L"TXT_KEY_NEWWORLD_SCENARIO_TP_RELIGION_TOOLTIP" )
			else
				if g_activePlayer:HasCreatedPantheon() then
					if (Game.GetNumReligionsStillToFound() > 0 or g_activePlayer:HasCreatedReligion())
						and (g_activePlayer:GetCurrentEra() < GameInfoTypes.ERA_INDUSTRIAL)
					then
						tips:insertLocalizedIfNonZero( "TXT_KEY_TP_FAITH_NEXT_PROPHET", g_activePlayer:GetMinimumFaithNextGreatProphet() )
					end
				else
					if g_activePlayer:CanCreatePantheon(false) then
						tips:insertLocalizedIfNonZero( "TXT_KEY_TP_FAITH_NEXT_PANTHEON", Game.GetMinimumFaithNextPantheon() )
					else
						insert( tips, L"TXT_KEY_TP_FAITH_PANTHEONS_LOCKED" )
					end
				end

				insert( tips, "" )
				insert( tips, L( "TXT_KEY_TP_FAITH_RELIGIONS_LEFT", math_max( Game.GetNumReligionsStillToFound(), 0 ) ) )

				if g_activePlayer:GetCurrentEra() >= GameInfoTypes.ERA_INDUSTRIAL then
					insert( tips, "" )
					insert( tips, L( "TXT_KEY_TP_FAITH_NEXT_GREAT_PERSON", g_activePlayer:GetMinimumFaithNextGreatProphet() ) )
					local numTips = #tips
					local capitalCity = g_activePlayer:GetCapitalCity()
					if capitalCity then
						for unit in GameInfo.Units{Special = "SPECIALUNIT_PEOPLE"} do
							local unitID = unit.ID
							if capitalCity:GetUnitFaithPurchaseCost(unitID, true) > 0
								and g_activePlayer:IsCanPurchaseAnyCity(false, true, unitID, -1, YieldTypes.YIELD_FAITH)
								and g_activePlayer:DoesUnitPassFaithPurchaseCheck(unitID)
							then
								insert( tips, "[ICON_BULLET]" .. unit._Name )
							end
						end
					end

					if numTips == #tips then
						insert( tips, "[ICON_BULLET]" .. L"TXT_KEY_RO_YR_NO_GREAT_PEOPLE" )
					end
				end
			end
			return setTextToolTip( concat( tips, "[NEWLINE]" ) )
		else
			return setTextToolTip( L"TXT_KEY_TOP_PANEL_RELIGION_OFF_TOOLTIP" )	--TXT_KEY_TOP_PANEL_RELIGION_OFF
		end
	end
	g_toolTipHandler.FaithIcon = g_toolTipHandler.FaithString

	local function OnFaithLClick()
		return GamePopup( ButtonPopupTypes.BUTTONPOPUP_RELIGION_OVERVIEW )
	end
	local function OnFaithRClick()
		return GamePedia( "TXT_KEY_CONCEPT_RELIGION_FAITH_EARNING_DESCRIPTION" )	-- TXT_KEY_PEDIA_CATEGORY_15_LABEL
	end
	Controls.FaithString:RegisterCallback( Mouse.eLClick, OnFaithLClick )
	Controls.FaithString:RegisterCallback( Mouse.eRClick, OnFaithRClick )
	Controls.FaithString:SetHide( false )
	Controls.FaithTurns:SetHide( false )
	Controls.FaithIcon:RegisterCallback( Mouse.eLClick, OnFaithLClick )
	Controls.FaithIcon:RegisterCallback( Mouse.eRClick, OnFaithRClick )
	Controls.FaithIcon:SetHide( false )
end

-------------------------------------------------
-- Strategic Resources Tooltips & Click Actions
-------------------------------------------------
local function ResourcesToolTip( control )

	local tips = table()

	-- show resources available to the active player

	local resource = GameInfo.Resources[ control:GetVoid1() ]
	local resourceID = resource and resource.ID
	if resourceID and Game.GetResourceUsageType(resourceID) == ResourceUsageTypes.RESOURCEUSAGE_STRATEGIC then

		local numResourceUsed = g_activePlayer:GetNumResourceUsed( resourceID )

		if numResourceUsed > 0 or
			( g_activeTeamTechs:HasTech( GameInfoTypes[ resource.TechReveal ] ) and
			g_activeTeamTechs:HasTech( GameInfoTypes[ resource.TechCityTrade ] ) )
		then
--			local numResourceTotal = g_activePlayer:GetNumResourceTotal( resourceID, true )	-- true means includes both imports & minors - but exports are deducted regardless
			local numResourceAvailable = g_activePlayer:GetNumResourceAvailable( resourceID, true )	-- same as (total - used)
			local numResourceExport = g_activePlayer:GetResourceExport( resourceID )
			local numResourceImport = g_activePlayer:GetResourceImport( resourceID ) + g_activePlayer:GetResourceFromMinors( resourceID )
			local numResourceLocal = g_activePlayer:GetNumResourceTotal( resourceID, false ) + numResourceExport

			insert( tips, ColorizeAbs(numResourceAvailable) .. resource.IconString .. " " .. Locale.ToUpper(resource._Name) )
			insert( tips, "----------------" )

			----------------------------
			-- Local Resources in Cities
			----------------------------
			insert( tips, "" )
			insert( tips, Colorize(numResourceLocal) .. " " .. L"TXT_KEY_EO_LOCAL_RESOURCES" )

			-- Resources from city terrain
			for city in g_activePlayer:Cities() do
				local numConnectedResource = 0
				local numUnconnectedResource = 0
				for plot in CityPlots( city ) do
					local numResource = plot:GetNumResource()
					if numResource > 0  and resourceID == plot:GetResourceType( g_activeTeamID ) then
						if plot:IsCity() or (not plot:IsImprovementPillaged() and plot:IsResourceConnectedByImprovement( plot:GetImprovementType() )) then
							numConnectedResource = numConnectedResource + numResource
						else
							numUnconnectedResource = numUnconnectedResource + numResource
						end
					end
				end
				local tip = ""
				if numConnectedResource > 0 then
					tip = " " .. ColorizeAbs( numConnectedResource ) .. resource.IconString
				end
				if numUnconnectedResource > 0 then
					tip = tip .. " " .. ColorizeAbs( -numUnconnectedResource ) .. resource.IconString
				end
				if #tip > 0 then
					insert( tips, "[ICON_BULLET]" .. city:GetName() .. tip )
				end
			end
			if gk_mode then
				-- Resources from buildings
				local tipIndex = #tips
				for row in GameInfo.Building_ResourceQuantity{ ResourceType = resource.Type } do
					local building = GameInfo.Buildings[ row.BuildingType ]
					local numResource = row.Quantity
					if building and numResource and numResource > 0 then
						local buildingID = building.ID
						-- count how many such buildings player has
						local numExisting = g_activePlayer:CountNumBuildings( buildingID )
						-- count how many such units player is building
						local numBuilds = 0
						for city in g_activePlayer:Cities() do
							if city:GetProductionBuilding() == buildingID then
								numBuilds = numBuilds + 1
							end
						end
						-- can player build this building someday ?
						local canBuildSomeday
						-- check whether this Unit has been blocked out by the civ XML
						local buildingOverride = GameInfo.Civilization_BuildingClassOverrides{ CivilizationType = g_activeCivilization.Type, BuildingClassType = building.BuildingClass }()
						if buildingOverride then
							canBuildSomeday = buildingOverride.BuildingType == building.Type
						else
							canBuildSomeday = GameInfo.BuildingClasses[ building.BuildingClass ].DefaultBuilding == building.Type
						end
						canBuildSomeday = canBuildSomeday and not (
							-- no espionage buildings for a non-espionage game
							( Game.IsOption(GameOptionTypes.GAMEOPTION_NO_ESPIONAGE) and building.IsEspionage )
							-- Has obsolete tech?
							or ( building.ObsoleteTech and g_activeTeamTechs:HasTech( GameInfoTypes[building.ObsoleteTech] ) )
						)
						if canBuildSomeday or numExisting > 0 or numBuilds > 0 then
							local totalResource = (numExisting + numBuilds) * numResource
							local tip = "[COLOR_YIELD_FOOD]" .. building._Name .. "[ENDCOLOR]"
							if canBuildSomeday then
								local tech = building.PrereqTech and GameInfo.Technologies[ building.PrereqTech ]
								if tech and not g_activeTeamTechs:HasTech( tech.ID ) then
									tip = tip .. " [COLOR_CYAN]" .. tech._Name .. "[ENDCOLOR]"
								end
								local policyBranch = building.PolicyBranchType and GameInfo.PolicyBranchTypes[ building.PolicyBranchType ]
								if policyBranch and not g_activePlayer:GetPolicyBranchChosen( policyBranch.ID ) then
									tip = tip .. " [COLOR_MAGENTA]" .. policyBranch._Name .. "[ENDCOLOR]"
								end
							end
							if totalResource > 0 then
								tipIndex = tipIndex+1
								insert( tips, tipIndex, "[ICON_BULLET]" .. totalResource .. resource.IconString .. " = " ..  numExisting .. " (+" .. numBuilds .. ") " .. tip )
							else
								insert( tips, "[ICON_BULLET] (" .. numResource .. "/" .. tip .. ")" )
							end
						end
					end
				end
			end
			----------------------------
			-- Import & Export Breakdown
			----------------------------

			-- Get specified resource traded with the active player

			local itemType, duration, finalTurn, data1, data2, data3, flag1, fromPlayerID
			local gameTurn = Game.GetGameTurn()-1
			local Exports = {}
			local Imports = {}
			for playerID = 0, GameDefines.MAX_MAJOR_CIVS-1 do
				Exports[ playerID ] = {}
				Imports[ playerID ] = {}
			end
			PushScratchDeal()
			for i = 0, UI.GetNumCurrentDeals( g_activePlayerID ) - 1 do
				UI.LoadCurrentDeal( g_activePlayerID, i )
				local otherPlayerID = g_ScratchDeal:GetOtherPlayer( g_activePlayerID )
				g_ScratchDeal:ResetIterator()
				repeat
					if bnw_mode then
						itemType, duration, finalTurn, data1, data2, data3, flag1, fromPlayerID = g_ScratchDeal:GetNextItem()
					else
						itemType, duration, finalTurn, data1, data2, fromPlayerID = g_ScratchDeal:GetNextItem()
					end
					-- data1 is resourceID, data2 is quantity

					if itemType == TradeableItems.TRADE_ITEM_RESOURCES and data1 == resourceID and data2 then
						if fromPlayerID == g_activePlayerID then
							Exports[otherPlayerID][finalTurn] = (Exports[otherPlayerID][finalTurn] or 0) + data2
						else
							Imports[fromPlayerID][finalTurn] = (Imports[fromPlayerID][finalTurn] or 0) + data2
						end
					end
				until not itemType
			end
			PopScratchDeal()

			----------------------------
			-- Resource Imports
			----------------------------
			if numResourceImport > 0 then
				insert( tips, "" )
				insert( tips, Colorize(numResourceImport) .. " " .. L"TXT_KEY_RESOURCES_IMPORTED" )
				for playerID, row in pairs( Imports ) do
					local tip = ""
					for turn, quantity in pairs(row) do
						if quantity > 0 then
							tip = tip .. " " .. quantity .. resource.IconString .. "(" .. turn - gameTurn .. ")"
						end
					end
					if #tip > 0 then
						insert( tips, "[ICON_BULLET]" .. Players[ playerID ]:GetCivilizationShortDescription() .. tip )
					end
				end
				for minorID = GameDefines.MAX_MAJOR_CIVS, GameDefines.MAX_CIV_PLAYERS-1 do
					local minor = Players[ minorID ]
					if minor and minor:IsAlive() and minor:GetAlly() == g_activePlayerID then
						local quantity = minor:GetResourceExport(resourceID)
						if quantity > 0 then
							insert( tips, "[ICON_BULLET]" .. minor:GetCivilizationShortDescription() .. " " .. quantity .. resource.IconString )
						end
					end
				end
			end
			----------------------------
			-- Resource Exports
			----------------------------
			if numResourceExport > 0 then
				insert( tips, "" )
				insert( tips, Colorize(-numResourceExport) .. " " .. L"TXT_KEY_RESOURCES_EXPORTED" )
				for playerID, row in pairs( Exports ) do
					local tip = ""
					for turn, quantity in pairs(row) do
						if quantity > 0 then
							tip = tip .. " " .. quantity .. resource.IconString .. "(" .. turn - gameTurn .. ")"
						end
					end
					if #tip > 0 then
						insert( tips, "[ICON_BULLET]" .. Players[ playerID ]:GetCivilizationShortDescription() .. tip )
					end
				end
			end

			----------------------------
			-- Resource Useage Breakdown
			----------------------------
			insert( tips, "" )
			insert( tips, Colorize(-numResourceUsed) .. " " .. L"TXT_KEY_PEDIA_REQ_RESRC_LABEL" )
			local tipIndex = #tips

			for unit in GameInfo.Units() do
				local unitID = unit.ID
				local numResource = Game.GetNumResourceRequiredForUnit( unitID, resourceID )
				if numResource > 0 then
					-- count how many such units player has
					local numExisting = 0
					for unit in g_activePlayer:Units() do
						if unit:GetUnitType() == unitID then
							numExisting = numExisting + 1
						end
					end
					-- count how many such units player is building
					local numBuilds = 0
					for city in g_activePlayer:Cities() do
						for i=0, city:GetOrderQueueLength()-1 do
							local queuedOrderType, queuedItemType = city:GetOrderFromQueue( i )
							if queuedOrderType == OrderTypes.ORDER_TRAIN and queuedItemType == unitID then
								numBuilds = numBuilds + 1
							end
						end
					end
					-- can player build this unit someday ?
					local canBuildSomeday = true
					if bnw_mode then
						-- does player trait prohibits training this unit ?
						local leader = GameInfo.Leaders[ g_activePlayer:GetLeaderType() ]
						for leaderTrait in GameInfo.Leader_Traits{ LeaderType = leader.Type } do
							if GameInfo.Trait_NoTrain{ UnitClassType = unit.Class, TraitType = leaderTrait.TraitType }() then
								canBuildSomeday = false
								break
							end
						end
					end
					if canBuildSomeday then
						-- check whether this Unit has been blocked out by the civ XML unit override
						local unitOverride = GameInfo.Civilization_UnitClassOverrides{ CivilizationType = g_activeCivilization.Type, UnitClassType = unit.Class }()
						if unitOverride then
							canBuildSomeday = unitOverride.UnitType == unit.Type
						else
							canBuildSomeday = GameInfo.UnitClasses[ unit.Class ].DefaultUnit == unit.Type
						end
					end
					canBuildSomeday = canBuildSomeday and not (
						-- one City Challenge?
						( Game.IsOption(GameOptionTypes.GAMEOPTION_ONE_CITY_CHALLENGE) and (unit.Found or unit.FoundAbroad) )
						-- Faith Requirements?
						or ( g_isReligionEnabled and (unit.FoundReligion or unit.SpreadReligion or unit.RemoveHeresy) )
						-- obsolete by tech?
						or ( unit.ObsoleteTech and g_activeTeamTechs:HasTech( GameInfoTypes[unit.ObsoleteTech] ) )
					)
					if canBuildSomeday or numExisting > 0 or numBuilds > 0 then
						local totalResource = (numExisting + numBuilds) * numResource
						local tip = "[COLOR_YELLOW]" .. unit._Name .. "[ENDCOLOR]"
						if canBuildSomeday then
							-- Tech requirements
							local tech = unit.PrereqTech and GameInfo.Technologies[ unit.PrereqTech ]
							if tech and not g_activeTeamTechs:HasTech( tech.ID ) then
								tip = format( "%s [COLOR_CYAN]%s[ENDCOLOR]", tip, tech._Name )
							end
							-- Policy Requirement
							local policy = civ5bnw_mode and unit.PolicyType and GameInfo.Policies[ unit.PolicyType ]
							if policy and not g_activePlayer:HasPolicy( policy.ID ) then
								tip = format( "%s [COLOR_MAGENTA]%s[ENDCOLOR]", tip, policy._Name )
							end
							if civBE_mode then
								-- Affinity Level Requirements
								for affinityPrereq in GameInfo.Unit_AffinityPrereqs{ UnitType = unit.Type } do
									local affinityInfo = (tonumber( affinityPrereq.Level) or 0 ) > 0 and GameInfo.Affinity_Types[ affinityPrereq.AffinityType ]
									if affinityInfo and g_activePlayer:GetAffinityLevel( affinityInfo.ID ) < affinityPrereq.Level then
										tip = format("%s [%s]%i%s%s[ENDCOLOR]", tip, affinityInfo.ColorType, affinityPrereq.Level, affinityInfo.IconString or "???", affinityInfo._Name )
									end
								end
							end
						end
						if totalResource > 0 then
							tipIndex = tipIndex+1
							insert( tips, tipIndex, "[ICON_BULLET]" .. totalResource .. resource.IconString .. " = " ..  numExisting .. " (+" .. numBuilds .. ") " .. tip )
						else
							insert( tips, "[ICON_BULLET] (" .. numResource .. "/" .. tip .. ")" )
						end
					end
				end
			end
			for building in GameInfo.Buildings() do
				local buildingID = building.ID
				local numResource = Game.GetNumResourceRequiredForBuilding( buildingID, resourceID )
				if numResource > 0 then
					-- count how many such buildings player has
					local numExisting = g_activePlayer:CountNumBuildings( buildingID )
					-- count how many such units player is building
					local numBuilds = 0
					for city in g_activePlayer:Cities() do
						for i=0, city:GetOrderQueueLength()-1 do
							local queuedOrderType, queuedItemType = city:GetOrderFromQueue( i )
							if queuedOrderType == OrderTypes.ORDER_CONSTRUCT and queuedItemType == buildingID then
								numBuilds = numBuilds + 1
							end
						end
					end
					-- can player build this building someday ?
					local canBuildSomeday
					-- check whether this Unit has been blocked out by the civ XML
					local buildingOverride = GameInfo.Civilization_BuildingClassOverrides{ CivilizationType = g_activeCivilization.Type, BuildingClassType = building.BuildingClass }()
					if buildingOverride then
						canBuildSomeday = buildingOverride.BuildingType == building.Type
					else
						canBuildSomeday = GameInfo.BuildingClasses[ building.BuildingClass ].DefaultBuilding == building.Type
					end
					canBuildSomeday = canBuildSomeday and not (
						-- no espionage buildings for a non-espionage game
						( Game.IsOption(GameOptionTypes.GAMEOPTION_NO_ESPIONAGE) and building.IsEspionage )
						-- Has obsolete tech?
						or ( civ5_mode and building.ObsoleteTech and g_activeTeamTechs:HasTech( GameInfoTypes[building.ObsoleteTech] ) )
					)
					if canBuildSomeday or numExisting > 0 or numBuilds > 0 then
						local totalResource = (numExisting + numBuilds) * numResource
						local tip = "[COLOR_YIELD_FOOD]" .. building._Name .. "[ENDCOLOR]"
						if canBuildSomeday then
							local tech = GameInfo.Technologies[ building.PrereqTech ]
							if tech and not g_activeTeamTechs:HasTech( tech.ID ) then
								tip = format( "%s [COLOR_CYAN]%s[ENDCOLOR]", tip, tech._Name )
							end
							local policyBranch = civ5bnw_mode and building.PolicyBranchType and GameInfo.PolicyBranchTypes[ building.PolicyBranchType ]
							if policyBranch and not g_activePlayer:GetPolicyBranchChosen( policyBranch.ID ) then
								tip = format( "%s [COLOR_MAGENTA]%s[ENDCOLOR]", tip, policyBranch._Name )
							end
							if civBE_mode then
								-- Affinity Level Requirements
								for affinityPrereq in GameInfo.Building_AffinityPrereqs{ BuildingType = building.Type } do
									local affinityInfo = (tonumber( affinityPrereq.Level) or 0 ) > 0 and GameInfo.Affinity_Types[ affinityPrereq.AffinityType ]
									if affinityInfo and g_activePlayer:GetAffinityLevel( affinityInfo.ID ) < affinityPrereq.Level then
										tip = format("%s [%s]%i%s%s[ENDCOLOR]", tip, affinityInfo.ColorType, affinityPrereq.Level, affinityInfo.IconString or "???", affinityInfo._Name )
									end
								end
							end
						end
						if totalResource > 0 then
							tipIndex = tipIndex+1
							insert( tips, tipIndex, "[ICON_BULLET]" .. totalResource .. resource.IconString .. " = " ..  numExisting .. " (+" .. numBuilds .. ") " .. tip )
						else
							insert( tips, "[ICON_BULLET] (" .. numResource .. "/" .. tip .. ")" )
						end
					end
				end
			end
		end

		-- show foreign strategic resources available for trade to the active player

		local tipIndex = #tips
		local totalResource = 0
		----------------------------
		-- Available for Import
		----------------------------
		for playerID = 0, GameDefines.MAX_CIV_PLAYERS - 1 do

			local player = Players[playerID]
			local isMinorCiv = player:IsMinorCiv()

			-- Valid player? - Can't be us, has to be alive, and has to be met
			if playerID ~= g_activePlayerID
				and player:IsAlive()
				and g_activeTeam:IsHasMet( player:GetTeam() )
				and not (isMinorCiv and player:IsAllies(g_activePlayerID))
			then
				local numResource = Game.GetResourceUsageType(resourceID) == ResourceUsageTypes.RESOURCEUSAGE_STRATEGIC
					and ( ( isMinorCiv and player:GetNumResourceTotal(resourceID, false) + player:GetResourceExport( resourceID ) )
					or ( g_ScratchDeal:IsPossibleToTradeItem(playerID, g_activePlayerID, TradeableItems.TRADE_ITEM_RESOURCES, resourceID, 1) and player:GetNumResourceAvailable(resourceID, false) ) )
				if numResource and numResource > 0 then
					totalResource = totalResource + numResource
					insert( tips, "[ICON_BULLET]" .. player:GetCivilizationShortDescription() .. " " .. numResource .. resource.IconString )
				end
			end
		end
		if totalResource > 0 then
			insert( tips, tipIndex+1, "" )
			insert( tips, tipIndex+2, "----------------")
			insert( tips, tipIndex+3, totalResource .. " " .. L"TXT_KEY_EO_RESOURCES_AVAILBLE" )
		end
	end

	return setTextToolTip( concat( tips, "[NEWLINE]" ) )
end

--[[
for _, texture in pairs{ NATURAL_WONDERS = "SV_NaturalWonders.dds", IMPROVEMENT_BARBARIAN_CAMP	= "SV_BarbarianCamp.dds", GOODY_HUT = "SV_AncientRuins.dds", RESOURCE_ARTIFACTS = "SV_AntiquitySite.dds", RESOURCE_HIDDEN_ARTIFACTS = "SV_AntiquitySite_Night.dds", FEATURE_FALLOUT = "SV_Fallout.dds" } do
	local instance = {}
	ContextPtr:BuildInstanceForControlAtIndex( "ResourceInstance", instance, Controls.TopPanelDiploStack, 7 )
	instance.Image:SetTexture( texture )
	instance.Image:SetTextureSizeVal( 160, 160 )
	instance.Image:NormalizeTexture()
	instance.Image:SetHide( false )
end
--]]

local function CreateIcon( index, texture, ToolTipHandler, OnLClick, OnRClick, void1 )
	local instance = {}
	ContextPtr:BuildInstanceForControlAtIndex( "ResourceInstance", instance, Controls.TopPanelDiploStack, index )
	instance.Image:SetTexture( texture )
	instance.Image:SetTextureSizeVal( 160, 160 )
	instance.Image:NormalizeTexture()
	instance.Count:SetToolTipCallback( ToolTipHandler )
	instance.Count:RegisterCallback( Mouse.eLClick, OnLClick )
	instance.Count:RegisterCallback( Mouse.eRClick, OnRClick )
	instance.Count:SetVoid1( void1 )
	return instance
end

local function FindOnMap( list, index, nameFunc )
	local plot
	index, plot = next( list, index )
	if not plot then
		index, plot = next( list, index )
	end
	if plot then
		UI.LookAt( plot )
		local x, y = plot:GetX(), plot:GetY()
		local hex = ToHexFromGrid{ x=x, y=y }
		Events.GameplayFX( hex.x, hex.y, -1 )
		Events.AddPopupTextEvent( HexToWorld( hex ), nameFunc( plot ) or "*", 0 )
	end
	return index
end

-------------------------------------------------
-- Initialization
-------------------------------------------------

local function OnResourceLClick()
	return GamePopup( ButtonPopupTypes.BUTTONPOPUP_ECONOMIC_OVERVIEW )
end
local function OnResourceRClick( resourceID )
	return GamePedia( GameInfo.Resources[ resourceID ]._Name )
end

for resource in GameInfo.Resources() do
	local resourceID = resource.ID
	if Game.GetResourceUsageType( resourceID ) == ResourceUsageTypes.RESOURCEUSAGE_STRATEGIC then
		local instance = CreateIcon( 9, resource._Texture, ResourcesToolTip, OnResourceLClick, OnResourceRClick, resourceID )
		if instance then
			instance.TechRevealID = GameInfoTypes[resource.TechReveal]
			g_ResourceIcons[ resourceID ] = instance
		end
	end
end

local function NaturalWonderInfo( plot )
	local row = g_NaturalWonder[ plot:GetFeatureType() ] 
	return row and row._Name
end

local g_NaturalWonderIcon = CreateIcon( 9, "SV_NaturalWonders.dds",
		function()
			setTextToolTip( L"TXT_KEY_ADVISOR_DISCOVERED_NATURAL_WONDER_DISPLAY" )
		end,
		function()
			g_NaturalWonderIndex = FindOnMap( g_NaturalWonderPlots, g_NaturalWonderIndex, NaturalWonderInfo )
		end,
		function()
			return GamePedia( NaturalWonderInfo( g_NaturalWonderPlots[g_NaturalWonderIndex or next(g_NaturalWonderPlots)] ) )
		end,
		-1 )

Events.NaturalWonderRevealed.Add( function( hexX, hexY )
print("NaturalWonderRevealed at", ToGridFromHex( hexX, hexY ) )
	local plot = Map.GetPlot( ToGridFromHex( hexX, hexY ) )
	if plot then
		local index = plot:GetPlotIndex()
		g_NaturalWonderPlots[ index ] = plot
		g_NaturalWonderIcon.Image:SetHide( false )
		g_NaturalWonderIcon.Count:SetText( table.count( g_NaturalWonderPlots ) )
	end
end )

local function UpdateTopPanel()
	g_requestTopPanelUpdate = true
end

local function UpdateOptions()
	g_clockFormat = g_options
				and g_options.GetValue
				and g_options.GetValue( "Clock" ) == 1
				and g_clockFormats[ g_options.GetValue("ClockMode") or 1 ]
	Controls.CurrentTime:SetHide( not g_clockFormat )
	g_isBasicHelp = civBE_mode or not OptionsManager.IsNoBasicHelp()
	g_isScienceEnabled = not Game.IsOption(GameOptionTypes.GAMEOPTION_NO_SCIENCE)
	g_isPoliciesEnabled = not Game.IsOption(GameOptionTypes.GAMEOPTION_NO_POLICIES)
	g_isHappinessEnabled = civ5_mode and not Game.IsOption(GameOptionTypes.GAMEOPTION_NO_HAPPINESS)
	g_isReligionEnabled = civ5_mode and gk_mode and not Game.IsOption(GameOptionTypes.GAMEOPTION_NO_RELIGION)
	g_isHealthEnabled = not (civ5_mode or Game.IsOption(GameOptionTypes.GAMEOPTION_NO_HEALTH) )
	UpdateTopPanel()
end

for row in GameInfo.Features() do
	if row.NaturalWonder then
		g_NaturalWonder[ row.ID ] = row
	end
end

local function SetActivePlayer()
	g_activePlayerID = Game.GetActivePlayer()
	g_activePlayer = Players[g_activePlayerID]
	g_activeTeamID = g_activePlayer:GetTeam()
	g_activeTeam = Teams[g_activeTeamID]
	g_activeCivilizationID = g_activePlayer:GetCivilizationType()
	g_activeCivilization = GameInfo.Civilizations[ g_activeCivilizationID ]
	g_activeTeamTechs = g_activeTeam:GetTeamTechs()

	local t = g_PlayerSettings[ g_activePlayerID ]
	if not t then
		t = { GoodyPlots = {}, NaturalWonderPlots = {} }
		local GetPlotByIndex = Map.GetPlotByIndex
		local plot
		for index = 0, Map.GetNumPlots()-1 do
			plot = GetPlotByIndex( index )
			if plot and plot:IsRevealed( g_activeTeamID ) then
				if plot:IsGoody() then
					t.GoodyPlots[ index ] = plot
				elseif plot:HasBarbarianCamp() then
				elseif g_NaturalWonder[ plot:GetFeatureType() ] then
					t.NaturalWonderPlots[ index ] = plot
				end
			end
		end
		g_PlayerSettings[ g_activePlayerID ] = t
	end
	g_NaturalWonderPlots = t.NaturalWonderPlots
	g_NaturalWonderIndex = nil
	g_GoodyPlots = t.GoodyPlots
	local n = table.count( g_NaturalWonderPlots )
	g_NaturalWonderIcon.Image:SetHide( n<1 )
	g_NaturalWonderIcon.Count:SetText( n )
	UpdateOptions()
end
SetActivePlayer()

Controls.TopPanelBar:SetHide( not g_isSmallScreen )
Controls.TopPanelBarL:SetHide( g_isSmallScreen )
Controls.TopPanelBarR:SetHide( g_isSmallScreen )
Controls.TopPanelMask:SetHide( true )
for k, f in pairs( g_toolTipHandler ) do
	Controls[k]:SetToolTipCallback( f )
end

-------------------------------------------------
-- Use an animation control to control refresh (not per frame!)
-- Periodic refresh Speed is determined by "Timer" AlphaAnim in xml
-------------------------------------------------
Controls.Timer:RegisterAnimCallback( function()

	if g_alarmTime and os_time() >= g_alarmTime then
		g_alarmTime = nil
		UI.AddPopup{ Type = ButtonPopupTypes.BUTTONPOPUP_TEXT,
			Data1 = 800,	-- WrapWidth
			Option1 = true, -- show TopImage
			Text = os_date( g_clockFormat ) }
	end

	if g_clockFormat then
		Controls.CurrentTime:SetText( os_date( g_clockFormat ) )
	end

	if g_isPopupUp ~= UI.IsPopupUp() then
		Controls.TopPanelMask:SetHide( g_isPopupUp or g_isSmallScreen )
		g_isPopupUp = not g_isPopupUp
		UpdateTopPanelNow()

	elseif g_requestTopPanelUpdate then
		UpdateTopPanelNow()
	end
end)

Events.SerialEventGameDataDirty.Add( UpdateTopPanel )
Events.SerialEventTurnTimerDirty.Add( UpdateTopPanel )
Events.SerialEventCityInfoDirty.Add( UpdateTopPanel )
Events.SerialEventImprovementCreated.Add( UpdateTopPanel )	-- required to update happiness & resources if a resource got hooked up
Events.GameplaySetActivePlayer.Add( SetActivePlayer )
Events.GameOptionsChanged.Add( UpdateOptions )

-------------------------------------------------
-- Alarm Clock
-------------------------------------------------

for clockFormatIndex, clockFormat in ipairs( g_clockFormats ) do
	local instance = {}
	ContextPtr:BuildInstanceForControl( "ClockOptionInstance", instance, Controls.ClockOptions )
	instance = instance.ClockOption
	instance:GetTextButton():SetText( os_date( clockFormat ) )
	instance:SetCheck( g_clockFormat == clockFormat )
	instance:RegisterCheckHandler(
	function( isChecked )
		if isChecked then
			g_options.SetValue( "ClockMode", clockFormatIndex )
			UpdateOptions()
		end
	end)
end
local function GetAlarmOptions()
	g_alarmTime = nil
	local time = tonumber( g_options.GetValue( "AlarmTime" ) ) or 0
	local t = os_date( "*t", time )
	if t then
		Controls.AlarmHours:SetText( format( "%2d", t.hour ) )
		Controls.AlarmMinutes:SetText( format( "%2d", t.min ) )
		if time > os_time() + 1 then

			g_alarmTime = g_options.GetValue( "AlarmIsOn" ) == 1 and time
		end
	end
	Controls.AlarmCheckBox:SetCheck( g_alarmTime )
end
GetAlarmOptions()
Controls.ClockOptions:CalculateSize()
Controls.ClockOptionsPanel:SetSizeY( Controls.ClockOptions:GetSizeY() + 88 )

Controls.CurrentTime:RegisterCallback( Mouse.eLClick,
function()
	Controls.ClockOptionsPanel:SetHide( not Controls.ClockOptionsPanel:IsHidden() )
end)

Controls.ClockOptionsPanelClose:RegisterCallback( Mouse.eLClick,
function()
	Controls.ClockOptionsPanel:SetHide( true )
end)

local function SetAlarmOptions()
	local t = os_date("*t")
	t.hour = tonumber( Controls.AlarmHours:GetText() ) or 0
	t.min = tonumber( Controls.AlarmMinutes:GetText() ) or 0
	local time = os_time(t)

	if time < os_time()+2 then
		time = time + 86400	-- 1 day in seconds
	end
	g_options.SetValue( "AlarmTime", time )
	g_options.SetValue( "AlarmIsOn", Controls.AlarmCheckBox:IsChecked() )

	GetAlarmOptions()
end

Controls.AlarmHours:RegisterCallback( SetAlarmOptions )
Controls.AlarmMinutes:RegisterCallback( SetAlarmOptions )
Controls.AlarmCheckBox:RegisterCheckHandler( SetAlarmOptions )

print("Finished loading EUI top panel",os.clock())
end)
