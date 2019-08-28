------------------------------------------------------------------------------
--	FILE:	 MultilayeredFractal.lua
--	AUTHOR:  Bob Thomas
--	PURPOSE: Plot generation via layered fractals.
------------------------------------------------------------------------------
--	Copyright (c) 2010 Firaxis Games, Inc. All rights reserved.
------------------------------------------------------------------------------

-- MultilayeredFractal enables multiple fractals to be
-- layered over a single map, to generate plot types.

--[[ "MULTILAYERED FRACTAL" INSTRUCTIONS FOR CIV5:

In Civ5, there are two steps with MultilayeredFractal.
1. Replace the method "MultilayeredFractal.GeneratePlotsByRegion()" with one 
containing your regional definitions. From here, you call GenerateFractalLayer
once for each fractal layer, passing in arguments that define each layer. Or
you may call GenerateFractalLayerWithoutHills over and over, then at the end
call ApplyTectonics to add hills and mountain ranges.
2. Replace GeneratePlotTypes() and include these three steps:
	a. local variable1 = MultilayeredFractal.Create();
	b. local variable2 = variable1:GeneratePlotsByRegion();
	c. return variable2

- Bob Thomas   February 27, 2010
]]--

--[[ Additional background and information.

This function's purpose and scope remain the same as for Civ4. The operation 
has been adapted to Lua, which does not have a class structure the way C++ 
and Python do. If you are not already familiar with Lua, you will need to 
learn how it handles inheritance and grouping of functions. If you are
familiar with Civ4 and Python, comparing old and new should cover this.

Since some map scripting concepts demanded the ability to use more than one
fractal instance to generate plot types, I created this operation for use
in Civ4, to layer multiple "regional fractals" to assemble a complex map.

MultilayeredFractal duplicates the effects of FractalWorld for each layer
in turn. GeneratePlotsByRegion is the controlling function. You will need to
customize this function for each script, but the rest of the function group will
stand as written unless your needs fall outside the normal intended usage.

I've included an enormous amount of power over the layers, but this means a
long list of parameters that you must understand and organize for each layer.

New in Civ5 is how the parameters are handled. Defaults have been improved.

-------------------------
Regional Variables List:

iWaterPercent,
iRegionWidth,
iRegionHeight,
iRegionWestX,
iRegionSouthY,
iRegionGrain,
iRegionHillsGrain,
iRegionPlotFlags,
iRegionFracXExp,
iRegionFracYExp,
iRiftGrain,
bShift
-------------------------

Grain is the density of land vs sea. Higher numbers generate more and smaller land masses.

HillsGrain is the density of highlands vs flatlands.
Peaks are included in highlands and work off the same density numbers.

Flags are special variables to pass to the fractal generator.
* FRAC_POLAR will eliminate straight edges along the border of your region.
* FRAC_WRAP_X will "spread out" the fractal horizontally.
* FRAC_WRAP_Y will "spread out" the fractal vertically.
All the known-useful combinations are defined under Create().

FracXExp is the width of the source fractal.
FracYExp is the height of the source fractal.
These exponents are raised to powers of two. So a value of FracXExp = 7 
means 2^7, which would be 128 units wide. FracXExp = 6 would be only 64 
units wide. FracYExp works the same way.

Default values are now 6 for FracXExp and 5 for FracYExp, or 64x32 matrix. If
a region may need to be larger than this, use larger exponents.

Values lower than 5 seem to distort the fractal's definition too much, so I
don't recommend them even for use with very small regions. 6x5 proved to be the 
smallest exponents that I trust. These are also now the defaults for the 
Multilayered Fractal, since there tend to be more tiny regions forming up
subcontinents or island batches than there tend to be continental cores and 
whole-map layers (which would need larger exponents). Higher exponents will 
generate more defined and refined fractal outputs, but at the cost of increased 
calculation times. I would not recommend using exponents higher than 9.

Rifts create wider oceans between continents, and sometimes roughen shorelines
or affect peninsulas. Valid rift grains range from 1 to 3. These only tend to
be useful in combination with plot grains of 1 or 2. The vast majority of my 
regions do not use rifts. Rifts now default to off, so you can mostly ignore them.

Shift is a boolean flag as to whether or not to shift plots in that region. Using
shift will generally center your high concentrations of land plots to the middle
of the map, or more accurately, it aligns your lowest concentrations of land
plots along the region's edges. I have written new plot shifting functions for 
Civ5, which are simpler to operate. Most regions should use plot shifting.
-------------------------------------------------

Each region needs to be defined by the map scripter, then organized in the
controlling function. Pass in the necessary arguments to GenerateFractalLayer
and get back a region of land, "layered" on to the global plot array.

The global plot array begins as all water. Each layer of fractalized plots is
applied in turn, overwriting the previous layer. Water plots in each layer are
ignored. Land plots of any type are assigned to the applicable plot. The water
"left over" at the end of the process will be whatever plots went untouched by
any of the regional layers' land plots. If regions overlap, landforms may overlap,
too. This allows both separate-distinct regional use, and layering over a single
area with as many passes as the scripter selects.

]]--


-- Use GeneratePlotsByRegion to organize your fractal layers.
-------------------------------------------------------------------------------------------
MultilayeredFractal = {};
-------------------------------------------------------------------------------------------
function MultilayeredFractal.Create()
	local iW, iH = Map.GetGridSize();
	-- Set up flags for the fractal generator. These are no longer bit values.
	-- For Lua, we had to convert to a table of booleans to simulate bits.
	local iNoFlags = {};
	local iTerrainFlags = Map.GetFractalFlags(); -- Matches wrap to that of the map.
	iTerrainFlags.FRAC_POLAR = false;
	local iRoundFlags = {};
	local iHorzFlags = {
		FRAC_WRAP_X = true,
	};
	local iVertFlags = {
		FRAC_WRAP_Y = true,
	};
	local iXYFlags = {
		FRAC_WRAP_X = true,
		FRAC_WRAP_Y = true,
	};
	
	-- Current region, reinitiated in GeneratePlotsByRegion for each layer.
	local plotTypes = {};

	-- Sum of all layered regions
	local wholeworldPlotTypes = table.fill(PlotTypes.PLOT_OCEAN, iW * iH);

	-- Create data.
	local data = {
	
		-- member variables
		iW				= iW,
		iH				= iH,
		iTerrainFlags	= iTerrainFlags,
		iNoFlags		= iNoFlags,
		iRoundFlags		= iRoundFlags,
		iHorzFlags		= iHorzFlags,
		iVertFlags		= iVertFlags,
		iXYFlags		= iXYFlags,
		
		-- plot arrays
		plotTypes		= plotTypes,
		wholeworldPlotTypes = wholeworldPlotTypes,		
	}
	
	setmetatable(data, {__index = MultilayeredFractal});

	return data;
end
-------------------------------------------------------------------------------------------
function MultilayeredFractal:ShiftRegionPlots(iRegionWidth, iRegionHeight)
	-- Minimizes land plots along the region's edges by shifting the coordinates.
	local shift_x = 0; 
	local shift_y = 0;

	shift_x = self:DetermineXShift(iRegionWidth, iRegionHeight);
	shift_y = self:DetermineYShift(iRegionWidth, iRegionHeight);
	self:ShiftRegionPlotsBy(shift_x, shift_y, iRegionWidth, iRegionHeight);
end
-------------------------------------------------------------------------------------------
function MultilayeredFractal:ShiftRegionPlotsBy(xshift, yshift, iRegionWidth, iRegionHeight)
	if (xshift > 0 or yshift > 0) then
		local iWH = iRegionWidth * iRegionHeight;
		local buf = {};
		for i = 1, iWH + 1, 1 do
			buf[i] = self.plotTypes[i];
		end

		for iDestY = 0, iRegionHeight, 1 do
			for iDestX = 0, iRegionWidth, 1 do
				local iDestI = iRegionWidth * iDestY + iDestX;
				local iSourceX = (iDestX + xshift) % iRegionWidth;
				local iSourceY = (iDestY + yshift) % iRegionHeight;
				local iSourceI = iRegionWidth * iSourceY + iSourceX;
				self.plotTypes[iDestI] = buf[iSourceI]
			end
		end
	end
end
-------------------------------------------------------------------------------------------
function MultilayeredFractal:DetermineXShift(iRegionWidth, iRegionHeight)
	--[[ This function will align the most water-heavy vertical portion of the region with
	its vertical edge. This is a form of centering the landmasses, but it emphasizes the
	edge not the middle. If there are columns completely empty of land, these will tend to
	be chosen as the new edge. The operation looks at a group of columns not just a single
	column, then picks the center of the most water heavy group of columns to be the new
	vertical reguin edge. ]]--

	-- First loop through the map columns and record land plots in each column.
	local land_totals = {};
	for x = 0, iRegionWidth - 1 do
		local current_column = 0;
		for y = 0, iRegionHeight - 1 do
			local i = y * iRegionWidth + x + 1;
			if (self.plotTypes[i] ~= PlotTypes.PLOT_OCEAN) then
				current_column = current_column + 1;
			end
		end
		table.insert(land_totals, current_column);
	end
	
	-- Now evaluate column groups, each record applying to the center column of the group.
	local column_groups = {};
	-- Determine the group size in relation to map width.
	local group_radius = math.max(1, math.floor(iRegionWidth / 10));
	-- Measure the groups.
	for column_index = 1, iRegionWidth do
		local current_group_total = 0;
		for current_column = column_index - group_radius, column_index + group_radius do
			local current_index = current_column % iRegionWidth;
			if current_index == 0 then -- Modulo of the last column will be zero; this repairs the issue.
				current_index = iRegionWidth;
			end
			current_group_total = current_group_total + land_totals[current_index];
		end
		table.insert(column_groups, current_group_total);
	end
	
	-- Identify the group with the least amount of land in it.
	local best_value = iRegionHeight * (2 * group_radius + 1); -- Set initial value to max possible.
	local best_group = 1; -- Set initial best group as current map edge.
	for column_index, group_land_plots in ipairs(column_groups) do
		if group_land_plots < best_value then
			best_value = group_land_plots;
			best_group = column_index;
		end
	end
	
	-- Determine X Shift
	local x_shift = best_group - 1;
	return x_shift;
end
-------------------------------------------------------------------------------------------
function MultilayeredFractal:DetermineYShift(iRegionWidth, iRegionHeight)
	-- Counterpart to DetermineXShift()

	-- First loop through the map rows and record land plots in each row.
	local land_totals = {};
	for y = 0, iRegionHeight - 1 do
		local current_row = 0;
		for x = 0, iRegionWidth - 1 do
			local i = y * iRegionWidth + x + 1;
			if (self.plotTypes[i] ~= PlotTypes.PLOT_OCEAN) then
				current_row = current_row + 1;
			end
		end
		table.insert(land_totals, current_row);
	end
	
	-- Now evaluate row groups, each record applying to the center row of the group.
	local row_groups = {};
	-- Determine the group size in relation to map height.
	local group_radius = math.max(1, math.floor(iRegionHeight / 10));
	-- Measure the groups.
	for row_index = 1, iRegionHeight do
		local current_group_total = 0;
		for current_row = row_index - group_radius, row_index + group_radius do
			local current_index = current_row % iRegionHeight;
			if current_index == 0 then -- Modulo of the last row will be zero; this repairs the issue.
				current_index = iRegionHeight;
			end
			current_group_total = current_group_total + land_totals[current_index];
		end
		table.insert(row_groups, current_group_total);
	end
	
	-- Identify the group with the least amount of land in it.
	local best_value = iRegionWidth * (2 * group_radius + 1); -- Set initial value to max possible.
	local best_group = 1; -- Set initial best group as current map edge.
	for row_index, group_land_plots in ipairs(row_groups) do
		if group_land_plots < best_value then
			best_value = group_land_plots;
			best_group = row_index;
		end
	end
	
	-- Determine Y Shift
	local y_shift = best_group - 1;
	return y_shift;
end
-------------------------------------------------------------------------------------------
function MultilayeredFractal:GenerateFractalLayer(args)
	local args = args or {};
	
	-- Handle args or assign defaults.
	local world_age = args.world_age or 2; -- Default to 4 Billion Years old.
	local iWaterPercent = 0; --args.iWaterPercent or 55;
	local iRegionWidth = args.iRegionWidth; -- Mandatory Parameter, no default
	local iRegionHeight = args.iRegionHeight; -- Mandatory Parameter, no default
	local iRegionWestX = args.iRegionWestX; -- Mandatory Parameter, no default
	local iRegionSouthY = args.iRegionSouthY; -- Mandatory Parameter, no default
	local iRegionGrain = args.iRegionGrain or 1;
	local iRegionHillsGrain = args.iRegionHillsGrain or 3;
	local iRegionPlotFlags = args.iRegionPlotFlags or self.iRoundFlags;
	local iRegionTerrainFlags = self.iTerrainFlags; -- Removed from args list.
	local iRegionFracXExp = args.iRegionFracXExp or 6;
	local iRegionFracYExp = args.iRegionFracYExp or 5;
	local iRiftGrain = args.iRiftGrain or -1;
	local bShift = args.bShift or true;

	--print("Received Region Data.");
	--print(iRegionWidth, iRegionHeight, iRegionWestX, iRegionSouthY, iRegionGrain);
	--print("- - -");
	
	-- Init the plot types array for this region's plot data. Redone for each new layer.
	-- Compare to self.wholeworldPlotTypes, which contains the sum of all layers.
	self.plotTypes = {};
	table.fill(self.plotTypes, PlotTypes.PLOT_OCEAN, iRegionWidth * iRegionHeight);
	
	--print("Filled regional table.");

	-- Init the land/water fractal
	local regionContinentsFrac;
	if (iRiftGrain > 0) and (iRiftGrain < 4) then
		local riftsFrac = Fractal.Create(iRegionWidth, iRegionHeight, iRiftGrain, {}, iRegionFracXExp, iRegionFracYExp);
		regionContinentsFrac = Fractal.CreateRifts(iRegionWidth, iRegionHeight, iRegionGrain, iRegionPlotFlags, riftsFrac, iRegionFracXExp, iRegionFracYExp);
	else
		regionContinentsFrac = Fractal.Create(iRegionWidth, iRegionHeight, iRegionGrain, iRegionPlotFlags, iRegionFracXExp, iRegionFracYExp);	
	end
	--print("Initialized main fractal.");
	
	-- temp workaround, remove when the chunk above is activated.
	-- local regionContinentsFrac = Fractal.Create(iRegionWidth, iRegionHeight, iRegionGrain, iRegionPlotFlags, iRegionFracXExp, iRegionFracYExp);	
	
	-- Init the hills/peaks fractals.
	print(iRegionTerrainFlags);
	local regionHillsFrac = Fractal.Create(iRegionWidth, iRegionHeight, iRegionHillsGrain, iRegionTerrainFlags, iRegionFracXExp, iRegionFracYExp);
	local regionPeaksFrac = Fractal.Create(iRegionWidth, iRegionHeight, iRegionHillsGrain + 1, iRegionTerrainFlags, iRegionFracXExp, iRegionFracYExp);
	--print("Initialized secondary fractals.");

	-- Need to implement the new WorldAge startup options
	--
	-- Set values for hills and mountains according to World Age chosen by user.
	local adjustment = 5;
	local mountains = 30;
	if world_age == 3 then -- 5 Billion Years
		adjustment = 3;
		mountains = 25;
	elseif world_age == 1 then -- 3 Billion Years
		adjustment = 8;
		mountains = 35;
	else -- 4 Billion Years
	end

	-- Using the fractal matrices we just created, determine fractal-height values for sea level, hills, and peaks.
	local iWaterThreshold = regionContinentsFrac:GetHeight(iWaterPercent);
	local iHillsBottom1 = regionHillsFrac:GetHeight(25 - adjustment);
	local iHillsTop1 = regionHillsFrac:GetHeight(25 + adjustment);
	local iHillsBottom2 = regionHillsFrac:GetHeight(75 - adjustment);
	local iHillsTop2 = regionHillsFrac:GetHeight(75 + adjustment);
	local iPeakThreshold = regionPeaksFrac:GetHeight(mountains);

	-- Loop through the region's plots
	for x = 0, iRegionWidth - 1, 1 do
		for y = 0, iRegionHeight - 1, 1 do
			local i = y * iRegionWidth + x + 1; -- Lua arrays start at 1.
			local val = regionContinentsFrac:GetHeight(x,y);
			if val <= iWaterThreshold then
				--do nothing
			else
				local hillVal = regionHillsFrac:GetHeight(x,y);
				if ((hillVal >= iHillsBottom1 and hillVal <= iHillsTop1) or (hillVal >= iHillsBottom2 and hillVal <= iHillsTop2)) then
					local peakVal = regionPeaksFrac:GetHeight(x,y);
					if (peakVal <= iPeakThreshold) then
						self.plotTypes[i] = PlotTypes.PLOT_PEAK
					else
						self.plotTypes[i] = PlotTypes.PLOT_HILLS
					end
				else
					self.plotTypes[i] = PlotTypes.PLOT_LAND
				end
			end
		end
	end
	
	--print("Generated Plot Types.");
	
	if bShift then -- Shift plots to obtain a more natural shape.
		self:ShiftRegionPlots(iRegionWidth, iRegionHeight);
		--print("Shifted Plots.");
	end

	-- Once the plot types for the region have been generated, they must be
	-- applied to the global plot array.
	--
	-- Default approach is to ignore water and layer the lands over one another.
	-- Land of any type in each new layer overwrites whatever had been there.
	-- If you want to layer the water, too, or some other method, then
	-- you need to replace this function with a custom version, in your script.
	--
	-- Apply the region's plots to the global plot array.
	for x = 0, iRegionWidth - 1, 1 do
		local wholeworldX = x + iRegionWestX;
		for y = 0, iRegionHeight - 1, 1 do
			local i = y * iRegionWidth + x + 1
			if self.plotTypes[i] ~= PlotTypes.PLOT_OCEAN then
				local wholeworldY = y + iRegionSouthY;
				local iWorld = wholeworldY * self.iW + wholeworldX + 1
				self.wholeworldPlotTypes[iWorld] = self.plotTypes[i]
			end
		end
	end
	
	--print("Applied region's plots to global plot array."); print("-");

	-- This region is done.
	return
end
-------------------------------------------------------------------------------------------
function MultilayeredFractal:GenerateFractalLayerWithoutHills(args)
	--[[ This function is intended to be paired with ApplyTectonics. If all the hills and
	mountains plots are going to be overwritten by the tectonics results, then why waste
	calculations generating them? ]]--
	local args = args or {};
	
	-- Handle args or assign defaults.
	local iWaterPercent = 0; --args.iWaterPercent or 55;
	local iRegionWidth = args.iRegionWidth; -- Mandatory Parameter, no default
	local iRegionHeight = args.iRegionHeight; -- Mandatory Parameter, no default
	local iRegionWestX = args.iRegionWestX; -- Mandatory Parameter, no default
	local iRegionSouthY = args.iRegionSouthY; -- Mandatory Parameter, no default
	local iRegionGrain = args.iRegionGrain or 1;
	local iRegionPlotFlags = args.iRegionPlotFlags or self.iRoundFlags;
	local iRegionTerrainFlags = self.iTerrainFlags; -- Removed from args list.
	local iRegionFracXExp = args.iRegionFracXExp or 6;
	local iRegionFracYExp = args.iRegionFracYExp or 5;
	local iRiftGrain = args.iRiftGrain or -1;
	local bShift = args.bShift or true;

	--print("Received Region Data");
	--print(iRegionWidth, iRegionHeight, iRegionWestX, iRegionSouthY, iRegionGrain);
	--print("- - -");
	
	-- Init the plot types array for this region's plot data. Redone for each new layer.
	-- Compare to self.wholeworldPlotTypes, which contains the sum of all layers.
	self.plotTypes = {};
	table.fill(self.plotTypes, PlotTypes.PLOT_OCEAN, iRegionWidth * iRegionHeight);
	
	--print("Filled regional table.");

	-- Init the land/water fractal
	local regionContinentsFrac;
	if (iRiftGrain > 0) and (iRiftGrain < 4) then
		local riftsFrac = Fractal.Create(iRegionWidth, iRegionHeight, iRiftGrain, {}, iRegionFracXExp, iRegionFracYExp);
		regionContinentsFrac = Fractal.CreateRifts(iRegionWidth, iRegionHeight, iRegionGrain, iRegionPlotFlags, riftsFrac, iRegionFracXExp, iRegionFracYExp);
	else
		regionContinentsFrac = Fractal.Create(iRegionWidth, iRegionHeight, iRegionGrain, iRegionPlotFlags, iRegionFracXExp, iRegionFracYExp);	
	end
	--print("Initialized main fractal");
	
	-- temp workaround, remove when the chunk above is activated.
	-- local regionContinentsFrac = Fractal.Create(iRegionWidth, iRegionHeight, iRegionGrain, iRegionPlotFlags, iRegionFracXExp, iRegionFracYExp);	
	
	-- Using the fractal matrices we just created, determine fractal-height values for sea level.
	local iWaterThreshold = regionContinentsFrac:GetHeight(iWaterPercent);

	-- Loop through the region's plots
	for x = 0, iRegionWidth - 1, 1 do
		for y = 0, iRegionHeight - 1, 1 do
			local i = y * iRegionWidth + x + 1; -- Lua arrays start at 1.
			local val = regionContinentsFrac:GetHeight(x,y);
			if val <= iWaterThreshold then
				self.plotTypes[i] = PlotTypes.PLOT_LAND
			else
				self.plotTypes[i] = PlotTypes.PLOT_LAND
			end
		end
	end
	
	--print("Generated Plot Types");
	
	if bShift then -- Shift plots to obtain a more natural shape.
		self:ShiftRegionPlots(iRegionWidth, iRegionHeight);
	end

	--print("Shifted Plots");

	-- Once the plot types for the region have been generated, they must be
	-- applied to the global plot array.
	--
	-- Default approach is to ignore water and layer the lands over one another.
	-- Land of any type in each new layer overwrites whatever had been there.
	-- If you want to layer the water, too, or some other method, then
	-- you need to replace this function with a custom version, in your script.
	--
	-- Apply the region's plots to the global plot array.
	for x = 0, iRegionWidth - 1, 1 do
		local wholeworldX = x + iRegionWestX;
		for y = 0, iRegionHeight - 1, 1 do
			local i = y * iRegionWidth + x + 1
			if self.plotTypes[i] ~= PlotTypes.PLOT_OCEAN then
				local wholeworldY = y + iRegionSouthY;
				local iWorld = wholeworldY * self.iW + wholeworldX + 1
				self.wholeworldPlotTypes[iWorld] = self.plotTypes[i]
			end
		end
	end
	
	--print("Applied region's plots to global plot array.");

	-- This region is done.
	return
end
-------------------------------------------------------------------------------------------
function MultilayeredFractal:GenerateWaterLayer(args)
	-- This function is intended to allow adding seas to specific areas of large continents.
	--
	-- Usage: Because of how the Shift operation works, we have to treat the "water" we are
	-- trying to place in this layer as "land", until the shift (if any) has occurred. Once
	-- the shift is done, the actual layering of the plots is handled by turning any "land"
	-- plots from this layer in to water plots when applied to the whole world plot table.
	-- This is all under the hood. The only thing is that the WaterPercent in the args table
	-- does NOT apply to the water you are trying to place, but rather the dead space where
	-- no changes will occur. Put another way, you should treat this layer of water as if
	-- it were an island or continent you are trying to add, except that in actual placement
	-- it will come out as water in the end, letting you place a sea inside a larger piece 
	-- of land, or a bay that eats in to a continent from the sea. -- Sirian
	local args = args or {};
	
	-- Handle args or assign defaults.
	local iWaterPercent = 0; --args.iWaterPercent or 55;
	local iRegionWidth = args.iRegionWidth; -- Mandatory Parameter, no default
	local iRegionHeight = args.iRegionHeight; -- Mandatory Parameter, no default
	local iRegionWestX = args.iRegionWestX; -- Mandatory Parameter, no default
	local iRegionSouthY = args.iRegionSouthY; -- Mandatory Parameter, no default
	local iRegionGrain = args.iRegionGrain or 1;
	local iRegionPlotFlags = args.iRegionPlotFlags or self.iRoundFlags;
	local iRegionFracXExp = args.iRegionFracXExp or 6;
	local iRegionFracYExp = args.iRegionFracYExp or 5;
	local iRiftGrain = args.iRiftGrain or -1;
	local bShift = args.bShift or true;

	-- Init the plot types array for this region's plot data. Redone for each new layer.
	-- Compare to self.wholeworldPlotTypes, which contains the sum of all layers.
	self.plotTypes = {};
	table.fill(self.plotTypes, PlotTypes.PLOT_OCEAN, iRegionWidth * iRegionHeight);
	
	-- Init the land/water fractal
	local regionContinentsFrac;
	if (iRiftGrain > 0) and (iRiftGrain < 4) then
		local riftsFrac = Fractal.Create(iRegionWidth, iRegionHeight, iRiftGrain, {}, iRegionFracXExp, iRegionFracYExp);
		regionContinentsFrac = Fractal.CreateRifts(iRegionWidth, iRegionHeight, iRegionGrain, iRegionPlotFlags, riftsFrac, iRegionFracXExp, iRegionFracYExp);
	else
		regionContinentsFrac = Fractal.Create(iRegionWidth, iRegionHeight, iRegionGrain, iRegionPlotFlags, iRegionFracXExp, iRegionFracYExp);	
	end
	
	-- Using the fractal matrices we just created, determine fractal-height values for sea level.
	local iWaterThreshold = regionContinentsFrac:GetHeight(iWaterPercent);

	-- Loop through the region's plots
	for x = 0, iRegionWidth - 1, 1 do
		for y = 0, iRegionHeight - 1, 1 do
			local i = y * iRegionWidth + x + 1; -- Lua arrays start at 1.
			local val = regionContinentsFrac:GetHeight(x,y);
			if val <= iWaterThreshold then
				self.plotTypes[i] = PlotTypes.PLOT_LAND
			else
				self.plotTypes[i] = PlotTypes.PLOT_LAND
			end
		end
	end
	
	if bShift then -- Shift plots to obtain a more natural shape.
		self:ShiftRegionPlots(iRegionWidth, iRegionHeight);
	end

	-- Apply the region's plots to the global plot array.
	for x = 0, iRegionWidth - 1, 1 do
		local wholeworldX = x + iRegionWestX;
		for y = 0, iRegionHeight - 1, 1 do
			local i = y * iRegionWidth + x + 1
			if self.plotTypes[i] ~= PlotTypes.PLOT_OCEAN then
				local wholeworldY = y + iRegionSouthY;
				local iWorld = wholeworldY * self.iW + wholeworldX + 1
				self.wholeworldPlotTypes[iWorld] = PlotTypes.PLOT_OCEAN
			end
		end
	end
	
	-- This region is done.
	return
end
-------------------------------------------------------------------------------------------
function MultilayeredFractal:ApplyTectonics(args)
	--[[ One of the most impactful changes in Civ5 arises from Jon's new vision of how the
	maps should "look and feel". He wanted a more realistic terrain mix. I warned him this
	would come at the cost of game balance, but he refused to accept that, saying that we
	could devise methods to overcome any problems that arose. So we set out together first
	to get the maps to look the way he wanted, then to optimize the gameplay to make the
	most of this shift, capitalizing on new opportunities and resolving balance issues.
	
	In the early going of Civ5's development, we worked through numerous iterations of
	changes to terrain generation, gradually moving in the direction of his vision. I
	was unable, however, to wring the kind of results he wanted for mountain ranges
	from the fractal generator or any other method, despite numerous approaches. This is 
	where Brian stepped in, crafting a ridgebuilder method using a simple Voronoi diagram
	to simulate tectonic plates. These ridges are able to remain thin enough even on 
	huge maps to avoid fat and unrealistic mountain clusters the way Civ3 and, to a lesser
	extent, Civ4 used to produce. They are also very good at simulating numerous angles
	away from the standard up down left and right, or the diagonals. So via a combination 
	of my fractal solution to craft both scattered bits of hills and clusters of hills, 
	plus the tectonics ridgelines for mountains (complete with random mountain passes), we
	were able, finally, to satisfy Jon's Colorado sensibilities about how mountains look.
	
	However, Brian's ridgebuilder is a whole-world event. It cannot be adapted successfully 
	to be applied to one fractal layer of a multilayered fractal world. This function is
	intended to overlay on to the entire map, applying the tectonics-style mountain ranges
	to multilayered fractal map scripts such as Pangaea.
	
	Proper use of this function means pairing it with GenerateFractalLayerWithoutHills to
	reduce wasted calculations and speed map completion time, even if only marginally. Do
	all your layers first, then call ApplyTectonics at the end. This will not alter any of
	your water plots unless you have enabled generation of tectonic islands.
	
	- Bob Thomas	April, 2010			]]--
	
	local args = args or {};
	local world_age = args.world_age or 2; -- Default to 4 Billion Years old.
	--
	local world_age_old =  3;
	local world_age_normal =  6;
	local world_age_new = 9;
	--
	local extra_mountains = args.extra_mountains or 0;
	local grain_amount = args.grain_amount or 3;
	local adjust_plates = args.adjust_plates or 1.0;
	local shift_plot_types = args.shift_plot_types or false; -- Default to false for tectonics pass. Land/sea already generated.
	local tectonic_islands = args.tectonic_islands or false;
	local hills_ridge_flags = args.hills_ridge_flags or self.iTerrainFlags;
	local peaks_ridge_flags = args.peaks_ridge_flags or self.iTerrainFlags;
	local fracXExp = args.fracXExp or -1;
	local fracYExp = args.fracYExp or -1;
	
	-- Need to implement the new WorldAge startup options
	--
	-- Set values for hills and mountains according to World Age chosen by user.
	local adjustment = world_age_normal;
	if world_age == 3 then -- 5 Billion Years
		adjustment = world_age_old;
		adjust_plates = adjust_plates * 0.75;
	elseif world_age == 1 then -- 3 Billion Years
		adjustment = world_age_new;
		adjust_plates = adjust_plates * 1.5;
	else -- 4 Billion Years
	end
	-- Apply adjustment to hills and peaks settings.
	local hillsBottom1 = 28 - adjustment;
	local hillsTop1 = 28 + adjustment;
	local hillsBottom2 = 72 - adjustment;
	local hillsTop2 = 72 + adjustment;
	local hillsClumps = 1 + adjustment;
	local hillsNearMountains = 91 - (adjustment * 2) - extra_mountains;
	local mountains = 40 - adjustment - extra_mountains;

	-- Hills and Mountains handled differently according to map size
	local WorldSizeTypes = {};
	for row in GameInfo.Worlds() do
		WorldSizeTypes[row.Type] = row.ID;
	end
	local sizekey = Map.GetWorldSize();
	-- Fractal Grains
	local sizevalues = {
		[WorldSizeTypes.WORLDSIZE_DUEL]     = 3,
		[WorldSizeTypes.WORLDSIZE_TINY]     = 3,
		[WorldSizeTypes.WORLDSIZE_SMALL]    = 3,
		[WorldSizeTypes.WORLDSIZE_STANDARD] = 3,
		[WorldSizeTypes.WORLDSIZE_LARGE]    = 3,
		[WorldSizeTypes.WORLDSIZE_HUGE]		= 3
	};
	local grain = sizevalues[sizekey] or 3;
	-- Tectonics Plate Counts
	local platevalues = {
		[WorldSizeTypes.WORLDSIZE_DUEL]		= 80,
		[WorldSizeTypes.WORLDSIZE_TINY]     = 80,
		[WorldSizeTypes.WORLDSIZE_SMALL]    = 80,
		[WorldSizeTypes.WORLDSIZE_STANDARD] = 80,
		[WorldSizeTypes.WORLDSIZE_LARGE]    = 80,
		[WorldSizeTypes.WORLDSIZE_HUGE]     = 80
	};
	local numPlates = platevalues[sizekey] or 5;
	-- Add in any plate count modifications passed in from the map script.
	numPlates = numPlates * adjust_plates;

	-- Generate fractals to govern hills and mountains
	self.hillsFrac = Fractal.Create(self.iW, self.iH, grain_amount, self.iTerrainFlags, fracXExp, fracYExp);
	self.mountainsFrac = Fractal.Create(self.iW, self.iH, grain_amount, self.iTerrainFlags, fracXExp, fracYExp);

	-- Use Brian's tectonics method to weave ridgelines in to the fractals.
	self.hillsFrac:BuildRidges(numPlates, hills_ridge_flags, 1, 2);
	self.mountainsFrac:BuildRidges((numPlates * 2) / 3, peaks_ridge_flags, 6, 1);

	-- Get height values for plot types
	local iHillsBottom1 = self.hillsFrac:GetHeight(hillsBottom1);
	local iHillsTop1 = self.hillsFrac:GetHeight(hillsTop1);
	local iHillsBottom2 = self.hillsFrac:GetHeight(hillsBottom2);
	local iHillsTop2 = self.hillsFrac:GetHeight(hillsTop2);
	local iHillsClumps = self.mountainsFrac:GetHeight(hillsClumps);
	local iHillsNearMountains = self.mountainsFrac:GetHeight(hillsNearMountains);
	local iMountainThreshold = self.mountainsFrac:GetHeight(mountains);
	local iPassThreshold = self.hillsFrac:GetHeight(hillsNearMountains);

	-- Get height values for tectonic islands
	local iMountain100 = self.mountainsFrac:GetHeight(100);
	local iMountain99 = self.mountainsFrac:GetHeight(99);
	local iMountain97 = self.mountainsFrac:GetHeight(97);
	local iMountain95 = self.mountainsFrac:GetHeight(95);

	--[[ Activate printout for debugging only.
	print("-"); print("--- Tectonics Readout ---");
	print("- World Age Setting:", world_age);
	print("- Mountain Threshold:", mountains);
	print("- Foot Hills Threshold:", hillsNearMountains);
	print("- Clumps of Hills %:", hillsClumps);
	print("- Loose Hills %:", 4 * adjustment);
	print("- Tectonic Plate Count:", numPlates);
	print("- Tectonic Islands?", tectonic_islands);
	print("- - - - - - - - - - - - - - - - -");
	]]--

	-- Main loop
	for x = 0, self.iW - 1 do
		for y = 0, self.iH - 1 do
		
			local i = y * self.iW + x + 1;
	
			if self.wholeworldPlotTypes[i] == PlotTypes.PLOT_OCEAN then
				-- No hills or mountains here
				
			else
				local mountainVal = self.mountainsFrac:GetHeight(x, y);
				local hillVal = self.hillsFrac:GetHeight(x, y);
				if (mountainVal >= iMountainThreshold) then
					if (hillVal >= iPassThreshold) then -- Mountain Pass though the ridgeline
						self.wholeworldPlotTypes[i] = PlotTypes.PLOT_HILLS;
					else -- Mountain
						local iIsMount = Map.Rand(100, "");
						local iIsMountAdj = 98 - adjustment;
						if iIsMount >= iIsMountAdj then
							self.wholeworldPlotTypes[i] = PlotTypes.PLOT_MOUNTAIN;
						else
							-- set some randomness to hills or flat land next to the mountain
							local iIsHill = Map.Rand(100, "Hill Spwan Chance");
							
							local iIsHillAdj = 40 - adjustment;
							if iIsHillAdj >= iIsHill then
								self.wholeworldPlotTypes[i] = PlotTypes.PLOT_HILLS;
							else
								self.wholeworldPlotTypes[i] = PlotTypes.PLOT_LAND;
							end
						end
					end
				elseif (mountainVal >= iHillsNearMountains) then
					self.wholeworldPlotTypes[i] = PlotTypes.PLOT_HILLS; -- Foot hills
				else
					if ((hillVal >= iHillsBottom1 and hillVal <= iHillsTop1) or (hillVal >= iHillsBottom2 and hillVal <= iHillsTop2)) then
						self.wholeworldPlotTypes[i] = PlotTypes.PLOT_HILLS;
					else
						self.wholeworldPlotTypes[i] = PlotTypes.PLOT_LAND;
					end
				end
			end
		end
	end
end
-------------------------------------------------------------------------------------------
function MultilayeredFractal:GeneratePlotsByRegion()
	-- Sirian's MultilayeredFractal controlling function.
	-- You -MUST- customize this function for each script using MultilayeredFractal.
	--
	-- The details in the function you see here are provided
	-- to you as a template. You will have to build your own version for
	-- use with your map scripts, according to your designs. Terra.lua offers
	-- a strong example of how to construct a map using many layers.
	
	
	-- All regions must be rectangular. (The fractal only feeds on these!)
	-- Obtain region width and height by any method you care to design.
	-- Obtain WestX and EastX, NorthY and SouthY, to define the boundaries.
	--
	-- Note that Lat and Lon as used here allow for percentage-of-map definitions,
	-- which will scale appropriately to any map size or grid dimensions.
	--
	-- Latitude and Longitude are values between 0.0 and 1.0
	-- Latitude South to North is 0.0 to 1.0
	-- Longitude West to East is 0.0 to 1.0
	-- Plots are indexed by X,Y with 0,0 in SW corner.
	--
	-- Here is an example set of definitions. We use the same Lat values for both
	-- regions one and two, so one set in this case will suffice. The various values
	-- for subcontinent indicate where extra pieces will be layered over a larger 
	-- region. You can label and define your regions however you please, so long as
	-- each one contains enough defined parameters to get the results you seek.
	--
	-- Note, it is best to keep all your variables local in scope.
	local regiononeWestLon = 0.05;
	local regiononeEastLon = 0.35;
	local NorthLat = 0.95;
	local SouthLat = 0.45;
	local regiontwoWestLon = 0.45;
	local regiontwoEastLon = 0.95;
	local subcontinentLargeHorz = 0.2;
	local subcontinentLargeVert = 0.32;
	local subcontinentLargeNorthLat = 0.6;
	local subcontinentLargeSouthLat = 0.28;
	local subcontinentSmallDimension = 0.125;
	local subcontinentSmallNorthLat = 0.525;
	local subcontinentSmallSouthLat = 0.4;

	-- Define your first region here.
	print("Generating Region One (Lua Map_Script_Name) ...")
	-- Set dimensions of your region. (Below is an example).
	local regiononeWestX = math.floor(self.iW * regiononeWestLon);
	local regiononeEastX = math.floor(self.iW * regiononeEastLon);
	local regiononeNorthY = math.floor(self.iH * NorthLat);
	local regiononeSouthY = math.floor(self.iH * SouthLat);
	local regiononeWidth = regiononeEastX - regiononeWestX + 1;
	local regiononeHeight = regiononeNorthY - regiononeSouthY + 1;

	-- With all of your parameters figured out, it is time to define your argument list.
	-- This is where the rubber meets the road.
	local args = {};
	--
	args.iWaterPercent = 0;
	args.iRegionWidth = regiononeWidth;
	args.iRegionHeight = regiononeHeight;
	args.iRegionWestX = regiononeWestX;
	args.iRegionSouthY = regiononeSouthY;
	args.iRegionGrain = 3;
	args.iRegionHillsGrain = 4;
	--args.iRegionPlotFlags --left at default
	--args.iRegionFracXExp -- left at default
	--args.iRegionFracYExp -- left at default
	--args.iRiftGrain -- left at default
	--args.bShift -- left at default
	
	-- Now call the plot generator for this layer.
	self:GenerateFractalLayer(args)
	
	-- That was just the first layer. You will of course have more layers to handle.
	-- Do each in turn, repeating the same method, but with appropriate arguments.
	-- Regions can overlap or add on to other existing regions.
	
	-- Example of a subcontinent region appended to region one from above:
	print("Generating subcontinent for Region One (Lua Map_Script_Name) ...");
	local scLargeWidth = math.floor(subcontinentLargeHorz * self.iW);
	local scLargeHeight = math.floor(subcontinentLargeVert * self.iH);
	local scRoll = Map.Rand((regiononeWidth - scLargeWidth), "Large Subcontinent Placement - Map_Script_Name LUA");
	local scWestX = regiononeWestX + scRoll;
	local scEastX = scWestX + scLargeWidth;
	local scNorthY = math.floor(self.iH * subcontinentLargeNorthLat);
	local scSouthY = math.floor(self.iH * subcontinentLargeSouthLat);

	-- Clever use of dice rolls can inject some randomization in to definitions.
	local scShape = Map.Rand(3, "Large Subcontinent Shape - Map_Script_Name LUA");
	if scShape == 2 then -- Massive subcontinent!
		local scWater, scGrain, scRift = 55, 1, -1;
	elseif scShape == 1 then -- Standard subcontinent.
		local scWater, scGrain, scRift = 66, 2, 2;
	else -- scShape == 0, Archipelago subcontinent.
		local scWater, scGrain, scRift = 77, 3, -1;
	end

	-- Each regional fractal needs its own uniquely defined parameters.
	-- With proper settings, there's almost no limit to what can be done.
	local args = {};
	--
	args.iWaterPercent = scWater;
	args.iRegionWidth = scLargeWidth;
	args.iRegionHeight = scLargeHeight;
	args.iRegionWestX = scWestX;
	args.iRegionSouthY = scSouthY;
	args.iRegionGrain = scGrain;
	args.iRegionHillsGrain = scGrain + 1;
	--args.iRegionPlotFlags --left at default
	--args.iRegionFracXExp -- left at default
	--args.iRegionFracYExp -- left at default
	args.iRiftGrain = scRift;
	--args.bShift -- left at default
	
	-- Now call the plot generator for this layer.
	self:GenerateFractalLayer(args)


	-- Once all your of your fractal regions (and other regions! You do not have
	-- to make every region a fractal-based region) have been processed, and
	-- your plot generation is complete, return the global plot array.
	--
	-- All regions have been processed. Plot Type generation completed.
	return self.wholeworldPlotTypes
end
-------------------------------------------------------------------------------------------

--[[ ----------------------------------------------
Regional Variables Key:

iWaterPercent,				DEFAULT: 55
iRegionWidth,				MANDATORY (no default)
iRegionHeight,				MANDATORY (no default)
iRegionWestX,				MANDATORY (no default)
iRegionSouthY,				MANDATORY (no default)
iRegionGrain,				DEFAULT: 1
iRegionHillsGrain,			DEFAULT: 3
iRegionPlotFlags,			DEFAULT: iRoundFlags
iRegionFracXExp,			DEFAULT: 6
iRegionFracYExp,			DEFAULT: 5
iRiftGrain,					DEFAULT: -1 (no rifts)
bShift,						DEFAULT: true
---------------------------------------------- ]]--
