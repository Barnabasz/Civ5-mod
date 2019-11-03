function addTreasureFleetsBuilding(player, iX, iY)
	local plot = Map.GetPlot(iX, iY);
	local cCity = plot:GetPlotCity();
	cCity:SetNumRealBuilding(GameInfoTypes["BUILDING_TREASURE_FLEETS"], 1)
end


function NQMP_Exploration_TreasureFleets_OnCityCaptureComplete(iOldOwner, bIsCapital, iX, iY, iNewOwner, iPop, bConquest)
	local player = Players[iNewOwner]
	if (player:IsEverAlive()) then
		if (player:HasPolicy(GameInfo.Policies["POLICY_TREASURE_FLEETS"].ID)) then
			addTreasureFleetsBuilding(player, iX, iY)
		end
	end
end
GameEvents.CityCaptureComplete.Add(NQMP_Exploration_TreasureFleets_OnCityCaptureComplete)

function NQMP_Exploration_TreasureFleets_OnFoundCity(iPlayer, iX, iY)
	local player = Players[iPlayer]
	if (player:IsEverAlive()) then
		if (player:HasPolicy(GameInfo.Policies["POLICY_TREASURE_FLEETS"].ID)) then
			addTreasureFleetsBuilding(player, iX, iY)
		end
	end
end
GameEvents.PlayerCityFounded.Add(NQMP_Exploration_TreasureFleets_OnFoundCity)

function NQMP_POLICY_TREASURE_FLEETS_OnPolicyAdopted(playerID, policyID)
	local player = Players[playerID]
	if (policyID == GameInfo.Policies["POLICY_TREASURE_FLEETS"].ID) then
		for loopCity in player:Cities() do
			loopCity:SetNumRealBuilding(GameInfoTypes["BUILDING_TREASURE_FLEETS"], 1)
		end
	end
end
GameEvents.PlayerAdoptPolicy.Add(NQMP_POLICY_TREASURE_FLEETS_OnPolicyAdopted)




function NQMP_UpdateGrandBazaar(iPlayer)
	local player = Players[iPlayer]
	local pCapital = player:GetCapitalCity()

	-- destroy extraneous Grand Bazaar
	for pCity in player:Cities() do
		if (pCity ~= pCapital) then
			if (pCity:GetNumRealBuilding(GameInfoTypes["BUILDING_TREASURE_FLEETS"]) < 1) then
				pCity:SetNumRealBuilding(GameInfoTypes["BUILDING_TREASURE_FLEETS"], 1)
			end
		end
	end

	-- add Grand Bazaar to capital if needed
	if (pCapital:GetNumRealBuilding(GameInfoTypes["BUILDING_TREASURE_FLEETS"]) < 1) then
		pCapital:SetNumRealBuilding(GameInfoTypes["BUILDING_TREASURE_FLEETS"], 1)
	end

end

function NQMP_Exploration_Tresure_Fleets_PlayerDoTurn(iPlayer)

	local player = Players[iPlayer]
	if (player:IsEverAlive()) then
		if (player:HasPolicy(GameInfo.Policies["POLICY_TREASURE_FLEETS"].ID)) then
			NQMP_UpdateGrandBazaar(iPlayer)
		end
	end

end
GameEvents.PlayerDoTurn.Add(NQMP_Exploration_Tresure_Fleets_PlayerDoTurn);


function NQMP_TreatyOrganization_OnPolicyAdopted(playerID, policyID)
	local player = Players[playerID]
	if (policyID == GameInfo.Policies["POLICY_TREATY_ORGANIZATION"].ID) then
		for loopCity in player:Cities() do
			loopCity:SetNumRealBuilding(GameInfoTypes["BUILDING_TREATY_DUMMY"], 1)
		end
	end
end
GameEvents.PlayerAdoptPolicy.Add(NQMP_TreatyOrganization_OnPolicyAdopted)


function NQMP_UpdateTreatyOrganization(iPlayer)
	local player = Players[iPlayer]
	local pCapital = player:GetCapitalCity()

	-- destroy extraneous Grand Bazaar
	for pCity in player:Cities() do
		if (pCity ~= pCapital) then
			if (pCity:GetNumRealBuilding(GameInfoTypes["BUILDING_TREATY_DUMMY"]) > 0) then
				pCity:SetNumRealBuilding(GameInfoTypes["BUILDING_TREATY_DUMMY"], 0)
			end
		end
	end

	-- add Grand Bazaar to capital if needed
	if (pCapital:GetNumRealBuilding(GameInfoTypes["BUILDING_TREATY_DUMMY"]) < 1) then
		pCapital:SetNumRealBuilding(GameInfoTypes["BUILDING_TREATY_DUMMY"], 1)
	end

end

function NQMP_TreatyOrganization_PlayerDoTurn(iPlayer)

	local player = Players[iPlayer]
	if (player:IsEverAlive()) then
		if (player:HasPolicy(GameInfo.Policies["POLICY_TREATY_ORGANIZATION"].ID)) then
			NQMP_UpdateTreatyOrganization(iPlayer)
		end
	end

end
GameEvents.PlayerDoTurn.Add(NQMP_TreatyOrganization_PlayerDoTurn);


function NQMP_TreatyOrganization_OnPolicyAdopted(playerID, policyID)
	local player = Players[playerID]
	if (policyID == GameInfo.Policies["POLICY_TREATY_ORGANIZATION"].ID) then
		for loopCity in player:Cities() do
			loopCity:SetNumRealBuilding(GameInfoTypes["BUILDING_TREATY_DUMMY"], 1)
		end
	end
end
GameEvents.PlayerAdoptPolicy.Add(NQMP_TreatyOrganization_OnPolicyAdopted)


function NQMP_UpdateTreatyOrganization(iPlayer)
	local player = Players[iPlayer]
	local pCapital = player:GetCapitalCity()

	-- destroy extraneous Grand Bazaar
	for pCity in player:Cities() do
		if (pCity ~= pCapital) then
			if (pCity:GetNumRealBuilding(GameInfoTypes["BUILDING_TREATY_DUMMY"]) > 0) then
				pCity:SetNumRealBuilding(GameInfoTypes["BUILDING_TREATY_DUMMY"], 0)
			end
		end
	end

	-- add Grand Bazaar to capital if needed
	if (pCapital:GetNumRealBuilding(GameInfoTypes["BUILDING_TREATY_DUMMY"]) < 1) then
		pCapital:SetNumRealBuilding(GameInfoTypes["BUILDING_TREATY_DUMMY"], 1)
	end

end

function NQMP_TreatyOrganization_PlayerDoTurn(iPlayer)

	local player = Players[iPlayer]
	if (player:IsEverAlive()) then
		if (player:HasPolicy(GameInfo.Policies["POLICY_TREATY_ORGANIZATION"].ID)) then
			NQMP_UpdateTreatyOrganization(iPlayer)
		end
	end
	if (player:IsAlive()) then
		if ((player:GetLateGamePolicyTree() == 10) or (player:GetLateGamePolicyTree() == 11)) then
			for pCity in player:Cities() do
				if (pCity:GetNumRealBuilding(GameInfoTypes["BUILDING_TREATY_DUMMY"]) > 0) then
					pCity:SetNumRealBuilding(GameInfoTypes["BUILDING_TREATY_DUMMY"], 0)
				end
			end
		end
	end

end
GameEvents.PlayerDoTurn.Add(NQMP_TreatyOrganization_PlayerDoTurn);



function NQMP_UpdateUniversalSuffrage(iPlayer)
	local player = Players[iPlayer]
	local pCapital = player:GetCapitalCity()

	-- destroy extraneous Grand Bazaar
	for pCity in player:Cities() do
		if (pCity ~= pCapital) then
			if (pCity:GetNumRealBuilding(GameInfoTypes["DUMMY_BUILDING_T2_UNIVERSAL_SUFFRAGE"]) > 0) then
				pCity:SetNumRealBuilding(GameInfoTypes["DUMMY_BUILDING_T2_UNIVERSAL_SUFFRAGE"], 0)
			end
		end
	end

	-- add Grand Bazaar to capital if needed
	if (pCapital:GetNumRealBuilding(GameInfoTypes["DUMMY_BUILDING_T2_UNIVERSAL_SUFFRAGE"]) < 1) then
		pCapital:SetNumRealBuilding(GameInfoTypes["DUMMY_BUILDING_T2_UNIVERSAL_SUFFRAGE"], 1)
	end

end

function NQMP_UniversalSuffrage_PlayerDoTurn(iPlayer)

	local player = Players[iPlayer]
	if (player:IsEverAlive()) then
		if (player:HasPolicy(GameInfo.Policies["POLICY_UNIVERSAL_SUFFRAGE"].ID)) then
			NQMP_UpdateUniversalSuffrage(iPlayer)
		end
	end
	if (player:IsAlive()) then
		if ((player:GetLateGamePolicyTree() == 10) or (player:GetLateGamePolicyTree() == 11)) then
			for pCity in player:Cities() do
				if (pCity:GetNumRealBuilding(GameInfoTypes["DUMMY_BUILDING_T2_UNIVERSAL_SUFFRAGE"]) > 0) then
					pCity:SetNumRealBuilding(GameInfoTypes["DUMMY_BUILDING_T2_UNIVERSAL_SUFFRAGE"], 0)
				end
			end
		end
	end

end
GameEvents.PlayerDoTurn.Add(NQMP_UniversalSuffrage_PlayerDoTurn);

function T3_2SatelliteStates_OnEvents(iPlayerID)
	local pPlayer = Players[iPlayerID];
	local bHasPolicy = pPlayer:HasPolicy(GameInfo.Policies["POLICY_SKYSCRAPERS"].ID);
	if (bHasPolicy) then
		for loopCity in pPlayer:Cities() do
			loopCity:SetNumRealBuilding(GameInfoTypes["DUMMY_BUILDING_T3_2_SATELLITE_STATES"], loopCity:GetNumBuilding(GameInfo.Buildings["BUILDING_COURTHOUSE"].ID));
		end
	end
	if (pPlayer:IsAlive()) then
		if ((pPlayer:GetLateGamePolicyTree() == 9) or (pPlayer:GetLateGamePolicyTree() == 11)) then
			for loopCity in pPlayer:Cities() do
					if (loopCity:GetNumRealBuilding(GameInfoTypes["DUMMY_BUILDING_T3_2_SATELLITE_STATES"]) > 0) then
						loopCity:SetNumRealBuilding(GameInfoTypes["DUMMY_BUILDING_T3_2_SATELLITE_STATES"], 0);
				end
			end
		end
	end
end
GameEvents.PlayerDoTurn.Add(T3_2SatelliteStates_OnEvents);

function T3_2SatelliteStates_OnEvents(iPlayerID, iPolicyID)
	local pPlayer = Players[iPlayerID];
	local bHasPolicy = pPlayer:HasPolicy(GameInfo.Policies["POLICY_SKYSCRAPERS"].ID);
	if (bHasPolicy) then
		for loopCity in pPlayer:Cities() do
			loopCity:SetNumRealBuilding(GameInfoTypes["DUMMY_BUILDING_T3_2_SATELLITE_STATES"], loopCity:GetNumBuilding(GameInfo.Buildings["BUILDING_COURTHOUSE"].ID));
		end
	end
	if (pPlayer:IsAlive()) then
		if ((pPlayer:GetLateGamePolicyTree() == 9) or (pPlayer:GetLateGamePolicyTree() == 11)) then
			for loopCity in pPlayer:Cities() do
					if (loopCity:GetNumRealBuilding(GameInfoTypes["DUMMY_BUILDING_T3_2_SATELLITE_STATES"]) > 0) then
						loopCity:SetNumRealBuilding(GameInfoTypes["DUMMY_BUILDING_T3_2_SATELLITE_STATES"], 0);
				end
			end
		end
	end
end
GameEvents.PlayerAdoptPolicy.Add(T3_2SatelliteStates_OnEvents);

-- add dummy when courthouse is constructed
function T3_2SatelliteStates_OnCityConstructed(iPlayerID, iCityID, iBuildingID)
	if (iBuildingID == GameInfoTypes.BUILDING_COURTHOUSE) then
		local pPlayer = Players[iPlayerID];
		if (pPlayer:HasPolicy(GameInfo.Policies["POLICY_SKYSCRAPERS"].ID)) then
			local pCity = pPlayer:GetCityByID(iCityID);
			pCity:SetNumRealBuilding(GameInfoTypes["DUMMY_BUILDING_T3_2_SATELLITE_STATES"], 1);
		end
	end
end
GameEvents.CityConstructed.Add(T3_2SatelliteStates_OnCityConstructed);