
-------------------------------------------------
-- Game View 
--
-- this is the parent of both WorldView and CityView
--
-- This is the final lua message handler that will be 
-- processed in the processing chain, after this is 
-- it is in engine side C++
-------------------------------------------------
include( "FLuaVector" );
include( "InstanceManager" );
include( "Bombardment");

local g_InstanceManager = InstanceManager:new( "AlertMessageInstance", "AlertMessageLabel", Controls.AlertStack );
local g_PopupIM = InstanceManager:new( "PopupText", "Anchor", Controls.PopupTextContainer );
local g_InstanceMap = {};

local alertTable = {};
local mustRefreshAlerts = false;

local bHideDebug = true;
local g_ShowWorkerRecommendation = not Game.IsNetworkMultiPlayer();
local lastCityEntered = nil;
local lastCityEnteredPlot = nil;
local aWorkerSuggestHighlightPlots;
local aFounderSuggestHighlightPlots;
local bCityScreenOpen = false;

local genericUnitHexBorder = "GUHB";
local pathBorderStyle = "MovementRangeBorder";
local attackPathBorderStyle = "AMRBorder"; -- attack move

local workerSuggestHighlightColor = Vector4( 0.0, 0.5, 1.0, 0.65 );

local InterfaceModeMessageHandler = 
{
	[InterfaceModeTypes.INTERFACEMODE_DEBUG] = {},
	[InterfaceModeTypes.INTERFACEMODE_SELECTION] = {},
	[InterfaceModeTypes.INTERFACEMODE_PING] = {},
	[InterfaceModeTypes.INTERFACEMODE_MOVE_TO] = {},
	[InterfaceModeTypes.INTERFACEMODE_MOVE_TO_TYPE] = {},
	[InterfaceModeTypes.INTERFACEMODE_MOVE_TO_ALL] = {},
	[InterfaceModeTypes.INTERFACEMODE_ROUTE_TO] = {},
	[InterfaceModeTypes.INTERFACEMODE_AIRLIFT] = {},
	[InterfaceModeTypes.INTERFACEMODE_NUKE] = {},
	[InterfaceModeTypes.INTERFACEMODE_PARADROP] = {},
	[InterfaceModeTypes.INTERFACEMODE_ATTACK] = {},
	[InterfaceModeTypes.INTERFACEMODE_RANGE_ATTACK] = {},
	[InterfaceModeTypes.INTERFACEMODE_CITY_RANGE_ATTACK] = {},
	[InterfaceModeTypes.INTERFACEMODE_AIRSTRIKE] = {},
	[InterfaceModeTypes.INTERFACEMODE_AIR_SWEEP] = {},
	[InterfaceModeTypes.INTERFACEMODE_REBASE] = {},
	[InterfaceModeTypes.INTERFACEMODE_PLACE_UNIT] = {},
	[InterfaceModeTypes.INTERFACEMODE_EMBARK] = {},
	[InterfaceModeTypes.INTERFACEMODE_DISEMBARK] = {},
	[InterfaceModeTypes.INTERFACEMODE_GIFT_UNIT] = {},
	[InterfaceModeTypes.INTERFACEMODE_GIFT_TILE_IMPROVEMENT] = {},
};

local DefaultMessageHandler = {};

DefaultMessageHandler[KeyEvents.KeyDown] =
function( wParam, lParam )
	if( wParam == Keys.VK_ESCAPE ) then
	    UIManager:QueuePopup( Controls.GameMenu, PopupPriority.InGameMenu );
        return true;
    end
    return false;
end


DefaultMessageHandler[KeyEvents.KeyUp] =
function( wParam, lParam )

    if ( wParam == Keys.VK_OEM_3 and UI:ShiftKeyDown() and UI:DebugFlag() and PreGame.IsMultiplayerGame()) then -- shift - ~
        Controls.NetworkDebug:SetHide( not Controls.NetworkDebug:IsHidden() );
        return true;
        
	elseif ( wParam == Keys.VK_OEM_3 and UI:DebugFlag() and not PreGame.IsMultiplayerGame() and not PreGame.IsHotSeatGame()) then -- ~
        bHideDebug = not bHideDebug;
        Controls.DebugMenu:SetHide( bHideDebug );
        return true;
        
    elseif ( wParam == Keys.Z and UIManager:GetControl() and UI:DebugFlag() and not PreGame.IsMultiplayerGame() and not PreGame.IsHotSeatGame()) then
        Game.ToggleDebugMode();
		local pPlot;
		local team = Game.GetActiveTeam();
		local bIsDebug = Game.IsDebugMode();

		for iPlotLoop = 0, Map.GetNumPlots()-1, 1 do
			pPlot = Map.GetPlotByIndex(iPlotLoop);

			if (pPlot:GetVisibilityCount() > 0) then
				pPlot:ChangeVisibilityCount(team, -1, -1, true, true);
			end
			pPlot:SetRevealed(team, false);

			pPlot:ChangeVisibilityCount(team, 1, -1, true, true);
			pPlot:SetRevealed(team, bIsDebug);
		end       
		return true;
    elseif ( wParam == Keys.G ) then
		UI.ToggleGridVisibleMode();
		return true;
    end
    return false;
end

-- add all of the Interface Mode specific handling

----------------------------------------------------------
----------------------------------------------------------
function ClickSelect( wParam, lParam )

end



function EjectHandler( wParam, lParam )
	local plot = Map.GetPlot( UI.GetMouseOverHex() );
	local plotX = plot:GetX();
	local plotY = plot:GetY();
	--print("INTERFACEMODE_PLACE_UNIT");
		
	local unit = UI.GetPlaceUnit();
	UI.ClearPlaceUnit();	
	local returnValue = false;
		
	if (unit ~= nil) then
		--print("INTERFACEMODE_PLACE_UNIT - got placed unit");
		local city = unitPlot:GetPlotCity();
		if (city ~= nil) then
			--print("INTERFACEMODE_PLACE_UNIT - not nil city");
			if UI.CanPlaceUnitAt(unit, plot) then
				--print("INTERFACEMODE_PLACE_UNIT - Can eject unit");
				--Network.SendCityEjectGarrisonChoice(city:GetID(), plotX, plotY);
				returnValue =  true;					
			end
		end
	end
	
	UI.SetInterfaceMode(InterfaceModeTypes.INTERFACEMODE_SELECTION);
	
	return returnValue;
end
InterfaceModeMessageHandler[InterfaceModeTypes.INTERFACEMODE_PLACE_UNIT][MouseEvents.LButtonUp] = EjectHandler;
InterfaceModeMessageHandler[InterfaceModeTypes.INTERFACEMODE_PLACE_UNIT][MouseEvents.RButtonUp] = EjectHandler;
InterfaceModeMessageHandler[InterfaceModeTypes.INTERFACEMODE_PLACE_UNIT][MouseEvents.PointerUp] = EjectHandler;

function GiftUnit( wParam, lParam )
	local returnValue = false;
	
	local plot = Map.GetPlot( UI.GetMouseOverHex() );
	local plotX = plot:GetX();
	local plotY = plot:GetY();
	
	local iToPlayer = UI.GetInterfaceModeValue();
	local iPlayerID = Game.GetActivePlayer();
	local player = Players[iPlayerID];

	if (player == nil) then
		print("Error - player index not correct");		
		return;	
	end
	
	
	local pUnit = nil;
    local unitCount = plot:GetNumUnits();
    
    for i = 0, unitCount - 1, 1
    do
    	local pFoundUnit = plot:GetUnit(i);
		if (pFoundUnit:GetOwner() == iPlayerID) then
			pUnit = pFoundUnit;
		end
    end
		
	if (pUnit) then
		
		if (pUnit:CanDistanceGift(iToPlayer)) then
			
			--print("Picked unit");
			returnValue = true;
			
			--print("iPlayerID " .. iPlayerID);
			--print("Other player id (interfacemodevalue) " .. UI.GetInterfaceModeValue());
			--print("UnitID " .. pUnit:GetID());
			
			local popupInfo = {
				Type = ButtonPopupTypes.BUTTONPOPUP_GIFT_CONFIRM,
				Data1 = iPlayerID;
				Data2 = iToPlayer;
				Data3 = pUnit:GetID();
			}
			Events.SerialEventGameMessagePopup(popupInfo);
		end
	end
	
	UI.SetInterfaceMode(InterfaceModeTypes.INTERFACEMODE_SELECTION);
	
	return returnValue;
end

InterfaceModeMessageHandler[InterfaceModeTypes.INTERFACEMODE_GIFT_UNIT][MouseEvents.LButtonUp] = GiftUnit;
InterfaceModeMessageHandler[InterfaceModeTypes.INTERFACEMODE_GIFT_UNIT][MouseEvents.RButtonUp] = GiftUnit;
InterfaceModeMessageHandler[InterfaceModeTypes.INTERFACEMODE_GIFT_UNIT][MouseEvents.PointerUp] = GiftUnit;

function AttackIntoTile( wParam, lParam)
	--print("Calling attack into tile");
	local returnValue = false;
	
	local iPlayerID = Game.GetActivePlayer();
	local player = Players[iPlayerID];

	if (player == nil) then
		print("Error - player index not correct");		
		return;	
	end
	
	local plot = Map.GetPlot( UI.GetMouseOverHex() );
	local plotX = plot:GetX();
	local plotY = plot:GetY();	

	local pUnit = UI.GetHeadSelectedUnit();
	
	if (plot:IsVisible(player:GetTeam(), false) and (plot:IsVisibleEnemyUnit(pUnit) or plot:IsEnemyCity(pUnit))) then
		Game.SelectionListMove(plot, false, false, false);
		returnValue = true;
	end
    
	ClearUnitHexHighlights();
	UI.SetInterfaceMode(InterfaceModeTypes.INTERFACEMODE_SELECTION);
	return returnValue;
end

InterfaceModeMessageHandler[InterfaceModeTypes.INTERFACEMODE_ATTACK][MouseEvents.LButtonUp] = AttackIntoTile;
InterfaceModeMessageHandler[InterfaceModeTypes.INTERFACEMODE_ATTACK][MouseEvents.RButtonUp] = AttackIntoTile;
InterfaceModeMessageHandler[InterfaceModeTypes.INTERFACEMODE_ATTACK][MouseEvents.PointerUp] = AttackIntoTile;


------------------------------------------
-- Gifting a tile improvement (to a city-state)
------------------------------------------
function GiftTileImprovement( wParam, lParam )
	local returnValue = false;
	
	local pPlot = Map.GetPlot( UI.GetMouseOverHex() );
	local iFromPlayer = Game.GetActivePlayer();
	local iToPlayer = UI.GetInterfaceModeValue();
	local pToPlayer = Players[iToPlayer];
	
	if (pPlot == nil) then
		print("Error - pPlot is nil");
		return false;
	end
	
	if (pToPlayer == nil) then
		print("Error - pToPlayer is nil");
		return false;
	end
	
	local iPlotX = pPlot:GetX();
	local iPlotY = pPlot:GetY();
	if (pToPlayer:CanMajorGiftTileImprovementAtPlot(iFromPlayer, iPlotX, iPlotY)) then
		Game.DoMinorGiftTileImprovement(iFromPlayer, iToPlayer, iPlotX, iPlotY);
	end
	
	UI.SetInterfaceMode(InterfaceModeTypes.INTERFACEMODE_SELECTION);
	
	return returnValue;
end
InterfaceModeMessageHandler[InterfaceModeTypes.INTERFACEMODE_GIFT_TILE_IMPROVEMENT][MouseEvents.LButtonUp] = GiftTileImprovement;
InterfaceModeMessageHandler[InterfaceModeTypes.INTERFACEMODE_GIFT_TILE_IMPROVEMENT][MouseEvents.RButtonUp] = GiftTileImprovement;
InterfaceModeMessageHandler[InterfaceModeTypes.INTERFACEMODE_GIFT_TILE_IMPROVEMENT][MouseEvents.PointerUp] = GiftTileImprovement;
----------------------------------------------------------------        
-- Input handling
----------------------------------------------------------------        
function InputHandler( uiMsg, wParam, lParam )
	local interfaceMode = UI.GetInterfaceMode();
	local currentInterfaceModeHandler = InterfaceModeMessageHandler[interfaceMode];
	if currentInterfaceModeHandler and currentInterfaceModeHandler[uiMsg] then
		return currentInterfaceModeHandler[uiMsg]( wParam, lParam );
	elseif DefaultMessageHandler[uiMsg] then
		return DefaultMessageHandler[uiMsg]( wParam, lParam );
	end
	return false;
end
ContextPtr:SetInputHandler( InputHandler );


-------------------------------------------------
-------------------------------------------------
function SetRecommendationCheck(value)	
	-- Value is true if recommendations are hidden.
	g_ShowWorkerRecommendation = not value;
	OnUpdateSelection( value );
end
LuaEvents.OnRecommendationCheckChanged.Add( SetRecommendationCheck );

----------------------------------------------------------------        
---------------------------------------------------------------- 
function OnGameOptionsChanged()
	local value = not OptionsManager.IsNoTileRecommendations();
	g_ShowWorkerRecommendation = value;
	OnUpdateSelection( value );
end
Events.GameOptionsChanged.Add(OnGameOptionsChanged);

----------------------------------------------------------------        
----------------------------------------------------------------        


----------------------------------------------------------------        
----------------------------------------------------------------        


----------------------------------------------------------------        
----------------------------------------------------------------        
function OnGameplayAlertMessage( data )
	local newAlert = {};
	newAlert.text = data;
	newAlert.elapsedTime = 0;
	newAlert.shownYet = false;
	table.insert(alertTable,newAlert);
	mustRefreshAlerts = true;
end
Events.GameplayAlertMessage.Add( OnGameplayAlertMessage );

----------------------------------------------------------------        
-- Allow Lua to do any post and pre-processing of the InterfaceMode change
----------------------------------------------------------------       

-- add any functions that you want to have called to the handler table
local giftUnitColor = Vector4( 1.0, 1.0, 0.0, 0.65 );

function HighlightGiftUnits ()
	
	local iPlayerID = Game.GetActivePlayer();
	local player = Players[iPlayerID];
	
	if (player == nil) then
		print("Error - player index not correct");		
		return;	
	end
	
	local iToPlayer = UI.GetInterfaceModeValue();
	
	--print("iToPlayer: " .. iToPlayer);
	
	for unit in player:Units() do
		if (unit:CanDistanceGift(iToPlayer)) then
			local hexID = ToHexFromGrid( Vector2( unit:GetX(), unit:GetY() ) );
			Events.SerialEventHexHighlight( hexID, true, Vector4( 1.0, 1.0, 0.0, 1 ), genericUnitHexBorder );
		end
	end
    
end


local embarkColor = Vector4( 1.0, 1.0, 0.0, 0.65 );

function HighlightEmbarkPlots()
	local unit = UI.GetHeadSelectedUnit();
	if not unit then
		return;
	end
	
	local checkFunction = nil;
	if unit:IsEmbarked() then
		checkFunction = function(targetPlot) 
			return unit:CanDisembarkOnto(targetPlot) 
		end;
	else
		checkFunction = function(targetPlot)
			return unit:CanEmbarkOnto(unit:GetPlot(), targetPlot);
		end;
	end
	
	local unitTeam = unit:GetTeam();
	local unitX = unit:GetX();
	local unitY = unit:GetY();
	
	local iRange = 1;
	for iX = -iRange, iRange, 1 do
		for iY = -iRange, iRange, 1 do
			local evalPlot = Map.PlotXYWithRangeCheck(unitX, unitY, iX, iY, iRange);
			if evalPlot then
				local evalPlotX = evalPlot:GetX();
				local evalPlotY = evalPlot:GetY();
				if evalPlotX ~= unitX or evalPlotY ~= unitY then -- we are looking at a different plot than us
					if evalPlot:IsRevealed(unitTeam, false) then
						if checkFunction(evalPlot) then -- tricky
							local hexID = ToHexFromGrid( Vector2( evalPlotX, evalPlotY ) );
							Events.SerialEventHexHighlight( hexID, true, embarkColor, genericUnitHexBorder );
						end
					end
				end
			end
		end
	end
end

local upgradeColor = Vector4( 0.0, 1.0, 0.5, 0.65 );

function HighlightUpgradePlots()
	local unit = UI.GetHeadSelectedUnit();
	if not unit then
		return;
	end
	
	local unitX = unit:GetX();
	local unitY = unit:GetY();

	for thisDirection = 0, (DirectionTypes.NUM_DIRECTION_TYPES-1), 1 do
		local adjacentPlot = Map.PlotDirection(unitX, unitY, thisDirection);
		if (adjacentPlot) then
			local adjacentUnit = unit:GetUpgradeUnitFromPlot(adjacentPlot);
			if adjacentUnit then
				local hexID = ToHexFromGrid( Vector2( adjacentPlot:GetX(), adjacentPlot:GetY() ) );
				Events.SerialEventHexHighlight( hexID, true, upgradeColor, genericUnitHexBorder );
			end
		end
	end
end

function ClearAllHighlights()
	--Events.ClearHexHighlights(); other systems might be using these!
	Events.ClearHexHighlightStyle("");
	Events.ClearHexHighlightStyle(pathBorderStyle);
	Events.ClearHexHighlightStyle(attackPathBorderStyle);
	Events.ClearHexHighlightStyle(genericUnitHexBorder);  
	Events.ClearHexHighlightStyle("FireRangeBorder");
	Events.ClearHexHighlightStyle("GroupBorder");
	Events.ClearHexHighlightStyle("ValidFireTargetBorder");
end

function ClearUnitHexHighlights()
	Events.ClearHexHighlightStyle(pathBorderStyle);
	Events.ClearHexHighlightStyle(attackPathBorderStyle);
	Events.ClearHexHighlightStyle(genericUnitHexBorder);  
	Events.ClearHexHighlightStyle("FireRangeBorder");
	Events.ClearHexHighlightStyle("GroupBorder");
	Events.ClearHexHighlightStyle("ValidFireTargetBorder");
end;

function ShowMovementRangeIndicator()
	local unit = UI.GetHeadSelectedUnit();
	if not unit then
		return;
	end
	
	local iPlayerID = Game.GetActivePlayer();

	Events.ShowMovementRange( iPlayerID, unit:GetID() );
	UI.SendPathfinderUpdate();
	Events.DisplayMovementIndicator( true );
end

function HideMovementRangeIndicator()
	ClearUnitHexHighlights();
	Events.DisplayMovementIndicator( false );
end


function ShowRebaseRangeIndicator()
	local pHeadSelectedUnit = UI.GetHeadSelectedUnit();
	if not pHeadSelectedUnit then
		return;
	end
	
	local iRange= pHeadSelectedUnit:Range();
	
	print("iRange: " .. iRange);
	
	iRange = iRange * GameDefines.AIR_UNIT_REBASE_RANGE_MULTIPLIER;
	iRange = iRange / 100;

	print("iRange: " .. iRange);
	
	local thisPlot = pHeadSelectedUnit:GetPlot();
	local thisX = pHeadSelectedUnit:GetX();
	local thisY = pHeadSelectedUnit:GetY();
	
	for iDX = -iRange, iRange, 1 do
		for iDY = -iRange, iRange, 1 do
			local pTargetPlot = Map.GetPlotXY(thisX, thisY, iDX, iDY);
			if pTargetPlot ~= nil then
				local plotX = pTargetPlot:GetX();
				local plotY = pTargetPlot:GetY();
				local plotDistance = Map.PlotDistance(thisX, thisY, plotX, plotY);
				if plotDistance <= iRange then
					local hexID = ToHexFromGrid( Vector2( plotX, plotY) );
					--Events.SerialEventHexHighlight( hexID, true, turn1Color, pathBorderStyle );
					if pHeadSelectedUnit:CanRebaseAt(thisPlot,plotX,plotY) then
						Events.SerialEventHexHighlight( hexID, true, turn2Color, "GroupBorder" );
					end
				end
			end
		end
	end

end

function HideRebaseRangeIndicator()
	ClearUnitHexHighlights();
end


function ShowParadropRangeIndicator()
	local pHeadSelectedUnit = UI.GetHeadSelectedUnit();
	if not pHeadSelectedUnit then
		return;
	end
	
	local thisPlot = pHeadSelectedUnit:GetPlot();
	if pHeadSelectedUnit:CanParadrop(thisPlot, false) then
		local iRange= pHeadSelectedUnit:GetDropRange();
		print("irange: "..tostring(iRange))
		local thisX = pHeadSelectedUnit:GetX();
		local thisY = pHeadSelectedUnit:GetY();
		
		for iDX = -iRange, iRange, 1 do
			for iDY = -iRange, iRange, 1 do
				local pTargetPlot = Map.GetPlotXY(thisX, thisY, iDX, iDY);
				if pTargetPlot ~= nil then
					local plotX = pTargetPlot:GetX();
					local plotY = pTargetPlot:GetY();
					local plotDistance = Map.PlotDistance(thisX, thisY, plotX, plotY);
					if plotDistance <= iRange then
						if pHeadSelectedUnit:CanParadropAt(thisPlot, plotX, plotY) then
							local hexID = ToHexFromGrid( Vector2( plotX, plotY) );
							Events.SerialEventHexHighlight( hexID, true, turn1Color, pathBorderStyle );
						end
					end
				end
			end
		end
	end
end

function HideParadropRangeIndicator()
	ClearUnitHexHighlights();
end

function ShowAirliftRangeIndicator()

	print ("In ShowAirliftRangeIndicator()");
	
	local pHeadSelectedUnit = UI.GetHeadSelectedUnit();
	if not pHeadSelectedUnit then
		return;
	end
	
	local thisPlot = pHeadSelectedUnit:GetPlot();
	if pHeadSelectedUnit:CanAirlift(thisPlot, false) then		
		for iPlotLoop = 0, Map.GetNumPlots()-1, 1 do
			pPlot = Map.GetPlotByIndex(iPlotLoop);
			local plotX = pPlot:GetX();
			local plotY = pPlot:GetY();
			if pHeadSelectedUnit:CanAirliftAt(thisPlot, plotX, plotY) then
				local hexID = ToHexFromGrid( Vector2( plotX, plotY) );
				Events.SerialEventHexHighlight( hexID, true, turn1Color, pathBorderStyle );
			end
		end
	end
end

function HideAirliftRangeIndicator()
	print ("In HideAirliftRangeIndicator()");
	
	ClearUnitHexHighlights();
end

function ShowAttackTargetsIndicator()
	local unit = UI.GetHeadSelectedUnit();
	if not unit then
		return;
	end;
	
	local iPlayerID = Game.GetActivePlayer();
	Events.ShowAttackTargets(iPlayerID, unit:GetID());
end


local vGiftTileImprovementColor = Vector4( 1.0, 0.0, 1.0, 1.0 );

function HighlightImprovableCityStatePlots()
	local iFromPlayer = Game.GetActivePlayer();
	local iToPlayer = UI.GetInterfaceModeValue();
	local pToPlayer = Players[iToPlayer];
	if (pToPlayer == nil) then
		print("Error - pToPlayer is nil");
		return;
	end
	
	print("iToPlayer: " .. iToPlayer);
	
	local pCityStateCity = Players[iToPlayer]:GetCapitalCity()
	if (pCityStateCity == nil) then
		print("Error - pCityStateCity is nil");
		return;
	end
	
	local iCityStateX = pCityStateCity:GetX();
	local iCityStateY = pCityStateCity:GetY();
	
	local iRange = GameDefines["MINOR_CIV_RESOURCE_SEARCH_RADIUS"];
	for iX = -iRange, iRange, 1 do
		for iY = -iRange, iRange, 1 do
			local pPlot = Map.PlotXYWithRangeCheck(iCityStateX, iCityStateY, iX, iY, iRange);
			if (pPlot) then
				local iPlotX = pPlot:GetX();
				local iPlotY = pPlot:GetY();
				if (pToPlayer:CanMajorGiftTileImprovementAtPlot(iFromPlayer, iPlotX, iPlotY)) then
					local iHexID = ToHexFromGrid( Vector2( iPlotX, iPlotY) );
					Events.SerialEventHexHighlight( iHexID, true, vGiftTileImprovementColor, genericUnitHexBorder );
				end
			end
		end
	end
end

local vPossibleTradeRouteColor = Vector4( 1.0, 0.0, 1.0, 1.0 );

function HighlightPossibleTradeCities()
	--print("HighlightPossibleTradeCities");
	local pHeadSelectedUnit = UI.GetHeadSelectedUnit();
	if not pHeadSelectedUnit then
		return;
	end
	
	local iActivePlayer = Game.GetActivePlayer();
	local pActivePlayer = Players[iActivePlayer];
	local thisPlot = pHeadSelectedUnit:GetPlot();
	if pHeadSelectedUnit:CanMakeTradeRoute(thisPlot, false) then
		local potentialTradeSpots = pActivePlayer:GetPotentialInternationalTradeRouteDestinations(pHeadSelectedUnit);
		for i,v in ipairs(potentialTradeSpots) do
			local hexID = ToHexFromGrid( Vector2( v.X, v.Y) );
			Events.SerialEventHexHighlight( hexID, true, vPossibleTradeRouteColor, genericUnitHexBorder );
		end
	end
end

--function EnterCityPlotSelection()
    --if( lastCityEntered ~= nil ) then
		--Events.RequestYieldDisplay( YieldDisplayTypes.CITY_OWNED, lastCityEntered:GetX(), lastCityEntered:GetY() );
	--end
--end
--
--function ExitCityPlotSelection()
	--if( lastCityEntered ~= nil ) then
		--Events.RequestYieldDisplay( YieldDisplayTypes.CITY_WORKED, lastCityEntered:GetX(), lastCityEntered:GetY() );
	--end
--end
--
-- don't actually add the nils to the table
local OldInterfaceModeChangeHandler = 
{
	--[InterfaceModeTypes.INTERFACEMODE_DEBUG] = nil,
	--[InterfaceModeTypes.INTERFACEMODE_SELECTION] = nil,
	--[InterfaceModeTypes.INTERFACEMODE_PING] = nil,
	[InterfaceModeTypes.INTERFACEMODE_MOVE_TO] = HideMovementRangeIndicator,
	--[InterfaceModeTypes.INTERFACEMODE_MOVE_TO_TYPE] = nil,
	--[InterfaceModeTypes.INTERFACEMODE_MOVE_TO_ALL] = nil,
	--[InterfaceModeTypes.INTERFACEMODE_ROUTE_TO] = nil,
	[InterfaceModeTypes.INTERFACEMODE_AIRLIFT] = HideAirliftRangeIndicator,
	[InterfaceModeTypes.INTERFACEMODE_NUKE] = EndNukeAttack,
	[InterfaceModeTypes.INTERFACEMODE_PARADROP] = HideParadropRangeIndicator,
	[InterfaceModeTypes.INTERFACEMODE_ATTACK] = ClearUnitHexHighlights,
	[InterfaceModeTypes.INTERFACEMODE_RANGE_ATTACK] = EndRangedAttack,
	[InterfaceModeTypes.INTERFACEMODE_CITY_RANGE_ATTACK] = EndRangedAttack,
	[InterfaceModeTypes.INTERFACEMODE_AIRSTRIKE] = EndAirAttack,
	--[InterfaceModeTypes.INTERFACEMODE_AIR_SWEEP] = nil,
	[InterfaceModeTypes.INTERFACEMODE_REBASE] = HideRebaseRangeIndicator,
	[InterfaceModeTypes.INTERFACEMODE_PLACE_UNIT] = ClearUnitHexHighlights,
	[InterfaceModeTypes.INTERFACEMODE_EMBARK] = ClearUnitHexHighlights,
	[InterfaceModeTypes.INTERFACEMODE_DISEMBARK] = ClearUnitHexHighlights,
	[InterfaceModeTypes.INTERFACEMODE_GIFT_UNIT] = ClearUnitHexHighlights,
	--[InterfaceModeTypes.INTERFACEMODE_CITY_PLOT_SELECTION] = ExitCityPlotSelection
	--[InterfaceModeTypes.INTERFACEMODE_PURCHASE_PLOT] = ClearUnitHexHighlights
	[InterfaceModeTypes.INTERFACEMODE_GIFT_TILE_IMPROVEMENT] = ClearUnitHexHighlights,
};

local NewInterfaceModeChangeHandler = 
{
	--[InterfaceModeTypes.INTERFACEMODE_DEBUG] = nil,
	[InterfaceModeTypes.INTERFACEMODE_SELECTION] = ClearUnitHexHighlights,
	--[InterfaceModeTypes.INTERFACEMODE_PING] = nil,
	[InterfaceModeTypes.INTERFACEMODE_MOVE_TO] = ShowMovementRangeIndicator,
	--[InterfaceModeTypes.INTERFACEMODE_MOVE_TO_TYPE] = nil,
	--[InterfaceModeTypes.INTERFACEMODE_MOVE_TO_ALL] = nil,
	--[InterfaceModeTypes.INTERFACEMODE_ROUTE_TO] = nil,
	[InterfaceModeTypes.INTERFACEMODE_AIRLIFT] = ShowAirliftRangeIndicator,
	[InterfaceModeTypes.INTERFACEMODE_NUKE] = BeginNukeAttack,
	[InterfaceModeTypes.INTERFACEMODE_PARADROP] = ShowParadropRangeIndicator,
	[InterfaceModeTypes.INTERFACEMODE_ATTACK] = ShowAttackTargetsIndicator,
	[InterfaceModeTypes.INTERFACEMODE_RANGE_ATTACK] = BeginRangedAttack,
	[InterfaceModeTypes.INTERFACEMODE_CITY_RANGE_ATTACK] = BeginRangedAttack,
	[InterfaceModeTypes.INTERFACEMODE_AIRSTRIKE] = BeginAirAttack,
	--[InterfaceModeTypes.INTERFACEMODE_AIR_SWEEP] = nil,
	[InterfaceModeTypes.INTERFACEMODE_REBASE] = ShowRebaseRangeIndicator,
	[InterfaceModeTypes.INTERFACEMODE_PLACE_UNIT] = nil, -- this actually has some special case code with it in CityBannerManager and/or CityView
	[InterfaceModeTypes.INTERFACEMODE_EMBARK] = HighlightEmbarkPlots,
	[InterfaceModeTypes.INTERFACEMODE_DISEMBARK] = HighlightEmbarkPlots,
	[InterfaceModeTypes.INTERFACEMODE_GIFT_UNIT] = HighlightGiftUnits,
	--[InterfaceModeTypes.INTERFACEMODE_CITY_PLOT_SELECTION] = EnterCityPlotSelection
	--[InterfaceModeTypes.INTERFACEMODE_PURCHASE_PLOT] = nil
	[InterfaceModeTypes.INTERFACEMODE_GIFT_TILE_IMPROVEMENT] = HighlightImprovableCityStatePlots,
};

local defaultCursor = GameInfoTypes[GameInfo.InterfaceModes[InterfaceModeTypes.INTERFACEMODE_SELECTION].CursorType];

----------------------------------------------------------------        
----------------------------------------------------------------        
function OnInterfaceModeChanged( oldInterfaceMode, newInterfaceMode)
	print("OnInterfaceModeChanged");
	print("oldInterfaceMode: " .. oldInterfaceMode);
	print("newInterfaceMode: " .. newInterfaceMode);
	if (oldInterfaceMode ~= newInterfaceMode) then
		-- do any cleanup of the old mode
		local oldInterfaceModeHandler = OldInterfaceModeChangeHandler[oldInterfaceMode];
		if oldInterfaceModeHandler then
			oldInterfaceModeHandler();
		end
		
		-- update the cursor to reflect this mode - these cursor are defined in Civ5CursorInfo.xml
		local cursorIndex = GameInfoTypes[GameInfo.InterfaceModes[newInterfaceMode].CursorType];
		if cursorIndex then
			UIManager:SetUICursor(cursorIndex);
		else
			UIManager:SetUICursor(defaultCursor);
		end
		
		-- do any setup for the new mode
		local newInterfaceModeHandler = NewInterfaceModeChangeHandler[newInterfaceMode];
		if newInterfaceModeHandler then
			newInterfaceModeHandler();
		end
	end
end
Events.InterfaceModeChanged.Add( OnInterfaceModeChanged );


----------------------------------------------------------------        
----------------------------------------------------------------        
function OnActivePlayerTurnEnd()
	UIManager:SetUICursor(1); -- busy
end
Events.ActivePlayerTurnEnd.Add( OnActivePlayerTurnEnd );

function OnActivePlayerTurnStart()
	local interfaceMode = UI.GetInterfaceMode();
	local cursorIndex = GameInfoTypes[GameInfo.InterfaceModes[interfaceMode].CursorType];
	if cursorIndex then
		UIManager:SetUICursor(cursorIndex);
	else
		UIManager:SetUICursor(defaultCursor);
	end
end
Events.ActivePlayerTurnStart.Add( OnActivePlayerTurnStart );

----------------------------------------------------------------
-- 'Active' (local human) player has changed
----------------------------------------------------------------
function OnActivePlayerChanged(iActivePlayer, iPrevActivePlayer)

	-- Reset the alert table and display
	alertTable = {};
	g_InstanceManager:ResetInstances();	
	KillAllPopupText();
	mustRefreshAlerts = false;	
end
Events.GameplaySetActivePlayer.Add(OnActivePlayerChanged);

----------------------------------------------------------------        
----------------------------------------------------------------        
function OnUnitSelectionChange( p, u, i, j, k, isSelected )
	local interfaceMode = UI.GetInterfaceMode();
	if interfaceMode ~= InterfaceModeTypes.INTERFACEMODE_CITY_RANGE_ATTACK then -- this is a bit hacky, but the order of event processing is what it is
		ClearUnitHexHighlights();
	end
	if interfaceMode ~= InterfaceModeTypes.INTERFACEMODE_SELECTION and interfaceMode ~= InterfaceModeTypes.INTERFACEMODE_CITY_RANGE_ATTACK then
		UI.SetInterfaceMode(InterfaceModeTypes.INTERFACEMODE_SELECTION);
	end
	OnUpdateSelection( isSelected );
end
Events.UnitSelectionChanged.Add( OnUnitSelectionChange );

function OnUpdateSelection( isSelected )
    RequestYieldDisplay();	

	local iPlayerID = Game.GetActivePlayer();
	local player = Players[iPlayerID];

	--print("Unit selection changed!");

	-- workers - clear old list first
	if (aWorkerSuggestHighlightPlots ~= nil) then
		for i, v in ipairs(aWorkerSuggestHighlightPlots) do
			if (v.plot ~= nil) then
				local hexID = ToHexFromGrid( Vector2( v.plot:GetX(), v.plot:GetY() ) );
				Events.GenericWorldAnchor( GenericWorldAnchorTypes.WORLD_ANCHOR_WORKER, false, v.plot:GetX(), v.plot:GetY(), v.buildType );
			end
		end
	end	
	aWorkerSuggestHighlightPlots = nil;
		
	-- founders - clear old list first
	if (aFounderSuggestHighlightPlots ~= nil) then
		for i, v in ipairs(aFounderSuggestHighlightPlots) do
			local hexID = ToHexFromGrid( Vector2( v:GetX(), v:GetY() ) );
			Events.GenericWorldAnchor( GenericWorldAnchorTypes.WORLD_ANCHOR_SETTLER, false, v:GetX(), v:GetY(), -1 );
		end
	end	
	aFounderSuggestHighlightPlots = nil;
		
	if isSelected ~= true then
		return
	end
	
	if (UI.CanSelectionListWork()) then
		--print("Can Selection List Work");
		aWorkerSuggestHighlightPlots = player:GetRecommendedWorkerPlots();

		-- Player can disable tile recommendations
		if (not OptionsManager.IsNoTileRecommendations()) then
			for i, v in ipairs(aWorkerSuggestHighlightPlots) do
				if (v.plot ~= nil) then
					local hexID = ToHexFromGrid( Vector2( v.plot:GetX(), v.plot:GetY() ) );
					if(g_ShowWorkerRecommendation) then
						Events.GenericWorldAnchor( GenericWorldAnchorTypes.WORLD_ANCHOR_WORKER, true, v.plot:GetX(), v.plot:GetY(), v.buildType );
					end
				end
			end
		end
	end
		
	if (UI.CanSelectionListFound() and player:GetNumCities() > 0) then
		if(g_ShowWorkerRecommendation) then
			aFounderSuggestHighlightPlots = player:GetRecommendedFoundCityPlots();
			--print("Founder check");
			--print("aFounderSuggestHighlightPlots " .. tostring(aFounderSuggestHighlightPlots));
		
			-- Player can disable tile recommendations
			if (not OptionsManager.IsNoTileRecommendations()) then
				for i, v in ipairs(aFounderSuggestHighlightPlots) do
					--print("founder highlight x: " .. v:GetX() .. " y: " .. v:GetY());
					local hexID = ToHexFromGrid( Vector2( v:GetX(), v:GetY() ) );
					Events.GenericWorldAnchor( GenericWorldAnchorTypes.WORLD_ANCHOR_SETTLER, true, v:GetX(), v:GetY(), -1 );
				end
			end
		end
	end
end
----------------------------------------------------------------        
----------------------------------------------------------------        
function OnUnitSelectionCleared()

    RequestYieldDisplay();	
	
	-- Clear Worker recommendations
	if (not UI.CanSelectionListWork()) then
		if (aWorkerSuggestHighlightPlots ~= nil) then
			for i, v in ipairs(aWorkerSuggestHighlightPlots) do
				if (v.plot ~= nil) then
					local hexID = ToHexFromGrid( Vector2( v.plot:GetX(), v.plot:GetY() ) );
					Events.GenericWorldAnchor( GenericWorldAnchorTypes.WORLD_ANCHOR_WORKER, false, v.plot:GetX(), v.plot:GetY(), v.buildType );
				end
			end
		end	
		aWorkerSuggestHighlightPlots = nil;
	end
	
	-- Clear Settler Recommendations
	if (not UI.CanSelectionListFound()) then
		if (aFounderSuggestHighlightPlots ~= nil) then
			for i, v in ipairs(aFounderSuggestHighlightPlots) do
				local hexID = ToHexFromGrid( Vector2( v:GetX(), v:GetY() ) );
				Events.GenericWorldAnchor( GenericWorldAnchorTypes.WORLD_ANCHOR_SETTLER, false, v:GetX(), v:GetY() );
			end
		end	
		aFounderSuggestHighlightPlots = nil;
	end
end
Events.UnitSelectionCleared.Add( OnUnitSelectionCleared );

-------------------------------------------------
-- On Unit Destroyed
-------------------------------------------------
function OnUnitDestroyed( playerID, unitID )
    if( playerID == Game.GetActivePlayer() ) then
        RequestYieldDisplay();
    end
end
Events.SerialEventUnitDestroyed.Add( OnUnitDestroyed );

----------------------------------------------------------------        
----------------------------------------------------------------        
function OnUpdate(fDTime)

	if #alertTable > 0 then
		for i, v in ipairs( alertTable ) do
			if v.shownYet == true then
				v.elapsedTime = v.elapsedTime + fDTime;
			end
			if v.elapsedTime >= 8 then
				mustRefreshAlerts = true;
			end
		end
		
		if mustRefreshAlerts then
			local newAlertTable = {};
			g_InstanceManager:ResetInstances();
			for i, v in ipairs( alertTable ) do
				if v.elapsedTime < 8 then
					v.shownYet = true;
					table.insert( newAlertTable, v );
				end
			end
			alertTable = newAlertTable;
			for i, v in ipairs( alertTable ) do
				local controlTable = g_InstanceManager:GetInstance();
				controlTable.AlertMessageLabel:SetText( v.text );
				Controls.AlertStack:CalculateSize();
				Controls.AlertStack:ReprocessAnchoring();
			end
		end

	end
	
	mustRefreshAlerts = false;
	
end
ContextPtr:SetUpdate( OnUpdate );


----------------------------------------------------------------        
----------------------------------------------------------------        
function AddPopupText( worldPosition, text, delay )
    local instance = g_PopupIM:GetInstance();
    instance.Anchor:SetWorldPosition( worldPosition );
    instance.Text:SetText( text );
    instance.AlphaAnimOut:RegisterAnimCallback( KillPopupText );
    instance.Anchor:BranchResetAnimation();
    instance.SlideAnim:SetPauseTime( delay );
    instance.AlphaAnimIn:SetPauseTime( delay );
    instance.AlphaAnimOut:SetPauseTime( delay + 0.75 );
    
    g_InstanceMap[ tostring( instance.AlphaAnimOut ) ] = instance;
end
Events.AddPopupTextEvent.Add( AddPopupText );


----------------------------------------------------------------        
----------------------------------------------------------------        
function KillPopupText( control )

	local szKey = tostring( control );
    local instance = g_InstanceMap[ szKey ];
    
    if( instance == nil )
    then
        print( "Error killing popup text" );
    else
        g_PopupIM:ReleaseInstance( instance );
        g_InstanceMap[ szKey ] = null;
    end
end

----------------------------------------------------------------        
----------------------------------------------------------------        
function KillAllPopupText( )

	for i, v in pairs(g_InstanceMap) do
		if (v ~= nil) then
	        g_PopupIM:ReleaseInstance( v );
		end
	end
	g_InstanceMap = {};
end


----------------------------------------------------------------        
----------------------------------------------------------------        
function OnUnitHexHighlight( i, j, k, bOn, unitId )

    --print( "GotEvent " .. unitId );
    local unit = UI.GetHeadSelectedUnit();
    
    if( unit ~= nil and
        unit:GetID() == unitId and
	    UI.CanSelectionListFound() ) then
	    
		-- Yield icons off by default
	    if (OptionsManager.IsCivilianYields()) then
			local gridX, gridY = ToGridFromHex( i, j );
			Events.RequestYieldDisplay( YieldDisplayTypes.AREA, 2, gridX, gridY );
		end
    end
    
end
Events.UnitHexHighlight.Add( OnUnitHexHighlight )


----------------------------------------------------------------        
----------------------------------------------------------------        
function RequestYieldDisplay()

	-- Yield icons off by default
	local bDisplayCivilianYields = OptionsManager.IsCivilianYields();
	
    local unit = UI.GetHeadSelectedUnit();
	
	local bShowYields = true;
    if( unit ~= nil ) then
		if (GameInfo.Units[unit:GetUnitType()].DontShowYields) then
			bShowYields = false;
		end
	end
	
	if( bDisplayCivilianYields and UI.CanSelectionListWork() and bShowYields) then
        Events.RequestYieldDisplay( YieldDisplayTypes.EMPIRE );
		
	elseif( bDisplayCivilianYields and UI.CanSelectionListFound() ) then
	    if( unit ~= nil ) then
            Events.RequestYieldDisplay( YieldDisplayTypes.AREA, 2, unit:GetX(), unit:GetY() );
		end
		
    elseif( not bCityScreenOpen ) then
        Events.RequestYieldDisplay( YieldDisplayTypes.AREA, 0 );
	end
end


----------------------------------------------------------------        
----------------------------------------------------------------        
local TOP    = 0;
local BOTTOM = 1;
local LEFT   = 2;
local RIGHT  = 3;
function ScrollMouseEnter( which )

    if( bCityScreenOpen ) then
        return;
    end;

    if( which == TOP ) then
		Events.SerialEventCameraStartMovingForward();
    elseif( which == BOTTOM ) then
		Events.SerialEventCameraStartMovingBack();
    elseif( which == LEFT ) then
		Events.SerialEventCameraStartMovingLeft();
    else
		Events.SerialEventCameraStartMovingRight();
    end
end

function ScrollMouseExit( which )

    if( bCityScreenOpen ) then
        return;
    end;

    if( which == TOP ) then
		Events.SerialEventCameraStopMovingForward();
    elseif( which == BOTTOM ) then
		Events.SerialEventCameraStopMovingBack();
    elseif( which == LEFT ) then
		Events.SerialEventCameraStopMovingLeft();
    else
		Events.SerialEventCameraStopMovingRight();
    end
end
Controls.ScrollTop:RegisterCallback( Mouse.eMouseEnter, ScrollMouseEnter );
Controls.ScrollTop:RegisterCallback( Mouse.eMouseExit, ScrollMouseExit );
Controls.ScrollTop:SetVoid1( TOP );
Controls.ScrollBottom:RegisterCallback( Mouse.eMouseEnter, ScrollMouseEnter );
Controls.ScrollBottom:RegisterCallback( Mouse.eMouseExit, ScrollMouseExit );
Controls.ScrollBottom:SetVoid1( BOTTOM );
Controls.ScrollLeft:RegisterCallback( Mouse.eMouseEnter, ScrollMouseEnter );
Controls.ScrollLeft:RegisterCallback( Mouse.eMouseExit, ScrollMouseExit );
Controls.ScrollLeft:SetVoid1( LEFT );
Controls.ScrollRight:RegisterCallback( Mouse.eMouseEnter, ScrollMouseEnter );
Controls.ScrollRight:RegisterCallback( Mouse.eMouseExit, ScrollMouseExit );
Controls.ScrollRight:SetVoid1( RIGHT );


-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
function SystemUpdateUIHandler( eType )
    if( eType == SystemUpdateUIType.BulkHideUI ) then
        Controls.BulkUI:SetHide( true );
    elseif( eType == SystemUpdateUIType.BulkShowUI ) then
        Controls.BulkUI:SetHide( false );
    end
end
Events.SystemUpdateUI.Add( SystemUpdateUIHandler )


---------------------------------------------------------------------------------------
function ShowHideHandler( bIsHide )
    if( not bIsHide ) then
        if( not OptionsManager.GetFullscreen() ) then
            Controls.ScreenEdgeScrolling:SetHide( true );
        end
        
        -- Check to see if we've been kicked.  It's possible that we were kicked while 
        -- loading into the game.
        if(Network.IsPlayerKicked(Game.GetActivePlayer())) then
					-- Display kicked popup.
					local popupInfo = 
					{
						Type  = ButtonPopupTypes.BUTTONPOPUP_KICKED,
						Data1 = NetKicked.BY_HOST
					};

					Events.SerialEventGameMessagePopup(popupInfo);
					UI.SetInterfaceMode(InterfaceModeTypes.INTERFACEMODE_SELECTION);
				end
        
        
		Controls.WorldViewControls:SetHide( false );
    end
end
ContextPtr:SetShowHideHandler( ShowHideHandler );

ClearAllHighlights();

---------------------------------------------------------------------------------------
-- Check to see if the world view controls should be hidden
function OnGameViewTypeChanged(eNewType)

	local bWorldViewHide = (GetGameViewRenderType() == GameViewTypes.GAMEVIEW_NONE);
	Controls.WorldViewControls:SetHide( bWorldViewHide );
	Controls.StagingRoom:SetHide( not bWorldViewHide );
	
end

Events.GameViewTypeChanged.Add(OnGameViewTypeChanged);


---------------------------------------------------------------------------------------
-- Support for Modded Add-in UI's
---------------------------------------------------------------------------------------

ContextPtr:LoadNewContext("Aesthetics0_OpenerAndFinisher")
ContextPtr:LoadNewContext("AustriaChanges")
ContextPtr:LoadNewContext("BuildingTreasury")
ContextPtr:LoadNewContext("CarthageChanges")
ContextPtr:LoadNewContext("ChinaChanges")
ContextPtr:LoadNewContext("Commerce4_Entrepreneurship")
ContextPtr:LoadNewContext("Exploration1_Colonialism")
ContextPtr:LoadNewContext("Exploration5_TreasureFleets")
ContextPtr:LoadNewContext("GreatWallChanges")
ContextPtr:LoadNewContext("GreeceChanges")
ContextPtr:LoadNewContext("HelicopterGunshipChanges")
ContextPtr:LoadNewContext("Patronage5_Consulates")
ContextPtr:LoadNewContext("T1_1EliteForces")
-------------------------------------------------
-- Game View
--
-- this is the parent of both WorldView and CityView
--
-- This is the final lua message handler that will be
-- processed in the processing chain, after this is
-- it is in engine side C++
-------------------------------------------------
include( "FLuaVector" )
include( "InstanceManager" )
local InstanceManager = InstanceManager
--[[
include( "Bombardment")
local BeginAirAttack = BeginAirAttack
local BeginNukeAttack = BeginNukeAttack
local BeginRangedAttack = BeginRangedAttack
local EndAirAttack = EndAirAttack
local EndNukeAttack = EndNukeAttack
local EndRangedAttack = EndRangedAttack
--]]
local print = print
local type = type
local insert = table.insert

local ButtonPopupTypes = ButtonPopupTypes
local CITY_UPDATE_TYPE_BANNER = CityUpdateTypes.CITY_UPDATE_TYPE_BANNER
local COMMAND_CANCEL_ALL = CommandTypes.COMMAND_CANCEL_ALL
local ContextPtr = ContextPtr
local Controls = Controls
local DOMAIN_AIR = DomainTypes.DOMAIN_AIR
local DOMAIN_LAND = DomainTypes.DOMAIN_LAND
local DOMAIN_SEA = DomainTypes.DOMAIN_SEA
local Events = Events
local EventsRequestYieldDisplay = Events.RequestYieldDisplay.Call
local EventsClearHexHighlightStyle = Events.ClearHexHighlightStyle.Call
local EventsSerialEventHexHighlight = Events.SerialEventHexHighlight.Call
local Game = Game
local GameDefines = GameDefines
local CITY_PLOTS_RADIUS = GameDefines.CITY_PLOTS_RADIUS
local GameInfoTypes = GameInfoTypes
local GAMEMESSAGE_PUSH_MISSION = GameMessageTypes.GAMEMESSAGE_PUSH_MISSION
local GAMEMESSAGE_DO_COMMAND = GameMessageTypes.GAMEMESSAGE_DO_COMMAND
local GAMEMESSAGE_DO_TASK = GameMessageTypes.GAMEMESSAGE_DO_TASK
local GAMEVIEW_NONE = GameViewTypes.GAMEVIEW_NONE
local WORLD_ANCHOR_WORKER = GenericWorldAnchorTypes.WORLD_ANCHOR_WORKER
local WORLD_ANCHOR_SETTLER = GenericWorldAnchorTypes.WORLD_ANCHOR_SETTLER
local GetGameViewRenderType = GetGameViewRenderType
local InStrategicView = InStrategicView
local GameData_DIRTY_BIT = InterfaceDirtyBits.GameData_DIRTY_BIT
local InterfaceModeTypes = InterfaceModeTypes
local INTERFACEMODE_SELECTION = InterfaceModeTypes.INTERFACEMODE_SELECTION
local KeyEvents = KeyEvents
local Keys = Keys
local Map = Map
local GetPlot = Map.GetPlot
local MissionTypes = MissionTypes
local Modding = Modding
local Mouse = Mouse
local MouseEvents = MouseEvents
local BY_HOST = NetKicked.BY_HOST
local Network = Network
local OptionsManager = OptionsManager
local Players = Players
local InGameMenu = PopupPriority.InGameMenu
local PreGame = PreGame
local ProcessStrategicViewMouseClick = ProcessStrategicViewMouseClick
local BulkHideUI = SystemUpdateUIType.BulkHideUI
local BulkShowUI = SystemUpdateUIType.BulkShowUI
local TASK_RANGED_ATTACK = TaskTypes.TASK_RANGED_ATTACK
local ToGridFromHex = ToGridFromHex
local ToHexFromGrid = ToHexFromGrid
local ToggleStrategicView = ToggleStrategicView
local UI = UI
local GetHeadSelectedUnit = UI.GetHeadSelectedUnit
local GetHeadSelectedCity = UI.GetHeadSelectedCity
local GetInterfaceMode = UI.GetInterfaceMode
local GetMouseOverHex = UI.GetMouseOverHex
local IsTouchScreenEnabled = UI.IsTouchScreenEnabled
local SetInterfaceMode = UI.SetInterfaceMode
local UIManager = UIManager
local YieldDisplayTypes = YieldDisplayTypes

include( "EUI_utilities" )
local GameInfo = EUI.GameInfoCache -- warning! use iterator ONLY with table field conditions, NOT string SQL query
local IndexPlot = EUI.IndexPlot
local CountHexPlots = EUI.CountHexPlots
local g_ColorTurn1 = EUI.Color( 0, 1, 0, 0.25 )
local g_ColorTurn2 = EUI.Color( 1, 1, 0, 0.25 )
local g_ColorEmbark = EUI.Color( 1.0, 1.0, 0.0, 0.65 )
local g_ColorGiftUnit = EUI.Color( 1.0, 1.0, 0.0, 1 )
local g_ColorGiftTileImprovement = EUI.Color( 1.0, 0.0, 1.0, 1.0 )

local gk_mode = Game.GetReligionName ~= nil

local g_IsPathShown = false
local g_ShowWorkerRecommendation = not Game.IsNetworkMultiPlayer()
local g_WorkerSuggestHighlightPlots
local g_FounderSuggestHighlightPlots
local g_EatNextUp = false

local g_InterfaceModeNames = {} for k,v in pairs(InterfaceModeTypes) do g_InterfaceModeNames[v]=k end

local g_InterfaceModeMessageHandler = {}
local g_NewInterfaceModeChangeHandler = {}
local g_OldInterfaceModeChangeHandler = {}

local FoundCityIcon
local MiniMapOptionsPanel
Events.SequenceGameInitComplete.Add( function()
	MiniMapOptionsPanel = LookUpControl( "/InGame/WorldView/MiniMapPanel/OptionsPanel" )
	FoundCityIcon = LookUpControl( "/Ingame/YieldIconManager/CityAnchor" )
end)

-------------------------------------------------
-- Utilities
local function CallIfNotNil( f, ... )
	if f then return f( ... ) end
end

local function SetInterfaceModeSelection()
	return SetInterfaceMode( INTERFACEMODE_SELECTION )
end

local function SetInterfaceModeSelectionTrue()
	SetInterfaceModeSelection()
	return true
end

local function AssignInterfaceModeMessageHandler( interfaceMode, action )
	local IMMH = {}
	IMMH[ MouseEvents.LButtonUp ] = action
	IMMH[ MouseEvents.RButtonUp ] = action
	if IsTouchScreenEnabled() then
		IMMH[ MouseEvents.PointerUp ] = action
	end
	g_InterfaceModeMessageHandler[ interfaceMode ] = IMMH
end

local function AssignInterfaceMode( interfaceMode, new, old, action )
	if interfaceMode then
		g_NewInterfaceModeChangeHandler[ interfaceMode ] = new
		g_OldInterfaceModeChangeHandler[ interfaceMode ] = old
		if type(action)=="function" then
			return AssignInterfaceModeMessageHandler( interfaceMode, action )
		elseif type(action)=="table" then
			g_InterfaceModeMessageHandler[ interfaceMode ] = action
		end
	end
end

local function ClearStrikeRange()
	--print( "ClearStrikeRange" )
	EventsClearHexHighlightStyle( "FireRangeBorder" )
	return EventsClearHexHighlightStyle( "ValidFireTargetBorder" )
end

local function ClearMovementRange()
	--print("ClearMovementRange")
	EventsClearHexHighlightStyle( "MovementRangeBorder" )
	return EventsClearHexHighlightStyle( "AMRBorder" )
end
Events.ClearUnitMoveHexRange.Add( ClearMovementRange )
Events.StartUnitMoveHexRange.Add( ClearMovementRange )
Events.AddUnitMoveHexRangeHex.Add( function( i, j, k, attackMove )
	if attackMove then --and GetPlot(ToGridFromHex( i, j )):IsVisibleEnemyUnit(Game.GetActivePlayer()) then
		return EventsSerialEventHexHighlight( {x=i, y=j}, true, g_ColorTurn1, "AMRBorder" )
	else
		return EventsSerialEventHexHighlight( {x=i, y=j}, true, g_ColorTurn1, "MovementRangeBorder" )
	end
end)

local function plotIsLand( plot )
	return not plot:IsWater()
end

local function returnTrue()
	return true
end

local function RequestYieldDisplay()
	local unit = GetHeadSelectedUnit()
	-- Yield icons off by default
	if OptionsManager.IsCivilianYields() then
		if ( UI.CanSelectionListWork() or UI.CanSelectionListFound() ) and not( unit and (GameInfo.Units[unit:GetUnitType()]or{}).DontShowYields ) then
			return EventsRequestYieldDisplay( YieldDisplayTypes.EMPIRE )

--		elseif unit and UI.CanSelectionListFound() then
--			return EventsRequestYieldDisplay( YieldDisplayTypes.AREA, CITY_PLOTS_RADIUS, unit:GetX(), unit:GetY() )
		end
	end
	if not UI.IsCityScreenUp() then
		EventsRequestYieldDisplay( YieldDisplayTypes.AREA, 0 )
	end
end

local function DisplayStrikeRange( unit, thisPlot, range, isIndirectFireAllowed, isDomainOnly, unitDomainType, isRevealed )
	ClearStrikeRange()
	--print( "DisplayStrikeRange", unit:GetName(), "x", thisPlot:GetX(), "y", thisPlot:GetY(), "range", range, "isIndirectFireAllowed", isIndirectFireAllowed, "isDomainOnly", isDomainOnly, "unitDomainType", unitDomainType )
	local plot, x, y, hex
	local team = unit:GetTeam()
	local testVisibility = isRevealed and thisPlot.IsRevealed or thisPlot.IsVisible
	local testDomain = isDomainOnly and ( (unitDomainType == DOMAIN_LAND and plotIsLand) or (unitDomainType == DOMAIN_SEA and thisPlot.IsWater) ) or returnTrue
	local testCanSee = (isIndirectFireAllowed or unitDomainType == DOMAIN_AIR) and returnTrue or thisPlot.CanSeePlot
	-- highlight the bombardable plots
	for i = 0, CountHexPlots( range ) do
		plot = IndexPlot( thisPlot, i )
		if plot and testVisibility( plot, team, false ) and testDomain( plot ) and testCanSee( thisPlot, plot, team, range-1, -1 ) then -- -1 = no direction
			x, y = plot:GetX(), plot:GetY()
			hex = ToHexFromGrid{ x=x, y=y }
			EventsSerialEventHexHighlight( hex, true, nil, "FireRangeBorder" )
			if unit:CanRangeStrikeAt( x, y ) then
				EventsSerialEventHexHighlight( hex, true, nil, "ValidFireTargetBorder" )
			end
		end
	end
end

local function DisplayUnitStrikeRange( unit )
	return DisplayStrikeRange( unit, unit:GetPlot(), unit:Range(), unit:IsRangeAttackIgnoreLOS(), unit:IsRangeAttackOnlyInDomain(), unit:GetDomainType() )
end

local function DisplayPredictiveUnitStrikeRange( unit, plot )
	return DisplayStrikeRange( unit, plot, unit:Range(), unit:IsRangeAttackIgnoreLOS(), unit:IsRangeAttackOnlyInDomain(), unit:GetDomainType(), true )
end

local function DisplayCityStrikeArrow( x, y )
	local city = GetHeadSelectedCity()
	if city and city:CanRangeStrikeAt( x, y ) then
		Events.SpawnArrowEvent( city:GetX(), city:GetY(), x, y )
	else
		Events.RemoveAllArrowsEvent()
	end
end

local function DisplayStrikeArrow( x, y )
	local unit = GetHeadSelectedUnit()
	if unit and unit:CanMove() and unit:CanRangeStrikeAt( x, y ) then
		Events.SpawnArrowEvent( unit:GetX(), unit:GetY(), x, y )
	else
		Events.RemoveAllArrowsEvent()
	end
end

local function DisplayNukeArrow( x, y )
	local unit = GetHeadSelectedUnit()
	if unit and unit:CanMove() and unit:CanNukeAt( x, y ) then
		Events.SpawnArrowEvent( unit:GetX(), unit:GetY(), x, y )
	else
		Events.RemoveAllArrowsEvent()
	end
end

local function RefreshMovementIndicator()
	Events.DisplayMovementIndicator( true )
end

local function DisplayPath( x, y )
	--print( "DisplayPath", x, y )
	UI.SendPathfinderUpdate()
	Events.DisplayMovementIndicator( true )
	local unit = GetHeadSelectedUnit()
	if unit then
		local plot = GetPlot( x, y )
		local unitOwnerID = unit:GetOwner()
		if unit:IsCanAttackRanged() and not unit:IsEmbarked() then
			if not plot or plot:IsVisibleEnemyUnit( unitOwnerID ) or plot:IsEnemyCity( unit ) then
				return DisplayUnitStrikeRange( unit )
			else
				return DisplayPredictiveUnitStrikeRange( unit, plot )
			end
		end
		if UI.CanSelectionListFound() then
--			g_isCityLimits = true
			EventsClearHexHighlightStyle( "CityLimits" )
			EventsClearHexHighlightStyle( "OverlapFill" )
			EventsClearHexHighlightStyle( "OverlapOutline" )
			if plot and unit:CanFound( plot ) and plot:IsRevealed( unit:GetTeam() ) then
				EventsRequestYieldDisplay( YieldDisplayTypes.AREA, CITY_PLOTS_RADIUS, x, y )
				if FoundCityIcon then
					local a, b, c = GridToWorld( x, y )
					FoundCityIcon:SetWorldPositionVal( a, b, c )
					FoundCityIcon:SetHide( false  )
				end
				for i=0, CountHexPlots( CITY_PLOTS_RADIUS ) do
					local p = IndexPlot( plot, i )
					if p then
						local hex = ToHexFromGrid{ x=p:GetX(), y=p:GetY() }
						EventsSerialEventHexHighlight( hex, true, nil, "CityLimits" )
						local plotOwnerID = p:GetOwner()
						if plotOwnerID >= 0 and plotOwnerID ~= unitOwnerID or p:IsPlayerCityRadius( unitOwnerID ) then
							EventsSerialEventHexHighlight( hex, true, nil, "OverlapFill" )
							EventsSerialEventHexHighlight( hex, true, nil, "OverlapOutline" )
						end
					end
				end
			else
				EventsRequestYieldDisplay( YieldDisplayTypes.AREA, 0 )
				if FoundCityIcon then
					FoundCityIcon:SetHide( true )
				end
			end
		end
	end
end

local function ShowPath()
	--print( "ShowPath", "g_IsPathShown", g_IsPathShown )
	if not g_IsPathShown then
		g_IsPathShown = true
		Events.SerialEventMouseOverHex.Add( DisplayPath )
		DisplayPath( GetMouseOverHex() )
		Events.UIPathFinderUpdate.Add( RefreshMovementIndicator )
		return RefreshMovementIndicator()
	end
end

local function HidePath()
	--print( "HidePath", "g_IsPathShown=", g_IsPathShown )
	if g_IsPathShown then
		g_IsPathShown = false
		EventsClearHexHighlightStyle( "CityLimits" )
		EventsClearHexHighlightStyle( "OverlapFill" )
		EventsClearHexHighlightStyle( "OverlapOutline" )
		Events.UIPathFinderUpdate.RemoveAll() --.Remove( RefreshMovementIndicator )
		Events.SerialEventMouseOverHex.Remove( DisplayPath )
		Events.DisplayMovementIndicator( false )
		RequestYieldDisplay()
		if FoundCityIcon then
			FoundCityIcon:SetHide( true )
		end
	end
end

local function EndUnitStrikeAttack()
	Events.SerialEventMouseOverHex.Remove( DisplayStrikeArrow )
	Events.SerialEventMouseOverHex.Remove( DisplayNukeArrow )
	Events.RemoveAllArrowsEvent()
	return ClearStrikeRange()
end

local function DoUnitStrikeAttack()
	local x, y = GetMouseOverHex()
	local plot = GetPlot( x, y )
	local unit = GetHeadSelectedUnit()
	--print( "RangedAttack", unit and unit:GetName() )
	-- Don't let the user do a ranged attack on a plot that contains some fighting.
	if not plot or plot:IsFighting() then
	-- should handle the case of units bombarding tiles when they are already at war
	elseif unit and unit:CanRangeStrikeAt( x, y, true, true ) then
		Game.SelectionListGameNetMessage( GAMEMESSAGE_PUSH_MISSION, MissionTypes.MISSION_RANGE_ATTACK, x, y, 0, false, UI.ShiftKeyDown() )
		--return SetInterfaceModeSelectionTrue()
	-- Unit Range Strike - special case for declaring war with range strike
	elseif unit and unit:CanRangeStrikeAt( x, y, false, true ) then
		-- Is there someone here that we COULD bombard, perhaps?
		local rivalTeamID = unit:GetDeclareWarRangeStrike(plot)
		if rivalTeamID ~= -1 then
			UIManager:SetUICursor(0)
			Events.SerialEventGameMessagePopup{
				Type  = ButtonPopupTypes.BUTTONPOPUP_DECLAREWARRANGESTRIKE,
				Data1 = rivalTeamID,
				Data2 = x,
				Data3 = y
			}
			--return SetInterfaceModeSelectionTrue()
		end
	end
	return true
end

local function ClickSelect()
	-- Give the strategic view a chance to process the click first
	if InStrategicView() and ProcessStrategicViewMouseClick() then else
		local plot = GetPlot( GetMouseOverHex() )
		if plot then
			UI.LocationSelect( plot, UIManager:GetControl(), UIManager:GetAlt(), UI.ShiftKeyDown() )
			return true
		end
	end
end

--[[
UI.CenterCamera
CameraProjectionChanged; CameraViewChanged;
Events.SerialEventCameraBack; Events.SerialEventCameraCenter; Events.SerialEventCameraForward; Events.SerialEventCameraLeft; Events.SerialEventCameraRight; 
Events.SerialEventCameraSetCenterAndZoom{x=-1280,y=720,z=zoom};
Events.CameraStopPitchingDown(), Events.CameraStartPitchingUp(), Events.CameraStopPitchingUp(), Events.CameraStartPitchingDown()
Events.SerialEventCameraSetCenterAndZoom.Add(
function(...)
	local s = "SerialEventCameraSetCenterAndZoom"
	for _, v in pairs{...} do
		s = s ..", "..tostring(v)
	end
	Events.GameplayAlertMessage( s )
end)
	[Keys.VK_DIVIDE] = function( b )
		local x, y = GridToWorld( GetMouseOverHex() )
		if b then
			Events.SerialEventCameraSetCenterAndZoom{x=x,y=y,z=70}
		else
			Events.SerialEventCameraSetCenterAndZoom{x=x,y=y,z=1800}
		end
	end,
--]]

-------------------------------------------------
-- Default key down handler
local DefaultKeyDownFunction = {
	[Keys.VK_LEFT] = function( b )
		if b then
			Events.CameraStopRotatingCW()
			Events.CameraStartRotatingCCW()
		else
			Events.SerialEventCameraStopMovingRight()
			Events.SerialEventCameraStartMovingLeft()
		end
	end,
	[Keys.VK_RIGHT] = function( b )
		if b then
			Events.CameraStopRotatingCCW()
			Events.CameraStartRotatingCW()
		else
			Events.SerialEventCameraStopMovingLeft()
			Events.SerialEventCameraStartMovingRight()
		end
	end,
	[Keys.VK_UP] = function( b )
		if b then
			Events.SerialEventCameraForward()
		else
			Events.SerialEventCameraStopMovingBack()
			Events.SerialEventCameraStartMovingForward()
		end
	end,
	[Keys.VK_DOWN] = function( b )
		if b then
			Events.SerialEventCameraBack()
		else
			Events.SerialEventCameraStopMovingForward()
			Events.SerialEventCameraStartMovingBack()
		end
	end,
	[Keys.VK_NEXT] = function()
			Events.SerialEventCameraOut{ x=0, y=0 }
	end,
	[Keys.VK_PRIOR] = function()
		Events.SerialEventCameraIn{ x=0, y=0 }
	end,
	[Keys.VK_ESCAPE] = function()
		if MiniMapOptionsPanel and not MiniMapOptionsPanel:IsHidden() then
			MiniMapOptionsPanel:SetHide( true )
		elseif g_IsPathShown or GetInterfaceMode() ~= INTERFACEMODE_SELECTION then
			SetInterfaceModeSelection()
		elseif InStrategicView() then
			ToggleStrategicView()
		else
			UIManager:QueuePopup( Controls.GameMenu, InGameMenu )
		end
	end,
	[Keys.VK_OEM_3] = function() -- ~ en_us ù fr_azerty
		if UI.DebugFlag() then
			if UI.ShiftKeyDown() and PreGame.IsMultiplayerGame() then
				Controls.NetworkDebug:SetHide( not Controls.NetworkDebug:IsHidden() )
			elseif not PreGame.IsMultiplayerGame() and not PreGame.IsHotSeatGame() then
				Controls.DebugMenu:SetHide( not Controls.DebugMenu:IsHidden() )
			end
		end
	end,
	[Keys.Z] = function()
		if UIManager:GetControl() and UI.DebugFlag() and not PreGame.IsMultiplayerGame() and not PreGame.IsHotSeatGame() then
			Game.ToggleDebugMode()
			local plot
			local team = Game.GetActiveTeam()
			local bIsDebug = Game.IsDebugMode()
			for iPlotLoop = 0, Map.GetNumPlots()-1, 1 do
				plot = Map.GetPlotByIndex(iPlotLoop)
				if plot:GetVisibilityCount() > 0 then
					plot:ChangeVisibilityCount( team, -1, -1, true, true )
				end
				plot:SetRevealed( team, false )
				plot:ChangeVisibilityCount( team, 1, -1, true, true )
				plot:SetRevealed( team, bIsDebug )
			end
		end
	end,
	[Keys.G] = UI.ToggleGridVisibleMode,
}
local function DefaultKeyDownHandler( wParam )
	if DefaultKeyDownFunction[ wParam ] then
		DefaultKeyDownFunction[ wParam ]( UI.ShiftKeyDown() )
		return true
	end
end

-------------------------------------------------
-- Default key up handler
local DefaultKeyUpFunction = {
	[Keys.VK_LEFT] = function()
		Events.CameraStopRotatingCCW()
		Events.SerialEventCameraStopMovingLeft()
	end,
	[Keys.VK_RIGHT] = function()
		Events.CameraStopRotatingCW()
		Events.SerialEventCameraStopMovingRight()
	end,
	[Keys.VK_UP] = Events.SerialEventCameraStopMovingForward.Call,
	[Keys.VK_DOWN] = Events.SerialEventCameraStopMovingBack.Call,
}
local function DefaultKeyUpHandler( wParam )
	if DefaultKeyUpFunction[ wParam ] then
		DefaultKeyUpFunction[ wParam ]()
		return true
	end
end
-- Emergency key up handler
-- Events.KeyUpEvent.Add( DefaultKeyUpHandler )

-------------------------------------------------
-- Default message handler
local DefaultMessageHandler = { [KeyEvents.KeyDown] = DefaultKeyDownHandler, [KeyEvents.KeyUp] = DefaultKeyUpHandler, [MouseEvents.LButtonUp] = ClickSelect }
if IsTouchScreenEnabled() then
	DefaultMessageHandler[MouseEvents.PointerUp] = SetInterfaceModeSelectionTrue
	DefaultMessageHandler[MouseEvents.PointerDown] = function()
		if UIManager:GetNumPointers() > 1 then
			SetInterfaceModeSelectionTrue()
		end
	end
end

-------------------------------------------------
-- DEFAULT MISSIONS
for row in GameInfo.InterfaceModes() do
	local interfaceModeMission = GameInfoTypes[ row.Mission ]
	if interfaceModeMission and interfaceModeMission ~= MissionTypes.NO_MISSION then
		AssignInterfaceModeMessageHandler( row.ID, function()
			--print( "DefaultMissionHandler", g_InterfaceModeNames[ GetInterfaceMode() ] )
			local x, y = GetMouseOverHex()
			if GetPlot( x, y ) then
				Game.SelectionListGameNetMessage( GAMEMESSAGE_PUSH_MISSION, interfaceModeMission, x, y, 0, false, UI.ShiftKeyDown() )
			end
			return SetInterfaceModeSelectionTrue()
		end)
	end
end

-------------------------------------------------
-- DEBUG
--local g_PlopperSettings, g_UnitPlopper, g_ResourcePlopper, g_ImprovementPlopper, g_CityPlopper

g_UnitPlopper =
{
	UnitType = -1,
	Embarked = false,
	Plop =
	function( plot )
		if g_PlopperSettings.Player ~= -1 and g_UnitPlopper.UnitType ~= -1 then
			local player = Players[g_PlopperSettings.Player]
			if player then
				--print( "plop", g_UnitPlopper.UnitNameOffset, player.InitUnitWithNameOffset )
				local unit

				if g_UnitPlopper.UnitNameOffset and player.InitUnitWithNameOffset then
					unit = player:InitUnitWithNameOffset(g_UnitPlopper.UnitType, g_UnitPlopper.UnitNameOffset, plot:GetX(), plot:GetY())
				else
					unit = player:InitUnit(g_UnitPlopper.UnitType, plot:GetX(), plot:GetY())
				end

				if g_UnitPlopper.Embarked then
					unit:Embark()
				end
			end
		end
	end,
	Deplop =
	function( plot )
		for i = 0, plot:GetNumUnits() - 1 do
			local unit = plot:GetUnit(i)
			if unit then
				unit:Kill( true, -1 )
			end
		end
	end
}

g_ResourcePlopper =
{
	ResourceType = -1,
	ResourceAmount = 1,
	Plop =
	function(plot)
		if g_ResourcePlopper.ResourceType ~= -1 then
			plot:SetResourceType(g_ResourcePlopper.ResourceType, g_ResourcePlopper.ResourceAmount)
		end
	end,
	Deplop =
	function(plot)
		plot:SetResourceType(-1)
	end
}

g_ImprovementPlopper =
{
	ImprovementType = -1,
	Pillaged = false,
	HalfBuilt = false,
	Plop =
	function( plot )
		if g_ImprovementPlopper.ImprovementType ~= -1 then
			plot:SetImprovementType(g_ImprovementPlopper.ImprovementType)
			plot:SetImprovementPillaged( g_ImprovementPlopper.Pillaged )
		end
	end,
	Deplop =
	function( plot )
		plot:SetImprovementType(-1)
	end
}

g_CityPlopper =
{
	Plop =
	function( plot )
		if g_PlopperSettings.Player ~= -1 then
			local player = Players[g_PlopperSettings.Player]
			if player then
				player:InitCity(plot:GetX(), plot:GetY())
			end
		end
	end,
	Deplop =
	function( plot )
		local city = plot:GetPlotCity()
		if city then
			city:Kill()
		end
	end
}

g_PlopperSettings =
{
	Player = -1,
	Plopper = g_UnitPlopper,
	EnabledWhenInTab = false
}

AssignInterfaceMode( InterfaceModeTypes.INTERFACEMODE_DEBUG, nil, nil, {
	[MouseEvents.LButtonUp] = function()
		local x, y = GetMouseOverHex()
		local plot = GetPlot( x, y )
		local activePlayer = Players[Game.GetActivePlayer()]
		local debugItem1 = UI.GetInterfaceModeDebugItemID1()
		local debugItem2 = UI.GetInterfaceModeDebugItemID2()
		if debugItem1 == 0 then
			activePlayer:InitCity( x, y )
		elseif debugItem1 == 1 then
			activePlayer:InitUnit( debugItem2, x, y )
		elseif debugItem1 == 2 then
			plot:SetImprovementType( debugItem2 )
		elseif debugItem1 == 3 then
			plot:SetRouteType( debugItem2 )
		elseif debugItem1 == 4 then
			plot:SetFeatureType( debugItem2 )
		elseif debugItem1 == 5 then
			plot:SetResourceType( debugItem2, 5 )
		-- Plopper
		elseif debugItem1 == 6
			and type(g_PlopperSettings) == "table"
			and type(g_PlopperSettings.Plopper) == "table"
			and type(g_PlopperSettings.Plopper.Plop) == "function"
		then
			g_PlopperSettings.Plopper.Plop( plot )
			return true -- Do not allow the interface mode to be set back to INTERFACEMODE_SELECTION
		end
		return SetInterfaceModeSelectionTrue()
	end,
	[MouseEvents.RButtonDown] = function()
		local plot = GetPlot( GetMouseOverHex() )
		local debugItem1 = UI.GetInterfaceModeDebugItemID1()
		-- Plopper
		if debugItem1 == 6
			and type(g_PlopperSettings) == "table"
			and type(g_PlopperSettings.Plopper) == "table"
			and type(g_PlopperSettings.Plopper.Plop) == "function"
		then
			g_PlopperSettings.Plopper.Plop( plot )
		end
		return true
	end,
	[MouseEvents.LButtonDown] = function() return true end, -- Trap LButtonDown
	[MouseEvents.RButtonUp] = function() return true end, -- Trap RButtonUp
})
-- /DEBUG
-------------------------------------------------

-------------------------------------------------
-- SELECTION & MOVETO
local function EndMovement()
	--print( "EndMovement" )
--[[
	if g_EatNextUp == true then
		g_EatNextUp = false
		return
	end
--]]
	HidePath()
	
	if IsTouchScreenEnabled() then
		SetInterfaceModeSelection()
	end
	local bShift = UI.ShiftKeyDown()
	local bAlt = UIManager:GetAlt()
	local bCtrl = UIManager:GetControl()
	local x, y = GetMouseOverHex()
	local plot = GetPlot( x, y )
	local unit = GetHeadSelectedUnit()

	if plot and unit then
		if UI.IsCameraMoving() and not Game.GetAllowRClickMovementWhileScrolling() then
			--print( "Blocked by moving camera" )
			--Events.ClearHexHighlights()
--			HidePath()
			return false
		end

		Game.SetEverRightClickMoved( true )

		-- Is there someone here that we COULD bombard perhaps?
		local rivalTeamID = unit:GetDeclareWarRangeStrike(plot)
		if rivalTeamID ~= -1 then
			UIManager:SetUICursor( 0 )
			Events.SerialEventGameMessagePopup{
				Type  = ButtonPopupTypes.BUTTONPOPUP_DECLAREWARRANGESTRIKE,
				Data1 = rivalTeamID,
				Data2 = x,
				Data3 = y
			}
			return true
		-- Visible enemy... bombardment?
		elseif plot:IsVisibleEnemyUnit( unit:GetOwner() ) or plot:IsEnemyCity( unit ) then

			-- Already some combat going on in there, just exit
			if plot:IsFighting() then
				return true
			elseif unit:CanMove() and unit:CanRangeStrikeAt( x, y, true, false ) then -- true = NeedWar, false = isNoncombatAllowed
				Game.SelectionListGameNetMessage( GAMEMESSAGE_PUSH_MISSION, unit:GetDomainType() == DOMAIN_AIR and MissionTypes.MISSION_MOVE_TO or MissionTypes.MISSION_RANGE_ATTACK, x, y, 0, false, bShift) -- Air strikes are moves... yep
				return SetInterfaceModeSelectionTrue()
			end
		end

		if not gk_mode then
			-- Garrison in a city
			local city = plot:GetPlotCity()
			if city and city:GetOwner() == unit:GetOwner() and unit:IsCanAttack() then
				local cityOwner = Players[city:GetOwner()]
				if not cityOwner:IsMinorCiv() and city:GetGarrisonedUnit() == nil and unit:GetDomainType() == DOMAIN_LAND then
					Game.SelectionListGameNetMessage( GAMEMESSAGE_PUSH_MISSION, MissionTypes.MISSION_GARRISON, x, y, 0, false, bShift)
					return SetInterfaceModeSelectionTrue()
				end
			end
		end

		-- No visible enemy to bombard, just move
		if not bShift and unit:AtPlot( plot ) then
			--print("Game.SelectionListGameNetMessage( GAMEMESSAGE_DO_COMMAND, COMMAND_CANCEL_ALL)")
			Game.SelectionListGameNetMessage( GAMEMESSAGE_DO_COMMAND, COMMAND_CANCEL_ALL )
		else--if plot == UI.GetGotoPlot() then
			--print("Game.SelectionListMove(plot,  bAlt, bShift, bCtrl)")
			Game.SelectionListMove( plot,  bAlt, bShift, bCtrl )
			--UI.SetGotoPlot(nil)
		end
	end
--	HidePath()
	return true
end

local function RefreshMovementAndStrikeRanges()
	local unit = GetHeadSelectedUnit()
	if unit then
		--print("RefreshMovementAndStrikeRanges", playerID, unitID, unit:GetOwner(), unit:GetID(), unit:GetName(), "IsCanAttackRanged", unit:IsCanAttackRanged(), "CanNuke", unit:CanNuke() )
		if unit:CanMove() then
			Events.ShowMovementRange( unit:GetOwner(), unit:GetID() )
		else
			ClearMovementRange()
			SetInterfaceModeSelection() -- game engine does nothing if already in selection mode
		end
		if not unit:IsEmbarked() and (unit:IsCanAttackRanged() or unit:CanNuke()) then
			DisplayStrikeArrow( GetMouseOverHex() )
			return DisplayUnitStrikeRange( unit )
		end
	end
end

AssignInterfaceMode( InterfaceModeTypes.INTERFACEMODE_SELECTION,
	RefreshMovementAndStrikeRanges,
	nil,
	{ [MouseEvents.RButtonDown] = ShowPath, [MouseEvents.RButtonUp] = EndMovement } )

AssignInterfaceMode( InterfaceModeTypes.INTERFACEMODE_MOVE_TO,
	ShowPath,
	HidePath,
	{ [MouseEvents.RButtonUp] = EndMovement } )
--[[
g_NewInterfaceModeChangeHandler[InterfaceModeTypes.INTERFACEMODE_SELECTION] = function()
	--print( "ShowStrikeArrow" )
	DisplayStrikeArrow( GetMouseOverHex() )
	Events.SerialEventMouseOverHex.Add( DisplayStrikeArrow )
end
--]]
if IsTouchScreenEnabled() then
	g_InterfaceModeMessageHandler[InterfaceModeTypes.INTERFACEMODE_MOVE_TO][MouseEvents.PointerUp] = EndMovement
	g_InterfaceModeMessageHandler[InterfaceModeTypes.INTERFACEMODE_SELECTION][MouseEvents.PointerUp] = ClickSelect
	g_InterfaceModeMessageHandler[InterfaceModeTypes.INTERFACEMODE_SELECTION][MouseEvents.LButtonDoubleClick] =
	function()
		if GetHeadSelectedUnit() then
			SetInterfaceMode( InterfaceModeTypes.INTERFACEMODE_MOVE_TO )
			g_EatNextUp = true
		end
	end
end
-- /SELECTION & MOVETO
-------------------------------------------------

-------------------------------------------------
-- ATTACK
AssignInterfaceMode( InterfaceModeTypes.INTERFACEMODE_ATTACK,
	function()
		local unit = GetHeadSelectedUnit()
		if unit then
			Events.ShowAttackTargets( unit:GetOwner(), unit:GetID() )
		else
			SetInterfaceModeSelection()
		end
	end,
	function()
		EventsClearHexHighlightStyle( "GUHB" )
	end,
	function()
		--print("Calling attack into tile")
		local plot = GetPlot( GetMouseOverHex() )
		if plot:IsVisible( Game.GetActiveTeam() ) then
			local unit = GetHeadSelectedUnit()
			if plot:IsVisibleEnemyUnit( unit:GetOwner() ) or plot:IsEnemyCity( unit ) then
				Game.SelectionListMove( plot, false, false, false )
				return SetInterfaceModeSelectionTrue()
			end
		end
		return true
	end)

-------------------------------------------------
-- CITY RANGED ATTACK
AssignInterfaceMode( InterfaceModeTypes.INTERFACEMODE_CITY_RANGE_ATTACK,
	function()
		local city = GetHeadSelectedCity()
		--print("Begin City Range Attack",city and city:GetName())
		if city and city:CanRangeStrike() then
			Events.SerialEventCityInfoDirty.Add( function() if GetHeadSelectedCity() ~= city then SetInterfaceModeSelection() end end) -- Still selected?
			Events.SerialEventMouseOverHex.Add( DisplayCityStrikeArrow )
			DisplayCityStrikeArrow( GetMouseOverHex() )
			return DisplayStrikeRange( city, city:Plot(), GameDefines.CITY_ATTACK_RANGE, GameDefines.CAN_CITY_USE_INDIRECT_FIRE == 1 )
		end
		SetInterfaceModeSelection()
	end,
	function()
		--print("End City Range Attack")
		UI.ClearSelectedCities() -- required for events to be processed properly
		Events.SerialEventCityInfoDirty.RemoveAll()
		Events.SerialEventMouseOverHex.Remove( DisplayCityStrikeArrow )
		Events.RemoveAllArrowsEvent()
		return ClearStrikeRange()
	end,
	function()
		--print( "City Ranged Attack" )
		local x, y = GetMouseOverHex()
		local plot = GetPlot( x, y )
		if plot then
			local city = GetHeadSelectedCity()
			-- Don't let the user do a ranged attack on a plot that contains some fighting.
			if plot:IsFighting() then
			elseif city and city:CanRangeStrikeAt( x, y, true, true ) then
				Game.SelectedCitiesGameNetMessage( GAMEMESSAGE_DO_TASK, TASK_RANGED_ATTACK, x, y )
				Events.SpecificCityInfoDirty( city:GetOwner(), city:GetID(), CITY_UPDATE_TYPE_BANNER )
				return SetInterfaceModeSelectionTrue()
			end
		end
		return true
	end)

-------------------------------------------------
-- AIR STRIKE
AssignInterfaceMode( InterfaceModeTypes.INTERFACEMODE_AIRSTRIKE,
	function()
		local unit = GetHeadSelectedUnit()
		if unit and unit:IsCanAttackRanged() then
			Events.SerialEventMouseOverHex.Add( DisplayStrikeArrow )
			DisplayStrikeArrow( GetMouseOverHex() )
			return DisplayUnitStrikeRange( unit )
		end
		SetInterfaceModeSelection()
	end,
	EndUnitStrikeAttack,
	DoUnitStrikeAttack)

-------------------------------------------------
-- RANGED ATTACK
AssignInterfaceMode( InterfaceModeTypes.INTERFACEMODE_RANGE_ATTACK,
	function()
		local unit = GetHeadSelectedUnit()
		if unit and unit:IsCanAttackRanged() then
			Events.SerialEventMouseOverHex.Add( DisplayStrikeArrow )
			DisplayStrikeArrow( GetMouseOverHex() )
			return DisplayUnitStrikeRange( unit )
		end
		SetInterfaceModeSelection()
	end,
	EndUnitStrikeAttack,
	DoUnitStrikeAttack)

g_InterfaceModeMessageHandler[InterfaceModeTypes.INTERFACEMODE_RANGE_ATTACK][KeyEvents.KeyDown] = function( wParam )
	if wParam == Keys.VK_NUMPAD1 or wParam == Keys.VK_NUMPAD3 or wParam == Keys.VK_NUMPAD4 or wParam == Keys.VK_NUMPAD6 or wParam == Keys.VK_NUMPAD7 or wParam == Keys.VK_NUMPAD8 then
		SetInterfaceModeSelection()
	end
	return DefaultKeyDownHandler( wParam )
end

-------------------------------------------------
-- NUKE
AssignInterfaceMode( InterfaceModeTypes.INTERFACEMODE_NUKE,
	function()
		local unit = GetHeadSelectedUnit()
		if unit and unit:CanNuke() then
			-- highlight nukable plots
			local thisPlot = unit:GetPlot()
			local team = unit:GetTeam()
			local plot, x, y
			for i = 0, CountHexPlots( unit:Range() ) do
				plot = IndexPlot( thisPlot, i )
				if plot and plot:IsVisible( team, false ) then
					x = plot:GetX()
					y = plot:GetY()
					if unit:CanNukeAt( x, y ) then
						EventsSerialEventHexHighlight( ToHexFromGrid{ x=x, y=y }, true, nil, "FireRangeBorder" )
					end
				end
			end
			Events.SerialEventMouseOverHex.Add( DisplayNukeArrow )
			return DisplayNukeArrow( GetMouseOverHex() )
		end
		SetInterfaceModeSelection()
	end,
	EndUnitStrikeAttack)

-------------------------------------------------
-- EMBARK
AssignInterfaceMode( InterfaceModeTypes.INTERFACEMODE_EMBARK,
	function()
		local unit = GetHeadSelectedUnit()
		if unit then
			local unitPlot, plot = unit:GetPlot()
			for i = 1, 6 do
				plot = IndexPlot( unitPlot, i )
				if plot and plot:IsRevealed( unit:GetTeam(), false ) and unit:CanEmbarkOnto( unit:GetPlot(), plot ) then
					EventsSerialEventHexHighlight( ToHexFromGrid{ x=plot:GetX(), y=plot:GetY() }, true, g_ColorEmbark, "GUHB" )
				end
			end
		else
			SetInterfaceModeSelection()
		end
	end,
	function()
		EventsClearHexHighlightStyle( "GUHB" )
	end,
	function()
		--print( "Embark" )
		local x, y = GetMouseOverHex()
		local plot = GetPlot( x, y )
		local unit = plot and GetHeadSelectedUnit()
		if unit and unit:CanEmbarkOnto(unit:GetPlot(), plot) then
			Game.SelectionListGameNetMessage( GAMEMESSAGE_PUSH_MISSION, MissionTypes.MISSION_EMBARK, x, y, 0, false, UI.ShiftKeyDown() )
			return SetInterfaceModeSelectionTrue()
		end
	end)

-------------------------------------------------
-- DISEMBARK
AssignInterfaceMode( InterfaceModeTypes.INTERFACEMODE_DISEMBARK, 
	function()
		local unit = GetHeadSelectedUnit()
		if unit then
			local unitPlot, plot = unit:GetPlot()
			for i = 1, 6 do
				plot = IndexPlot( unitPlot, i )
				if plot and plot:IsRevealed( unit:GetTeam(), false ) and unit:CanDisembarkOnto( plot ) then
					EventsSerialEventHexHighlight( ToHexFromGrid{ x=plot:GetX(), y=plot:GetY() }, true, g_ColorEmbark, "GUHB" )
				end
			end
		else
			SetInterfaceModeSelection()
		end
	end,
	function()
		EventsClearHexHighlightStyle( "GUHB" )
	end,
	function()
		--print( "Disembark" )
		local x, y = GetMouseOverHex()
		local plot = GetPlot( x, y )
		local unit = plot and GetHeadSelectedUnit()
		if unit and unit:CanDisembarkOnto(plot) then
			Game.SelectionListGameNetMessage( GAMEMESSAGE_PUSH_MISSION, MissionTypes.MISSION_DISEMBARK, x, y, 0, false, UI.ShiftKeyDown() )
			return SetInterfaceModeSelectionTrue()
		end
	end)

-------------------------------------------------
-- PLACE UNIT
AssignInterfaceMode( InterfaceModeTypes.INTERFACEMODE_PLACE_UNIT,
	nil,
	nil,
	function()
		--print( "EjectHandler" )
		local x, y = GetMouseOverHex()
		local plot = GetPlot( x, y )
		--print("INTERFACEMODE_PLACE_UNIT")
		local unit = UI.GetPlaceUnit()
		UI.ClearPlaceUnit()
		if unit and plot then
			--print("INTERFACEMODE_PLACE_UNIT - got placed unit")
			local city = unit:GetPlot():GetPlotCity()
			if city then
				--print("INTERFACEMODE_PLACE_UNIT - not nil city")
				if UI.CanPlaceUnitAt(unit, plot) then
					--print("INTERFACEMODE_PLACE_UNIT - Can eject unit")
					--Network.SendCityEjectGarrisonChoice(city:GetID(), x, y )
					SetInterfaceModeSelectionTrue()
				end
			end
		end
	end)

-------------------------------------------------
-- GIFT UNIT
AssignInterfaceMode( InterfaceModeTypes.INTERFACEMODE_GIFT_UNIT,
	function()
		local activePlayer = Players[Game.GetActivePlayer()]
		if activePlayer then
			local minorPlayerID = UI.GetInterfaceModeValue()
			for unit in activePlayer:Units() do
				if unit:CanDistanceGift(minorPlayerID) then
					EventsSerialEventHexHighlight( { x=unit:GetX(), y=unit:GetY() }, true, g_ColorGiftUnit, "GUHB" )
				end
			end
		else
			SetInterfaceModeSelection()
		end
	end,
	function()
		EventsClearHexHighlightStyle( "GUHB" )
	end,
	function()
		--print( "GiftUnit" )
		local plot = GetPlot( GetMouseOverHex() )
		local activePlayerID = Game.GetActivePlayer()
		local minorPlayerID = UI.GetInterfaceModeValue()
		if Players[activePlayerID] then
			local unit
			for i = 0, plot:GetNumUnits() - 1 do
				local u = plot:GetUnit(i)
				if u:GetOwner() == activePlayerID then
					unit = u
					break
				end
			end
			if unit and unit:CanDistanceGift(minorPlayerID) then
				--print( "Gift unit player ID", activePlayerID, "Other player ID", UI.GetInterfaceModeValue(), "UnitID", unit:GetID(), unit:GetName() )
				Events.SerialEventGameMessagePopup{
					Type = ButtonPopupTypes.BUTTONPOPUP_GIFT_CONFIRM,
					Data1 = activePlayerID,
					Data2 = minorPlayerID,
					Data3 = unit:GetID(),
				}
				return SetInterfaceModeSelectionTrue()
			end
		end
		return true
	end)

-------------------------------------------------
-- GIFT TILE IMPROVEMENT
AssignInterfaceMode( InterfaceModeTypes.INTERFACEMODE_GIFT_TILE_IMPROVEMENT,
	function()
		local activePlayerID = Game.GetActivePlayer()
		local minorPlayer = Players[UI.GetInterfaceModeValue()]
		if minorPlayer then
			local city = minorPlayer:GetCapitalCity()
			if city then
				local cityPlot = city:Plot()
				local plot, x, y
				-- highlight the improvable plots
				for i = 0, CountHexPlots( GameDefines.MINOR_CIV_RESOURCE_SEARCH_RADIUS ) do
					plot = IndexPlot( cityPlot, i )
					if plot then
						x, y = plot:GetX(), plot:GetY()
						if minorPlayer:CanMajorGiftTileImprovementAtPlot(activePlayerID, x, y) then
							EventsSerialEventHexHighlight( { x=x, y=y }, true, g_ColorGiftTileImprovement, "GUHB" )
						end
					end
				end
				return
			end
		end
		SetInterfaceModeSelection()
	end,
	function()
		EventsClearHexHighlightStyle( "GUHB" )
	end,
	function()
		local x, y = GetMouseOverHex()
		local plot = GetPlot( x, y )
		if plot then
			local activePlayerID = Game.GetActivePlayer()
			local minorPlayerID = UI.GetInterfaceModeValue()
			local minorPlayer = Players[minorPlayerID]
			if minorPlayer then
				if minorPlayer:CanMajorGiftTileImprovementAtPlot(activePlayerID, x, y) then
					Game.DoMinorGiftTileImprovement(activePlayerID, minorPlayerID, x, y)
				end
				return SetInterfaceModeSelectionTrue()
			end
		end
		return true
	end)

-------------------------------------------------
-- AIRLIFT
AssignInterfaceMode( InterfaceModeTypes.INTERFACEMODE_AIRLIFT,
	function()
		local unit = GetHeadSelectedUnit()
		if unit then
			local unitPlot = unit:GetPlot()
			if unit:CanAirlift(unitPlot, false) then
				for iPlotLoop = 0, Map.GetNumPlots()-1, 1 do
					local plot = Map.GetPlotByIndex(iPlotLoop)
					local x = plot:GetX()
					local y = plot:GetY()
					if unit:CanAirliftAt(unitPlot, x, y) then
						EventsSerialEventHexHighlight( ToHexFromGrid{ x=x, y=y }, true, g_ColorTurn1, "MovementRangeBorder" )
					end
				end
				return
			end
		end
		SetInterfaceModeSelection()
	end,
	function()
		EventsClearHexHighlightStyle( "MovementRangeBorder" )
	end)

-------------------------------------------------
-- PARADROP
AssignInterfaceMode( InterfaceModeTypes.INTERFACEMODE_PARADROP, 
	function()
		local unit = GetHeadSelectedUnit()
		if unit then
			local unitPlot = unit:GetPlot()
			local plot, x, y
			if unit:CanParadrop(unitPlot, false) then
			for i = 0, CountHexPlots( unit:GetDropRange() ) do
					plot = IndexPlot( unitPlot, i )
					if plot then
						x, y = plot:GetX(), plot:GetY()
						if unit:CanParadropAt(unitPlot,x,y) then
							EventsSerialEventHexHighlight( ToHexFromGrid{ x=x, y=y }, true, g_ColorTurn2, "MovementRangeBorder" )
						end
					end
				end
				return
			end
		end
		SetInterfaceModeSelection()
	end,
	function()
		EventsClearHexHighlightStyle( "MovementRangeBorder" )
	end)

-------------------------------------------------
-- AIRSWEEP
--AssignInterfaceMode( InterfaceModeTypes.INTERFACEMODE_AIR_SWEEP )

-------------------------------------------------
-- REBASE
AssignInterfaceMode( InterfaceModeTypes.INTERFACEMODE_REBASE,
	function()
		local unit = GetHeadSelectedUnit()
		if unit then
			local unitPlot = unit:GetPlot()
			local plot, x, y, hex
			for i = 0, CountHexPlots( unit:Range() * GameDefines.AIR_UNIT_REBASE_RANGE_MULTIPLIER / 100 ) do
				plot = IndexPlot( unitPlot, i )
				if plot then
					x, y = plot:GetX(), plot:GetY()
					hex = ToHexFromGrid{ x=x, y=y }
					EventsSerialEventHexHighlight( hex, true, g_ColorTurn1, "MovementRangeBorder" )
					if unit:CanRebaseAt(unitPlot,x,y) then
						EventsSerialEventHexHighlight( ToHexFromGrid{ x=x, y=y }, true, g_ColorTurn2, "GroupBorder" )
					end
				end
			end
		else
			SetInterfaceModeSelection()
		end
	end,
	function()
		EventsClearHexHighlightStyle( "MovementRangeBorder" )
		EventsClearHexHighlightStyle( "GroupBorder" )
	end)


----------------------------------------------------------------
-- Input handling
----------------------------------------------------------------
do
	local uiMsgName = {}
	for k, v in pairs(MouseEvents) do uiMsgName[v]=k end
	for k, v in pairs(KeyEvents) do uiMsgName[v]=k end
	uiMsgName[512]=nil
	local wParamName = {}
	for k, v in pairs(Keys) do wParamName[v]=k end

	ContextPtr:SetInputHandler( function( uiMsg, wParam )
	--	if uiMsgName[uiMsg] then print("input handler:", uiMsgName[uiMsg], uiMsg, wParamName[wParam], wParam ) end
		local currentInterfaceModeHandler = g_InterfaceModeMessageHandler[ GetInterfaceMode() ]
		CallIfNotNil( currentInterfaceModeHandler and currentInterfaceModeHandler[uiMsg] or DefaultMessageHandler[uiMsg], wParam )
	end)
end

local g_UnitFlagState, g_CityBannerState

Events.SerialEventEnterCityScreen.Add( function()
	-- Can get to city screen by C++ which bypasses lua selection code
	SetInterfaceModeSelection()
	g_UnitFlagState = Controls.UnitFlagManager:IsHidden()
	g_CityBannerState = Controls.CityBannerManager:IsHidden()
	Controls.UnitFlagManager:SetHide( true )
	Controls.CityBannerManager:SetHide( true )
	Controls.CityView:SetHide( false )
	Controls.WorldView:SetHide( true )
	Controls.ScreenEdgeScrolling:SetHide( true )
	-- Grid is always shown in city screen (even if user currently has it off).
	if not OptionsManager.GetGridOn() then
		Events.SerialEventHexGridOn()
	end
end)

Events.SerialEventExitCityScreen.Add( function()
	-- Just in case...
	SetInterfaceModeSelection()
	Controls.UnitFlagManager:SetHide( g_UnitFlagState )
	Controls.CityBannerManager:SetHide( g_CityBannerState )
	Controls.CityView:SetHide( true )
	Controls.WorldView:SetHide( false )
	Controls.ScreenEdgeScrolling:SetHide( not OptionsManager.GetFullscreen() )
	-- Grid is hidden when leaving the city screen (unless the user had it turned on when entering the city screen)
	if not OptionsManager.GetGridOn() then
		Events.SerialEventHexGridOff()
	end
	RequestYieldDisplay()
	UI.SetDirty( GameData_DIRTY_BIT, true )
end)

----------------------------------------------------------------
-- Allow Lua to do any post and pre-processing of the InterfaceMode change
----------------------------------------------------------------

local defaultCursor = GameInfoTypes[(GameInfo.InterfaceModes[INTERFACEMODE_SELECTION]or{}).CursorType] or 0

local function UpdateCursor( interfaceMode )
	-- update the cursor to reflect this mode - these cursor are defined in Civ5CursorInfo.xml
	UIManager:SetUICursor( GameInfoTypes[(GameInfo.InterfaceModes[interfaceMode]or{}).CursorType] or defaultCursor)
end

Events.InterfaceModeChanged.Add( function( oldInterfaceMode, newInterfaceMode )
	--print("Interface Mode Changed from", g_InterfaceModeNames[oldInterfaceMode], "to", g_InterfaceModeNames[newInterfaceMode])
--	if oldInterfaceMode ~= newInterfaceMode or newInterfaceMode == INTERFACEMODE_SELECTION then -- game engine already filters
	CallIfNotNil( g_OldInterfaceModeChangeHandler[oldInterfaceMode] )
	CallIfNotNil( g_NewInterfaceModeChangeHandler[newInterfaceMode] )
	UpdateCursor( newInterfaceMode )
end)

Events.ActivePlayerTurnEnd.Add( function()
	UIManager:SetUICursor(1) -- busy
end)

Events.ActivePlayerTurnStart.Add( function()
	UpdateCursor( GetInterfaceMode() )
end)

local function OnUpdateSelection( isSelected )
	RequestYieldDisplay()

	local activePlayerID = Game.GetActivePlayer()
	local activePlayer = Players[activePlayerID]

	--print("Unit selection changed!")
	local EventsGenericWorldAnchor = Events.GenericWorldAnchor.Call
	-- workers - clear old list first
	if g_WorkerSuggestHighlightPlots then
		for _, v in pairs(g_WorkerSuggestHighlightPlots) do
			if v.plot then
				EventsGenericWorldAnchor( WORLD_ANCHOR_WORKER, false, v.plot:GetX(), v.plot:GetY(), v.buildType )
			end
		end
	end
	g_WorkerSuggestHighlightPlots = nil

	-- founders - clear old list first
	if g_FounderSuggestHighlightPlots then
		for _, v in pairs(g_FounderSuggestHighlightPlots) do
			EventsGenericWorldAnchor( WORLD_ANCHOR_SETTLER, false, v:GetX(), v:GetY(), -1 )
		end
	end
	g_FounderSuggestHighlightPlots = nil

	if isSelected then
		if UI.CanSelectionListWork() then
			g_WorkerSuggestHighlightPlots = activePlayer:GetRecommendedWorkerPlots()
			if g_ShowWorkerRecommendation and not OptionsManager.IsNoTileRecommendations() then
				for _, v in pairs(g_WorkerSuggestHighlightPlots) do
					if v.plot then
						EventsGenericWorldAnchor( WORLD_ANCHOR_WORKER, true, v.plot:GetX(), v.plot:GetY(), v.buildType )
					end
				end
			end
		end
		if UI.CanSelectionListFound() and activePlayer:GetNumCities() > 0 then
			g_FounderSuggestHighlightPlots = activePlayer:GetRecommendedFoundCityPlots()
			if g_ShowWorkerRecommendation and not OptionsManager.IsNoTileRecommendations() then
				for _, v in pairs(g_FounderSuggestHighlightPlots) do
					EventsGenericWorldAnchor( WORLD_ANCHOR_SETTLER, true, v:GetX(), v:GetY(), -1 )
				end
			end
		end
	end
end

Events.UnitSelectionChanged.Add( function( playerID, unitID, i, j, k, isSelected )
	--print( "UnitSelectionChanged", g_InterfaceModeNames[GetInterfaceMode()], playerID, unitID, i, j, k, "isSelected", isSelected, "city", GetHeadSelectedCity(), "unit", GetHeadSelectedUnit()and GetHeadSelectedUnit():GetName() )
	if isSelected then
		-- ShowMovementAndStrikeRanges
		Events.SerialEventMouseOverHex.Add( DisplayStrikeArrow )
		RefreshMovementAndStrikeRanges()
		Events.SerialEventUnitInfoDirty.Add( RefreshMovementAndStrikeRanges )
		SetInterfaceModeSelection()
	else
		-- HideMovementAndStrikeRanges
		Events.SerialEventUnitInfoDirty.Remove( RefreshMovementAndStrikeRanges )
		ClearMovementRange()
		Events.SerialEventMouseOverHex.Remove( DisplayStrikeArrow )
		if GetInterfaceMode() ~= InterfaceModeTypes.INTERFACEMODE_CITY_RANGE_ATTACK then
			ClearStrikeRange()
			Events.RemoveAllArrowsEvent()
			SetInterfaceModeSelection()
		end
	end
	return OnUpdateSelection( isSelected )
end)

LuaEvents.OnRecommendationCheckChanged.Add( function( value )
	-- Value is true if recommendations are hidden.
	g_ShowWorkerRecommendation = not value
	OnUpdateSelection( UI.CanSelectionListWork() )
end)

Events.GameOptionsChanged.Add( function()
	local value = not OptionsManager.IsNoTileRecommendations()
	g_ShowWorkerRecommendation = value
	OnUpdateSelection( UI.CanSelectionListFound() )
end)
--[[
Events.SerialEventUnitDestroyed.Add( function( playerID, unitID )
	if playerID == Game.GetActivePlayer() then
		RequestYieldDisplay()
	end
end)
--]]
do
	local alertTable = {}
	local mustRefreshAlerts = false
	local g_InstanceMap = {}
	local g_InstanceManager = InstanceManager:new( "AlertMessageInstance", "AlertMessageLabel", Controls.AlertStack )
	local g_PopupIM = InstanceManager:new( "PopupText", "Anchor", Controls.PopupTextContainer )

	Events.GameplayAlertMessage.Add( function( text )
		local newAlert = { text = text, elapsedTime = 0, shownYet = false }
		insert( alertTable, newAlert )
		mustRefreshAlerts = true
	end)

	Events.GameplaySetActivePlayer.Add( function() --( iActivePlayer, iPrevActivePlayer )
		-- Reset the alert table and display
		alertTable = {}
		g_InstanceManager:ResetInstances()
		-- Kill All PopupText
		for _, v in pairs(g_InstanceMap) do
			if v then
				g_PopupIM:ReleaseInstance( v )
			end
		end
		g_InstanceMap = {}
		mustRefreshAlerts = false
	end)

	ContextPtr:SetUpdate( function(fDTime)
		if #alertTable > 0 then
			for _, v in ipairs( alertTable ) do
				if v.shownYet == true then
					v.elapsedTime = v.elapsedTime + fDTime
				end
				if v.elapsedTime >= 8 then
					mustRefreshAlerts = true
				end
			end
			if mustRefreshAlerts then
				local newAlertTable = {}
				g_InstanceManager:ResetInstances()
				for _, v in ipairs( alertTable ) do
					if v.elapsedTime < 8 then
						v.shownYet = true
						insert( newAlertTable, v )
					end
				end
				alertTable = newAlertTable
				for _, v in ipairs( alertTable ) do
					local controlTable = g_InstanceManager:GetInstance()
					controlTable.AlertMessageLabel:SetText( v.text )
					Controls.AlertStack:CalculateSize()
					Controls.AlertStack:ReprocessAnchoring()
				end
			end
		end
		mustRefreshAlerts = false
	end)

	local function KillPopupText( control )
		local szKey = tostring( control )
		local instance = g_InstanceMap[ szKey ]
		if instance then
			g_PopupIM:ReleaseInstance( instance )
			g_InstanceMap[ szKey ] = nil
		end
	end

	Events.AddPopupTextEvent.Add( function( worldPosition, text, delay )
		local instance = g_PopupIM:GetInstance()
		instance.Anchor:SetWorldPosition( worldPosition )
		instance.Text:SetText( text )
		g_InstanceMap[ tostring( instance.AlphaAnimOut ) ] = instance
		instance.AlphaAnimOut:RegisterAnimCallback( KillPopupText )
		instance.Anchor:BranchResetAnimation()
		instance.SlideAnim:SetPauseTime( delay )
		instance.AlphaAnimIn:SetPauseTime( delay )
		instance.AlphaAnimOut:SetPauseTime( delay + 0.75 )
	end)
end

----------------------------------------------------------------
----------------------------------------------------------------
Controls.ScrollTop:RegisterCallback( Mouse.eMouseEnter, Events.SerialEventCameraStartMovingForward.Call )
Controls.ScrollTop:RegisterCallback( Mouse.eMouseExit, Events.SerialEventCameraStopMovingForward.Call )
Controls.ScrollBottom:RegisterCallback( Mouse.eMouseEnter, Events.SerialEventCameraStartMovingBack.Call )
Controls.ScrollBottom:RegisterCallback( Mouse.eMouseExit, Events.SerialEventCameraStopMovingBack.Call )
Controls.ScrollLeft:RegisterCallback( Mouse.eMouseEnter, Events.SerialEventCameraStartMovingLeft.Call )
Controls.ScrollLeft:RegisterCallback( Mouse.eMouseExit, Events.SerialEventCameraStopMovingLeft.Call )
Controls.ScrollRight:RegisterCallback( Mouse.eMouseEnter, Events.SerialEventCameraStartMovingRight.Call )
Controls.ScrollRight:RegisterCallback( Mouse.eMouseExit, Events.SerialEventCameraStopMovingRight.Call )

-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
Events.SystemUpdateUI.Add( function( eType )
	if eType == BulkHideUI then
		Controls.BulkUI:SetHide( true )
	elseif eType == BulkShowUI then
		Controls.BulkUI:SetHide( false )
	end
end)

---------------------------------------------------------------------------------------
ContextPtr:SetShowHideHandler( function( bIsHide )
	if not bIsHide then
		Controls.ScreenEdgeScrolling:SetHide( not OptionsManager.GetFullscreen() )
		-- Check to see if we've been kicked.  It's possible that we were kicked while loading into the game.
		if Network.IsPlayerKicked(Game.GetActivePlayer()) then
			-- Display kicked popup.
			Events.SerialEventGameMessagePopup{ Type = ButtonPopupTypes.BUTTONPOPUP_KICKED, Data1 = BY_HOST }
			SetInterfaceModeSelection()
		end
		Controls.WorldViewControls:SetHide( false )
	end
end)

Events.SerialEventGameMessagePopup.Add( SetInterfaceModeSelection )

---------------------------------------------------------------------------------------
-- Check to see if the world view controls should be hidden
Events.GameViewTypeChanged.Add( function() --( eNewType )
	local bWorldViewHide = GetGameViewRenderType() == GAMEVIEW_NONE
	Controls.WorldViewControls:SetHide( bWorldViewHide )
	Controls.StagingRoom:SetHide( not bWorldViewHide )
end)

----------------------------------------------------------------
-- 'Active' (local human) player has changed
do
	local g_PerPlayerStrategicViewSettings = {}
	Events.GameplaySetActivePlayer.Add( function(iActivePlayer, iPrevActivePlayer)
		if iPrevActivePlayer ~= -1 then
			g_PerPlayerStrategicViewSettings[ iPrevActivePlayer ] = InStrategicView()
		end
		if iActivePlayer ~= -1 and not g_PerPlayerStrategicViewSettings[ iActivePlayer ] == InStrategicView() then
			ToggleStrategicView()
		end
		SetInterfaceModeSelection()
	end)
end

-------------------------------------------------
Events.MultiplayerGameAbandoned.Add( function( eReason )
	Events.SerialEventGameMessagePopup{ Type  = ButtonPopupTypes.BUTTONPOPUP_KICKED, Data1 = eReason }
	SetInterfaceModeSelection()
end)

-------------------------------------------------
Events.MultiplayerGameLastPlayer.Add( function()
	UI.AddPopup{ Type = ButtonPopupTypes.BUTTONPOPUP_TEXT, Data1 = 800, Option1 = true, Text = "TXT_KEY_MP_LAST_PLAYER" }
end)


---------------------------------------------------------------------------------------
-- Support for Modded Add-in UI's
---------------------------------------------------------------------------------------
do
	local g_uiAddins = {}
	local Path = Path
	for addin in Modding.GetActivatedModEntryPoints("InGameUIAddin") do
		local addinFile = Modding.GetEvaluatedFilePath(addin.ModID, addin.Version, addin.File)
		local addinPath = addinFile.EvaluatedPath
		-- Get the absolute path and filename without extension.
		local extension = Path.GetExtension(addinPath)
		local ok, result = pcall( ContextPtr.LoadNewContext, ContextPtr, addinPath:sub( 1, #addinPath - #extension ) )
		if ok then
			insert( g_uiAddins, result )
		else
			print( "Error loading InGameUIAddin", addinPath, result )
		end
	end
end


