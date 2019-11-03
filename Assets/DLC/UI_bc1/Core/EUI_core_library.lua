EUI = {} local EUI = EUI
local civ5_mode = InStrategicView ~= nil
local civBE_mode = not civ5_mode
local bnw_mode, gk_mode

-------------------------------------------------
-- Minor lua optimizations
-------------------------------------------------
local ceil = math.ceil
local floor = math.floor
local max = math.max
local min = math.min
local sqrt = math.sqrt
local pairs = pairs
local print = print
local setmetatable = setmetatable
local insert = table.insert
local remove = table.remove
local sort = table.sort
local tonumber = tonumber
local tostring = tostring
local type = type
local unpack = unpack or table.unpack -- depends on Lua version

local ContentManager_IsActive = ContentManager.IsActive
local ContentType_GAMEPLAY = ContentType.GAMEPLAY
local DB_Query = DB.Query
local Game = Game
local GameDefines = GameDefines
local GameInfo = GameInfo
local L = Locale.ConvertTextKey
local Locale = Locale
local PreGame = PreGame
local TradeableItems = TradeableItems

if Game and PreGame then

	local GetPlot = Map.GetPlot
	local GetPlotXY = Map.GetPlotXY
	local ScratchDeal = UI.GetScratchDeal()
	local g_savedDealStack = {}

	function EUI.PushScratchDeal()
--print("PushScratchDeal")
		-- save curent deal
		local item = {}
		local deal = {}
		item.SetFromPlayer = ScratchDeal:GetFromPlayer()
		item.SetToPlayer = ScratchDeal:GetToPlayer()
		item.SetSurrenderingPlayer = ScratchDeal:GetSurrenderingPlayer()
		item.SetDemandingPlayer = ScratchDeal:GetDemandingPlayer()
		item.SetRequestingPlayer = ScratchDeal:GetRequestingPlayer()

		ScratchDeal:ResetIterator()
		repeat
--print( unpack(item) )
			insert( deal, item )
			item = { ScratchDeal:GetNextItem() }
		until #item < 1
		insert( g_savedDealStack, deal )
		ScratchDeal:ClearItems()
	end

	local g_deal_functions = {
		[ TradeableItems.TRADE_ITEM_MAPS or-1] = function( from )
			return ScratchDeal:AddMapTrade( from )
		end,
		[ TradeableItems.TRADE_ITEM_RESOURCES or-1] = function( from, item )
			return ScratchDeal:AddResourceTrade( from, item[4], item[5], item[2] )
		end,
		[ TradeableItems.TRADE_ITEM_CITIES or-1] = function( from, item )
			local plot = GetPlot( item[4], item[5] )
			local city = plot and plot:GetPlotCity()
			if city and city:GetOwner() == from then
				return ScratchDeal:AddCityTrade( from, city:GetID() )
			else
				print( "Cannot add city trade", city and city:GetName(), unpack(item) )
			end
		end,
		[ TradeableItems.TRADE_ITEM_UNITS or-1] = function( from, item )
			return ScratchDeal:AddUnitTrade( from, item[4] )
		end,
		[ TradeableItems.TRADE_ITEM_OPEN_BORDERS or-1] = function( from, item )
			return ScratchDeal:AddOpenBorders( from, item[2] )
		end,
		[ TradeableItems.TRADE_ITEM_TRADE_AGREEMENT or-1] = function( from, item )
			return ScratchDeal:AddTradeAgreement( from, item[2] )
		end,
		[ TradeableItems.TRADE_ITEM_PERMANENT_ALLIANCE or-1] = function()
			print( "Error - alliance not supported by game DLL")--ScratchDeal:AddPermamentAlliance()
		end,
		[ TradeableItems.TRADE_ITEM_SURRENDER or-1] = function( from )
			return ScratchDeal:AddSurrender( from )
		end,
		[ TradeableItems.TRADE_ITEM_TRUCE or-1] = function()
			print( "Error - truce not supported by game DLL")--ScratchDeal:AddTruce()
		end,
		[ TradeableItems.TRADE_ITEM_PEACE_TREATY or-1] = function( from, item )
			return ScratchDeal:AddPeaceTreaty( from, item[2] )
		end,
		[ TradeableItems.TRADE_ITEM_THIRD_PARTY_PEACE or-1] = function( from, item )
			return ScratchDeal:AddThirdPartyPeace( from, item[4], item[2] )
		end,
		[ TradeableItems.TRADE_ITEM_THIRD_PARTY_WAR or-1] = function( from, item )
			return ScratchDeal:AddThirdPartyWar( from, item[4] )
		end,
		[ TradeableItems.TRADE_ITEM_THIRD_PARTY_EMBARGO or-1] = function( from, item )
			return ScratchDeal:AddThirdPartyEmbargo( from, item[4], item[2] )
		end,
		-- civ5
		[ TradeableItems.TRADE_ITEM_GOLD or-1] = function( from, item )
			return ScratchDeal:AddGoldTrade( from, item[4] )
		end,
		[ TradeableItems.TRADE_ITEM_GOLD_PER_TURN or-1] = function( from, item )
			return ScratchDeal:AddGoldPerTurnTrade( from, item[4], item[2] )
		end,
		[ TradeableItems.TRADE_ITEM_DEFENSIVE_PACT or-1] = function( from, item )
			return ScratchDeal:AddDefensivePact( from, item[2] )
		end,
		[ TradeableItems.TRADE_ITEM_RESEARCH_AGREEMENT or-1] = function( from, item )
			return ScratchDeal:AddResearchAgreement( from, item[2] )
		end,
		[ TradeableItems.TRADE_ITEM_ALLOW_EMBASSY or-1] = function( from )
			return ScratchDeal:AddAllowEmbassy( from )
		end,
		[ TradeableItems.TRADE_ITEM_DECLARATION_OF_FRIENDSHIP or-1] = function( from )
			return ScratchDeal:AddDeclarationOfFriendship( from )
		end,
		[ TradeableItems.TRADE_ITEM_VOTE_COMMITMENT or-1] = function( from, item )
			return ScratchDeal:AddVoteCommitment( from, item[4], item[5], item[6], item[7] )
		end,
		-- civ be
		[ TradeableItems.TRADE_ITEM_ENERGY or-1] = function( from, item )
			return ScratchDeal:AddGoldTrade( from, item[4] )
		end,
		[ TradeableItems.TRADE_ITEM_ENERGY_PER_TURN or-1] = function( from, item )
			return ScratchDeal:AddGoldPerTurnTrade( from, item[4], item[2] )
		end,
		[ TradeableItems.TRADE_ITEM_ALLIANCE or-1] = function( from, item )
			return ScratchDeal:AddAlliance( from, item[2] )
		end,
		[ TradeableItems.TRADE_ITEM_COOPERATION_AGREEMENT or-1] = function( from )
			return ScratchDeal:AddCooperationAgreement( from )
		end,
		[ TradeableItems.TRADE_ITEM_FAVOR or-1] = function( from, item )
			return ScratchDeal:AddFavorTrade( from, item[4] )
		end,
		[ TradeableItems.TRADE_ITEM_RESEARCH_PER_TURN or-1] = function( from, item )
			return ScratchDeal:AddResearchPerTurnTrade( from, item[4], item[2] )
		end,
		-- cdf / cp / cbp
		[ TradeableItems.TRADE_ITEM_VASSALAGE or-1] = function( from )
			return ScratchDeal:AddVassalageTrade( from )
		end,
		[ TradeableItems.TRADE_ITEM_VASSALAGE_REVOKE or-1] = function( from )
			return ScratchDeal:AddRevokeVassalageTrade( from )
		end,
		[ TradeableItems.TRADE_ITEM_TECHS or-1] = function( from, item )
			return ScratchDeal:AddTechTrade( from, item[4] )
		end,
	} g_deal_functions[-1] = nil

	function EUI.PopScratchDeal()
--print("PopScratchDeal")
		-- restore saved deal
		ScratchDeal:ClearItems()
		local deal = remove( g_savedDealStack )
		if deal then
			for k,v in pairs( deal[1] ) do
				ScratchDeal[ k ]( ScratchDeal, v )
			end

			for i = 2, #deal do
				local item = deal[ i ]
				local from = item[#item]
				local tradeType = item[1]
				local f = g_deal_functions[ tradeType ]
				if f and ScratchDeal:IsPossibleToTradeItem( from, ScratchDeal:GetOtherPlayer(from), tradeType, item[4], item[5], item[6], item[7] ) then
					f( from, item )
				else
					print( "Cannot restore deal trade", unpack(item) )
				end
			end
--print( "Restored deal#", #g_savedDealStack ) ScratchDeal:ResetIterator() repeat local item = { ScratchDeal:GetNextItem() } print( unpack(item) ) until #item < 1
		else
			print( "Cannot pop scratch deal" )
		end
	end

	local g_maximumAcquirePlotArea = (GameDefines.MAXIMUM_ACQUIRE_PLOT_DISTANCE+1) * GameDefines.MAXIMUM_ACQUIRE_PLOT_DISTANCE * 3
	local g_maximumAcquirePlotPerimeter = GameDefines.MAXIMUM_ACQUIRE_PLOT_DISTANCE * 6

	if GetPlot(0,0).GetCityPurchaseID then
		EUI.CityPlots = function( city, m )
			local cityID = city:GetID()
			local cityOwnerID = city:GetOwner()
			if not m then m = 0 end
			local n = g_maximumAcquirePlotArea
			local p = g_maximumAcquirePlotPerimeter
			return function()
				repeat
					for i = m, n do
						local plot = city:GetCityIndexPlot( i )
						if plot	and plot:GetOwner() == cityOwnerID and plot:GetCityPurchaseID() == cityID then
							m = i+1
							return plot
						end
					end
					-- if no owned plots were found in previous ring then we're done
					if m <= n-p+1 then
						return
					end
					-- plots found, search next ring
					m = n + 1	--first plot of next ring
					p = p + 6	--perimeter of next ring
					n = n + p	--last plot of next ring
				until false
			end
		end
	else
		EUI.CityPlots = function( city, i )
			if not i then i = 0 end
			return function()
				while i <= g_maximumAcquirePlotArea do
					local plot = city:GetCityIndexPlot( i )
					i = i+1
					if plot	and plot:GetWorkingCity() == city then
						return plot
					end
				end
			end
		end
	end

	--usage1: IndexPlot( plot, hexAreaPlotIndex )
	--OR usage2: IndexPlot( plot, ringPlotIndex, ringDistanceFromPlot )
	function EUI.IndexPlot( plot, i, r )
		-- determine if input parameters are valid - you can delete this part for a tiny performance boost
		if not plot or not i or i<0 or (r and (r<0 or i>6*r)) then
			return print("IndexPlot error - invalid parameters")
		end
		-- area plot index mode ?
		if not r then
			-- area plot index 0 is a special case
			if i == 0 then
				return plot
			else
				-- which ring are we on ?
				r = ceil( ( sqrt( 12*i + 9 ) - 3 ) / 6 )
				-- determine ring plot index (substract inside area)
				i = i - ( 3 * (r-1) * r ) - 1
			end
		end

		-- determine coordinate offsets corresponding to ring index
		local x, y
		if i <= 2*r then
			x = min( i, r )
		elseif i<= 4*r then
			x = 3*r-i
		else
			x = max( i-6*r, -r )
		end
		if i <= 3*r then
			y = max( r-i, -r )
		else
			y = min( i-4*r, r )
		end

		-- return plot offset from initial plot
		return GetPlotXY( plot:GetX(), plot:GetY(), x, y )
	end

	local isWrapX = Map.IsWrapX()
	local isWrapY = Map.IsWrapY()
	local Xmax, Ymax = Map.GetGridSize()
	local halfXmax, halfYmax = floor(Xmax/2), floor(Ymax/2)
	--usage: returns index of 2nd plot relative to 1st plot
	function EUI.PlotIndex( X, Y, x, y )
		-- offset & world wrap
		y = y - Y
		if isWrapY then y = (y+halfYmax) % Ymax - halfYmax end
		x = x - X - floor( y/2 )
		if isWrapX then x = (x+halfXmax) % Xmax - halfXmax end
		-- [4r..6r[
		if x<0 and y>=0 then
			local r = max(-x, y)
			return 3*r*r+2*r+1+x+y
		-- [0..2r]
		elseif x>=0 and x>=-y then
			local r = max(x, x+y)
			if r==0 then
				return 0
			end
			return 3*r*r-2*r+1-y
		-- [2r..4r]
		else --if x<=0 and x<=-y then
			local r = max(-y, -x-y)
			return 3*r*r+1-x
		end
	end

	--usage: returns number of plots in hexagonal area of specified radius, excluding center plot
	function EUI.CountHexPlots( r )
		return (r+1) * r * 3
	end

	--usage: returns radius of specified hexagonal area
	function EUI.RadiusHexArea( a )
		return ( sqrt( 1 + 4*a/3 ) - 1 ) / 2
	end
--[[
	do
		local r = 10
		local a = EUI.CountHexPlots( r-1 )+1
		local x0, y0 = 0, 20
		local p0 = GetPlot(x0, y0)
		local b=true
		for i = 0, r*6-1 do
			local p = EUI.IndexPlot( p0, i, r )
			local j, k, l, x, y
			if p then
				x, y = p:GetX(), p:GetY()
				j = EUI.PlotIndex( x0, y0, x, y )-a
			end
			b = b and i==j
			print( b, i==j, i, x - floor( y/2 ), y, j )
		end
	end
--]]
end

local table = {
	insert = table.insert,
	concat = table.concat,
	remove = table.remove,
	sort = table.sort,
	maxn = table.maxn,
	unpack = unpack,
	count = table.count or	--Firaxis specific
	function( t )
		local n=0
		for _ in pairs(t) do
			n=n+1
		end
		return n
	end,
	fill = table.fill or --Firaxis specific
	function( a, b, c )
		if c then
			a={}
			for i=1, c do a[i]=b end
		else
			local t={}
			for i=1, b do t[i]=a end
			return t
		end
	end,
	append = function( self, text )
		self[#self] = self[#self] .. text
	end,
	insertLocalized = function( self, ... )
		return insert( self, L( ... ) )
	end,
	insertIf = function( self, s )
		if s then
			return insert( self, s )
		end
	end,
	insertLocalizedIf = function( self, ... )
		if ... then
			return insert( self, L( ... ) )
		end
	end,
	insertLocalizedIfNonZero = function( self, textKey, ... )
		if ... ~= 0 then
			return insert( self, L( textKey, ... ) )
		end
	end,
	insertLocalizedBulletIfNonZero = function( self, a, b, ... )
		if tonumber( b ) then
			if b ~= 0 then
				return insert( self, "[ICON_BULLET]" .. L( a, b, ... ) )
			end
		elseif ... ~= 0 then
			return insert( self, a .. L( b, ... ) )
		end
	end,
}
table.__index = table
setmetatable( table, {__call = function(self, ...) return setmetatable( {...}, table ) end } )
EUI.table = table

local Color
if civ5_mode then
	Color = function( red, green, blue, alpha )
		return {x = red or 0, y = green or 0, z = blue or 0, w = alpha or 1}
	end
else
	local function byte(n)
		return (n>=1 and 255) or (n<=0 and 0) or floor(n * 255)
	end
	Color = function( red, green, blue, alpha )
		return byte(red or 0) + byte(green or 0)*0x100 + byte(blue or 0)*0x10000 + byte(alpha or 1)*0x1000000
	end
end
EUI.Color = Color

function EUI.Capitalize( s )
	return  Locale.ToUpper( s:sub(1,1) ) .. Locale.ToLower( s:sub(2) )
end

local nilTable = {}
local function nilFunction() end
local nilInfoCache = setmetatable( {}, { __call = function() return nilFunction end } )
local function sortByName(a,b) return a._Name < b._Name end
local sortFunction = {
	Beliefs = sortByName,
	Buildings = sortByName,
	Features = sortByName,
	Improvements = sortByName,
	Processes = sortByName,
	Promotions = sortByName,
	Resources = sortByName,
	Units = sortByName,
	}
local g_Textures = { RESOURCE_JEWELRY = "SV_Jewelry.dds", RESOURCE_PORCELAIN = "SV_Porcelain.dds" }
local recordTypes = { null=type(nil), integer=type(0),  int=type(0), float=type(0.1), boolean=type(true), text=type"" }

local GameInfoCache = setmetatable( {}, { __index = function( GameInfoCache, tableName )
	local GameInfoTable = GameInfo[ tableName ]
--[[
pre-game:
__call = function() DB_Query("SELECT * from "..tableName)
__index = function( t, key ): if tonumber(key) DB_Query("SELECT * from "..tableName.." where ID = ?", key) ID = key or Type = key...
--]]
	local cache
	local L = L
	if GameInfoTable then
		local keys = {}
--print( "Caching GameInfo table", tableName )
		for row in DB_Query( "PRAGMA table_info("..tableName..")" ) do
			-- cid	name	type	notnull	dflt_value	pk
			keys[ row.name ] = true
--print( row.cid, row.name, row.type, row.notnull, row.dflt_value, row.pk )
		end
--[[
Each cache table is created by GameInfoCache metatable __index function:
- master set row array is populated from game info, and with setMT metatable to populate master set αkeys
When a master set αkey is queried, setMT( set, key ) handles creation of αkey structure:
- an index of all possible αkey values found in row array, with each value having a sub-set structure
- each subset row array is populated, and with setMT metatable to populate subset αkeys

{ [#]row-{ [αkeys]-value }
  [αkeys]-{ [values]-{ [#]row-{ [αkeys]-value }
master                 [αkeys]-{ [values] ...
set       index      set       index
--]]
		local setMT
		setMT = { __index = function( set, key )
			if keys[ key ] then -- verify key name exists and is a string
--print("Creating index for key", key )
				local index, subset, r, v = {}
				for i = 1, #set do -- iterate over set row array
					r = set[ i ]
					v = r[ key ]
					if v ~= nil then -- does row have a defined value for this αkey ?
						subset = index[ v ] -- get subset corresponding to this αkey value
						if not subset then -- create subset if none already exists
							subset = setmetatable( {}, setMT ) -- setMT will populate subset αkeys
							index[ v ] = subset -- assign subset to index αkey value
						end
						insert( subset, r ) -- add row to subset row array
					end
				end
				if subset then -- have we created at least one subset ?
					set[ key ] = index -- assign index to set αkey
					return index
				else
					set[ key ] = false -- prevent setMT from being called again
				end
			end
		end }
		local masterset = setmetatable( {}, setMT )
		cache = setmetatable( {}, { __call = function( cache, condition )
			local set = masterset
			if condition then
				-- Warning: EUI's GameInfoCache iterator only supports table conditions, and assumes keys are strings (integer keys will break havok)
				for key, value in pairs( condition ) do
					set = (set[ key ] or nilTable)[ value ] -- can trigger setMT.__index for set and/or for set[ key ][ value ]
					if not set then
						return nilFunction -- no iterations
					end
				end
			end
			local i, n = 0, #set
			return function() -- iterator
				if i < n then
					i = i+1
					return set[ i ]
				end
			end
		end } )
--print( "populate cache primary key index and master set", tableName )
		local name, r = (keys.ShortDescription and "ShortDescription") or (keys.Description and "Description")
		for row in GameInfoTable() do
			r = {}
			for k, v in pairs( row ) do -- make local row copy
				r[ k ] = v
			end
			if r.ID then
				cache[ r.ID ] = r -- populate cache primary key index
			end
			if r.Type then
				cache[ r.Type ] = r -- populate cache secondary key index
			end
			if name then
				r._Name = L( tostring(r[name]) ) -- cache localized row name
			end
			if r.ArtDefineTag then
				if g_Textures[r.Type] then
					r._Texture = g_Textures[r.Type]
				else
					row = GameInfo.ArtDefine_StrategicView{ StrategicViewType = row.ArtDefineTag }()
					r._Texture = row and row.Asset -- cache texture name
				end
			end
			insert( masterset, r ) -- populate master set
		end
--[[
		-- Check database integrity
		local foreign_keys, fk = {}
		for row in DB_Query( "PRAGMA foreign_key_list("..tableName..")" ) do
		--	id	seq	table	from	to	on_update	on_delete
			if row.to ~= "Tag" then	-- exclude language Tag
				foreign_keys[ row.from ] = row
			end
--print( row.id, row.seq, row.table, row.from, row.to, row.on_update, row.on_delete )
		end
		for r in cache() do
			for k, v in pairs( r ) do
--				if keys[k] and type(v) ~= recordTypes[keys[k].type:lower()] then
--					if v ~= nil or keys[k].notnull ~= 0 then
--						print( "***DB ERROR***", tableName.."."..k, type(v), v, "format expected:", keys[k].type, recordTypes[keys[k].type] )
--					end
--				end
				-- check foreign keys
				fk = foreign_keys[ k ]
				if fk and not(GameInfo[ fk.table ] or nilFunction){ [fk.to] = v } then
					print( "***DB ERROR***", tableName.."."..k, "has an invalid foreign key value", v, "without corresponding record", fk.table.."."..fk.to )
				end
			end
		end
--]]
		if name and sortFunction[tableName] then
--print( "sorting master set for", tableName )
			sort( masterset, sortFunction[tableName] )
		end
--cache.__ = masterset
--print( "master set includes", #masterset, "items" )
	else
		print( tableName, "GameInfo table is undefined for this game version and/or mods" )
		cache = nilInfoCache
	end
	GameInfoCache[ tableName ] = cache
	return cache
end } )

EUI.GameInfoCache = GameInfoCache
local YieldIcons = {}
EUI.YieldIcons = YieldIcons
local YieldNames = {}
EUI.YieldNames = YieldNames
local IconTextureAtlases = {}
local PrimaryColors = {}
local BackgroundColors = {}
EUI.PrimaryColors = PrimaryColors
EUI.BackgroundColors = BackgroundColors
local PlayerCivs = {}
local IsCustomColor = {}

local AtlasMT = function( t, atlasName )
	setmetatable( t, nil ) -- remove metatable to prevent recursion
--print( "caching atlasses")
	for row in GameInfo.IconTextureAtlases() do
		local atlas = t[ row.Atlas ]
		if not atlas then
			atlas = {}
			t[ row.Atlas ] = atlas
		end
		atlas[ row.IconSize ] = { row.Filename, row.IconsPerRow, row.IconsPerColumn }
	end
	return t[ atlasName ]
end

local function cleartable( t )
	for k in pairs(t) do
		t[k] = nil
	end
end

local GreatPeopleIcons = {
	SPECIALIST_CITIZEN = "[ICON_CITIZEN]",
	SPECIALIST_WRITER = "[ICON_GREAT_WRITER]",
	SPECIALIST_ARTIST = "[ICON_GREAT_ARTIST]",
	SPECIALIST_MUSICIAN = "[ICON_GREAT_MUSICIAN]",
	SPECIALIST_SCIENTIST = "[ICON_GREAT_SCIENTIST]",
	SPECIALIST_MERCHANT = "[ICON_GREAT_MERCHANT]",
	SPECIALIST_ENGINEER = "[ICON_GREAT_ENGINEER]",
	SPECIALIST_GREAT_GENERAL = "[ICON_GREAT_GENERAL]",
	SPECIALIST_GREAT_ADMIRAL = "[ICON_GREAT_ADMIRAL]",
	SPECIALIST_PROPHET = "[ICON_PROPHET]",
	UNITCLASS_WRITER = "[ICON_GREAT_WRITER]",
	UNITCLASS_ARTIST = "[ICON_GREAT_ARTIST]",
	UNITCLASS_MUSICIAN = "[ICON_GREAT_MUSICIAN]",
	UNITCLASS_SCIENTIST = "[ICON_GREAT_SCIENTIST]",
	UNITCLASS_MERCHANT = "[ICON_GREAT_MERCHANT]",
	UNITCLASS_ENGINEER = "[ICON_GREAT_ENGINEER]",
	UNITCLASS_GREAT_GENERAL = "[ICON_GREAT_GENERAL]",
	UNITCLASS_GREAT_ADMIRAL = "[ICON_GREAT_ADMIRAL]",
	UNITCLASS_PROPHET = "[ICON_PROPHET]",
}

function EUI.GreatPeopleIcon(k)
	return bnw_mode and GreatPeopleIcons[k] or "[ICON_GREAT_PEOPLE]"
end
EUI.GreatPeopleIcons = GreatPeopleIcons

local g_SpecialYieldTextures = { YIELD_CULTURE="YieldAtlas_128_Culture.dds", YIELD_FAITH="YieldAtlas_128_Faith.dds" }
local g_SpecialYieldTextureOffsets = { YIELD_PRODUCTION=128, YIELD_GOLD=256, YIELD_SCIENCE=384 }

function EUI.ResetCache()
	bnw_mode = civBE_mode or ContentManager_IsActive("6DA07636-4123-4018-B643-6575B4EC336B", ContentType_GAMEPLAY)
	gk_mode = bnw_mode or ContentManager_IsActive("0E3751A1-F840-4e1b-9706-519BF484E59D", ContentType_GAMEPLAY)
	cleartable( GameInfoCache )
	cleartable( YieldIcons )
	cleartable( YieldNames )
	cleartable( IconTextureAtlases )
	setmetatable( IconTextureAtlases, { __index = AtlasMT } )
	for row in Game and GameInfo.Yields() or DB_Query("SELECT * from Yields") do
		YieldIcons[row.ID or false] = row.IconString
		YieldNames[row.ID or false] = L(row.Description)
		YieldIcons[row.Type or false] = row.IconString
		YieldNames[row.Type or false] = L(row.Description)
	end
	YieldIcons.YIELD_CULTURE = YieldIcons.YIELD_CULTURE or "[ICON_CULTURE]"
	YieldNames.YIELD_CULTURE = YieldNames.YIELD_CULTURE or L"TXT_KEY_TRADE_CULTURE"
	for unit in Game and GameInfo.Units() or DB_Query("SELECT * from Units") do
		GreatPeopleIcons[unit.ID or false] = GreatPeopleIcons[unit.Class]
		GreatPeopleIcons[unit.Type or false] = GreatPeopleIcons[unit.Class]
	end

	if PreGame then
		local i
		for y in GameInfoCache.Yields() do
			i = y.ID
			y.ImageTexture = y.ImageTexture or g_SpecialYieldTextures[y.Type] or "YieldAtlas.dds"
			y.ImageOffset = y.ImageOffset or g_SpecialYieldTextureOffsets[y.Type] or 0
			y.IconString = y.IconString or "?"
		end
		if civ5_mode and not gk_mode then
			local y = { ID=i+1, Type="YIELD_CULTURE", Description="TXT_KEY_TRADE_CULTURE", _Name=L"TXT_KEY_TRADE_CULTURE", IconString="[ICON_CULTURE]", ImageTexture="YieldAtlas_128_Culture.dds", ImageOffset=0,
						HillsChange=0, MountainChange=0, LakeChange=0, CityChange=0, PopulationChangeOffset=0, PopulationChangeDivisor=0, MinCity=0, GoldenAgeYield=0, GoldenAgeYieldThreshold=0, GoldenAgeYieldMod=0, AIWeightPercent=0 }
			GameInfoCache.Yields[y.Type] = y
			GameInfoCache.Yields[y.ID] = y
		end
		for playerID = 0, GameDefines.MAX_CIV_PLAYERS do -- including barbs/aliens !

			local thisCivType = PreGame.GetCivilization( playerID )
			local thisCiv = GameInfo.Civilizations[ thisCivType ] or {}
			local defaultColorSet = GameInfo.PlayerColors[thisCiv.DefaultPlayerColor or -1]
			local colorSet = GameInfo.PlayerColors[ PreGame.GetCivilizationColor( playerID ) ] or defaultColorSet
			local primaryColor = colorSet and GameInfo.Colors[ colorSet.PrimaryColor or -1 ]
			local secondaryColor = colorSet and GameInfo.Colors[ colorSet.SecondaryColor or -1 ]
			if thisCivType == GameInfo.Civilizations.CIVILIZATION_MINOR.ID then
				primaryColor, secondaryColor = secondaryColor, primaryColor
				defaultColorSet = false
			end
			PlayerCivs[ playerID ] = thisCiv
			IsCustomColor[ playerID ] = colorSet ~= defaultColorSet
			PrimaryColors[ playerID ] = primaryColor and Color( primaryColor.Red, primaryColor.Green, primaryColor.Blue, primaryColor.Alpha ) or Color( 1, 1, 1, 1 )
			BackgroundColors[ playerID ] = secondaryColor and Color( secondaryColor.Red, secondaryColor.Green, secondaryColor.Blue, secondaryColor.Alpha ) or Color( 0, 0, 0, 1 )
		end
--[[
print("ResetCache")
local function to_string_expanded( var )
--function x(var)
	local nt = {}
	local kt = {}
	local function f( n, var, k )
		if type( var ) == "table" then
			if not nt[var] or nt[var] > n then
				nt[var] = n
				kt[var] = k
				for k, v in pairs( var ) do
					f( n+1, v, k )
				end
			end
		end
	end
	f( 0, var, "!root" )
	function f( n, var, parent )
		if type( var ) ~= "table" then
			return tostring( var )
		elseif var == parent then
			return "!self"
		elseif nt[var] and nt[var] < n then
			return tostring(kt[var]).."("..tostring( var )..")"
		else
			local t = {}
			for k, v in pairs( var ) do
				if type(k) ~= "string" then
					k = "["..tostring(k).."]"
				end
				table.insert( t, k..string.rep(" ",5-k:len()).." = "..f( n+1, v, var ) )
			end
			local mt = getmetatable( var )
			if mt then
				table.insert( t, "!metatable = "..f( n+1, mt, var ) )
			end
			table.sort( t )
			return "{ "..table.concat( t, ","..string.char(10)..string.rep(string.char(9),n) ).." }"
		end
	end
	return f( 0, var )
end
for k, v in pairs( PlayerCivs ) do print( k, IsCustomColor[ k ], to_string_expanded(v), to_string_expanded(PrimaryColors[ k ]), to_string_expanded(BackgroundColors[ k ]) ) end
--]]
	end
end
EUI.ResetCache()
Events.AfterModsDeactivate.Add( EUI.ResetCache )
Events.AfterModsActivate.Add( EUI.ResetCache )

---------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------
local function IconLookup( index, iconSize, atlas )

	local entry = (index or -1) >= 0 and (IconTextureAtlases[ atlas ] or nilTable)[ iconSize ]
	if entry then
		local filename = entry[1]
		local numRows = entry[3]
		local numCols = entry[2]
		if filename and index < numRows * numCols then
			return { x=(index % numCols) * iconSize, y = floor(index / numCols) * iconSize }, filename
		end
		print( "IconLookup error - filename:", filename, "numRows:", numRows, "numCols:", numCols )
	end
	print( "IconLookup error - icon index:", index, "icon size:", iconSize, "atlas:", atlas )
end
EUI.IconLookup = IconLookup

---------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------
local function IconHookup( index, iconSize, atlas, imageControl )

	local entry = imageControl and (index or -1) >= 0 and (IconTextureAtlases[ atlas ] or nilTable)[ iconSize ]
	if entry then
		local filename = entry[1]
		local numRows = entry[3]
		local numCols = entry[2]
		if filename and index < numRows * numCols then
			imageControl:SetTextureOffsetVal( (index % numCols) * iconSize, floor(index / numCols) * iconSize )
			imageControl:SetTexture( filename )
			return true
		end
		print( "IconHookup error - filename:", filename, "numRows:", numRows, "numCols:", numCols )
	end
	print( "IconHookup error - icon index:", index, "icon size:", iconSize, "atlas:", atlas, "image control:", imageControl and imageControl:GetID() )
end
EUI.IconHookup = IconHookup

---------------------------------------------------------------------------------------------------------
-- Art Team Color Variables
---------------------------------------------------------------------------------------------------------
local white = Color( 1, 1, 1, 1 )
local downSizes = { [80] = 64, [64] = 48, [57] = 45, [45] = 32, [32] = 24 }
local textureOffsets = civ5_mode and { [64] = 141, [48] = 77, [32] = 32, [24] = 0 } or { [64] = 200, [48] = 137, [45] = 80, [32] = 32, [24] = 0 }
local unmetCiv = { PortraitIndex = civ5_mode and 23 or 24, IconAtlas = "CIV_COLOR_ATLAS", AlphaIconAtlas = civ5_mode and "CIV_COLOR_ATLAS" or "CIV_ALPHA_ATLAS" }
---------------------------------------------------------------------------------------------------------
-- This is a special case hookup for civilization icons that will take into account
-- the fact that player colors are dynamically handed out
---------------------------------------------------------------------------------------------------------
function EUI.CivIconHookup( playerID, iconSize, iconControl, backgroundControl, shadowIconControl, alwaysUseComposite, shadowed, highlightControl )
	local thisCiv = PlayerCivs[ playerID ]
	if thisCiv then
		if alwaysUseComposite or IsCustomColor[ playerID ] or not thisCiv.IconAtlas then

			if backgroundControl then
				iconSize = downSizes[ iconSize ] or iconSize
				backgroundControl:SetTexture( "CivIconBGSizes.dds" )
				backgroundControl:SetTextureOffsetVal( textureOffsets[ iconSize ] or 0, 0 )
				backgroundControl:SetColor( BackgroundColors[ playerID ] )
				backgroundControl:SetHide( false )
			end

			if highlightControl then
				highlightControl:SetTexture( "CivIconBGSizes_Highlight.dds" )
				highlightControl:SetTextureOffsetVal( textureOffsets[ iconSize ] or 0, 0 )
				highlightControl:SetColor( PrimaryColors[ playerID ] )
				highlightControl:SetHide( false )
			end

			local textureOffset, textureAtlas = IconLookup( thisCiv.PortraitIndex, iconSize, thisCiv.AlphaIconAtlas )

			if iconControl then
				if textureAtlas then
					iconControl:SetTexture( textureAtlas )
					iconControl:SetTextureOffset( textureOffset )
					iconControl:SetColor( PrimaryColors[ playerID ] )
					iconControl:SetHide( false )
				else
					iconControl:SetHide( true )
				end
			end

			if shadowIconControl then
				if shadowed and textureAtlas then
					shadowIconControl:SetTexture( textureAtlas )
					shadowIconControl:SetTextureOffset( textureOffset )
					return shadowIconControl:SetHide( false )
				else
					return shadowIconControl:SetHide( true )
				end
			end
			return
		end
	else
		thisCiv = unmetCiv
	end
	if backgroundControl then
		if iconControl then
			iconControl:SetHide( true )
		end
		IconHookup( thisCiv.PortraitIndex, iconSize, thisCiv.IconAtlas, backgroundControl )
		backgroundControl:SetColor( white )
		backgroundControl:SetHide( false )
	elseif iconControl then
		IconHookup( thisCiv.PortraitIndex, iconSize, thisCiv.IconAtlas, iconControl )
		iconControl:SetColor( white )
		iconControl:SetHide( false )
	end
	if shadowIconControl then
		shadowIconControl:SetHide( true )
	end
	if highlightControl then
		highlightControl:SetHide( true )
	end
end

---------------------------------------------------------------------------------------------------------
-- This is a special case hookup for civilization icons that always uses the one-piece version
---------------------------------------------------------------------------------------------------------
function EUI.SimpleCivIconHookup( playerID, iconSize, iconControl )
	local thisCiv = PlayerCivs[ playerID ] or unmetCiv
	return IconHookup( thisCiv.PortraitIndex, iconSize, thisCiv.IconAtlas, iconControl )
end
