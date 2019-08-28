------------------------------------------------------
-- Unit Panel Screen
-- modified by bc1 from Civ V 1.0.3.276 code
-- code is common using gk_mode and bnw_mode switches
------------------------------------------------------

include( "EUI_tooltips" )
Events.SequenceGameInitComplete.Add(function()
print("Loading EUI unit panel",ContextPtr,os.clock(),[[ 
 _   _       _ _   ____                  _ 
| | | |_ __ (_) |_|  _ \ __ _ _ __   ___| |
| | | | '_ \| | __| |_) / _` | '_ \ / _ \ |
| |_| | | | | | |_|  __/ (_| | | | |  __/ |
 \___/|_| |_|_|\__|_|   \__,_|_| |_|\___|_|
]])

local gk_mode = Game.GetReligionName ~= nil
local bnw_mode = Game.GetActiveLeague ~= nil


-------------------------------------------------
-- Minor lua optimizations
-------------------------------------------------
local ipairs = ipairs
local ceil = math.ceil
local floor = math.floor
local max = math.max
local pairs = pairs
local print = print
local format = string.format
local concat = table.concat
local insert = table.insert
local remove = table.remove
local tostring = tostring

--EUI_utilities
local StackInstanceManager = StackInstanceManager
local IconLookup = EUI.IconLookup
local IconHookup = EUI.IconHookup
local Color = EUI.Color
local PrimaryColors = EUI.PrimaryColors
local BackgroundColors = EUI.BackgroundColors
local GameInfo = EUI.GameInfoCache -- warning! use iterator ONLY with table field conditions, NOT string SQL query

--EUI_tooltips
local GetHelpTextForUnit = EUI.GetHelpTextForUnit
local GetHelpTextForBuilding = EUI.GetHelpTextForBuilding
local GetHelpTextForProject = EUI.GetHelpTextForProject
local GetHelpTextForProcess = EUI.GetHelpTextForProcess
local GetFoodTooltip = EUI.GetFoodTooltip
local GetProductionTooltip = EUI.GetProductionTooltip
local GetCultureTooltip = EUI.GetCultureTooltip

local ActionSubTypes = ActionSubTypes
local ActivityTypes = ActivityTypes
local ContextPtr = ContextPtr
local Controls = Controls
local DomainTypes = DomainTypes
local Events = Events
local Game = Game
local GameDefines = GameDefines
local GameInfoActions = GameInfoActions
local GameInfoTypes = GameInfoTypes
local GameInfo_Automates = GameInfo.Automates
local GameInfo_Builds = GameInfo.Builds
local GameInfo_Missions = GameInfo.Missions
local GameInfo_Units = GameInfo.Units
local L = Locale.ConvertTextKey
local ToUpper = Locale.ToUpper
local PlotDirection = Map.PlotDirection
local PlotDistance = Map.PlotDistance
local Mouse = Mouse
local OrderTypes = OrderTypes
local Players = Players
local PreGame = PreGame
local ReligionTypes = ReligionTypes
local ResourceUsageTypes = ResourceUsageTypes
local Teams = Teams
local ToHexFromGrid = ToHexFromGrid
local UI = UI
local GetHeadSelectedUnit = UI.GetHeadSelectedUnit
local GetUnitPortraitIcon = UI.GetUnitPortraitIcon
local YieldTypes = YieldTypes

-------------------------------------------------
-- Globals
-------------------------------------------------

local g_tipControls = {}
TTManager:GetTypeControlTable( "EUI_UnitPanelItemTooltip", g_tipControls )

local g_activePlayerID, g_activePlayer, g_activeTeamID, g_activeTeam, g_activeTechs
local g_AllPlayerOptions = { UnitTypes = {}, HideUnitTypes = {}, UnitsInRibbon = {} }

local g_ActivePlayerUnitTypes
local g_ActivePlayerUnitsInRibbon = {}
local g_isHideCityList, g_isHideUnitList, g_isHideUnitTypes
local ActionToolTipHandler

--[[ 
 _   _       _ _          ___      ____ _ _   _             ____  _ _     _                 
| | | |_ __ (_) |_ ___   ( _ )    / ___(_) |_(_) ___  ___  |  _ \(_) |__ | |__   ___  _ __  
| | | | '_ \| | __/ __|  / _ \/\ | |   | | __| |/ _ \/ __| | |_) | | '_ \| '_ \ / _ \| '_ \ 
| |_| | | | | | |_\__ \ | (_>  < | |___| | |_| |  __/\__ \ |  _ <| | |_) | |_) | (_) | | | |
 \___/|_| |_|_|\__|___/  \___/\/  \____|_|\__|_|\___||___/ |_| \_\_|_.__/|_.__/ \___/|_| |_|
]]

-- NO_ACTIVITY, ACTIVITY_AWAKE, ACTIVITY_HOLD, ACTIVITY_SLEEP, ACTIVITY_HEAL, ACTIVITY_SENTRY, ACTIVITY_INTERCEPT, ACTIVITY_MISSION
local g_activityMissions = {
[ActivityTypes.ACTIVITY_AWAKE or -1] = nil,
[ActivityTypes.ACTIVITY_HOLD or -1] = GameInfo_Missions.MISSION_SKIP,
[ActivityTypes.ACTIVITY_SLEEP or -1] = GameInfo_Missions.MISSION_SLEEP,
[ActivityTypes.ACTIVITY_HEAL or -1] = GameInfo_Missions.MISSION_HEAL,
[ActivityTypes.ACTIVITY_SENTRY or -1] = GameInfo_Missions.MISSION_ALERT,
[ActivityTypes.ACTIVITY_INTERCEPT or -1] = GameInfo_Missions.MISSION_AIRPATROL,
[ActivityTypes.ACTIVITY_MISSION or -1] = GameInfo_Missions.MISSION_MOVE_TO,
[-1] = nil }

local g_MaxDamage = GameDefines.MAX_HIT_POINTS or 100
local g_rebaseRangeMultipler = GameDefines.AIR_UNIT_REBASE_RANGE_MULTIPLIER
local g_pressureMultiplier = GameDefines.RELIGION_MISSIONARY_PRESSURE_MULTIPLIER or 1
local g_moveDenominator = GameDefines.MOVE_DENOMINATOR

local g_unitsIM, g_citiesIM, g_unitTypesIM, g_units, g_cities, g_unitTypes

local EUI_options = Modding.OpenUserData( "Enhanced User Interface Options", 1 )

local g_cityFocusIcons = {
--[CityAIFocusTypes.NO_CITY_AI_FOCUS_TYPE or -1] = "",
[CityAIFocusTypes.CITY_AI_FOCUS_TYPE_FOOD or -1] = "[ICON_FOOD]",
[CityAIFocusTypes.CITY_AI_FOCUS_TYPE_PRODUCTION or -1] = "[ICON_PRODUCTION]",
[CityAIFocusTypes.CITY_AI_FOCUS_TYPE_GOLD or -1] = "[ICON_GOLD]",
[CityAIFocusTypes.CITY_AI_FOCUS_TYPE_SCIENCE or -1] = "[ICON_RESEARCH]",
[CityAIFocusTypes.CITY_AI_FOCUS_TYPE_CULTURE or -1] = "[ICON_CULTURE]",
[CityAIFocusTypes.CITY_AI_FOCUS_TYPE_GREAT_PEOPLE or -1] = "[ICON_GREAT_PEOPLE]",
[CityAIFocusTypes.CITY_AI_FOCUS_TYPE_FAITH or -1] = "[ICON_PEACE]",
[-1] = nil }

local g_cityFocusTooltips = {
[CityAIFocusTypes.NO_CITY_AI_FOCUS_TYPE or -1] = L"TXT_KEY_CITYVIEW_FOCUS_BALANCED_TEXT",
[CityAIFocusTypes.CITY_AI_FOCUS_TYPE_FOOD or -1] = L"TXT_KEY_CITYVIEW_FOCUS_FOOD_TEXT",
[CityAIFocusTypes.CITY_AI_FOCUS_TYPE_PRODUCTION or -1] = L"TXT_KEY_CITYVIEW_FOCUS_PROD_TEXT",
[CityAIFocusTypes.CITY_AI_FOCUS_TYPE_GOLD or -1] = L"TXT_KEY_CITYVIEW_FOCUS_GOLD_TEXT",
[CityAIFocusTypes.CITY_AI_FOCUS_TYPE_SCIENCE or -1] = L"TXT_KEY_CITYVIEW_FOCUS_RESEARCH_TEXT",
[CityAIFocusTypes.CITY_AI_FOCUS_TYPE_CULTURE or -1] = L"TXT_KEY_CITYVIEW_FOCUS_CULTURE_TEXT",
[CityAIFocusTypes.CITY_AI_FOCUS_TYPE_GREAT_PEOPLE or -1] = L"TXT_KEY_CITYVIEW_FOCUS_GREAT_PERSON_TEXT",
[CityAIFocusTypes.CITY_AI_FOCUS_TYPE_FAITH or -1] = L"TXT_KEY_CITYVIEW_FOCUS_FAITH_TEXT",
[-1] = nil }

local g_UnitTypeOrder = {}
do
	local i = 1
	for unit in GameInfo.Units() do
		g_UnitTypeOrder[ unit.ID ] = i
		i = i + 1
	end
end

local function SortByVoid2( a, b )
	return a and b and a:GetVoid2() > b:GetVoid2()
end

-------------------------------------------------
-- Tooltip Utilities
-------------------------------------------------

local function ShowSimpleTip( ... )
	local toolTip = ... and concat( {...}, "[NEWLINE]----------------[NEWLINE]" )
	if toolTip then
		g_tipControls.Text:SetText( toolTip )
		g_tipControls.PortraitFrame:SetHide( true )
		g_tipControls.Box:DoAutoSize()
	end
	g_tipControls.Box:SetHide( not toolTip )
end

local function lookAt( plot )
	UI.LookAt( plot )
	local hex = ToHexFromGrid{ x=plot:GetX(), y=plot:GetY() }
	Events.GameplayFX( hex.x, hex.y, -1 )
end

local function lookAtUnit( unit )
	if unit then
		return lookAt( unit:GetPlot() )
	end
end

local function TextColor( c, s )
	return c..s.."[ENDCOLOR]"
end

local function UnitColor( s )
	return TextColor("[COLOR_UNIT_TEXT]", s)
end

local function BuildingColor( s )
	return TextColor("[COLOR_YIELD_FOOD]", s)
end

local function PolicyColor( s )
	return TextColor("[COLOR_MAGENTA]", s)
end

local function TechColor( s )
	return TextColor("[COLOR_CYAN]", s)
end

local function ReligionColor( s )
	return TextColor("[COLOR_WHITE]", s)
end

-------------------------------------------------
-- Ribbon Manager
-------------------------------------------------

local function g_RibbonManager( name, stack, scrap, createAllItems, initItem, updateItem, callbacks, tooltips, closure )
	local index = {}
	local spares = {}

	local function Create( item, itemID, itemOrder )
		if item then
			local instance = remove( spares )
			local button
			if instance then
--print("Recycle from scrap", name, instance, "item", itemID, item and item:GetName() )
				button = instance.Button
				button:ChangeParent( stack )
			else
				instance = {}
--print("Create new ", name, instance, "item", itemID, item and item:GetName() )
				ContextPtr:BuildInstanceForControl( name, instance, stack )
				-- Setup Tootip Callbacks
				button = instance.Button
				local control
				for name, callback in pairs( tooltips ) do
					control = instance[name]
					if control then
						control:SetToolTipCallback( function() callback( closure( button ) ) end )
						control:SetToolTipType( "EUI_UnitPanelItemTooltip" )
					end
				end
				-- Setup Callbacks
				for name, eventCallbacks in pairs( callbacks ) do
					control = instance[name]
					if control then
						for event, callback in pairs( eventCallbacks ) do
							control:RegisterCallback( event, callback )
						end
					end
				end
			end
			index[ itemID ] = instance
			button:SetVoids( itemID, itemOrder )
			return initItem( item, instance )
--else print( "Failed attempt to add an item to the list", itemID )
		end
	end

return{
	Create = Create,

	Destroy = function( itemID )
		local instance = index[ itemID ]
--print( "Remove item from list", name, "item", itemID, instance )
		if instance then
			index[ itemID ] = nil
			insert( spares, instance )
			instance.Button:ChangeParent( scrap )
		end
	end,

	Initialize = function( isHidden )
--print("Initializing ", name, " stack", "hidden ?", isHidden )
		for itemID, instance in pairs( index ) do
			insert( spares, instance )
			instance.Button:ChangeParent( scrap )
			index[ itemID ] = nil
		end
		if not isHidden then
--print("Initializing ", name, " stack contents" )
			createAllItems( Create )
		end
	end,

	Update = function( itemID )
		if itemID then
			local instance = index[ itemID ]
			if instance then
				updateItem( itemID, instance )
			end
		else
			for itemID, instance in pairs( index ) do
				updateItem( itemID, instance )
			end
		end
	end,

	}, index
end

-------------------------------------------------
-- Item Functions
-------------------------------------------------

local function UpdateCity( city, instance )
	if city and instance then
		local itemInfo, portraitOffset, portraitAtlas, buildPercent
		local turnsRemaining = city:GetProductionTurnsLeft()
		local productionNeeded = city:GetProductionNeeded()
		local storedProduction = city:GetProduction() + city:GetOverflowProduction() + city:GetFeatureProduction()
		local orderID, itemID = city:GetOrderFromQueue()
		if orderID == OrderTypes.ORDER_TRAIN then
			itemInfo = GameInfo.Units
			portraitOffset, portraitAtlas = GetUnitPortraitIcon( itemID, g_activePlayerID )
		elseif orderID == OrderTypes.ORDER_CONSTRUCT then
			itemInfo = GameInfo.Buildings
		elseif orderID == OrderTypes.ORDER_CREATE then
			itemInfo = GameInfo.Projects
		elseif orderID == OrderTypes.ORDER_MAINTAIN then
			itemInfo = GameInfo.Processes
			turnsRemaining = nil
			productionNeeded = 0
		end
		if itemInfo then
			itemInfo = itemInfo[ itemID ]or{}
			itemInfo = IconHookup( portraitOffset or itemInfo.PortraitIndex, 64, portraitAtlas or itemInfo.IconAtlas, instance.BuildIcon )
			if productionNeeded > 0 then
				buildPercent = 1 - max( 0, storedProduction/productionNeeded )
			else
				buildPercent = 0
			end
			instance.BuildMeter:SetPercents( 0, buildPercent )
		else
			turnsRemaining = nil
		end
		instance.BuildIcon:SetHide( not itemInfo )
		instance.BuildGrowth:SetString( turnsRemaining )
		instance.Population:SetString( city:GetPopulation() )
		local foodPerTurnTimes100 = city:FoodDifferenceTimes100()
		if foodPerTurnTimes100 < 0 then
			instance.CityGrowth:SetString( " [COLOR_RED]" .. (floor( city:GetFoodTimes100() / -foodPerTurnTimes100 ) + 1) .. "[ENDCOLOR] " )
		elseif city:IsForcedAvoidGrowth() then
			instance.CityGrowth:SetString( "[ICON_LOCKED]" )
		elseif city:IsFoodProduction() or foodPerTurnTimes100 == 0 then
			instance.CityGrowth:SetString()
		else
			instance.CityGrowth:SetString( " "..city:GetFoodTurnsLeft().." " )
		end

		local isNotPuppet = not city:IsPuppet()
		local isNotRazing = not city:IsRazing()
		local isNotResistance = not city:IsResistance()
		local isCapital = city:IsCapital()

		instance.CityIsCapital:SetHide( not isCapital )
		instance.CityIsPuppet:SetHide( isNotPuppet )
		instance.CityFocus:SetText( isNotRazing and isNotPuppet and g_cityFocusIcons[city:GetFocusType()] )
		instance.CityQuests:SetText( city:GetWeLoveTheKingDayCounter() > 0 and "[ICON_HAPPINESS_1]" or (GameInfo.Resources[city:GetResourceDemanded()] or {}).IconString )
		instance.CityIsRazing:SetHide( isNotRazing )
		instance.CityIsResistance:SetHide( isNotResistance )
		instance.CityIsConnected:SetHide( isCapital or not g_activePlayer:IsCapitalConnectedToCity( city ) )
		instance.CityIsBlockaded:SetHide( not city:IsBlockaded() )
		instance.CityIsOccupied:SetHide( not city:IsOccupied() or city:IsNoOccupiedUnhappiness() )
		instance.Name:SetString( city:GetName() )

		local culturePerTurn = city:GetJONSCulturePerTurn()
		instance.BorderGrowth:SetString( culturePerTurn > 0 and ceil( (city:GetJONSCultureThreshold() - city:GetJONSCultureStored()) / culturePerTurn ) )

		local percent = 1 - city:GetDamage() / ( gk_mode and city:GetMaxHitPoints() or GameDefines.MAX_CITY_HIT_POINTS )
		instance.Button:SetColor( Color( 1, percent, percent, 1 ) )
	end
end

local function getUnitBuildProgressData( plot, buildID, unit )
	local buildProgress = plot:GetBuildProgress( buildID )
	local nominalWorkRate = unit:WorkRate( true )
	-- take into account unit.cpp "wipe out all build progress also" game bug
	local buildTime = plot:GetBuildTime( buildID, g_activePlayerID ) - nominalWorkRate
	local buildTurnsLeft
	if buildProgress == 0 then
		buildTurnsLeft = plot:GetBuildTurnsLeft( buildID, g_activePlayerID, nominalWorkRate - unit:WorkRate() )
	else
		buildProgress = buildProgress - nominalWorkRate
		buildTurnsLeft = plot:GetBuildTurnsLeft( buildID, g_activePlayerID, -unit:WorkRate() )
	end
	if buildTurnsLeft > 99999 then
		return ceil( ( buildTime - buildProgress ) / nominalWorkRate ), buildProgress, buildTime
	else
		return buildTurnsLeft, buildProgress, buildTime
	end
end

local function UpdateUnit( unit, instance, unitID )
	local unitMovesLeft = unit:MovesLeft()
	local pip
	if unitMovesLeft >= unit:MaxMoves() then
		pip = 0 -- cyan (green)
	elseif unitMovesLeft > 0 then
		if unit:IsCombatUnit() and unit:IsOutOfAttacks() then
			pip = 96 -- orange (gray)
		else
			pip = 32 -- green (yellow)
		end
	else
		pip = 64 -- red
	end
	local damage = unit:GetDamage()
	local percent
	if damage <= 0 then
		percent = 1
	elseif instance == Controls then
		percent = 1 - damage / g_MaxDamage / 3
	else
		percent = 1 - damage / g_MaxDamage
	end

	local info
	local text
	local buildID = unit:GetBuildType()
	if buildID ~= -1 then -- unit is actively building something
		info = GameInfo_Builds[buildID]
		text = getUnitBuildProgressData( unit:GetPlot(), buildID, unit )
		if text > 99 then text = nil end

	elseif unit:IsEmbarked() then
		info = GameInfo_Missions.MISSION_EMBARK

	elseif unit:IsAutomated() then
		if unit:IsWork() then
			info = GameInfo_Automates.AUTOMATE_BUILD
		elseif bnw_mode and unit:IsTrade() then
			info = GameInfo_Missions.MISSION_ESTABLISH_TRADE_ROUTE
		else
			info = GameInfo_Automates.AUTOMATE_EXPLORE
		end
	else
		local activityType = unit:GetActivityType()
		if activityType == ActivityTypes.ACTIVITY_SLEEP then
			if unit:IsGarrisoned() then
				info = GameInfo_Missions.TXT_KEY_MISSION_GARRISON
			elseif unit:IsEverFortifyable() then
				info = GameInfo_Missions.MISSION_FORTIFY
			elseif unitMovesLeft > 0  then
				info = GameInfo_Missions.MISSION_SLEEP
			end
		else
			info = g_activityMissions[ activityType ]
		end
	end
	repeat
		instance.Button:SetColor( Color( 1, percent, percent, 1 ) )
		instance.MovementPip:SetTextureOffsetVal( 0, pip )
		instance.Mission:SetHide( not( info and IconHookup( info.IconIndex, 45, info.IconAtlas, instance.Mission ) ) )
		instance.MissionText:SetText( text )
		if unitID then
			instance = g_units[ unitID ]
			if instance then
				instance.MovementPip:Play()
				unitID = nil
			else
				break
			end
		else
			break
		end
	until false
end

local function FilterUnit( unit )
	return unit and g_ActivePlayerUnitsInRibbon[ unit:GetUnitType() ]
end

local function UnitToolTip( unit, ... )
	if unit then
		local unitTypeID = unit:GetUnitType()
		local unitInfo = GameInfo_Units[unitTypeID]

		-- Unit XML stats
--		local productionCost = g_activePlayer:GetUnitProductionNeeded( unitTypeID )
		local rangedStrength = unit:GetBaseRangedCombatStrength()
		local unitRange = unit:Range()
		local combatStrength = unitInfo.Combat or 0

		local thisUnitType = { UnitType = unitInfo.Type }

		-- Player data
		local city, activeCivilization, activeCivilizationType

		activeCivilization = GameInfo.Civilizations[ g_activePlayer:GetCivilizationType() ]
		activeCivilizationType = activeCivilization and activeCivilization.Type
		city = UI.GetHeadSelectedCity()
		city = (city and city:GetOwner() ~= g_activePlayerID and city) or g_activePlayer:GetCapitalCity() or g_activePlayer:Cities()(g_activePlayer)

		-- Name
		local combatClass = unitInfo.CombatClass and GameInfo.UnitCombatInfos[unitInfo.CombatClass]
		local tips = { UnitColor( ToUpper( unit:GetNameKey() ) ) .. (combatClass and " ("..L(combatClass.Description)..")" or ""), "----------------", ... }

		-- Required Resources:
		local resources = {}
		for resource in GameInfo.Resources() do
			local numResourceRequired = Game.GetNumResourceRequiredForUnit( unitTypeID, resource.ID )
-- TODO				local numResourceAvailable = g_activePlayer:GetNumResourceAvailable(resource.ID, true)
			if numResourceRequired > 0 then
				insert( resources, numResourceRequired .. resource.IconString )-- .. L(resource.Description) )
			end
		end
		if #resources > 0 then
			insert( tips, L"TXT_KEY_PEDIA_REQ_RESRC_LABEL" .. " " .. concat( resources, ", " ) )
		end

		-- Movement:
		if unitInfo.Domain ~= "DOMAIN_AIR" then
			insert( tips, format( "%s %.3g / %g[ICON_MOVES]", L"TXT_KEY_UPANEL_MOVEMENT", unit:MovesLeft() / g_moveDenominator, unit:MaxMoves() / g_moveDenominator ) )
		end

		-- Combat:
		if combatStrength > 0 then
			insert( tips, format( "%s %g[ICON_STRENGTH]", L"TXT_KEY_UPANEL_STRENGTH", combatStrength ) )
		end

		-- Ranged Combat:
		if rangedStrength > 0 then
			insert( tips, L"TXT_KEY_UPANEL_RANGED_ATTACK" .. " " .. rangedStrength .. "[ICON_RANGE_STRENGTH]" .. unitRange ) --TXT_KEY_PEDIA_RANGEDCOMBAT_LABEL
		end

		-- Health
		local damage = unit:GetDamage()
		if damage > 0 then
			insert( tips, L( "TXT_KEY_UPANEL_SET_HITPOINTS_TT", g_MaxDamage-damage, g_MaxDamage ) )
		end

		-- XP
		if (unit:IsCombatUnit() or unit:GetDomainType() == DomainTypes.DOMAIN_AIR) then
			insert( tips, L("TXT_KEY_UNIT_EXPERIENCE_INFO", unit:GetLevel(), unit:GetExperience(), unit:ExperienceNeeded() ) )
		--L( "TXT_KEY_EXPERIENCE_POPUP", unit:GetExperience().."/"..unit:ExperienceNeeded() ) )
		end

		-- Abilities:	--TXT_KEY_PEDIA_FREEPROMOTIONS_LABEL
		for unitPromotion in GameInfo.UnitPromotions() do
			if unit:IsHasPromotion(unitPromotion.ID) and not (bnw_mode and unit:IsTrade()) then
				insert( tips, "[ICON_BULLET]"..L(unitPromotion.Description) )-- L(unitPromotion.Help) )
			end
		end

		-- Ability to create building in city (e.g. vanilla great general)
		for row in GameInfo.Unit_Buildings( thisUnitType ) do
			local building = row.BuildingType and GameInfo.Buildings[row.BuildingType]
			if building then
				insert( tips, "[ICON_BULLET]"..L"TXT_KEY_MISSION_CONSTRUCT".." " .. BuildingColor( L(building.Description) ) )
			end
		end

		-- Actions	--TXT_KEY_PEDIA_WORKER_ACTION_LABEL
		for row in GameInfo.Unit_Builds( thisUnitType ) do
			local build = row.BuildType and GameInfo.Builds[row.BuildType]
			if build then
				local buildImprovement = build.ImprovementType and GameInfo.Improvements[ build.ImprovementType ]
				local requiredCivilizationType = buildImprovement and buildImprovement.CivilizationType
				if not requiredCivilizationType or GameInfoTypes[ requiredCivilizationType ] == g_activePlayer:GetCivilizationType() then
					local prereqTech = build.PrereqTech and GameInfo.Technologies[build.PrereqTech]
					if (not prereqTech or g_activeTechs:HasTech( prereqTech.ID or -1 ) ) then
						insert( tips, "[ICON_BULLET]" .. L(build.Description) )
					end
				end
			end
		end

		-- Great Engineer
		if unitInfo.BaseHurry > 0 then
			insert( tips, format( "[ICON_BULLET]%s %g[ICON_PRODUCTION]%+g[ICON_PRODUCTION]/[ICON_CITIZEN]", L"TXT_KEY_MISSION_HURRY_PRODUCTION", unitInfo.BaseHurry, unitInfo.HurryMultiplier or 0 ) )
		end

		-- Great Merchant
		if unitInfo.BaseGold > 0 then
			insert( tips, format( "[ICON_BULLET]%s %g[ICON_GOLD]%+g[ICON_INFLUENCE]", L"TXT_KEY_MISSION_CONDUCT_TRADE_MISSION", unitInfo.BaseGold + ( unitInfo.NumGoldPerEra or 0 ) * ( Game and Teams[Game.GetActiveTeam()]:GetCurrentEra() or PreGame.GetEra() ), GameDefines.MINOR_FRIENDSHIP_FROM_TRADE_MISSION or 0 ) )
		end

		-- Becomes Obsolete with:
		local obsoleteTech = unitInfo.ObsoleteTech and GameInfo.Technologies[unitInfo.ObsoleteTech]
		if obsoleteTech then
			insert( tips, L"TXT_KEY_PEDIA_OBSOLETE_TECH_LABEL" .. " " .. TechColor( L(obsoleteTech.Description) ) )
		end

		-- Upgrade unit
		local upgradeUnitTypeID = unit:GetUpgradeUnitType()
		local unitUpgradeInfo = upgradeUnitTypeID and GameInfo.Units[upgradeUnitTypeID]
		if unitUpgradeInfo then
			insert( tips, L"TXT_KEY_COMMAND_UPGRADE" .. ": " .. UnitColor( L(unitUpgradeInfo.Description) ) .. " ("..unit:UpgradePrice(upgradeUnitTypeID).."[ICON_GOLD])" )
		end

		g_tipControls.Text:SetText( concat( tips, "[NEWLINE]" ) )
		local portraitOffset, portraitAtlas = GetUnitPortraitIcon( unit )
		IconHookup( portraitOffset, g_tipControls.Portrait:GetSizeY(), portraitAtlas, g_tipControls.Portrait )
		g_tipControls.PortraitFrame:SetHide( false )
		g_tipControls.Box:DoAutoSize()
	end
	g_tipControls.Box:SetHide( not unit )
end

-------------------------------------------------
-- Unit Ribbon "Object"
-------------------------------------------------
g_unitsIM, g_units = g_RibbonManager( "UnitInstance", Controls.UnitStack, Controls.Scrap,
	function( Create ) -- createAllItems( Create )
		local unitID
		for unit in g_activePlayer:Units() do
			if FilterUnit( unit ) then
				unitID = unit:GetID()
				Create( unit, unitID, g_UnitTypeOrder[unit:GetUnitType()] + unitID / 65536 )
			end
		end
		Controls.UnitStack:SortChildren( SortByVoid2 )
	end,
	function( unit, instance ) -- initItem( item, instance )
		local portrait, portraitOffset, portraitAtlas = instance.Portrait, GetUnitPortraitIcon( unit )
		IconHookup( portraitOffset, portrait:GetSizeX(), portraitAtlas, portrait )
		if unit == GetHeadSelectedUnit() then
			instance.MovementPip:Play()
		else
			instance.MovementPip:SetToBeginning()
		end
		return UpdateUnit( unit, instance )
	end,
	function( unitID, instance ) -- updateItem( itemID, instance )
		local unit = g_activePlayer:GetUnitByID( unitID )
		if unit then
			UpdateUnit( unit, instance )
		end
	end,
-------------------------------------------------------------------------------------------------
{-- the callback function table names need to match associated instance control ID defined in xml
	Button = {
		[Mouse.eLClick] = function( unitID )
			local unit = g_activePlayer:GetUnitByID( unitID )
			UI.SelectUnit( unit )
			lookAtUnit( unit )
		end,
		[Mouse.eRClick] = function( unitID )
			lookAtUnit( g_activePlayer:GetUnitByID( unitID ) )
		end,
	},--/Button
},--/unit callbacks
------------------------------------------------------------------------------------------
{-- the tooltip function names need to match associated instance control ID defined in xml
	Button = UnitToolTip,
	MovementPip = function( unit )
		return ShowSimpleTip( unit and format( "%s %.3g / %g [ICON_MOVES]", L"TXT_KEY_UPANEL_MOVEMENT", unit:MovesLeft() / g_moveDenominator, unit:MaxMoves() / g_moveDenominator )
--[[
.." GetActivityType="..tostring(unit:GetActivityType())
.." GetFortifyTurns="..tostring(unit:GetFortifyTurns())
.." HasMoved="..tostring(unit:HasMoved())
.." IsReadyToMove="..tostring(unit:IsReadyToMove())
.." IsWaiting="..tostring(unit:IsWaiting())
.." IsAutomated="..tostring(unit:IsAutomated())
--]]
		)
	end,
	Mission = function( unit )
		local status = "Unkown unit state"
		if unit then
			local buildID = unit:GetBuildType()
			if buildID ~= -1 then -- this is a worker who is actively building something
				status = L(GameInfo_Builds[buildID].Description).. " (".. getUnitBuildProgressData( unit:GetPlot(), buildID, unit ) ..")"

			elseif unit:IsEmbarked() then
				status = L"TXT_KEY_MISSION_EMBARK_HELP" --"TXT_KEY_UNIT_STATUS_EMBARKED"

			elseif unit:IsAutomated() then
				if unit:IsWork() then
					status = L"TXT_KEY_ACTION_AUTOMATE_BUILD"
				elseif bnw_mode and unit:IsTrade() then
					status = L"TXT_KEY_ACTION_AUTOMATE_TRADE"
				else
					status = L"TXT_KEY_ACTION_AUTOMATE_EXPLORE"
				end

			else
				local activityType = unit:GetActivityType()
				local info
				if activityType == ActivityTypes.ACTIVITY_SLEEP then
					if unit:IsGarrisoned() then
						info = GameInfo_Missions.TXT_KEY_MISSION_GARRISON
					elseif unit:IsEverFortifyable() then
--						info = GameInfo_Missions.MISSION_FORTIFY
						status = format( "%s %+i%%[ICON_STRENGTH]", L"TXT_KEY_UNIT_STATUS_FORTIFIED", unit:FortifyModifier() )
					else
						info = GameInfo_Missions.MISSION_SLEEP
					end
				else
					info = g_activityMissions[ activityType ]
				end
				if info then
					status = L(info.Help)
				end
--[[
				local activityType = unit:GetActivityType()
				if activityType == ActivityTypes.ACTIVITY_HEAL then
					status = L"TXT_KEY_MISSION_HEAL_HELP"

				elseif activityType == ActivityTypes.ACTIVITY_SENTRY then
					status = L"TXT_KEY_MISSION_ALERT_HELP"

				elseif activityType == ActivityTypes.ACTIVITY_SLEEP then -- sleep is either sleep or fortify
					if unit:IsGarrisoned() then
						status = L"TXT_KEY_MISSION_GARRISON_HELP"
					elseif unit:IsEverFortifyable() then
						status = format( "%s %+i%[ICON_DEFENSE]", L"TXT_KEY_UNIT_STATUS_FORTIFIED", unit:FortifyModifier() )
					else
						status = L"TXT_KEY_MISSION_SLEEP_HELP"
					end
				elseif activityType == ActivityTypes.ACTIVITY_INTERCEPT then
					status = L"TXT_KEY_MISSION_INTERCEPT_HELP"

				elseif activityType == ActivityTypes.ACTIVITY_HOLD then
					status = L"TXT_KEY_MISSION_SKIP_HELP"

				elseif activityType == ActivityTypes.ACTIVITY_MISSION then
					status = L"TXT_KEY_INTERFACEMODE_MOVE_TO_HELP"
				end
--]]
			end
		else
			status = "Error - cannot find unit"
		end
		return ShowSimpleTip( status )
	end,
},--/units tooltips
function( button )
	return g_activePlayer:GetUnitByID( button:GetVoid1() )
end
)--/unit ribbon object

-------------------------------------------------
-- City Ribbon "Object"
-------------------------------------------------
local function ShowSimpleCityTip( city, tip, ... )
	return ShowSimpleTip( city:GetName() .. "[NEWLINE]" .. tip, ... )
end

g_citiesIM, g_cities = g_RibbonManager( "CityInstance", Controls.CityStack, Controls.Scrap,
	function( Create ) -- createAllItems( Create )
		for city in g_activePlayer:Cities() do
			Create( city, city:GetID() )
		end
	end,
	UpdateCity, -- initItem( item, instance )
	function( cityID, instance ) UpdateCity( g_activePlayer:GetCityByID( cityID ), instance ) end, -- updateItem( itemID, instance )
-------------------------------------------------------------------------------------------------
{-- the callback function table names need to match associated instance control ID defined in xml
	Button = {
		[Mouse.eLClick] = function( cityID )
			local city = g_activePlayer:GetCityByID( cityID )
			if city then
				UI.DoSelectCityAtPlot( city:Plot() )
			end
		end,
		[Mouse.eRClick] = function( cityID )
			local city = g_activePlayer:GetCityByID( cityID )
			if city then
				lookAt( city:Plot() )
			end
		end,
	},--/Button
},--/city callbacks
------------------------------------------------------------------------------------------
{-- the tooltip function names need to match associated instance control ID defined in xml
	Button = function( city )
		local itemInfo, strToolTip, portraitOffset, portraitAtlas
		local orderID, itemID = city:GetOrderFromQueue()
		if orderID == OrderTypes.ORDER_TRAIN then
			itemInfo = GameInfo.Units
			portraitOffset, portraitAtlas = GetUnitPortraitIcon( itemID, g_activePlayerID )
			strToolTip = GetHelpTextForUnit( itemID, true )

		elseif orderID == OrderTypes.ORDER_CONSTRUCT then
			itemInfo = GameInfo.Buildings
			strToolTip = GetHelpTextForBuilding( itemID, false, false, city:GetNumFreeBuilding(itemID) > 0, city )

		elseif orderID == OrderTypes.ORDER_CREATE then
			itemInfo = GameInfo.Projects
			strToolTip = GetHelpTextForProject( itemID, true )
		elseif orderID == OrderTypes.ORDER_MAINTAIN then
			itemInfo = GameInfo.Processes
			strToolTip = GetHelpTextForProcess( itemID, true )
		end
		if strToolTip and city:GetOrderQueueLength() > 0 then
			strToolTip = L( "TXT_KEY_CITY_CURRENTLY_PRODUCING_TT", city:GetName(), city:GetProductionNameKey(), city:GetProductionTurnsLeft() ) .. "[NEWLINE]----------------[NEWLINE]" .. strToolTip
		else
			strToolTip = L( "TXT_KEY_CITY_NOT_PRODUCING", city:GetName() )
		end
		local item = itemInfo and itemInfo[itemID]
		item = item and IconHookup( portraitOffset or item.PortraitIndex, g_tipControls.Portrait:GetSizeY(), portraitAtlas or item.IconAtlas, g_tipControls.Portrait )
		g_tipControls.Text:SetText( strToolTip )
		g_tipControls.PortraitFrame:SetHide( not item )
		g_tipControls.Box:DoAutoSize()
	end,
	BuildGrowth = function( city )
		return ShowSimpleTip( city and L( "TXT_KEY_CITY_CURRENTLY_PRODUCING_TT", city:GetName(), city:GetProductionNameKey(), city:GetProductionTurnsLeft() ), GetProductionTooltip( city ) )
	end,
	Population = function( city )
		return ShowSimpleCityTip( city, city:GetPopulation() .. "[ICON_CITIZEN] ".. L( "TXT_KEY_CITYVIEW_CITIZENS_TEXT", city:GetPopulation() ), GetFoodTooltip( city ) )
	end,
	CityGrowth = function( city )
		if city then
			local tip
			local foodPerTurnTimes100 = city:FoodDifferenceTimes100()
			if foodPerTurnTimes100 < 0 then
				tip = L( "TXT_KEY_NTFN_CITY_STARVING", city:GetName() )
			elseif city:IsForcedAvoidGrowth() then
				tip = L"TXT_KEY_CITYVIEW_FOCUS_AVOID_GROWTH_TEXT"
			elseif city:IsFoodProduction() or foodPerTurnTimes100 == 0 then
				tip = L"TXT_KEY_CITYVIEW_STAGNATION_TEXT"
			else
				tip = L( "TXT_KEY_CITYVIEW_TURNS_TILL_CITIZEN_TEXT", city:GetFoodTurnsLeft() )
			end
			return ShowSimpleCityTip( city, tip, GetFoodTooltip( city ) )
		end
	end,
	BorderGrowth = function( city )
		return ShowSimpleCityTip( city, L("TXT_KEY_CITYVIEW_TURNS_TILL_TILE_TEXT", ceil( (city:GetJONSCultureThreshold() - city:GetJONSCultureStored()) / city:GetJONSCulturePerTurn() ) ), GetCultureTooltip( city ) )
	end,
	CityIsCapital = function( city )
		return ShowSimpleCityTip( city, "[ICON_CAPITAL]" )
	end,
	CityIsPuppet = function( city )
		return ShowSimpleCityTip( city, L"TXT_KEY_CITY_PUPPET", L"TXT_KEY_CITY_ANNEX_TT" )
	end,
	CityFocus = function( city )
		return ShowSimpleCityTip( city, city and g_cityFocusTooltips[city:GetFocusType()] )
	end,
	CityQuests = function( city )
		local resource = GameInfo.Resources[city:GetResourceDemanded()]
		local weLoveTheKingDayCounter = city:GetWeLoveTheKingDayCounter()
		local tip
		-- We love the king
		if weLoveTheKingDayCounter > 0 then
			tip = L( "TXT_KEY_CITYVIEW_WLTKD_COUNTER", weLoveTheKingDayCounter )

		elseif resource then
			tip = L( "TXT_KEY_CITYVIEW_RESOURCE_DEMANDED", resource.IconString .. " " .. L(resource.Description) )
		end
		return ShowSimpleCityTip( city, tip )
	end,
	CityIsRazing = function( city )
		return ShowSimpleCityTip( city, L( "TXT_KEY_CITY_BURNING", city:GetRazingTurns() ) )
	end,
	CityIsResistance = function( city )
		return ShowSimpleCityTip( city, L( "TXT_KEY_CITY_RESISTANCE", city:GetResistanceTurns() ) )
	end,
	CityIsConnected = function( city )
		return ShowSimpleCityTip( city, format( "%s (%+g[ICON_GOLD])", L"TXT_KEY_CITY_CONNECTED", ( bnw_mode and g_activePlayer:GetCityConnectionRouteGoldTimes100( city ) or g_activePlayer:GetRouteGoldTimes100( city ) ) / 100 ) ) -- stupid function renaming
	end,
	CityIsBlockaded = function( city )
		return ShowSimpleCityTip( city, L"TXT_KEY_CITY_BLOCKADED" )
	end,
	CityIsOccupied = function( city )
		return ShowSimpleCityTip( city, L"TXT_KEY_CITY_OCCUPIED" )
	end,

},--/city tooltips
function( button )
	return g_activePlayer:GetCityByID( button:GetVoid1() )
end
)--/city ribbon object

--[[ 
 _   _       _ _     ____                  _ 
| | | |_ __ (_) |_  |  _ \ __ _ _ __   ___| |
| | | | '_ \| | __| | |_) / _` | '_ \ / _ \ |
| |_| | | | | | |_  |  __/ (_| | | | |  __/ |
 \___/|_| |_|_|\__| |_|   \__,_|_| |_|\___|_|
]]

local g_screenWidth , g_screenHeight = UIManager:GetScreenSizeVal()
local g_topOffset0 = Controls.CityPanel:GetOffsetY()
local g_topOffset = g_topOffset0
local g_bottomOffset0 = Controls.UnitPanel:GetOffsetY()
local g_bottomOffset = g_bottomOffset0

local g_Actions = {}
local g_Promotions = {}
local g_UnusedControls = Controls.Scrap

local g_lastUnitID		-- Used to determine if a different unit has been selected.
local g_isWorkerActionPanelOpen = false

local g_unitPortraitSize = Controls.UnitPortrait:GetSizeX()

local g_actionButtonSpacing = OptionsManager.GetSmallUIAssets() and 42 or 58

--[[
local g_actionIconSize = OptionsManager.GetSmallUIAssets() and 36 or 50
local g_recommendedActionButton = {}
ContextPtr:BuildInstanceForControlAtIndex( "UnitAction", g_recommendedActionButton, Controls.WorkerActionStack, 1 )
--Controls.RecommendedActionLabel:ChangeParent( g_recommendedActionButton.UnitActionButton )
local g_existingBuild = {}
ContextPtr:BuildInstanceForControl( "UnitAction", g_existingBuild, Controls.WorkerActionStack )
g_existingBuild.WorkerProgressBar:SetPercent( 1 )
g_existingBuild.UnitActionButton:SetDisabled( true )
g_existingBuild.UnitActionButton:SetAlpha( 0.8 )
--]]

local g_directionTypes = {
	DirectionTypes.DIRECTION_NORTHEAST,
	DirectionTypes.DIRECTION_EAST,
	DirectionTypes.DIRECTION_SOUTHEAST,
	DirectionTypes.DIRECTION_SOUTHWEST,
	DirectionTypes.DIRECTION_WEST,
	DirectionTypes.DIRECTION_NORTHWEST
}

local g_yieldString = {
[YieldTypes.YIELD_FOOD or -1] = "TXT_KEY_BUILD_FOOD_STRING",
[YieldTypes.YIELD_PRODUCTION or -1] = "TXT_KEY_BUILD_PRODUCTION_STRING",
[YieldTypes.YIELD_GOLD or -1] = "TXT_KEY_BUILD_GOLD_STRING",
[YieldTypes.YIELD_SCIENCE or -1] = "TXT_KEY_BUILD_SCIENCE_STRING",
[YieldTypes.YIELD_CULTURE or -1] = "TXT_KEY_BUILD_CULTURE_STRING",
[YieldTypes.YIELD_FAITH or -1] = "TXT_KEY_BUILD_FAITH_STRING",
[-1] = nil }
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
local function OnUnitActionClicked( actionID )
	local action = GameInfoActions[actionID]
	if action and g_activePlayer:IsTurnActive() then
		Game.HandleAction( actionID )
		if action.SubType == ActionSubTypes.ACTIONSUBTYPE_PROMOTION then
			Events.AudioPlay2DSound("AS2D_INTERFACE_UNIT_PROMOTION")
		end
	end
end


---------------------------------------------------
---- Promotion Help
---------------------------------------------------
--local function PromotionHelpOpen(iPromotionID)
	--local pPromotionInfo = GameInfo.UnitPromotions[iPromotionID]
	--local promotionHelp = L(pPromotionInfo.Description)
	--Controls.HelpText:SetText(promotionHelp)
--end



--------------------------------------------------------------------------------
-- Event Handlers
--------------------------------------------------------------------------------

Controls.CycleLeft:RegisterCallback( Mouse.eLClick,
function()
	-- Cycle to next selection.
	Game.CycleUnits(true, true, false)
end)

Controls.CycleRight:RegisterCallback( Mouse.eLClick,
function()
	-- Cycle to previous selection.
	Game.CycleUnits(true, false, false)
end)

local function OnUnitNameClicked()
	-- go to this unit
	lookAtUnit( GetHeadSelectedUnit() )
end
Controls.UnitNameButton:RegisterCallback( Mouse.eLClick, OnUnitNameClicked )

Controls.UnitPortraitButton:SetToolTipCallback(
function()
	UnitToolTip( GetHeadSelectedUnit(), L"TXT_KEY_CURRENTLY_SELECTED_UNIT", "----------------" )
end)

Controls.UnitPortraitButton:RegisterCallback( Mouse.eLClick, OnUnitNameClicked )

Controls.UnitPortraitButton:RegisterCallback( Mouse.eRClick,
function()
	local unit = GetHeadSelectedUnit()
	Events.SearchForPediaEntry( unit and unit:GetNameKey() )
end)


-------------------------------------------------
-- Unit rename
-------------------------------------------------
local function OnEditNameClick()

	if GetHeadSelectedUnit() then
		Events.SerialEventGameMessagePopup{
				Type = ButtonPopupTypes.BUTTONPOPUP_RENAME_UNIT,
				Data1 = GetHeadSelectedUnit():GetID(),
				Data2 = -1,
				Data3 = -1,
				Option1 = false,
				Option2 = false
			}
	end
end
Controls.EditButton:RegisterCallback( Mouse.eLClick, OnEditNameClick )
Controls.UnitNameButton:RegisterCallback( Mouse.eRClick, OnEditNameClick )

------------------------------------------------------
-- Action Tooltip Handler
------------------------------------------------------
local tipControlTable = {}
TTManager:GetTypeControlTable( "TypeUnitAction", tipControlTable )
function ActionToolTipHandler( control )

	local unit = GetHeadSelectedUnit()
	if not unit then
		tipControlTable.UnitActionMouseover:SetHide( true )
		return
	end

	local actionID = control:GetVoid1()
	local action = GameInfoActions[actionID]
	local unitPlot = unit:GetPlot()
	local x = unit:GetX()
	local y = unit:GetY()

	if action.Type == "MISSION_FOUND" then
		tipControlTable.UnitActionIcon:SetTextureOffsetVal( 0, 0 )
		tipControlTable.UnitActionIcon:SetTexture( "BuildCity64.dds" )
	else
		local instance = g_Actions[actionID] or {}
		IconHookup( instance.IconIndex, 64, instance.IconAtlas, tipControlTable.UnitActionIcon )
	end

	-- Able to perform action
	local gameCanHandleAction = Game.CanHandleAction( actionID, unitPlot, false )

	-- Build data
	local isBuild = action.SubType == ActionSubTypes.ACTIONSUBTYPE_BUILD
	local buildID = action.MissionData
	local build = GameInfo_Builds[buildID]

	-- Improvement data
	local improvement = build and GameInfo.Improvements[build.ImprovementType]
	local improvementID = improvement and improvement.ID or -1

	-- Feature data
	local featureID = unitPlot:GetFeatureType()
	local feature = GameInfo.Features[featureID]

	-- Route data
	local route = build and build.RouteType and build.RouteType ~= "NONE" and GameInfo.Routes[build.RouteType]

	local strBuildTurnsString = ""
	local toolTip = {}
	local disabledTip = {}

	-- Upgrade has special help text
	if action.Type == "COMMAND_UPGRADE" then

		local upgradeUnitTypeID = unit:GetUpgradeUnitType()
		local unitUpgradePrice = unit:UpgradePrice(upgradeUnitTypeID)

		insert( toolTip, L( "TXT_KEY_UPGRADE_HELP", GameInfo_Units[upgradeUnitTypeID].Description, unitUpgradePrice ) )
		insert( toolTip, "----------------" )
		insert( toolTip, GetHelpTextForUnit( upgradeUnitTypeID, true ) )

		if not gameCanHandleAction then
			insert( toolTip, "----------------" )

			-- Can't upgrade because we're outside our territory
			if unitPlot:GetOwner() ~= unit:GetOwner() then

				insert( disabledTip, L"TXT_KEY_UPGRADE_HELP_DISABLED_TERRITORY" )
			end

			-- Can't upgrade because we're outside of a city
			if unit:GetDomainType() == DomainTypes.DOMAIN_AIR and not unitPlot:IsCity() then

				insert( disabledTip, L"TXT_KEY_UPGRADE_HELP_DISABLED_CITY" )
			end

			-- Can't upgrade because we lack the Gold
			if unitUpgradePrice > g_activePlayer:GetGold() then

				insert( disabledTip, L"TXT_KEY_UPGRADE_HELP_DISABLED_GOLD" )
			end

			-- Can't upgrade because we lack the Resources
			local resourcesNeeded = {}

			-- Loop through all resources to see how many we need. If it's > 0 then add to the string
			for resource in GameInfo.Resources() do
				local iResourceLoop = resource.ID

				local iNumResourceNeededToUpgrade = unit:GetNumResourceNeededToUpgrade(iResourceLoop)

				if iNumResourceNeededToUpgrade > 0 and iNumResourceNeededToUpgrade > g_activePlayer:GetNumResourceAvailable(iResourceLoop) then
					insert( resourcesNeeded, iNumResourceNeededToUpgrade .. " " .. resource.IconString .. " " .. L(resource.Description) )
				end
			end

			-- Build resources required string
			if #resourcesNeeded > 0 then

				insert( disabledTip, L( "TXT_KEY_UPGRADE_HELP_DISABLED_RESOURCES", concat( resourcesNeeded, ", " ) ) )
			end

				-- if we can't upgrade due to stacking
			if unitPlot:GetNumFriendlyUnitsOfType(unit) > 1 then

				insert( disabledTip, L"TXT_KEY_UPGRADE_HELP_DISABLED_STACKING" )

			end
		end
	end

	if action.Type == "MISSION_ALERT" and not unit:IsEverFortifyable() then

		insert( toolTip, L"TXT_KEY_MISSION_ALERT_NO_FORTIFY_HELP" )

	-- Golden Age has special help text
	elseif action.Type == "MISSION_GOLDEN_AGE" then

		insert( toolTip, L(  "TXT_KEY_MISSION_START_GOLDENAGE_HELP", unit:GetGoldenAgeTurns() ) )

	-- Spread Religion has special help text
	elseif gk_mode and action.Type == "MISSION_SPREAD_RELIGION" then

		local eMajorityReligion = unit:GetMajorityReligionAfterSpread()

		insert( toolTip, L"TXT_KEY_MISSION_SPREAD_RELIGION_HELP" )
		insert( toolTip, "----------------" )
		insert( toolTip, L("TXT_KEY_MISSION_SPREAD_RELIGION_RESULT", Game.GetReligionName(unit:GetReligion()), unit:GetNumFollowersAfterSpread() ) .. " " ..
				( eMajorityReligion < ReligionTypes.RELIGION_PANTHEON and L"TXT_KEY_MISSION_MAJORITY_RELIGION_NONE" or L("TXT_KEY_MISSION_MAJORITY_RELIGION", Game.GetReligionName(eMajorityReligion) ) ) )
	-- Create Great Work has special help text
	elseif bnw_mode and action.Type == "MISSION_CREATE_GREAT_WORK" then

		insert( toolTip, L"TXT_KEY_MISSION_CREATE_GREAT_WORK_HELP" )
		insert( toolTip, "----------------" )

		if gameCanHandleAction then
			local eGreatWorkSlotType = unit:GetGreatWorkSlotType()
			local iBuilding = g_activePlayer:GetBuildingOfClosestGreatWorkSlot(x, y, eGreatWorkSlotType)
			local pCity = g_activePlayer:GetCityOfClosestGreatWorkSlot(x, y, eGreatWorkSlotType)
			insert( toolTip, L( "TXT_KEY_MISSION_CREATE_GREAT_WORK_RESULT", GameInfo.Buildings[iBuilding].Description, pCity:GetNameKey() ) )
		end

	-- Paradrop
	elseif action.Type == "INTERFACEMODE_PARADROP" then
		insert( toolTip, L( "TXT_KEY_INTERFACEMODE_PARADROP_HELP_WITH_RANGE", unit:GetDropRange() ) )

	-- Sell Exotic Goods
	elseif bnw_mode and action.Type == "MISSION_SELL_EXOTIC_GOODS" then

		insert( toolTip, L"TXT_KEY_MISSION_SELL_EXOTIC_GOODS_HELP" )

		if gameCanHandleAction then
			insert( toolTip, "----------------" )
			insert( toolTip, "+" .. unit:GetExoticGoodsGoldAmount() .. "[ICON_GOLD]" )
			insert( toolTip, L( "TXT_KEY_EXPERIENCE_POPUP", unit:GetExoticGoodsXPAmount() ) )
		end

	-- Great Scientist
	elseif bnw_mode and action.Type == "MISSION_DISCOVER" then

		insert( toolTip, L"TXT_KEY_MISSION_DISCOVER_TECH_HELP" )

		if gameCanHandleAction then
			insert( toolTip, "----------------" )
			insert( toolTip, "+" .. unit:GetDiscoverAmount() .. "[ICON_RESEARCH]" )
		end

	-- Great Engineer
	elseif bnw_mode and action.Type == "MISSION_HURRY" then

		insert( toolTip, L"TXT_KEY_MISSION_HURRY_PRODUCTION_HELP" )

		if gameCanHandleAction then
			insert( toolTip, "----------------" )
			insert( toolTip, "+" .. unit:GetHurryProduction(unitPlot) .. "[ICON_PRODUCTION]" )
		end

	-- Great Merchant
	elseif bnw_mode and action.Type == "MISSION_TRADE" then

		insert( toolTip, L"TXT_KEY_MISSION_CONDUCT_TRADE_MISSION_HELP" )

		if gameCanHandleAction then
			insert( toolTip, "----------------" )
			insert( toolTip, "+" .. unit:GetTradeInfluence(unitPlot) .. "[ICON_INFLUENCE]" )
			insert( toolTip, "+" .. unit:GetTradeGold(unitPlot) .. "[ICON_GOLD]" )
		end

	-- Great Writer
	elseif bnw_mode and action.Type == "MISSION_GIVE_POLICIES" then

		insert( toolTip, L"TXT_KEY_MISSION_GIVE_POLICIES_HELP" )

		if gameCanHandleAction then
			insert( toolTip, "----------------" )
			insert( toolTip, "+" .. unit:GetGivePoliciesCulture() .. "[ICON_CULTURE]" )
		end

	-- Great Musician
	elseif bnw_mode and action.Type == "MISSION_ONE_SHOT_TOURISM" then

		insert( toolTip, L"TXT_KEY_MISSION_ONE_SHOT_TOURISM_HELP" )

		if gameCanHandleAction then
			insert( toolTip, "----------------" )
			insert( toolTip, "+" .. unit:GetBlastTourism() .. "[ICON_TOURISM]" )
		end

	-- Help text
	elseif action.Help and action.Help ~= "" then

		insert( toolTip, L(action.Help) )
	end

	-- Delete has special help text
	if action.Type == "COMMAND_DELETE" then

		insert( toolTip, L( "TXT_KEY_SCRAP_HELP", unit:GetScrapGold() ) )
	end

	-- Not able to perform action
	if not gameCanHandleAction then

		-- Worker build
		if isBuild then

			-- Figure out what the name of the thing is that we're looking at
			local strImpRouteKey = (improvement and improvement.Description) or (route and route.Description) or ""

			-- Don't have Tech for Build?
			if improvement or route then
				local prereqTech = GameInfo.Technologies[build.PrereqTech]
				if prereqTech and prereqTech.ID ~= -1 and not g_activeTechs:HasTech(prereqTech.ID) then

					insert( disabledTip, L( "TXT_KEY_BUILD_BLOCKED_PREREQ_TECH", prereqTech.Description, strImpRouteKey ) )
				end
			end

			-- Trying to build something and are not adjacent to our territory?
			if gk_mode and improvement and improvement.InAdjacentFriendly then
				if unitPlot:GetTeam() ~= unit:GetTeam() and not unitPlot:IsAdjacentTeam(unit:GetTeam(), true) then

					insert( disabledTip, L( "TXT_KEY_BUILD_BLOCKED_NOT_IN_ADJACENT_TERRITORY", strImpRouteKey ) )
				end

			-- Trying to build something in a City-State's territory?
			elseif bnw_mode and improvement and improvement.OnlyCityStateTerritory then
				if not unitPlot:IsOwned() or not Players[unitPlot:GetOwner()]:IsMinorCiv() then
					insert( disabledTip, L( "TXT_KEY_BUILD_BLOCKED_NOT_IN_CITY_STATE_TERRITORY", strImpRouteKey ) )
				end

			-- Trying to build something outside of our territory?
			elseif improvement and not improvement.OutsideBorders then
				if unitPlot:GetTeam() ~= unit:GetTeam() then
					insert( disabledTip, L( "TXT_KEY_BUILD_BLOCKED_OUTSIDE_TERRITORY", strImpRouteKey ) )
				end
			end

			-- Trying to build something that requires an adjacent luxury?
			if bnw_mode and improvement and improvement.AdjacentLuxury then
				local bAdjacentLuxury = false

				for _, direction in ipairs( g_directionTypes ) do
					local adjacentPlot = PlotDirection(x, y, direction)
					if adjacentPlot then
						local eResourceType = adjacentPlot:GetResourceType()
						if eResourceType ~= -1 then
							if Game.GetResourceUsageType(eResourceType) == ResourceUsageTypes.RESOURCEUSAGE_LUXURY then
								bAdjacentLuxury = true
								break
							end
						end
					end
				end

				if not bAdjacentLuxury then

					insert( disabledTip, L( "TXT_KEY_BUILD_BLOCKED_NO_ADJACENT_LUXURY", strImpRouteKey ) )
				end
			end

			-- Trying to build something where we can't have two adjacent?
			if bnw_mode and improvement and improvement.NoTwoAdjacent then
				local bTwoAdjacent = false

				for _, direction in ipairs( g_directionTypes ) do
					local adjacentPlot = PlotDirection(x, y, direction)
					if adjacentPlot then
						if adjacentPlot:GetImprovementType() == improvementID or adjacentPlot:GetBuildProgress(buildID) > 0 then
							bTwoAdjacent = true
							break
						end
					end
				end

				if bTwoAdjacent then
					insert( disabledTip, L( "TXT_KEY_BUILD_BLOCKED_CANNOT_BE_ADJACENT", strImpRouteKey ) )
				end
			end

			-- Build blocked by a feature here?
			if g_activePlayer:IsBuildBlockedByFeature(buildID, featureID) then

				for row in GameInfo.BuildFeatures{ BuildType = build.Type, FeatureType = feature.Type } do
					local pFeatureTech = GameInfo.Technologies[row.PrereqTech]
					insert( disabledTip, L( "TXT_KEY_BUILD_BLOCKED_BY_FEATURE", pFeatureTech.Description, feature.Description ) )
				end

			end

		-- Not a Worker build, use normal disabled help from XML
		else

			if action.Type == "MISSION_FOUND" and g_activePlayer:IsEmpireVeryUnhappy() then

				insert( disabledTip, L"TXT_KEY_MISSION_BUILD_CITY_DISABLED_UNHAPPY" )

			elseif action.Type == "MISSION_CULTURE_BOMB" and g_activePlayer:GetCultureBombTimer() > 0 then

				insert( disabledTip, L( "TXT_KEY_MISSION_CULTURE_BOMB_DISABLED_COOLDOWN", g_activePlayer:GetCultureBombTimer() ) )

			elseif action.DisabledHelp and action.DisabledHelp ~= "" then

				insert( disabledTip, L( action.DisabledHelp ) )
			end
		end

		if #disabledTip > 0 then
			insert( toolTip, "[COLOR_WARNING_TEXT]" .. concat( disabledTip, "[NEWLINE]" ) .. "[ENDCOLOR]" )
		end
	end

	-- Is this a Worker build?
	if isBuild then

		local turnsRemaining = getUnitBuildProgressData( unitPlot, buildID, unit )
		if turnsRemaining > 0 then
			strBuildTurnsString = " ... " .. L("TXT_KEY_STR_TURNS", turnsRemaining )
		end

		-- Extra Yield from this build

		for yieldID = 0, YieldTypes.NUM_YIELD_TYPES-1 do
			local yieldChange = unitPlot:GetYieldWithBuild( buildID, yieldID, false, g_activePlayerID ) - unitPlot:CalculateYield(yieldID)

			if yieldChange > 0 then
				insert( toolTip, "[COLOR_POSITIVE_TEXT]+" .. L( g_yieldString[yieldID], yieldChange) )
			elseif  yieldChange < 0 then
				insert( toolTip, "[COLOR_NEGATIVE_TEXT]" .. L( g_yieldString[yieldID], yieldChange) )
			end
		end

		-- Resource connection
		if improvement then
			local resourceID = unitPlot:GetResourceType(g_activeTeamID)
			local resource = GameInfo.Resources[resourceID]
			if resource
				and unitPlot:IsResourceConnectedByImprovement(improvementID)
				and Game.GetResourceUsageType(resourceID) ~= ResourceUsageTypes.RESOURCEUSAGE_BONUS
			then
				insert( toolTip, L( "TXT_KEY_BUILD_CONNECTS_RESOURCE", resource.IconString, resource.Description ) )
			end
		end

		-- Production for clearing a feature
		if feature and unitPlot:IsBuildRemovesFeature(buildID) then
			local tip = L( "TXT_KEY_BUILD_FEATURE_CLEARED", feature.Description )
			local featureProduction = unitPlot:GetFeatureProduction( buildID, g_activeTeamID )
			if featureProduction > 0 then
				tip = tip .. L( "TXT_KEY_BUILD_FEATURE_PRODUCTION", featureProduction )
				local city = unitPlot:GetWorkingCity()
				if city then
					tip = tip .. " (".. city:GetName()..")"
				end
			end
			insert( toolTip, tip )
		end
	end

	-- Tooltip
	tipControlTable.UnitActionHelp:SetText( concat( toolTip, "[NEWLINE]" ) )

	-- Title
	tipControlTable.UnitActionText:SetText( "[COLOR_POSITIVE_TEXT]" .. L( tostring( action.TextKey or action.Type ) ) .. "[ENDCOLOR]".. strBuildTurnsString )

	-- HotKey
	if action.SubType == ActionSubTypes.ACTIONSUBTYPE_PROMOTION then
		tipControlTable.UnitActionHotKey:SetText()
	elseif action.HotKey and action.HotKey ~= "" then
		tipControlTable.UnitActionHotKey:SetText( "("..tostring(action.HotKey)..")" )
	else
		tipControlTable.UnitActionHotKey:SetText()
	end

	-- Autosize tooltip
	tipControlTable.UnitActionMouseover:DoAutoSize()
	local mouseoverSizeX = tipControlTable.UnitActionMouseover:GetSizeX()
	if mouseoverSizeX < 350 then
		tipControlTable.UnitActionMouseover:SetSizeX( 350 )
	end

end
--[[
g_existingBuild.UnitActionButton:SetToolTipCallback(
function()-- control )
	local unit = GetHeadSelectedUnit()
	if unit then
		local unitPlot = unit:GetPlot()
		local improvementID = unitPlot:GetImprovementType()
		local improvement = GameInfo.Improvements[ improvementID ]
		local build = improvement and GameInfo_Builds{ ImprovementType = improvement.Type }()
		if build then
			-- Icon
			IconHookup( build.IconIndex, 64, build.IconAtlas, tipControlTable.UnitActionIcon )
			-- Title
			tipControlTable.UnitActionText:SetText( "[COLOR_POSITIVE_TEXT]" .. L( improvement.Description ) .. "[ENDCOLOR]" )
			-- no HotKey
			tipControlTable.UnitActionHotKey:SetText()
			-- Yield from this improvement
			local toolTip = {}
			for yieldID = 0, YieldTypes.NUM_YIELD_TYPES-1 do
				local yieldChange = unitPlot:CalculateImprovementYieldChange( improvementID, yieldID, unitPlot:GetOwner() )
				--unitPlot:CalculateYield( yieldID ) - unitPlot:CalculateNatureYield( yieldID, g_activeTeamID )

				if yieldChange > 0 then
					insert( toolTip, "[COLOR_POSITIVE_TEXT]+" .. L( g_yieldString[yieldID], yieldChange) )
				elseif  yieldChange < 0 then
					insert( toolTip, "[COLOR_NEGATIVE_TEXT]" .. L( g_yieldString[yieldID], yieldChange) )
				end
			end
			tipControlTable.UnitActionHelp:SetText( concat( toolTip, "[NEWLINE]" ) )
			-- Autosize tooltip
			tipControlTable.UnitActionMouseover:DoAutoSize()
			return
		end
	end
	tipControlTable.UnitActionMouseover:SetHide( true )
end)
--]]

--[[----------------------------------------------------
 ___       _ _   _       _ _          _   _             
|_ _|_ __ (_) |_(_) __ _| (_)______ _| |_(_) ___  _ __  
 | || '_ \| | __| |/ _` | | |_  / _` | __| |/ _ \| '_ \ 
 | || | | | | |_| | (_| | | |/ / (_| | |_| | (_) | | | |
|___|_| |_|_|\__|_|\__,_|_|_/___\__,_|\__|_|\___/|_| |_|
]]------------------------------------------------------

local g_unitUpdateRequired, g_cityUpdateRequired
local IsProcessingDone = true
LuaEvents.EUI_UpdateUnitCityRibbons.Add( function()

--print("EUI_UpdateUnitCityRibbons", "Unit Update Required", g_unitUpdateRequired, "City Update Required", g_cityUpdateRequired )
	-- update all ribbon units
	if g_unitUpdateRequired then
		g_unitUpdateRequired = false
--print("UpdateUnitList")
		g_unitsIM.Update()
--print("UpdateUnitListDone")
	end
	-- update cities
	if g_cityUpdateRequired then
		g_citiesIM.Update( g_cityUpdateRequired ~= true and g_cityUpdateRequired )
		g_cityUpdateRequired = false
	end

--print("UpdateStacks")
	local maxTotalStackHeight = g_screenHeight - g_topOffset - g_bottomOffset
	local halfTotalStackHeight = floor(maxTotalStackHeight / 2)

	Controls.CityStack:CalculateSize()
	local cityStackHeight = Controls.CityStack:GetSizeY()
	Controls.UnitStack:CalculateSize()
	local unitStackHeight = Controls.UnitStack:GetSizeY()

	if unitStackHeight + cityStackHeight <= maxTotalStackHeight then
		unitStackHeight = false
		halfTotalStackHeight = false
	elseif cityStackHeight <= halfTotalStackHeight then
		unitStackHeight = maxTotalStackHeight - cityStackHeight
		halfTotalStackHeight = false
	elseif unitStackHeight <= halfTotalStackHeight then
		cityStackHeight = maxTotalStackHeight - unitStackHeight
		unitStackHeight = false
	else
		cityStackHeight = halfTotalStackHeight
		unitStackHeight = halfTotalStackHeight
	end

	Controls.CityScrollPanel:SetHide( not halfTotalStackHeight )
	if halfTotalStackHeight then
		Controls.CityStack:ChangeParent( Controls.CityScrollPanel )
		Controls.CityScrollPanel:SetSizeY( cityStackHeight )
		Controls.CityScrollPanel:CalculateInternalSize()
	else
		Controls.CityStack:ChangeParent( Controls.CityPanel )
	end
	Controls.CityPanel:ReprocessAnchoring()
--	Controls.CityPanel:SetSizeY( cityStackHeight )

	Controls.UnitScrollPanel:SetHide( not unitStackHeight )
	if unitStackHeight then
		Controls.UnitStack:ChangeParent( Controls.UnitScrollPanel )
		Controls.UnitScrollPanel:SetSizeY( unitStackHeight )
		Controls.UnitScrollPanel:CalculateInternalSize()
	else
		Controls.UnitStack:ChangeParent( Controls.UnitPanel )
	end
	Controls.UnitPanel:ReprocessAnchoring()
	IsProcessingDone = true
end)

local UpdateDisplayEvent = LuaEvents.EUI_UpdateUnitCityRibbons.Call
local function UpdateDisplay()
	if IsProcessingDone then
		IsProcessingDone = false
		UpdateDisplayEvent()
	end
end

local function UpdateUnits()
	g_unitUpdateRequired = true
	return UpdateDisplay()
end

local function UpdateCities()
	g_cityUpdateRequired = true
	return UpdateDisplay()
end

local function UpdateSpecificCity( playerID, cityID )
	if playerID == g_activePlayerID then
		if g_cityUpdateRequired == false then
			g_cityUpdateRequired = cityID
			return UpdateDisplay()
		elseif g_cityUpdateRequired ~= cityID then
			return UpdateCities()
		end
	end
end

local function SelectUnitType( isChecked, unitTypeID ) -- Void2, control )
	g_ActivePlayerUnitsInRibbon[ unitTypeID ] = isChecked
	g_unitsIM.Initialize( g_isHideUnitList )
	UpdateUnits()
	-- only save player 0 preferences, not other hotseat player's
	if g_activePlayerID == 0 then
		EUI_options.SetValue( "RIBBON_"..GameInfo_Units[ unitTypeID ].Type, isChecked and 1 or 0 )
	end
end
local function ResizeUnitTypesPanel()
--		if not g_isHideUnitTypes then
	local n = Controls.UnitTypesStack:GetNumChildren()
	Controls.UnitTypesStack:SetWrapWidth( ceil( n / ceil( n / 5 ) ) * 64 )
	Controls.UnitTypesStack:CalculateSize()
	local x, y = Controls.UnitTypesStack:GetSizeVal()
	if y<64 then y=64 elseif y>320 then y=320 end
	Controls.UnitTypesPanel:SetSizeVal( x+40, y+85 )
	Controls.UnitTypesScrollPanel:SetSizeVal( x, y )
	Controls.UnitTypesScrollPanel:CalculateInternalSize()
	Controls.UnitTypesScrollPanel:ReprocessAnchoring()
end
local function AddUnitType( unit, flag )
	local unitTypeID = unit:GetUnitType()
	g_ActivePlayerUnitTypes[ flag or unit:GetID() ] = unitTypeID
	local instance = g_unitTypes[ unitTypeID ]
	if instance then
--print( "Add unit:", unit:GetID(), unit:GetName(), "type:", instance, unitTypeID, "count:", n )
		return instance.Count:SetText( instance.Count:GetText()+1 )
	else
--print( "Add unit:", unit:GetID(), unit:GetName(), "new type:", unitTypeID )
		g_unitTypesIM.Create( unit, unitTypeID, -g_UnitTypeOrder[unitTypeID] )
		if flag then
			Controls.UnitTypesStack:SortChildren( SortByVoid2 )
			return ResizeUnitTypesPanel()
		end
	end
end
-------------------------------------------------
-- Unit Options "Object"
-------------------------------------------------
g_unitTypesIM, g_unitTypes = g_RibbonManager( "UnitTypeInstance", Controls.UnitTypesStack, Controls.Scrap,
	function() -- createAllItems
		g_ActivePlayerUnitTypes = {}
		for unit in g_activePlayer:Units() do
			AddUnitType( unit )
		end
		Controls.UnitTypesStack:SortChildren( SortByVoid2 )
		return ResizeUnitTypesPanel()
	end,
	function( unit, instance ) -- initItem( item, instance )
		local portrait, portraitOffset, portraitAtlas = instance.Portrait, GetUnitPortraitIcon( unit )
		portrait:SetHide(not ( portraitOffset and portraitAtlas and IconHookup( portraitOffset, portrait:GetSizeX(), portraitAtlas, portrait ) ) )
		instance.CheckBox:RegisterCheckHandler( SelectUnitType )
		local unitTypeID = unit:GetUnitType()
		instance.CheckBox:SetCheck( g_ActivePlayerUnitsInRibbon[ unitTypeID ] )
		instance.CheckBox:SetVoid1( unitTypeID )
		instance.Count:SetText("1")
	end,
	function() end, -- updateItem( itemID, instance )
-------------------------------------------------------------------------------------------------
{-- the callback function table names need to match associated instance control ID defined in xml
	Button = {
		[Mouse.eRClick] = function( unitTypeID )
			local unit = GameInfo.Units[ unitTypeID ]
			if unit then
				Events.SearchForPediaEntry( unit.Description )
			end
		end,
	},--/Button
},--/unit options callbacks
-------------------------------------------------------------------------------------------------
{-- the tooltip function names need to match associated instance control ID defined in xml
	Button = function( itemID )
		local portraitOffset, portraitAtlas = GetUnitPortraitIcon( itemID, g_activePlayerID )
		g_tipControls.PortraitFrame:SetHide( not IconHookup( portraitOffset, g_tipControls.Portrait:GetSizeY(), portraitAtlas, g_tipControls.Portrait ) )
		local instance = g_unitTypes[ itemID ]
		g_tipControls.Text:SetText( instance.Count:GetText().." "..GetHelpTextForUnit( itemID, true ) )
		g_tipControls.Box:DoAutoSize()
	end,
},--/units options tooltips
function( button )
	return button:GetVoid1()
end
)--/unit options object

local function CreateUnit( playerID, unitID ) --hexVec, unitType, cultureType, civID, primaryColor, secondaryColor, unitFlagIndex, fogState, selected, military, notInvisible )
	if playerID == g_activePlayerID then
		local unit = g_activePlayer:GetUnitByID( unitID )
--print("Create unit", unitID, unit and unit:GetName() )
		if unit then
			AddUnitType( unit, unitID )
			if FilterUnit( unit ) then
				g_unitsIM.Create( unit, unitID, g_UnitTypeOrder[unit:GetUnitType()] + unitID / 65536 )
				Controls.UnitStack:SortChildren( SortByVoid2 )
--				UpdateStacks()
--				return UpdateUnits()
			end
		end
	end
end

local function CreateCity( hexPos, playerID, cityID ) --, cultureType, eraType, continent, populationSize, size, fowState )
	if playerID == g_activePlayerID then
		g_citiesIM.Create( g_activePlayer:GetCityByID( cityID ), cityID )
		return UpdateSpecificCity( playerID, cityID )
	end
end

local function DestroyUnit( playerID, unitID )
	if playerID == g_activePlayerID then
		g_unitsIM.Destroy( unitID )
		local unitTypeID = g_ActivePlayerUnitTypes[ unitID ]
		local instance = g_unitTypes[ unitTypeID ]
--print( "Destroy unit", unitID, "type:", g_ActivePlayerUnitTypes[ unitID ], instance, "previous count:", instance.Count )
		g_ActivePlayerUnitTypes[ unitID ] = nil
		if instance then
			local n = instance.Count:GetText() - 1
			if n <= 0 then
				g_unitTypesIM.Destroy( unitTypeID )
				ResizeUnitTypesPanel()
			else
				instance.Count:SetText( n )
			end
		end
--		return UpdateUnits()
	end
end

local function DestroyCity( hexPos, playerID, cityID )
	if playerID == g_activePlayerID then
		g_citiesIM.Destroy( cityID )
--		return UpdateCities()
	end
end

local function UpdateOptions()

	local flag = EUI_options.GetValue( "UnitRibbon" ) == 0
	local AddOrRemove = flag and "Remove" or "Add"
	if g_isHideUnitList ~= flag then
		g_isHideUnitList = flag
		Events.SerialEventUnitCreated[ AddOrRemove ]( CreateUnit )
		Events.SerialEventUnitDestroyed[ AddOrRemove ]( DestroyUnit )
		Events.ActivePlayerTurnStart[ AddOrRemove ]( g_unitsIM.Update )
	end
	g_unitUpdateRequired = true
	g_unitsIM.Initialize( g_isHideUnitList )
	Controls.UnitPanel:SetHide( g_isHideUnitList )

	flag = EUI_options.GetValue( "CityRibbon" ) == 0
	if g_isHideCityList ~= flag then
		g_isHideCityList = flag
		Events.SerialEventCityCreated[ AddOrRemove ]( CreateCity )
		Events.SerialEventCityDestroyed[ AddOrRemove ]( DestroyCity )
		Events.SerialEventCityCaptured[ AddOrRemove ]( DestroyCity )
		Events.SerialEventCityInfoDirty[ AddOrRemove ]( UpdateCities )
		Events.SerialEventCitySetDamage[ AddOrRemove ]( UpdateSpecificCity )
		Events.SpecificCityInfoDirty[ AddOrRemove ]( UpdateSpecificCity )
	end
	g_cityUpdateRequired = not flag
	g_citiesIM.Initialize( g_isHideCityList )
	Controls.CityPanel:SetHide( g_isHideCityList )

	flag = EUI_options.GetValue( "HideUnitTypes" ) == 1
	if g_isHideUnitTypes ~= flag then
		g_unitTypesIM.Initialize( flag )
		ResizeUnitTypesPanel()
		g_isHideUnitTypes = flag
		Controls.UnitTypesOpen:SetHide( not flag )
		Controls.UnitTypesClose:SetHide( flag )
	end
	Controls.UnitTypesPanel:SetHide( g_isHideUnitList or g_isHideUnitTypes )
	UpdateCities()
	UpdateUnits()
end

Controls.UnitTypesButton:RegisterCallback( Mouse.eLClick,
function()
	EUI_options.SetValue( "HideUnitTypes", g_isHideUnitTypes and 0 or 1 )
	return UpdateOptions()
end)

local function SetActivePlayer()-- activePlayerID, prevActivePlayerID )
	-- initialize globals
	if g_activePlayerID then
		g_AllPlayerOptions.UnitTypes[ g_activePlayerID ] = g_ActivePlayerUnitTypes
		g_AllPlayerOptions.UnitsInRibbon[ g_activePlayerID ] = g_ActivePlayerUnitsInRibbon
	end
	g_activePlayerID = Game.GetActivePlayer()
	g_activePlayer = Players[ g_activePlayerID ]
	g_activeTeamID = g_activePlayer:GetTeam()
	g_activeTeam = Teams[ g_activeTeamID ]
	g_activeTechs = g_activeTeam:GetTeamTechs()
	g_ActivePlayerUnitTypes = g_AllPlayerOptions.UnitTypes[ g_activePlayerID ] or {}
	g_ActivePlayerUnitsInRibbon = g_AllPlayerOptions.UnitsInRibbon[ g_activePlayerID ]
	if not g_ActivePlayerUnitsInRibbon then
		g_ActivePlayerUnitsInRibbon = {}
		for row in GameInfo.Units() do
			g_ActivePlayerUnitsInRibbon[ row.ID ] = EUI_options.GetValue( "RIBBON_"..row.Type ) ~= 0
		end
	end

	-- set civilization icon and color
	local civInfo = GameInfo.Civilizations[ g_activePlayer:GetCivilizationType() ] or {}
	IconHookup( civInfo.PortraitIndex, 128, civInfo.IconAtlas, Controls.BackgroundCivSymbol )
	Controls.UnitIcon:SetColor( PrimaryColors[ g_activePlayerID ] )
	Controls.UnitIconBackground:SetColor( BackgroundColors[ g_activePlayerID ] )

	return UpdateOptions()
end

SetActivePlayer()
Events.GameplaySetActivePlayer.Add( SetActivePlayer )
Events.GameOptionsChanged.Add( UpdateOptions )

local function SetHide( ... )
	for _, control in pairs{...} do
		control:SetHide( true )
	end
end

local function SetShow( ... )
	for _, control in pairs{...} do
		control:SetHide( false )
	end
end

local function SetTextBounded( control, text, x )
	control:SetText( text )
	for i = 24, 14, -2 do
		control:SetFontByName( "TwCenMT"..i )
		if control:GetSizeVal() <= x then
			break
		end
	end
end

local function DeselectLastUnit()
	Events.UnitSelectionChanged( g_activePlayerID, g_lastUnitID, 0, 0, 0, false, false )
	local lastUnit = g_activePlayer:GetUnitByID( g_lastUnitID )
	if lastUnit then
		local instance = g_units[ g_lastUnitID ]
		if instance then
			instance.MovementPip:SetToBeginning()
			return UpdateUnit( lastUnit, instance )
		end
	end
end

Events.SerialEventEnterCityScreen.Add(
function()
	if g_lastUnitID then
		DeselectLastUnit()
		g_lastUnitID = nil
--		return UpdateDisplay()
	end
end)

local g_infoSource = {
		[ ActionSubTypes.ACTIONSUBTYPE_PROMOTION or -1 ] = GameInfo.UnitPromotions,
		[ ActionSubTypes.ACTIONSUBTYPE_INTERFACEMODE or -1 ] = GameInfo.InterfaceModes,
		[ ActionSubTypes.ACTIONSUBTYPE_MISSION or -1 ] = GameInfo.Missions,
		[ ActionSubTypes.ACTIONSUBTYPE_COMMAND or -1 ] = GameInfo.Commands,
		[ ActionSubTypes.ACTIONSUBTYPE_AUTOMATE or -1 ] = GameInfo.Automates,
		[ ActionSubTypes.ACTIONSUBTYPE_BUILD or -1 ] = GameInfo.Builds,
		[ ActionSubTypes.ACTIONSUBTYPE_CONTROL or -1 ] = GameInfo.Controls,
		[-1] = nil
}

Events.SerialEventUnitInfoDirty.Add( function()
	-- Retrieve the currently selected unit.
	local unit = GetHeadSelectedUnit()
	local unitID
-- Events.GameplayAlertMessage( "SerialEventUnitInfoDirty ".. tostring(unit and unit:GetName()).."-"..tostring(g_lastUnitID) )
	if unit then
		unitID = unit:GetID()
		local unitMovesLeft = unit:MovesLeft() / g_moveDenominator
		local unitPlot = unit:GetPlot()

		-- Selected Unit
		if unitID ~= g_lastUnitID then
			if g_lastUnitID then
				DeselectLastUnit()
			end
			g_lastUnitID = unitID
			local hexPosition = ToHexFromGrid{ x = unit:GetX(), y = unit:GetY() }
			Events.UnitSelectionChanged( g_activePlayerID, unitID, hexPosition.x, hexPosition.y, 0, true, false )
		end

		-- Unit Name
		SetTextBounded( Controls.UnitName, ToUpper( L( unit:IsGreatPerson() and unit:HasName() and unit:GetNameNoDesc() or unit:GetName() ) ), Controls.UnitNameButton:GetSizeVal()-50 )

		-- Unit Actions
		local canPromote = unit:IsPromotionReady()
		local canBuild, isBuildRecommended
		local GameCanHandleAction = Game.CanHandleAction

		local numBuildActions = 0
		local action
		local button, buildTurnsLeft, buildProgress, buildTime
		for actionID = 0, #GameInfoActions do
			action = GameInfoActions[ actionID ]
			if action and action.Visible ~= false then
				local instance = g_Actions[ actionID ]
				if GameCanHandleAction( actionID, unitPlot, true ) then
					if not instance then
						instance = {}
						instance.isBuild = action.SubType == ActionSubTypes.ACTIONSUBTYPE_BUILD
						instance.isBuildType = instance.isBuild or action.Type == "INTERFACEMODE_ROUTE_TO" or action.Type == "AUTOMATE_BUILD"
						instance.isPromotion = action.SubType == ActionSubTypes.ACTIONSUBTYPE_PROMOTION
						instance.isException = instance.isPromotion or action.Type == "COMMAND_CANCEL" or action.Type == "COMMAND_STOP_AUTOMATION"
						instance.recommendation = (bnw_mode and (L"TXT_KEY_UPANEL_RECOMMENDED" .. "[NEWLINE]") or "") .. L( tostring( action.TextKey or action.Type ) )
						if action.Type == "MISSION_FOUND" then
							instance.UnitActionButton = Controls.BuildCityButton
						else
							ContextPtr:BuildInstanceForControl( "UnitAction", instance, g_UnusedControls )
							instance.WorkerProgressBar:SetHide( not instance.isBuild )
							local info = ( g_infoSource[ action.SubType ] or {} )[ action.Type ]
							if info then
								instance.IconIndex = info.IconIndex or info.PortraitIndex
								instance.IconAtlas = info.IconAtlas
								IconHookup( instance.IconIndex, instance.UnitActionIcon:GetSizeX(), instance.IconAtlas, instance.UnitActionIcon )
							end
						end
						instance.UnitActionButton:RegisterCallback( Mouse.eLClick, OnUnitActionClicked )
						instance.UnitActionButton:SetVoid1( actionID )
						instance.UnitActionButton:SetToolTipCallback( ActionToolTipHandler )
						instance.ID = actionID
						g_Actions[ actionID ] = instance
					end
					if instance then
						button = instance.UnitActionButton
						if unitMovesLeft > 0 or instance.isException then
							if instance.isPromotion then
								numBuildActions = numBuildActions + 1
								button:ChangeParent( Controls.WorkerActionStack )

							elseif instance.isBuildType and not canPromote then
								numBuildActions = numBuildActions + 1
								if unitMovesLeft > 0 and not isBuildRecommended and unit:IsActionRecommended( actionID ) then
									isBuildRecommended = true
									button:ChangeParent( Controls.RecommendedActionIcon )
									Controls.RecommendedActionLabel:SetText( instance.recommendation )
								else
									button:ChangeParent( Controls.WorkerActionStack )
								end
								if instance.isBuild then
									canBuild = true
									buildTurnsLeft, buildProgress, buildTime = getUnitBuildProgressData( unitPlot, action.MissionData, unit )
									instance.WorkerProgressBar:SetPercent( buildProgress / buildTime )
									instance.UnitActionText:SetText( buildTurnsLeft > 0 and buildTurnsLeft or nil )
								end
							else
								button:ChangeParent( Controls.ActionStack )
							end
							-- test w/o visible flag (ie can train right now)
							if GameCanHandleAction( actionID, unitPlot, false ) then
								button:SetAlpha( 1.0 )
								button:SetDisabled( false )
							else
								button:SetAlpha( 0.6 )
								button:SetDisabled( true )
							end
							instance.isVisible = true
						elseif instance.isVisible then
							button:ChangeParent( g_UnusedControls )
							instance.isVisible = false
						end
					end
				elseif instance and instance.isVisible then
					instance.UnitActionButton:ChangeParent( g_UnusedControls )
					instance.isVisible = false
				end
			end -- action.Visible
		end -- GameInfoActions loop

		if numBuildActions > 0 or canPromote then
			Controls.WorkerActionPanel:SetHide( false )
			g_isWorkerActionPanelOpen = true
			Controls.RecommendedAction:SetHide( not isBuildRecommended )
--[[
			local improvement = canBuild and not canPromote and GameInfo.Improvements[ unitPlot:GetImprovementType() ]
			local build = improvement and GameInfo_Builds{ ImprovementType = improvement.Type }()
			if build then
				numBuildActions = numBuildActions + 1
				IconHookup( build.IconIndex, g_actionIconSize, build.IconAtlas, g_existingBuild.UnitActionIcon )
			end
			g_existingBuild.UnitActionButton:SetHide( not build )
--]]
			Controls.WorkerText:SetHide( canPromote )
			Controls.PromotionText:SetHide( not canPromote )
			Controls.PromotionAnimation:SetHide( not canPromote )
			Controls.EditButton:SetHide( not canPromote )
			Controls.WorkerActionStack:SetWrapWidth( isBuildRecommended and 232 or ceil( numBuildActions / ceil( numBuildActions / 5 ) ) * g_actionButtonSpacing )
			Controls.WorkerActionStack:CalculateSize()
			local x, y = Controls.WorkerActionStack:GetSizeVal()
			Controls.WorkerActionPanel:SetSizeVal( max( x, 200 ) + 50, y + 96 )
			Controls.WorkerActionStack:ReprocessAnchoring()
		else
			Controls.WorkerActionPanel:SetHide( true )
			g_isWorkerActionPanelOpen = false
		end

		-- Unit XP
		if unit:IsCombatUnit() or unit:GetDomainType() == DomainTypes.DOMAIN_AIR then
			local iLevel = unit:GetLevel()
			local iExperience = unit:GetExperience()
			local iExperienceNeeded = unit:ExperienceNeeded()
			Controls.XPMeter:LocalizeAndSetToolTip( "TXT_KEY_UNIT_EXPERIENCE_INFO", iLevel, iExperience, iExperienceNeeded )
			Controls.XPMeter:SetPercent( iExperience / iExperienceNeeded )
			Controls.XPFrame:SetHide( false )
		else
			Controls.XPFrame:SetHide( true )
		end

		-- Unit Flag
		local flagOffset, flagAtlas = UI.GetUnitFlagIcon( unit )
		IconHookup( flagOffset, 32, flagAtlas, Controls.UnitIcon )
		IconHookup( flagOffset, 32, flagAtlas, Controls.UnitIconShadow )

		-- Unit Portrait
		local portraitOffset, portraitAtlas = GetUnitPortraitIcon( unit )
		IconHookup( portraitOffset, g_unitPortraitSize, portraitAtlas, Controls.UnitPortrait )

		-- Unit Promotions
		for promotion in GameInfo.UnitPromotions() do
			if promotion.ShowInUnitPanel ~= false then
				local instance = g_Promotions[promotion.ID]
				if unit:IsHasPromotion(promotion.ID) then
					if instance then
						instance.EarnedPromotion:ChangeParent( Controls.EarnedPromotionStack )
					else
						instance = {}
						ContextPtr:BuildInstanceForControl( "EarnedPromotionInstance", instance, Controls.EarnedPromotionStack )
						IconHookup( promotion.PortraitIndex, 32, promotion.IconAtlas, instance.UnitPromotionImage )
						instance.EarnedPromotion:SetToolTipString( L(promotion.Description) .. "[NEWLINE][NEWLINE]" .. L(promotion.Help) )
						g_Promotions[ promotion.ID ] = instance
					end
					instance.isVisible = true
				elseif instance and instance.isVisible then
					instance.EarnedPromotion:ChangeParent( g_UnusedControls )
					instance.isVisible = false
				end
			end
		end

		-- Unit Movement
		if unit:GetDomainType() == DomainTypes.DOMAIN_AIR then
			local unitRange = unit:Range()
			Controls.UnitStatMovement:SetText( unitRange .. "[ICON_MOVES]" )
			Controls.UnitStatMovement:LocalizeAndSetToolTip( "TXT_KEY_UPANEL_UNIT_MAY_STRIKE_REBASE", unitRange, unitRange * g_rebaseRangeMultipler / 100 )
		else
			local text = format(" %.3g/%g[ICON_MOVES]", unitMovesLeft, unit:MaxMoves() / g_moveDenominator )
			Controls.UnitStatMovement:SetText( text )
			Controls.UnitStatMovement:LocalizeAndSetToolTip( "TXT_KEY_UPANEL_UNIT_MAY_MOVE", text )
		end

		-- Unit Strength
		local strength = ( unit:GetDomainType() == DomainTypes.DOMAIN_AIR and unit:GetBaseRangedCombatStrength() )
						or ( not unit:IsEmbarked() and unit:GetBaseCombatStrength() ) or 0
		if strength > 0 then
			Controls.UnitStatStrength:SetText( strength .. "[ICON_STRENGTH]" )
			Controls.UnitStatStrength:LocalizeAndSetToolTip( "TXT_KEY_UPANEL_STRENGTH_TT" )
		elseif gk_mode and unit:GetSpreadsLeft() > 0 then
			-- Religious units
			Controls.UnitStatStrength:SetText( floor(unit:GetConversionStrength()/g_pressureMultiplier) .. "[ICON_PEACE]" )
			Controls.UnitStatStrength:LocalizeAndSetToolTip( "TXT_KEY_UPANEL_RELIGIOUS_STRENGTH_TT" )
		elseif bnw_mode and unit:GetTourismBlastStrength() > 0 then
			Controls.UnitStatStrength:SetText( unit:GetTourismBlastStrength() .. "[ICON_TOURISM]" )
			Controls.UnitStatStrength:LocalizeAndSetToolTip( "TXT_KEY_UPANEL_TOURISM_STRENGTH_TT" )
		else
			Controls.UnitStatStrength:SetText()
		end

		-- Ranged Strength
		local rangedStrength = unit:GetDomainType() ~= DomainTypes.DOMAIN_AIR and unit:GetBaseRangedCombatStrength() or 0
		if rangedStrength > 0 then
			Controls.UnitStatRangedAttack:SetText( rangedStrength .. "[ICON_RANGE_STRENGTH]" .. unit:Range() )
			Controls.UnitStatRangedAttack:LocalizeAndSetToolTip( "TXT_KEY_UPANEL_RANGED_ATTACK_TT" )
		elseif gk_mode and unit:GetSpreadsLeft() > 0 then
			-- Religious units
			local unitReligion = unit:GetReligion()
			local icon = (GameInfo.Religions[unitReligion] or {}).IconString
			Controls.UnitStatRangedAttack:SetText( icon and (unit:GetSpreadsLeft()..icon) )
			Controls.UnitStatRangedAttack:SetToolTipString( L(Game.GetReligionName(unitReligion))..": "..L"TXT_KEY_UPANEL_SPREAD_RELIGION_USES_TT" )
--		elseif gk_mode and GameInfo_Units[unit:GetUnitType()].RemoveHeresy then
--			Controls.UnitStatRangedAttack:LocalizeAndSetText( "TXT_KEY_UPANEL_REMOVE_HERESY_USES" )
--			Controls.UnitStatRangedAttack:LocalizeAndSetToolTip( "TXT_KEY_UPANEL_REMOVE_HERESY_USES_TT" )
		elseif bnw_mode and unit:CargoSpace() > 0 then
			Controls.UnitStatRangedAttack:SetText( L"TXT_KEY_UPANEL_CARGO_CAPACITY" .. " " .. unit:CargoSpace() )
			Controls.UnitStatRangedAttack:LocalizeAndSetToolTip( "TXT_KEY_UPANEL_CARGO_CAPACITY_TT", unit:GetName() )
		else
			Controls.UnitStatRangedAttack:SetText()
		end
		Controls.UnitStats:CalculateSize()
		Controls.UnitStats:ReprocessAnchoring()

		-- Unit Health Bar
		local damage = unit:GetDamage()
		if damage ~= 0 then
			local healthPercent = 1.0 - (damage / g_MaxDamage)
			local barSize = 123 * healthPercent
			if healthPercent <= .33 then
				Controls.RedBar:SetSizeY(barSize)
				Controls.RedAnim:SetSizeY(barSize)
				Controls.GreenBar:SetHide(true)
				Controls.YellowBar:SetHide(true)
				Controls.RedBar:SetHide(false)
			elseif healthPercent <= .66 then
				Controls.YellowBar:SetSizeY(barSize)
				Controls.GreenBar:SetHide(true)
				Controls.YellowBar:SetHide(false)
				Controls.RedBar:SetHide(true)
			else
				Controls.GreenBar:SetSizeY(barSize)
				Controls.GreenBar:SetHide(false)
				Controls.YellowBar:SetHide(true)
				Controls.RedBar:SetHide(true)
			end
			Controls.HealthBar:LocalizeAndSetToolTip( "TXT_KEY_UPANEL_SET_HITPOINTS_TT", g_MaxDamage-damage, g_MaxDamage )
			Controls.HealthBar:SetHide(false)
		else
			Controls.HealthBar:SetHide(true)
		end

		-- Unit Stats
		UpdateUnit( unit, Controls, unitID )
		local instance = g_units[ unitID ]
		if instance then
			UpdateUnit( unit, instance )
			instance.MovementPip:Play()
		end
		Controls.UnitStatBox:SetHide( bnw_mode and unit:IsTrade() )

		-- These controls need to be shown since potentially hidden depending on previous selection
		SetShow( Controls.EarnedPromotionStack, Controls.UnitTypeFrame, Controls.CycleLeft, Controls.CycleRight, Controls.ActionStack )
		Controls.ActionStack:CalculateSize()
		Controls.ActionStack:ReprocessAnchoring()

	else
		-- Deselect last unit, if any
		if g_lastUnitID then
			DeselectLastUnit()
			g_lastUnitID = nil
		end
		-- Attempt to show currently selected city
		unit = UI.GetHeadSelectedCity()
		if unit then
			-- City Name
			SetTextBounded( Controls.UnitName, ToUpper( L(unit:GetName()) ), Controls.UnitNameButton:GetSizeVal()-50 )

			-- City Portrait
			IconHookup( 0, g_unitPortraitSize, "CITY_ATLAS", Controls.UnitPortrait )

			-- Hide various aspects of Unit Panel since they don't apply to the city.
			SetHide( Controls.EarnedPromotionStack, Controls.UnitTypeFrame, Controls.CycleLeft, Controls.CycleRight, Controls.XPFrame, Controls.UnitStatBox, Controls.WorkerActionPanel, Controls.ActionStack )
			g_isWorkerActionPanelOpen = false
		end
	end
	if unit then
		g_bottomOffset = g_bottomOffset0
		Controls.UnitTypesPanel:SetOffsetVal( g_unitPortraitSize * 0.625, 120 )
	else
		g_bottomOffset = 35
		Controls.UnitTypesPanel:SetOffsetVal( 80, -40 )
	end
	Controls.Panel:SetHide( not unit )
	Controls.Actions:SetHide( not unit )
	Controls.UnitPanel:SetOffsetY( g_bottomOffset )
end)

local g_infoCornerYmax = {
[InfoCornerID.None or -1] = g_topOffset0,
[InfoCornerID.Tech or -1] = OptionsManager.GetSmallUIAssets() and 150 or 225,
[-1] = nil }

Events.OpenInfoCorner.Add( function( infoCornerID )
	g_topOffset = g_infoCornerYmax[infoCornerID] or 380
	Controls.CityPanel:SetOffsetY( g_topOffset )
	return UpdateOptions()
end)

--[[
Events.EndCombatSim.Add( function(
			attackerPlayerID,
			attackerUnitID,
			attackerUnitDamage,
			attackerFinalUnitDamage,
			attackerMaxHitPoints,
			defenderPlayerID,
			defenderUnitID,
			defenderUnitDamage,
			defenderFinalUnitDamage,
			defenderMaxHitPoints )
	if attackerPlayerID == g_activePlayerID then
		local instance = g_units[ attackerUnitID ]
		if instance then
			local toolTip = instance.Button:GetToolTipString()
			if toolTip then
				toolTip = toolTip .. "[NEWLINE]"
			else
				toolTip = ""
			end
			toolTip = toolTip
				.."Attack: "
				.. " / " .. tostring( attackerPlayerID )
				.. " / " .. tostring( attackerUnitID )
				.. " / " .. tostring( attackerUnitDamage )
				.. " / " .. tostring( attackerFinalUnitDamage )
				.. " / " .. tostring( attackerMaxHitPoints )
				.. " / " .. tostring( defenderPlayerID )
				.. " / " .. tostring( defenderUnitID )
				.. " / " .. tostring( defenderUnitDamage )
				.. " / " .. tostring( defenderFinalUnitDamage )
				.. " / " .. tostring( defenderMaxHitPoints )
			instance.Button:SetToolTipString( toolTip )
		end
	elseif defenderPlayerID == g_activePlayerID then
		local instance = g_units[ defenderUnitID ]
		if instance then
			local toolTip = instance.Button:GetToolTipString()
			if toolTip then
				toolTip = toolTip .. "[NEWLINE]"
			else
				toolTip = ""
			end
			toolTip = toolTip
				.."Defense: "
				.. " / " .. tostring( attackerPlayerID )
				.. " / " .. tostring( attackerUnitID )
				.. " / " .. tostring( attackerUnitDamage )
				.. " / " .. tostring( attackerFinalUnitDamage )
				.. " / " .. tostring( attackerMaxHitPoints )
				.. " / " .. tostring( defenderPlayerID )
				.. " / " .. tostring( defenderUnitID )
				.. " / " .. tostring( defenderUnitDamage )
				.. " / " .. tostring( defenderFinalUnitDamage )
				.. " / " .. tostring( defenderMaxHitPoints )
			instance.Button:SetToolTipString( toolTip )
		end
	end
end)
--]]
-- Process request to hide enemy panel
LuaEvents.EnemyPanelHide.Add(
	function( isEnemyPanelHide )
		if g_isWorkerActionPanelOpen then
			Controls.WorkerActionPanel:SetHide( not isEnemyPanelHide )
		end
		if not g_isHideUnitTypes and not g_isHideUnitList then
			Controls.UnitTypesPanel:SetHide( not isEnemyPanelHide )
		end
	end)
local EnemyUnitPanel = LookUpControl( "/InGame/WorldView/EnemyUnitPanel" )
local isHidden = ContextPtr:IsHidden()
ContextPtr:SetShowHideHandler(
	function( isHide, isInit )
		if not isInit and isHidden ~= isHide then
			isHidden = isHide
			if isHide and EnemyUnitPanel then
				EnemyUnitPanel:SetHide( true )
			end
		end
	end)
ContextPtr:SetHide( false )

print("Finished loading EUI unit panel",os.clock())
end)
