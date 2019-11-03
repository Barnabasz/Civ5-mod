--==========================================================
-- Yield Icon Manager
-- re-written by bc1, compatible with all Civ V and BE versions
-- fix quantity erratic display & make code more efficient
-- add compatibility with "DLL - Various Mod Components" v63
-- show relevant resources in addition to yields
--==========================================================

-- Minor optimizations
local pairs = pairs
local insert = table.insert
local remove = table.remove
local sort = table.sort

local ContextPtr = ContextPtr
local GridToWorld = GridToWorld
local HexToWorld = HexToWorld
local ToHexFromGrid = ToHexFromGrid
local GetPlot = Map.GetPlot
local GetPlotByIndex = Map.GetPlotByIndex
local MaxPlotIndex = Map.GetNumPlots() - 1
local RefreshYieldVisibleMode = UI.RefreshYieldVisibleMode
local Mouse = Mouse
local Players = Players
local ShiftKeyDown = UI.ShiftKeyDown
local GetActiveTeam = Game.GetActiveTeam
local GetActivePlayer = Game.GetActivePlayer
local InStrategicView = InStrategicView

include( "EUI_utilities" )
local GameInfo = EUI.GameInfoCache
local PlotIndex = EUI.PlotIndex

-- Globals
local t = Modding.OpenUserData( "Enhanced User Interface Options", 1 )
local GetOptionValue = t.GetValue
local SetOptionValue = t.SetValue
local Controls = Controls
local g_HiddenControls = Controls.Scrap
local g_VisibleControls = Controls.YieldStore
local g_OptionsPanel = Controls.OptionsPanel
local g_Anchors = {}
local g_AvailableImageInstances = {}
local g_Textures = { "YieldAtlas.dds", "YieldAtlas.dds", "YieldAtlas.dds", "YieldAtlas.dds", "YieldAtlas_128_Culture.dds", "YieldAtlas_128_Faith.dds" }
local g_Offsets = { 0, 128 , 256, 384, 0, 0 }
local g_ColorRed = EUI.Color( 1, 0, 0, 1 )
local g_ColorWhite = EUI.Color( 1, 1, 1, 1 )
-- compatibility with "DLL - Various Mod Components" extra yields
local g_PlayerSettings = {}
local g_Sort = { "Resources", "Improvements", "Features", "Yields" }
local g_All = { Yields = {}, Resources = {}, Improvements = {}, Features = {} }
local g_CalculateYields = g_All.Yields
local g_Names = { Yields = "TXT_KEY_PEDIA_YIELD_LABEL", Resources = "TXT_KEY_CIV5_RESOURCES_HEADING", Features = "TXT_KEY_CIV5_FEATURES_HEADING", Improvements = "TXT_KEY_CIV5_IMPROVEMENTS_HEADING" }
local p = GetPlotByIndex(0)
local g_Funcs = { Resources = p.GetResourceType, Improvements = p.GetRevealedImprovementType, Features = p.GetFeatureType,
	Yields = function( plot, _, i )
		if g_CalculateYields[i]( plot, i-1, true ) > 0 then
			return i
		end
	end
}
local g_Controls = {}

for k, all in pairs( g_All ) do
	if k=="Yields" then
		for i = 1, (YieldTypes or {}).NUM_YIELD_TYPES or 4 do
			all[i] = p.CalculateYield
			local row = GameInfo.Yields[i-1]or{}
			for k, v in pairs( row ) do
				if k == "ImageTexture" then
					g_Textures[i] = v
				elseif k == "ImageOffset" then
					g_Offsets[i] = v
				end
			end
		end
		-- Ugly vanilla kludge
		if p.GetCulture then
			all[5] = p.GetCulture
		end
	else
		for row in GameInfo[k]() do
			all[ row.ID ] = row._Texture
		end
	end
end

local g_ActiveSettings, g_CalculateYields, g_Resources, g_Improvements, g_Features

--==========================================================
-- Update the controls to reflect the current known yields
local function UpdateYields( anchor, plot )

	local yields = {}
	local instance, amount, index, yieldIcon
	local stack, stack0, stack1, stack2 = anchor.Stack, anchor.Stack0, anchor.Stack1, anchor.Stack2
--	local size = 400

	-- show improvement icon
	local texture = g_Improvements[ plot:GetRevealedImprovementType( GetActiveTeam() ) ]
	local image = anchor.ImprovementImage
	if texture then
		if image then
			image:SetHide( false )
		else
			if not stack0 then
				ContextPtr:BuildInstanceForControlAtIndex( "Stack0", anchor, stack, 0 )
				stack0 = anchor.Stack0
			end
			ContextPtr:BuildInstanceForControlAtIndex( "Improvement", anchor, stack0, 0 )
			image = anchor.ImprovementImage
--			image:SetSizeVal( size, size )
		end
		image:SetTexture( texture )
		image:SetTextureSizeVal( 256, 256 )
		image:NormalizeTexture()
		image:SetColor( plot:IsImprovementPillaged() and g_ColorRed or g_ColorWhite )
	elseif image then
		image:SetHide( true )
	end

	-- show resource icon
	texture = g_Resources[ plot:GetResourceType( GetActiveTeam() ) ] or g_Features[ plot:GetFeatureType() ]
	image = anchor.ResourceImage
	if texture then
		if image then
			image:SetHide( false )
		else
			if not stack0 then
				ContextPtr:BuildInstanceForControlAtIndex( "Stack0", anchor, stack, 0 )
				stack0 = anchor.Stack0
			end
			ContextPtr:BuildInstanceForControl( "Resource", anchor, stack0 )
			image = anchor.ResourceImage
--			image:SetSizeVal( size, size )
		end
		image:SetTexture( texture )
		image:SetTextureSizeVal( 256, 256 )
		image:NormalizeTexture()
	elseif image then
		image:SetHide( true )
	end

	-- calculate terrain yields
	for i, calculateYield in pairs( g_CalculateYields ) do
		amount = calculateYield( plot, i-1, true )-- * 0 + math.random( 0, 3 ) * math.random( 0, 4 )
		if amount > 0 then
			insert( yields, i*1024 + amount )
		end
	end

	-- show yield icons
	local j = 1
	local n,m = #yields
	if n<5 then
		m = 4
	else
		m = (n+1)/2
		if not stack2 then
			ContextPtr:BuildInstanceForControl( "Stack2", anchor, stack )
			stack2 = anchor.Stack2
		end
	end
	for i = 1, n do
		index = yields[i]
		amount = index % 1024
		index = (index - amount) / 1024
		instance = anchor[j]
		if instance then
			yieldIcon = instance.Image
			yieldIcon:ChangeParent( i > m and stack2 or stack1 )
		else
			instance = remove( g_AvailableImageInstances )
			if instance then
				yieldIcon = instance.Image
				yieldIcon:ChangeParent( i > m and stack2 or stack1 )
			else
				instance = {}
				ContextPtr:BuildInstanceForControl( "Image", instance, i > m and stack2 or stack1 )
				yieldIcon = instance.Image
			end
			anchor[j] = instance
		end
		j = j + 1
		yieldIcon:SetTexture( g_Textures[ index ] or "YieldAtlas.dds" )
		yieldIcon:SetTextureOffsetVal( g_Offsets[ index ] or 0, amount>4 and 512 or 128 * (amount - 1) )

		-- add yield count icon
		if amount > 5 then
			instance = anchor[j]
			if instance then
				instance.Image:ChangeParent( yieldIcon )
			else
				instance = remove( g_AvailableImageInstances )
				if instance then
					instance.Image:ChangeParent( yieldIcon )
				else
					instance = {}
					ContextPtr:BuildInstanceForControl( "Image", instance, yieldIcon )
				end
			end
			anchor[j] = instance
			j = j + 1
			instance.Image:SetTexture( "YieldAtlas.dds" )
			instance.Image:SetTextureOffsetVal( amount > 12 and 256 or 128 * ((amount - 6) % 4), amount > 9  and 768 or 640 )
		end
	end
	-- discard unused images
	for _ = j, #anchor do
		instance = remove( anchor )
		instance.Image:ChangeParent( g_HiddenControls )
		insert( g_AvailableImageInstances, instance )
	end
	if stack0 then
		stack0:CalculateSize()
	end
	stack1:CalculateSize()
	if stack2 then
		stack2:CalculateSize()
	end
	stack:ReprocessAnchoring()
	anchor.NeedsUpdate = false
end

--==========================================================
-- Plot Yield Show / Hide
Events.ShowHexYield.Add(
function( x, y, isShown )
	local plot = GetPlot( x, y )
	if plot then

		local index = plot:GetPlotIndex()
		local anchor = g_Anchors[ index ]

		if isShown and plot:IsRevealed( GetActiveTeam(), false ) then
			if anchor then
				if not anchor.IsVisible then
					if anchor.NeedsUpdate then
						UpdateYields( anchor, plot )
					end
					-- make it visible
					anchor.Anchor:ChangeParent( g_VisibleControls )
					anchor.IsVisible = true
				end
			else
				-- set up new anchor: we do this only once per plot
				anchor = {}
				ContextPtr:BuildInstanceForControl( "Anchor", anchor, g_VisibleControls )
				anchor.IsVisible = true
				g_Anchors[ index ] = anchor
				x, y = GridToWorld( x, y )
				anchor.Anchor:SetWorldPositionVal( x, y, 0 )
				UpdateYields( anchor, plot )
			end

		elseif anchor and anchor.IsVisible then
			-- hide it
			anchor.Anchor:ChangeParent( g_HiddenControls )
			anchor.IsVisible = false
		end
	end
end)

--==========================================================
-- Plot Yield Update
Events.HexYieldMightHaveChanged.Add( function( x, y )
	local plot = GetPlot( x, y )
	if plot then
		local anchor = g_Anchors[ plot:GetPlotIndex() ]
		if anchor then
			if anchor.IsVisible then
				UpdateYields( anchor, plot )
			else
				anchor.NeedsUpdate = true -- will need to be updated when made visible again
			end
		end
	end
end)

local emptyTable = {}
local function UpdateYieldIcons_( isStrategicView )
	local t = g_ActiveSettings
	local enables = t.Enable
	g_Resources = not isStrategicView and enables.Resources and t.Resources or emptyTable
	g_Improvements = not isStrategicView and enables.Improvements and t.Improvements or emptyTable
	g_Features = not isStrategicView and enables.Features and t.Features or emptyTable
	g_CalculateYields = isStrategicView and g_All.Yields or (enables.Yields and t.Yields or emptyTable)
	for index, anchor in pairs( g_Anchors ) do
		if anchor.IsVisible then
			UpdateYields( anchor, GetPlotByIndex(index) )
		else
			anchor.NeedsUpdate = true
		end
	end
end
local function UpdateYieldIcons()
	return UpdateYieldIcons_( InStrategicView() )
end

--==========================================================
-- Initialize controls
local stack = Controls.OptionsStack
for _, what in pairs( g_Sort ) do
	local all = g_All[ what ]
	local info = GameInfo[ what ]
	local instance = {}
	local list = {}
	ContextPtr:BuildInstanceForControl( "OptionsEnable", instance, stack )
	local check = instance.OptionsEnable
	ContextPtr:BuildInstanceForControl( "OptionsStack", instance, stack )
	local stack = instance.OptionsStack -- !!! local change of destination stack to sub stack
	local controls = { list = list, stack = stack, check = check }
	g_Controls[ what ] = controls
	check:GetTextButton():LocalizeAndSetText( g_Names[ what ] )
	check:RegisterCheckHandler( function( isChecked )
		g_ActiveSettings.Enable[ what ] = isChecked
		stack:SetAlpha( isChecked and 1 or 0.5 )
		UpdateYieldIcons()
	end)
	local function OptionCheckHandler( isChecked, ID )
		if ShiftKeyDown() then
			for ID, control in pairs( list ) do
				g_ActiveSettings[ what ][ ID ] = isChecked and all[ ID ] or nil
				control:SetCheck( isChecked )
			end
		else
			g_ActiveSettings[ what ][ ID ] = isChecked and all[ ID ] or nil
		end
		UpdateYieldIcons()
	end
	local func = g_Funcs[ what ]
	local isYield = what == "Yields" and 1 or 0
	local currentID, set, idx
	local function FindOnMap( ID ) -- func, info, isYield
		if currentID ~=ID then
			currentID = ID
			idx = 0
			set = {}
			local activeTeam = GetActiveTeam()
			local GetPlotByIndex = GetPlotByIndex
			local func = func
			local set = set
			local insert = insert
			local plot = GetPlotByIndex(0)
			local IsRevealed = plot.IsRevealed
			for i = 0, MaxPlotIndex do
				plot = GetPlotByIndex(i)
				if IsRevealed( plot, activeTeam, true ) and func( plot, activeTeam, ID ) == ID then
					insert( set, plot )
				end
			end
			local player = Players[GetActivePlayer()]
			local capital = player and player:GetCapitalCity()
			if capital then
				local x, y = capital:GetX(), capital:GetY()
				sort( set, function(a,b) return PlotIndex(x,y,a:GetX(),a:GetY()) < PlotIndex(x,y,b:GetX(),b:GetY()) end )
			end
		end
		idx = idx % #set + 1
		local plot = set[idx]
		if plot then
			UI.LookAt( plot )
			local hex = ToHexFromGrid{ x=plot:GetX(), y=plot:GetY() }
			Events.GameplayFX( hex.x, hex.y, -1 )
			local n = plot:GetNumResource()
			return Events.AddPopupTextEvent( HexToWorld( hex ), (n>0 and (n>1 and n or"")..(info[ID-isYield].IconString or " ") or "")..info[ID-isYield]._Name..(#set>1 and"[NEWLINE]"..idx.."/"..#set or ""), 0 )
		else
			Events.AudioPlay2DSound( "AS2D_EVENT_NOTIFICATION_NEUTRAL" )
		end
	end
	local image, row
	for ID, texture in pairs(all) do
		ContextPtr:BuildInstanceForControl( "CheckBox", instance, stack )
		check = instance.CheckBox
		image = instance.Portrait
		if isYield==1 then
			image:SetTextureOffsetVal( (g_Offsets[ID]or 0)+32, 32 )
			image:SetTexture( g_Textures[ID] )
		else
			image:SetTexture( texture )
			image:SetTextureSizeVal( 256, 256 )
			image:NormalizeTexture()
		end
		row = info[ ID-isYield ]
		image:SetToolTipString( row and row._Name )
		check:SetVoid1( ID )
		check:RegisterCheckHandler( OptionCheckHandler )
		if func then
			check:RegisterCallback( Mouse.eRClick, FindOnMap )
		end
		list[ ID ] = check
	end
	if isYield~=1 then
		stack:SortChildren( function( a, b ) return a and b and a:GetToolTipString() < b:GetToolTipString() end )
	end
	stack:CalculateSize()
end

--==========================================================
-- Move option controls
Events.SequenceGameInitComplete.Add( function()
	local MiniMapOptionsPanel = LookUpControl( "/InGame/WorldView/MiniMapPanel/OptionsPanel" )
	if MiniMapOptionsPanel then
		stack:CalculateSize()
		local x, y = stack:GetSizeVal()
		if y<64 then y=64 elseif y>300 then y=300 end
		g_OptionsPanel:SetSizeVal( x+46, y+85 )
		g_OptionsPanel:ChangeParent( MiniMapOptionsPanel )
		Controls.OptionsScrollPanel:SetSizeVal( x, y )
		Controls.OptionsScrollPanel:CalculateInternalSize()
		Controls.OptionsScrollPanel:ReprocessAnchoring()
	end
end)

--==========================================================
-- 'Active' (local human) player has changed
local function OnGameplaySetActivePlayer() -- activePlayerID, prevActivePlayerID )
	local t = g_PlayerSettings[ GetActivePlayer() ]
	if not t then
		t = { Enable = {} }
		for what, all in pairs( g_All ) do
			local tt, i = {}
			local mapoption = "MAP_OPTIONS_"..what:upper()
			local isYield = what == "Yields" and 1 or 0
			for row in GameInfo[ what ]() do
				i = row.ID+isYield
				tt[ i ] = GetOptionValue( mapoption..row.Type ) ~= 0 and all[ i ] or nil
			end
			t[ what ] = tt
			t.Enable[ what ] = GetOptionValue( mapoption ) ~= 0
		end
		g_PlayerSettings[ GetActivePlayer() ] = t
	end
	local enables = t.Enable
	for what, controls in pairs( g_Controls ) do
		controls.check:SetCheck( enables[ what ] )
		controls.stack:SetAlpha( enables[ what ] and 1 or 0.5 )
		local tt = t[ what ]
		for ID, control in pairs( controls.list ) do
			control:SetCheck( tt[ ID ] )
		end
	end
	g_ActiveSettings = t
	UpdateYieldIcons()
	return RefreshYieldVisibleMode()
end
Events.GameplaySetActivePlayer.Add( OnGameplaySetActivePlayer )
OnGameplaySetActivePlayer()

if Events.StrategicViewStateChanged then
	Events.StrategicViewStateChanged.Add( function( isStrategicView )
		g_VisibleControls:SetOffsetY( isStrategicView and 60 or -60 )
		g_OptionsPanel:SetHide( isStrategicView )
		return UpdateYieldIcons_( isStrategicView )
	end)
end

--==========================================================
-- on shutdown we need to save settings and get our children
-- back, or they will get duplicated on future hotload
-- and we'll assert clearing the registered button handler
ContextPtr:SetShutdown( function()
	g_OptionsPanel:ChangeParent( g_HiddenControls )
	-- Save settings
	for what in pairs( g_All ) do
		local mapoption = "MAP_OPTIONS_"..what:upper()
		SetOptionValue( mapoption, g_ActiveSettings.Enable[ what ] and 1 or 0 )
		local tt = g_ActiveSettings[ what ]
		local isYield = what == "Yields" and 1 or 0
		for row in GameInfo[ what ]() do
			SetOptionValue( mapoption..row.Type, tt[ row.ID+isYield ] and 1 or 0 )
		end
	end
end)
