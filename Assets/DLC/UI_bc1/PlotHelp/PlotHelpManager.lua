-------------------------------
-- PlotHelpManager.lua
-- coded by bc1 from Civ V 1.0.3.276 and Civ BE code
-- without the caching optimizations (no longer applicable)
-- compatible with Gazebo's City-State Diplomacy Mod (CSD) for Brave New World v 21
-- compatible with GameInfo.Yields() iterator broken by Communitas
-- todo: resources hookup, maintenance cost & health, terraform
-- todo BE: don't show quest artifacts if there's already a (quest) improvement here
-------------------------------
include( "EUI_utilities" )
include( "EUI_unit_include" )

Events.SequenceGameInitComplete.Add(function()
print("Loading EUI plot help",ContextPtr,os.clock(),[[ 
 ____  _       _   _   _      _       __  __                                   
|  _ \| | ___ | |_| | | | ___| |_ __ |  \/  | __ _ _ __   __ _  __ _  ___ _ __ 
| |_) | |/ _ \| __| |_| |/ _ \ | '_ \| |\/| |/ _` | '_ \ / _` |/ _` |/ _ \ '__|
|  __/| | (_) | |_|  _  |  __/ | |_) | |  | | (_| | | | | (_| | (_| |  __/ |   
|_|   |_|\___/ \__|_| |_|\___|_| .__/|_|  |_|\__,_|_| |_|\__,_|\__, |\___|_|   
                               |_|                             |___/           
]])

-------------------------------
-- minor lua optimizations
-------------------------------
local ceil = math.ceil
local floor = math.floor
local max = math.max
local pairs = pairs
local format = string.format
local concat = table.concat
local insert = table.insert
local remove = table.remove
local tonumber = tonumber

include( "ResourceTooltipGenerator" )
local GenerateResourceToolTip = GenerateResourceToolTip
--EUI_utilities
local GameInfo = EUI.GameInfoCache -- warning! booleans are true, not 1, and use iterator ONLY with table field conditions, NOT string SQL query
--EUI_unit_include
local ShortUnitTip = EUI.ShortUnitTip

local ContextPtr = ContextPtr
local Game = Game
local GameDefines_HILLS_EXTRA_MOVEMENT = GameDefines.HILLS_EXTRA_MOVEMENT
local GameInfoTypes = GameInfoTypes
local GameOptionTypes = GameOptionTypes
local L = Locale.ConvertTextKey
local Map_GetPlot = Map.GetPlot
local MinorCivQuestTypes = MinorCivQuestTypes
local MouseOverStrategicViewResource = MouseOverStrategicViewResource
local OptionsManager = OptionsManager
local Players = Players
local ResourceUsageTypes_RESOURCEUSAGE_BONUS = ResourceUsageTypes.RESOURCEUSAGE_BONUS
local ResourceUsageTypes_RESOURCEUSAGE_STRATEGIC = ResourceUsageTypes.RESOURCEUSAGE_STRATEGIC
local Teams = Teams
local ToHexFromGrid = ToHexFromGrid
local GetMouseDelta = UIManager.GetMouseDelta
local GetHeadSelectedUnit = UI.GetHeadSelectedUnit
local GetMouseOverHex = UI.GetMouseOverHex
local YieldTypes = YieldTypes
local YieldTypes_NUM_YIELD_TYPES_1 = YieldTypes.NUM_YIELD_TYPES-1

-------------------------------
-- Globals
-------------------------------
local GameInfoTechnologies = GameInfo.Technologies
local GameInfoPolicies = GameInfo.Policies
local GameInfoBeliefs = GameInfo.Beliefs

local civ5_mode = type( MouseOverStrategicViewResource ) == "function"
local gk_mode = type( Game.GetReligionName ) == "function"
local bnw_mode = type( Game.GetActiveLeague ) == "function"
local csd_mode = civ5_mode and type( Map_GetPlot(0,0).GetPlayerThatBuiltImprovement ) == "function"	-- Compatibility with Gazebo's City-State Diplomacy Mod (CSD) for Brave New World v23
local civ5_bnw_mode = bnw_mode and civ5_mode
--local civBE_mode = type( Game.GetAvailableBeliefs ) == "function"

local MouseEvents_MouseMove = MouseEvents.MouseMove
local TipArea = Controls.TipArea
local Timer = Controls.Timer
local tipControlTable = {}
local g_PlotHelpToolTip = "PlotHelpToolTip"
TTManager:GetTypeControlTable( "PlotHelpToolTip", tipControlTable )
local TipGrid = tipControlTable.TipGrid
local TipText = tipControlTable.TipText

local g_tipTimer1, g_tipTimer2, g_isScienceEnabled, g_isPoliciesEnabled, g_isHappinessEnabled, g_isReligionEnabled, g_isNoob, g_isCivilianYields

local g_tipLevel = 0
local g_plot = false
local g_lastPlot = false

local g_specialFeatures = {
--	[FeatureTypes.FEATURE_JUNGLE or -1] = true,
--	[FeatureTypes.FEATURE_MARSH or -1] = true,
--	[FeatureTypes.FEATURE_OASIS or -1] = true,
	[FeatureTypes.FEATURE_ICE or -1] = true,
--	[FeatureTypes.FEATURE_FLOOD_PLAINS or -1] = true,
} g_specialFeatures[-1] = nil
local g_miasmaBurb = Map_GetPlot(0,0).HasMiasma and (GameInfo.Features[FeatureTypes.FEATURE_MIASMA] or {}).Description
g_miasmaBurb = g_miasmaBurb and "[COLOR_NEGATIVE_TEXT]"..L( g_miasmaBurb ).."[ENDCOLOR]"

local g_schemaQuirk = { CultureChange = YieldTypes.YIELD_CULTURE or "YIELD_CULTURE" }

local g_gameAvailableBeliefs = { Game.GetAvailablePantheonBeliefs, Game.GetAvailableFounderBeliefs, Game.GetAvailableFollowerBeliefs, Game.GetAvailableFollowerBeliefs, Game.GetAvailableEnhancerBeliefs, Game.GetAvailableBonusBeliefs }

local g_unitMouseOvers = {}
local g_lastTips = {}
local g_lastTip = false
local g_defaultWorkRate
for row in GameInfo.Units() do
	g_defaultWorkRate = max( g_defaultWorkRate or 0, row.WorkRate )
end
--print("found default work rate", g_defaultWorkRate)
g_defaultWorkRate = g_defaultWorkRate or 100

-------------------------------
-- Utilities
-------------------------------
local function ClearOverlays()
	for _ = 1, #g_unitMouseOvers do
		Game.MouseoverUnit( remove( g_unitMouseOvers ), false )
	end
end

local function isMountainNearby( city, distance )
	for i = 0, (distance+1) * distance * 3 do
		local plot = city:GetCityIndexPlot(i)
		if plot and plot:IsMountain() then
			return true
		end
	end
end

local function isTerrainNearby( city, distance, terrainTypeID )
	for i = 0, (distance+1) * distance * 3 do
		local plot = city:GetCityIndexPlot(i)
		if plot and plot:GetTerrainType() == terrainTypeID then
			return true
		end
	end
end

-------------------------------
-- Plot Tool Tip
-------------------------------

local PlotToolTips = EUI.PlotToolTips or function( plot, isExtraTips )
	local insert = insert
	-- New Plot Tool Tip
	local activePlayerID = Game.GetActivePlayer()
	local activePlayer = Players[ activePlayerID ]
	local activeTeamID = Game.GetActiveTeam()
	local activeTeam = Teams[ activeTeamID ]
	local activeTeamTechs = activeTeam:GetTeamTechs()
	local activeCivilizationID = activePlayer:GetCivilizationType()
	local activeCivilizationType = (GameInfo.Civilizations[ activeCivilizationID ] or {}).Type
	local availableBeliefs = {}
	local activePlayerIdeologyType
	local plotOwner, plotCity, workingCity, owningCity
	local plotTechs = activeTeamTechs
	local plotBeliefs = {}

	local tips = {}

	if g_isReligionEnabled then
		if civ5_mode then
			local activePlayerBeliefs
			if activePlayer:HasCreatedReligion() then
				activePlayerBeliefs = Game.GetBeliefsInReligion( activePlayer:GetReligionCreatedByPlayer() )
			elseif activePlayer:HasCreatedPantheon() then
				activePlayerBeliefs = { activePlayer:GetBeliefInPantheon() }
			elseif activePlayer:CanCreatePantheon() then
				activePlayerBeliefs = {}
			end
			if activePlayerBeliefs then
				for i = 1, activePlayer:IsTraitBonusReligiousBelief() and 6 or 5 do
					local beliefID = activePlayerBeliefs[i]
					if beliefID and beliefID >= 0 then
						availableBeliefs[beliefID] = true -- because active player already has this belief in "i" belief class
					else
						for _,beliefID in pairs( g_gameAvailableBeliefs[i]() ) do
							availableBeliefs[beliefID] = true -- because available to active player in "i" belief class
						end
					end
				end
			end
		else
			for _, beliefID in pairs( Game.GetAvailableBeliefs() ) do
				availableBeliefs[ beliefID ] = true
			end
		end
	end
	if civ5_bnw_mode and g_isPoliciesEnabled then
		local activePlayerIdeologyID = activePlayer:GetLateGamePolicyTree()
		local activePlayerIdeology = GameInfo.PolicyBranchTypes[ activePlayerIdeologyID ]
		activePlayerIdeologyType = activePlayerIdeology and activePlayerIdeology.Type
	end

	------------------
	-- Tech Filter
	local function TechFilter( row )

		return row and plotTechs and not plotTechs:HasTech( row.ID )
	end

	------------------
	-- Policy Filter
	local function PolicyFilter( row )

		return row and not( plotOwner and plotOwner:HasPolicy( row.ID ) and not plotOwner:IsPolicyBlocked( row.ID ) )
			and not( activePlayerIdeologyType and activePlayerIdeologyType ~= row.PolicyBranchType )
	end

	------------------
	-- Belief Filter
	local function BeliefFilter(row)

		return row and not plotBeliefs[ row.ID ] and availableBeliefs[ row.ID ]
	end

	------------------
	-- Building Filter
	local function BuildingFilter( building )

		if building and activePlayer and activeTeam and activeCivilizationType then
			local buildingClass = building.BuildingClass
			if buildingClass then
				if owningCity then
					-- filter out building classes that city already has
					for row in GameInfo.Buildings{ BuildingClass = buildingClass } do
						if owningCity:IsHasBuilding(row.ID) then
							return false
						end
					end
					local owningCityPlot = owningCity:Plot()
					-- filter out buildings that city will never be able to build
					if ( owningCityPlot and owningCity:IsBuildingsMaxed() )
						or ( building.Water and not owningCity:IsCoastal( building.MinAreaSize ) )
						or ( building.River and not owningCityPlot:IsRiver())
						or ( building.FreshWater and not owningCityPlot:IsFreshWater() )
						or ( building.Hill and not owningCityPlot:IsHills() )
						or ( building.Flat and owningCityPlot:IsHills() )
						or ( building.ProhibitedCityTerrain and owningCityPlot:GetTerrainType() == GameInfoTypes[building.ProhibitedCityTerrain] )
						or ( building.NearbyTerrainRequired and not isTerrainNearby( owningCity, 1, GameInfoTypes[building.NearbyTerrainRequired] ) )
						or ( building.Mountain and not isMountainNearby( owningCity, 1 ))
						or ( building.NearbyMountainRequired and not isMountainNearby( owningCity, 2 ) )
					then
						return false
					end
				end

				-- filter out buildings which player will never be able to build
				if activePlayer:IsProductionMaxedBuildingClass( GameInfoTypes[buildingClass] )
-- redundant						or Game.IsBuildingClassMaxedOut( GameInfoTypes[buildingClass] )
-- redundant						or activeTeam:IsBuildingClassMaxedOut( GameInfoTypes[buildingClass] )
-- redundant						or activePlayer:IsBuildingClassMaxedOut( GameInfoTypes[buildingClass] )
					or activeTeam:IsObsoleteBuilding( building.ID )
					or ( building.MaxStartEra and Game.GetStartEra() > GameInfoTypes[building.MaxStartEra] )
				then
					return false
				end

				-- special building ?
				local buildingClassOverride = GameInfo.Civilization_BuildingClassOverrides{ BuildingClassType = buildingClass, CivilizationType = activeCivilizationType }()
				if buildingClassOverride then
					return building.Type == buildingClassOverride.BuildingType
				else
					return building.Type == (GameInfo.BuildingClasses[ buildingClass ] or {}).DefaultBuilding
				end
			end
		end
	end
	-- Building Filter
	------------------

	------------------
	-- Yield Changes
	local function insertYieldChanges( tips, bullet, color, type, filter, info, ... )
		if tips and bullet and color and type and filter and info then
			local Yields = {}
			-- loop through tables to search
			for _, search in pairs{...} do
				-- scan table rows which match search
				if search then
					for row in search do
						-- get item which matches the type we're looking for
						local itemType, yieldType, yieldChange
						for k, v in pairs(row) do
							if k == type then
								itemType = v
							elseif k == "YieldType" then
								yieldType = YieldTypes[v]
							elseif tonumber(v) then
								yieldChange = v
								yieldType = g_schemaQuirk[k] or yieldType
							end
						end
						if itemType and yieldType and yieldChange then
							local itemYields = Yields[itemType]
							if not itemYields then
								itemYields = {}
								Yields[itemType] = itemYields
							end
							itemYields[yieldType] = (itemYields[yieldType] or 0) + yieldChange
						end
					end
				end
			end

			local row, yieldChange, yieldInfo, text
			for itemType, itemYields in pairs(Yields) do
				text = ""
-- TODO: add culture for vanilla, happiness & resources
				for yieldID = 0, YieldTypes_NUM_YIELD_TYPES_1 do
					yieldChange = itemYields[ yieldID ]
					if yieldChange then
						yieldInfo = GameInfo.Yields[ yieldID ]
						if yieldInfo then
							if yieldChange > 0 then
								text = format( "%s [COLOR_POSITIVE_TEXT]%+i[ENDCOLOR]%s", text, yieldChange, yieldInfo.IconString )
							elseif yieldChange < 0 then
								text = format( "%s [COLOR_NEGATIVE_TEXT]%+i[ENDCOLOR]%s", text, yieldChange, yieldInfo.IconString )
							end
						end
					end
				end
				if #text > 0 then
					row = info[itemType]
					if filter(row) then
						local alreadyHave, belief
						local canHave = true
						local name = row._Name -- set by EUI info cache
						
						-- does it have a tech requirement ?
						local tech = info ~= GameInfoTechnologies and GameInfoTechnologies[row.PrereqTech]
						if tech then
							alreadyHave = activeTeamTechs:HasTech( tech.ID )
							canHave = alreadyHave or g_isScienceEnabled
							tech = canHave and not alreadyHave and "[COLOR_CYAN]" .. tech._Name .. "[ENDCOLOR] "
						end

						-- does it have a policy branch requirement ?
						local policy = info ~= GameInfoPolicies and GameInfo.PolicyBranchTypes[row.PolicyBranchType]
						if policy then
							policy = GameInfoPolicies[ policy.FreePolicy ]
							if policy then
								alreadyHave = activePlayer:HasPolicy( policy.ID )
								canHave = (alreadyHave or g_isPoliciesEnabled)
									and not activePlayer:IsPolicyBlocked( policy.ID )
									and not( activePlayerIdeologyType and activePlayerIdeologyType ~= policy.PolicyBranchType )
								policy = canHave and not alreadyHave and "[COLOR_MAGENTA]" .. policy._Name .. "[ENDCOLOR] "
							end
						end

						-- does building have a belief requirement ?
						if row.UnlockedByBelief and row.Cost < 2 then -- schema assumption: key exists only for bnw buildings
							if bnw_mode then
								belief = GameInfo.Belief_BuildingClassFaithPurchase{ BuildingClassType = row.BuildingClass }()
							else
								belief = GameInfo.Beliefs{ BuildingClassEnabled = row.BuildingClass }()
							end
							if belief then
								belief = GameInfoBeliefs[ belief.BeliefType ]
								if belief then
									canHave = availableBeliefs[ belief.ID ]
									belief = canHave and not plotBeliefs[ belief.ID ]
										and ("[COLOR_WHITE]" .. belief._Name .. "[ENDCOLOR] ")
								end
							end
						end
						if canHave and name then
							insert( tips, bullet .. (tech or "") .. (belief or "") .. (policy or "") .. color .. name .. "[ENDCOLOR]" .. text )
						end
					end
				end
			end
		end
	end
	-- Yield Changes
	------------------

-- TODO: GameInfo.Improvement_ResourceTypes
-- TODO: GameInfo.Improvement_ResourceType_Yields

	-------------------------------------------------
	-- Improvement Yield Changes
	-------------------------------------------------
	local function insertImprovementYieldChanges( tips, improvement, bullet )
		if tips and improvement then
			bullet = bullet or ""
			local thisImprovementType = { ImprovementType = improvement.Type }
			if g_isScienceEnabled then
				insertYieldChanges( tips, bullet, "[COLOR_CYAN]", "TechType", TechFilter, GameInfoTechnologies, GameInfo.Improvement_TechYieldChanges( thisImprovementType ),
					( plot:IsFreshWater() and GameInfo.Improvement_TechFreshWaterYieldChanges or GameInfo.Improvement_TechNoFreshWaterYieldChanges)( thisImprovementType ) )
			end
			if g_isPoliciesEnabled then
				insertYieldChanges( tips, bullet, "[COLOR_MAGENTA]", "PolicyType", PolicyFilter, GameInfoPolicies, GameInfo.Policy_ImprovementYieldChanges( thisImprovementType ), GameInfo.Policy_ImprovementCultureChanges( thisImprovementType ) )
			end
			if g_isReligionEnabled then
				insertYieldChanges( tips, bullet, "[COLOR_WHITE]", "BeliefType", BeliefFilter, GameInfoBeliefs, GameInfo.Belief_ImprovementYieldChanges( thisImprovementType ) )
			end
		end
	end

	--------------------
	-- City State Quests
	local function insertCityStateQuest( tips, questID, textKey )
		for _, minorPlayer in pairs(Players) do
			if minorPlayer and minorPlayer:IsMinorCiv() and minorPlayer:IsAlive() then
				local minorTeamID = minorPlayer:GetTeam()
				if activeTeamID ~= minorTeamID and activeTeam:IsHasMet( minorTeamID ) then
					-- Does the player have a quest corresponding to questID here?
					local isQuest
					if gk_mode then
						isQuest = minorPlayer:IsMinorCivActiveQuestForPlayer( activePlayerID, questID )
					else
						isQuest = minorPlayer:GetActiveQuestForPlayer( activePlayerID ) == questID
					end
					if isQuest
						and plot:GetX() == minorPlayer:GetQuestData1( activePlayerID, questID )
						and plot:GetY() == minorPlayer:GetQuestData2( activePlayerID, questID )
					then
						insert( tips, "[COLOR_POSITIVE_TEXT]" .. L( textKey, minorPlayer:GetCivilizationShortDescriptionKey() ) .. "[ENDCOLOR]" )
					end
				end
			end
		end
	end

	-------------------------------------------------
	-- Plot Help
	-------------------------------------------------

	if plot and plot:IsRevealed( activeTeamID, true ) then

		local plotOwnerID = plot:GetRevealedOwner( activeTeamID, true )
		plotOwner = Players[ plotOwnerID ]
		local plotTeamID = plotOwner and plotOwner:GetTeam()
		local plotTeam = Teams[ plotTeamID ]
		if plotTeam then
			plotTechs = plotTeam:GetTeamTechs()
		end
		workingCity = plot:GetWorkingCity()
		owningCity =  workingCity or ( plot.GetCityPurchaseID and plotOwner and plotOwner:GetCityByID( plot:GetCityPurchaseID() ) )
		plotCity = plot:GetPlotCity()
		local buildsInProgress = {}

		if g_isReligionEnabled and workingCity then
			if civ5_mode then
				local religionID = workingCity:GetReligiousMajority()
				if religionID > 0 then
					for _,belief in pairs( Game.GetBeliefsInReligion(religionID) ) do
						plotBeliefs[belief] = true
					end
				elseif religionID == 0 and plotOwner and plotOwner:HasCreatedPantheon() then --pantheon
					plotBeliefs[plotOwner:GetBeliefInPantheon()] = true
				end
				if bnw_mode then
					local pantheonID = workingCity:GetSecondaryReligionPantheonBelief()
					if pantheonID >= 0 then
						plotBeliefs[pantheonID] = true
					end
				end
			else
				for _, beliefID in pairs( Game.GetBeliefsAcquiredByPlayer( plotOwnerID ) ) do
					plotBeliefs[ beliefID ] = true
				end
			end
		end
		local workRate = max(0, (activePlayer:GetWorkerSpeedModifier() + 100) * g_defaultWorkRate ) / 100

		if Game.IsDebugMode() then
			local x, y = plot:GetX(), plot:GetY()
			local hex = ToHexFromGrid{ x=x, y=y }
			insert( tips, "x:"..x.." y:"..y.." hex x:"..hex.x.." hex y:"..hex.y )
		end
		--------
		-- Units
		if plot:IsVisible( activeTeamID, true ) then

			local units = {}
			-- Loop through all units in plot
			for i = 1, (bnw_mode and plot:GetNumLayerUnits() or plot:GetNumUnits()) do
				units[i] = bnw_mode and plot:GetLayerUnit(i-1) or plot:GetUnit(i-1)
			end
			if not civ5_mode then
				local unit = plot:GetOrbitalUnitInfluencingPlot()
				if unit and unit ~= units[#units] then
					units[#units+1] = unit
				end
			end
			for i=1, #units do
				local unit = units[i]
				local unitOwnerID = unit:GetOwner()

				if unit and not unit:IsInvisible( activeTeamID, true ) then
					insert( tips, ShortUnitTip( unit ) )
					if unit.IsTrade and unit:IsTrade() then
						-- show trade route
						insert( g_unitMouseOvers, unit )
						Game.MouseoverUnit( unit, true )
					end
					-- Can build something?
					if unitOwnerID == activePlayerID then
						local unitWorkRate = unit:WorkRate( true )
						if unitWorkRate > workRate then
							workRate = unitWorkRate
						end
					end
					-- Building something?
					local build = GameInfo.Builds[ unit:GetBuildType() ]
					if build then
						local buildTurnsLeft = plot:GetBuildTurnsLeft( build.ID, unitOwnerID, -unit:WorkRate() )
						buildsInProgress[ build.ID ] = buildTurnsLeft
						insert( tips, L( "TXT_KEY_WORKER_BUILD_PROGRESS", buildTurnsLeft, build._Name ) )
					end
				end
			end
		end

		local selectedUnit = GetHeadSelectedUnit()
		local isCombatUnitSelected = selectedUnit and selectedUnit:IsCombatUnit()

		--------
		-- Owner
		local strOwner = ""
		local isOpenBorders = false

		if plotOwner then
			-- Met ?
			if activeTeam:IsHasMet( plotTeamID ) then
				if activeTeamID == plotTeamID or (plotOwner:IsMinorCiv() and plotOwner:IsAllies(activePlayerID))then
					strOwner = "[COLOR_POSITIVE_TEXT]"
					isOpenBorders = true
				elseif activeTeam:IsAtWar( plotTeamID ) then
					strOwner = "[COLOR_NEGATIVE_TEXT]"
				elseif plotTeam:IsAllowsOpenBordersToTeam( activeTeamID ) then
					strOwner = "[COLOR_WHITE]"
					isOpenBorders = true
				else
					strOwner = "[COLOR_YELLOW]"
				end
				-- Known city plot ?
				if owningCity and owningCity:Plot():IsRevealed( activeTeamID, true ) then
					strOwner = strOwner .. owningCity:GetName() .. "[ENDCOLOR]"
					if g_isNoob then
						strOwner = L( "TXT_KEY_CITY_OF", plotOwner:IsMinorCiv() and "" or plotOwner:GetCivilizationAdjectiveKey(), strOwner )
					end
				-- No city, plot is just owned
				else
					strOwner = strOwner .. plotOwner:GetCivilizationShortDescription() .. "[ENDCOLOR]"
				end
			-- Not met
			else
				strOwner = L"TXT_KEY_UNMET_PLAYER"
			end
		end

		if #strOwner > 0 then
			insert( tips, strOwner )
		end

		------------
		-- Resources
		local resourceTip = ""
		local resourceID = plot:GetResourceType( activeTeamID )
		local resourceHappiness = 0
		local resource =  GameInfo.Resources[ resourceID ]
		local resourceCount, isResourceConnected, isResourceUsefull, resourceUsageType
		local isPillaged = plot:IsImprovementPillaged()
		local revealedImprovementID = plot:GetRevealedImprovementType( activeTeamID, true )
		local actualImprovementID = plot:GetImprovementType()
		local revealedImprovement

		if resource then
			resourceUsageType = Game.GetResourceUsageType( resourceID )
			resourceHappiness = activePlayer:GetHappinessFromLuxury( resourceID ) -- !! todo for vanilla
			isResourceUsefull = resourceUsageType ~= ResourceUsageTypes_RESOURCEUSAGE_BONUS
			isResourceConnected = plot:IsResourceConnectedByImprovement( revealedImprovementID ) and not isPillaged
			resourceCount = plot:GetNumResource()

			if resourceUsageType == ResourceUsageTypes_RESOURCEUSAGE_STRATEGIC then
				resourceTip = resourceTip .. resourceCount
			end
			resourceTip = resourceTip .. ( resource.IconString or "" ) .. resource._Name

			-- Resource Hookup info
			local resourceEnablerTechID = civ5_mode and GameInfoTypes[resource.TechCityTrade] -- todo
			if resourceEnablerTechID and resourceEnablerTechID ~= -1 and not activeTeamTechs:HasTech(resourceEnablerTechID) then

				local techName = GameInfoTechnologies[resourceEnablerTechID]
				techName = techName and techName._Name or "<unknown tech>"
				if g_isNoob then
					resourceTip = resourceTip .. " " .. L( "TXT_KEY_PLOTROLL_REQUIRES_TECH_TO_USE", techName )
				else
					resourceTip = resourceTip .. " " .. L( "TXT_KEY_PLOTROLL_REQUIRES_TECH", techName )
				end
			end
			if #resourceTip > 0 then
				if g_isNoob then
					insert( tips, L"TXT_KEY_RESOURCE" .. ": " .. resourceTip )
				else
					insert( tips, resourceTip )
				end
			end
		end

		------------------------
		-- Terrain type, feature
		local featureID = plot:GetFeatureType()
		local feature = featureID >= 0 and GameInfo.Features[ featureID ]
		local isFeatureReplacesTerrain = false
		local terrain = GameInfo.Terrains[ plot:GetTerrainType() ] or {}
		local featureTips = {}

		local isLakePlot = plot:IsLake()
		local isWaterPlot = plot:IsWater()
		local isMountainPlot = plot:IsMountain()
		local isSpecialFeature = g_specialFeatures[ featureID ] -- Some features are handled in a special manner, since they always have the same terrain type under it
		local isNaturalWonder = false
		local moveCost = 0

		-- Miasma CIV BE only
		if g_miasmaBurb and plot:HasMiasma() then
			insert( featureTips, g_miasmaBurb )
		end

		-- Feature
		if feature then
			moveCost = feature.Movement or 0
			isFeatureReplacesTerrain = feature.YieldNotAdditive
			if feature.NaturalWonder then
				isNaturalWonder = true
				isSpecialFeature = true
			end
			insert( featureTips, feature._Name )
		else
			moveCost = terrain.Movement or 0
			-- Mountain
			if isMountainPlot then
				isSpecialFeature = true
				insert( featureTips, L"TXT_KEY_PLOTROLL_MOUNTAIN" )

			-- Canyon CIV BE only
			elseif not civ5_mode and plot:IsCanyon() then
				isSpecialFeature = true
				insert( featureTips, L"TXT_KEY_PLOTROLL_CANYON" )
			end
		end

		-- Terrain
		if not isSpecialFeature then
			-- Lake
			if isLakePlot then
				insert( featureTips, L"TXT_KEY_PLOTROLL_LAKE" )
			else
				insert( featureTips, terrain._Name )
			end
		end

		-- Hills
		if plot:IsHills() then
			if not plotCity then
				moveCost = moveCost + GameDefines_HILLS_EXTRA_MOVEMENT
			end
			insert( featureTips, L"TXT_KEY_PLOTROLL_HILL" )
		end

		-- River & Fresh Water
		if plot:IsRiver() then
			insert( featureTips, L"TXT_KEY_PLOTROLL_RIVER" )
		elseif plot:IsFreshWater() then
			insert( featureTips, L"TXT_KEY_PLOTROLL_FRESH_WATER" )
		end

		if #featureTips > 0 then
			if g_isNoob and not isNaturalWonder then
				insert( tips, L"TXT_KEY_PEDIA_TERRAIN_LABEL" .. ": " .. concat( featureTips, ", " ) )
			else
				insert( tips, concat( featureTips, ", " ) )
			end
		end

		--------
		-- Yield
		local yieldTips = {}
		local yieldChange, yieldInfo

		for yieldID = 0, YieldTypes_NUM_YIELD_TYPES_1 do -- GameInfo.Yields() iterator is broken by Communitas
			yieldInfo = GameInfo.Yields[ yieldID ]
			yieldChange = plot:CalculateYield( yieldID, true ) -- true = as shown to the active player
			if yieldInfo and yieldChange ~= 0 then
				insert( yieldTips, yieldChange .. yieldInfo.IconString )
			end
		end

		if not civ5_mode then
			-- Health (local to plot)
			yieldChange = plot:GetHealth()
			if yieldChange ~= 0 then
				insert( yieldTips, yieldChange .. "[ICON_HEALTH_1]" )
			end

		elseif gk_mode then
			-- Happiness (should probably be calculated in CvPlayer)
			if feature and g_isHappinessEnabled then
				yieldChange = feature.InBorderHappiness
				yieldChange = floor( yieldChange * ( 100 + activePlayer:GetNaturalWonderYieldModifier() ) / 100 )

				if yieldChange ~= 0 then
					insert( yieldTips, yieldChange .. "[ICON_HAPPINESS_1]" )
				end
			end
		else
			yieldChange = plot:GetCulture()
			-- Only fudge in the additional culture if the owner is NOT the active player.
			if isNaturalWonder and plotOwnerID ~= activePlayerID then
				yieldChange = yieldChange + floor(feature.Culture * (100 + activePlayer:GetNaturalWonderYieldModifier()) / 100)
			end
			if yieldChange ~= 0 then
				insert( yieldTips, yieldChange .. "[ICON_CULTURE]" )
			end
		end
		if resource and isResourceConnected and isResourceUsefull then
			if resourceHappiness ~=0 and activePlayer:GetNumResourceAvailable(resourceID, true) == 1 then
				insert( yieldTips, format("%i%s%i[ICON_HAPPINESS_1]", resourceCount, resource.IconString or "?", resourceHappiness) )
			else
				insert( yieldTips, resourceCount .. (resource.IconString or"?") )
			end
		end

		-- Moves & Defense
		if isMountainPlot then
		elseif plot:IsImpassable() then
			insert( tips, L"TXT_KEY_PEDIA_IMPASSABLE" )
		else
			local defenseModifier = plot:DefenseModifier( activeTeamID, false, false )
			if defenseModifier ~= 0 then
				if g_isNoob then
					insert( tips, format( "%s %+i%%[ICON_STRENGTH]", L"TXT_KEY_PEDIA_DEFENSE_LABEL", defenseModifier ) )
				else
					insert( yieldTips, format( "%+i%%[ICON_STRENGTH]", defenseModifier ) )
				end
			end
			-- Great Wall
			if plotTeam and not (isWaterPlot or isOpenBorders) and plotTeam:IsBorderObstacle() then
				moveCost = moveCost + 1
			end
			if moveCost > 1 then
				if g_isNoob then
					insert( tips, format( "%s %i[ICON_MOVES]", L"TXT_KEY_PEDIA_MOVECOST_LABEL", moveCost ) )
				else
					insert( yieldTips, format("%i[ICON_MOVES]", moveCost) )
				end
			end
		end

		if #yieldTips > 0  then -- and (isExtraTips or g_isNoob or not isCombatUnitSelected) then
			if g_isNoob then
				insert( tips, L"TXT_KEY_OUTPUT" .. ": " .. concat( yieldTips, " " ) )
			else
				insert( tips, concat( yieldTips, " " ) )
			end
		end


		----------------------
		-- Improvement & Route
		local improvementTips = {}

		local function checkPillaged( row, flag )
			if row then
				local txt = row._Name
				-- Compatibility with Gazebo's City-State Diplomacy Mod (CSD) for Brave New World
				if csd_mode and row.Type == "IMPROVEMENT_EMBASSY" then
					local player = Players[plot:GetPlayerThatBuiltImprovement()]
					if player then
						txt = txt .. " - ".. player:GetCivilizationShortDescription()
					end
				end
				if flag then
					return "[COLOR_NEGATIVE_TEXT]" .. txt .. " " .. L"TXT_KEY_PLOTROLL_PILLAGED" .. "[ENDCOLOR]"
				else
					return txt
				end
			else
				return ""
			end
		end

		if revealedImprovementID >= 0 then
			revealedImprovement = GameInfo.Improvements[revealedImprovementID]
			insert( improvementTips, "[COLOR_POSITIVE_TEXT]" .. checkPillaged( revealedImprovement, isPillaged ) .. "[ENDCOLOR]" )
		end

		local routeID = plot:GetRevealedRouteType( activeTeamID, true )
		if routeID >= 0 then
			insert( improvementTips, checkPillaged(GameInfo.Routes[routeID], plot:IsRoutePillaged()) )
		end

		if g_isNoob and isExtraTips and plot:IsTradeRoute() then
			insert( improvementTips, L"TXT_KEY_PLOTROLL_TRADE_ROUTE" )
		end

		if #improvementTips > 0 then
			if g_isNoob then
				insert( tips, L"TXT_KEY_IMPROVEMENT" .. ": " .. concat( improvementTips, ", ") )
			else
				insert( tips, concat( improvementTips, ", ") )
			end
		end

		-- Maintenance (Improvement) CIVBE ONLY
		if not civ5_mode and plotOwnerID == activePlayerID then
			local energyMaintenance = plot:GetPlotMaintenance( activePlayerID )
			if energyMaintenance > 0 then
				insert( tips, "[COLOR_NEGATIVE_TEXT]" .. L"TXT_KEY_CITYVIEW_MAINTENANCE" .. "[ENDCOLOR]" .. ": " .. energyMaintenance.."[ICON_ENERGY]" )
			end
		end

		if not isCombatUnitSelected or ( plotOwnerID == activePlayerID and isExtraTips ) then
			if not isPillaged then
				insertImprovementYieldChanges( tips, revealedImprovement, "[ICON_BULLET]" )
			end
			local isSeaPlot = isWaterPlot and not isLakePlot
			insertYieldChanges(tips, "[ICON_BULLET]", "[COLOR_YIELD_FOOD]", "BuildingType", BuildingFilter, GameInfo.Buildings,
--TODO modifiers	GameInfo.Building_AreaYieldModifiers(),
--TODO modifiers	resource and GameInfo.Building_ResourceYieldModifiers{ ResourceType = resource.Type },
				resource and GameInfo.Building_ResourceCultureChanges{ ResourceType = resource.Type },
				plot:IsRiver() and GameInfo.Building_RiverPlotYieldChanges(),
				isSeaPlot and GameInfo.Building_SeaPlotYieldChanges(),
				isLakePlot and GameInfo.Building_LakePlotYieldChanges(),
				isSeaPlot and resource and GameInfo.Building_SeaResourceYieldChanges(),
				resource and GameInfo.Building_ResourceYieldChanges{ ResourceType = resource.Type },
				feature and GameInfo.Building_FeatureYieldChanges{ FeatureType = feature.Type },
				gk_mode and not isFeatureReplacesTerrain and GameInfo.Building_TerrainYieldChanges{ TerrainType = terrain.Type } )
			if g_isPoliciesEnabled then
				insertYieldChanges( tips, "[ICON_BULLET]", "[COLOR_MAGENTA]", "PolicyType", PolicyFilter, GameInfoPolicies,
					plotCity and GameInfo.Policy_CityYieldChanges(),
					plotCity and plotCity:IsCoastal() and GameInfo.Policy_CoastalCityYieldChanges(),
					plotCity and plotCity:IsCapital() and plotOwner == activePlayer and GameInfo.Policy_CapitalYieldChanges() )
--TODO modifiers	Policy_CapitalYieldModifiers
			end
			if g_isReligionEnabled then
				insertYieldChanges( tips, "[ICON_BULLET]", "[COLOR_WHITE]", "BeliefType", BeliefFilter, GameInfoBeliefs,
					plotCity and GameInfo.Belief_CityYieldChanges(),
					plotCity and plotCity:IsHolyCityAnyReligion() and GameInfo.Belief_HolyCityYieldChanges(),
					feature and GameInfo.Belief_FeatureYieldChanges{ FeatureType = feature.Type },
					resource and GameInfo.Belief_ResourceYieldChanges{ ResourceType = resource.Type },
					not isFeatureReplacesTerrain and GameInfo.Belief_TerrainYieldChanges{ TerrainType = terrain.Type },
					isNaturalWonder and GameInfo.Belief_YieldChangeNaturalWonder() )
--TODO modifiers			isNaturalWonder and GameInfo.GetYieldModifierNaturalWonder()
			end

			for build in GameInfo.Builds() do
				local buildID = build.ID
				local buildTip = build._Name

				local canBuild = plot:CanBuild( buildID, activePlayerID ) and build.ShowInPedia ~= false and isWaterPlot == build.Water -- filter duplicates, fix DLL bug can build roads in lakes
				local isBasicBuild = true
				local buildImprovement = GameInfo.Improvements[ build.ImprovementType ]

				local buildInProgress = buildsInProgress[ buildID ]

				if buildImprovement then
					buildTip = buildImprovement._Name

					-- Work around unrevealed improvement game bug
					-- can always build unrevealed improvements (prevents "CanBuild" detection)
					if not (revealedImprovement or canBuild) then
						canBuild = actualImprovementID == buildImprovement.ID
					end

					-- case where improvement requires a specific civilization
					local civRequirement = buildImprovement.CivilizationType
					if civRequirement and canBuild then
						canBuild = GameInfoTypes[civRequirement] == activeCivilizationID
					end

					-- it's not basic to create a GP improvement
					if buildImprovement.CreatedByGreatPerson then
						canBuild = canBuild and selectedUnit and selectedUnit:CanBuild( plot, buildID, 1, 0 )
						isBasicBuild = buildInProgress or canBuild
					end
				end

				-- does build have a tech requirement ?
				local tech1 = GameInfoTechnologies[ build.PrereqTech ]
				if tech1 and not activeTeamTechs:HasTech( tech1.ID ) then
					buildTip = "[COLOR_CYAN]" .. tech1._Name .. "[ENDCOLOR] ".. buildTip
					canBuild = canBuild and g_isScienceEnabled
					isBasicBuild = isBasicBuild and (g_isNoob or isExtraTips)
				end

				-- does build remove a feature, and require a tech for doing so ?
				if feature then
					local row
					if civ5_mode then
						row = GameInfo.BuildFeatures{ BuildType = build.Type, FeatureType = feature.Type, Remove = true }() -- cache uses true / SQL uses 1
					else
						row = GameInfo.BuildsOnFeatures{ BuildType = build.Type, FeatureType = feature.Type, Remove = true }() -- stupid table rename by Firaxis
					end
					if row then
						buildTip = "[COLOR_RED]" .. feature._Name .. "[ENDCOLOR] ".. buildTip
						local tech2 = GameInfoTechnologies[ row.PrereqTech ]
						if tech2 and tech1 ~= tech2 and not activeTeamTechs:HasTech( tech2.ID ) then
							buildTip = "[COLOR_CYAN]" .. tech2._Name .. "[ENDCOLOR] ".. buildTip
							canBuild = canBuild and g_isScienceEnabled
							isBasicBuild = isBasicBuild and (g_isNoob or isExtraTips)
						end
					end
				end

				-- does build require time to build ?
				if plot:GetBuildTime(buildID) > 0 then
					local turnsRemaining = buildInProgress or ceil( ( plot:GetBuildTime( buildID, activePlayerID ) - max( workRate, plot:GetBuildProgress( buildID ) ) ) / workRate )
					if g_isNoob then
						buildTip = buildTip .. " (" .. L( "TXT_KEY_STR_TURNS", turnsRemaining ):lower() .. ")"
					else
						buildTip = buildTip .. " (" .. turnsRemaining .. ")"
					end
				end

				-- repair special case
				if build.Repair then
					buildImprovement = revealedImprovement
					isBasicBuild = true
					-- can always repair but not an unrevealed improvement
					canBuild = revealedImprovement
				end

				if canBuild or buildInProgress then
					-- Determine yield changes from this build
					canBuild = false
					local yieldChange, yieldInfo
					for yieldID = 0, YieldTypes_NUM_YIELD_TYPES_1 do -- GameInfo.Yields() iterator is broken by Communitas
						yieldInfo = GameInfo.Yields[ yieldID ]
						if yieldInfo then
							-- Work around unrevealed improvement game bug
							if buildImprovement and revealedImprovementID ~= actualImprovementID then
								yieldChange = plot:CalculateImprovementYieldChange( buildImprovement.ID, yieldID, activePlayerID ) -- false = not optimal
							else
								yieldChange = plot:GetYieldWithBuild( buildID, yieldID, false, activePlayerID ) - plot:CalculateYield( yieldID, false ) -- false = without upgrade, false = actual
							end

							-- Positive or negative change?
							if yieldChange > 0 then
								buildTip = format( "%s [COLOR_POSITIVE_TEXT]%+i[ENDCOLOR]%s", buildTip, yieldChange, yieldInfo.IconString )
								canBuild = true
							elseif yieldChange < 0 then
								buildTip = format( "%s [COLOR_NEGATIVE_TEXT]%+i[ENDCOLOR]%s", buildTip, yieldChange, yieldInfo.IconString )
							end
						end
					end
					-- Maintenance
					if buildImprovement then
						if civ5_mode then
							if (tonumber(buildImprovement.GoldMaintenance) or 0) > 0 then
								buildTip = format("%s [COLOR_NEGATIVE_TEXT]%+i[ENDCOLOR][ICON_GOLD]", buildTip, -buildImprovement.GoldMaintenance )
							end
						else
							if (tonumber(buildImprovement.Health) or 0) ~= 0 then
								buildTip = format("%s [COLOR_POSITIVE_TEXT]%+i[ENDCOLOR][ICON_HEALTH_1]", buildTip, buildImprovement.Health )
							end
							if (tonumber(buildImprovement.EnergyMaintenance) or 0) ~= 0 then
								buildTip = format("%s [COLOR_NEGATIVE_TEXT]%+i[ENDCOLOR][ICON_ENERGY]", buildTip, -buildImprovement.EnergyMaintenance )
							end
							if (tonumber(buildImprovement.Unhealth) or 0) ~= 0 then
								buildTip = format("%s [COLOR_NEGATIVE_TEXT]%+i[ENDCOLOR][ICON_HEALTH_4]", buildTip, -buildImprovement.Unhealth )
							end
						end
						if resource and isResourceUsefull then
							local happiness = 0
							if plot:IsResourceConnectedByImprovement( buildImprovement.ID ) then
								if not isResourceConnected then
									buildTip = format("%s [COLOR_POSITIVE_TEXT]%+i[ENDCOLOR]%s", buildTip, resourceCount, resource.IconString or "?" )
									if activePlayer:GetNumResourceAvailable(resourceID, true) < 1 then
										happiness = resourceHappiness
									end
								end
							elseif isResourceConnected then
								buildTip = format("%s [COLOR_NEGATIVE_TEXT]%+i[ENDCOLOR]%s", buildTip, -resourceCount, resource.IconString or "?" )
								if activePlayer:GetNumResourceAvailable(resourceID, true) == 1 then
									happiness = -resourceHappiness
								end
							end
							if happiness > 0 then
								buildTip = format("%s [COLOR_POSITIVE_TEXT]%+i[ENDCOLOR][ICON_HAPPINESS_1]", buildTip, happiness)
							elseif happiness < 0 then
								buildTip = format("%s [COLOR_NEGATIVE_TEXT]%+i[ENDCOLOR][ICON_HAPPINESS_1]", buildTip, happiness)
							end
						end
					end

					-- Determine possible further yields from this build
					if isExtraTips then
						local yieldTips = {}
						insertImprovementYieldChanges( yieldTips, buildImprovement, "[NEWLINE]      " )
						buildTip = "[ICON_MINUS]" .. buildTip .. concat( yieldTips )
					else
						buildTip = "[ICON_PLUS]" .. buildTip
					end
				end

				if buildInProgress or (canBuild and (isBasicBuild or (g_isNoob and isExtraTips))) then
					insert( tips, buildTip )
				end
			end
		end

		-- City state quest
		if civ5_mode and revealedImprovementID == GameInfoTypes.IMPROVEMENT_BARBARIAN_CAMP then
			insertCityStateQuest( tips, MinorCivQuestTypes.MINOR_CIV_QUEST_KILL_CAMP, "TXT_KEY_CITY_STATE_BARB_QUEST_LONG" )
		-- Compatibility with Gazebo's City-State Diplomacy Mod (CSD) for Brave New World
		elseif csd_mode and revealedImprovementID == GameInfoTypes.IMPROVEMENT_ARCHAEOLOGICAL_DIG then
			insertCityStateQuest( tips, MinorCivQuestTypes.MINOR_CIV_QUEST_ARCHAEOLOGY, "TXT_KEY_CITY_STATE_ARCHAEOLOGY_QUEST_LONG" )
		end

	end
	return concat( tips, "[NEWLINE]" )
end

-------------------------------------------------
-- Events & Initialisation
-------------------------------------------------

local function ResetTimer()
	g_plot = Map_GetPlot( GetMouseOverHex() )
	if g_tipTimer1 ~= 0 or g_plot ~= g_lastPlot then
		g_tipLevel = 0
		Timer:SetPauseTime( g_tipTimer1 )
		Timer:Play()
		TipArea:SetToolTipType()
		return ClearOverlays()
	end
end

-------------------------------------------------
local function GameIsNotOption( GameOption )
	return GameOption and not Game.IsOption( GameOption )
end

local function UpdateOptions()
	g_tipTimer1 = OptionsManager.GetTooltip1Seconds() / 100
	g_tipTimer2 = OptionsManager.GetTooltip2Seconds() / 100
	g_isCivilianYields = not OptionsManager.IsCivilianYields()
	g_isScienceEnabled = GameIsNotOption(GameOptionTypes.GAMEOPTION_NO_SCIENCE)
	g_isPoliciesEnabled = GameIsNotOption(GameOptionTypes.GAMEOPTION_NO_POLICIES)
	g_isHappinessEnabled = GameIsNotOption(GameOptionTypes.GAMEOPTION_NO_HAPPINESS)
	g_isReligionEnabled = GameIsNotOption(GameOptionTypes.GAMEOPTION_NO_RELIGION)
	g_isNoob = OptionsManager.IsNoBasicHelp and not OptionsManager.IsNoBasicHelp()
	g_lastPlot = false
	return ResetTimer()
end
Events.GameOptionsChanged.Add( UpdateOptions )
UpdateOptions()

-------------------------------------------------
ContextPtr:SetInputHandler(
function( uiMsg ) --, wParam, lParam )
	if uiMsg == MouseEvents_MouseMove then
		local x, y = GetMouseDelta()
		if x ~= 0 or y ~= 0 then
			return ResetTimer()
		end
	end
end)

-------------------------------------------------
Events.CameraViewChanged.Add( ResetTimer )
if civ5_mode then
	Events.StrategicViewStateChanged.Add( ResetTimer )
end
Events.SerialEventUnitInfoDirty.Add( function()
	g_lastPlot = false
	g_tipLevel = -1
end)
Events.WorldMouseOver( true )

-------------------------------------------------
Timer:RegisterAnimCallback( function()
	g_tipLevel = g_tipLevel + 1
	if g_tipLevel == 1 then
		Timer:SetPauseTime( g_tipTimer2 )
	elseif g_tipLevel == 2 then
		Timer:Stop()
	else
		--print("Unexpected plothelp tip level", g_tipLevel)
		return ResetTimer()
	end
	local plot = g_plot
	local tips
	if plot == g_lastPlot then
		tips = g_lastTips[ g_tipLevel ]
	else
		g_lastTips = { false, false, false }
		g_lastPlot = plot
	end
	if civ5_mode and MouseOverStrategicViewResource() then
		-- Resource Tool Tip
		tips = g_lastTips[ 3 ]
		if not tips then
			tips = plot and plot:IsRevealed( Game.GetActiveTeam(), false ) and GenerateResourceToolTip( plot )
			g_lastTips[ 3 ] = tips
		end
	elseif not tips then
		ClearOverlays()
		tips = PlotToolTips( plot, g_tipLevel > 1 )
		g_lastTips[ g_tipLevel ] = tips
	end
	if #(tips or "") > 0 then
		if g_lastTip ~= tips then
			g_lastTip = tips
			TipText:SetText( tips )
			TipGrid:DoAutoSize()
		end
		TipArea:SetToolTipType( g_PlotHelpToolTip )
	else
		TipArea:SetToolTipType()
	end
end)

LuaEvents.PlotHelpToolTip.Add( function( control )
	if control then
		g_PlotHelpToolTip = nil
		TipGrid:ChangeParent( control )
		TipGrid:SetAnchor( "R,B" )
	else
		g_PlotHelpToolTip = "PlotHelpToolTip"
		TipGrid:ChangeParent( tipControlTable.PlotHelpToolTip )
		TipGrid:SetAnchor( "L,T" )
	end
end)
LuaEvents.PlotHelpToolTip()
ContextPtr:SetShutdown( LuaEvents.PlotHelpToolTip.Call )

print("Finished loading EUI plot help",os.clock())
end)
