-- Lua Script1
-- Author: Takhyon
-- DateCreated: 7/15/2018 5:19:30 PM
--------------------------------------------------------------
function addMaterialismBuilding(player, iX, iY)
	local plot = Map.GetPlot(iX, iY);
	local cCity = plot:GetPlotCity();
	cCity:SetNumRealBuilding(GameInfoTypes["BUILDING_MATERIALISM"], 1)
end

function NQMP_Materialism_OnCityCaptureComplete(iOldOwner, bIsCapital, iX, iY, iNewOwner, iPop, bConquest)
	local player = Players[iNewOwner]
	if (player:IsEverAlive()) then
		if (player:HasPolicy(GameInfo.Policies["POLICY_UNIVERSAL_HEALTHCARE_F"].ID)) then
			addMaterialismBuilding(player, iX, iY)
		end
	end
end
GameEvents.CityCaptureComplete.Add(NQMP_Materialism_OnCityCaptureComplete)

function NQMP_Materialism_OnFoundCity(iPlayer, iX, iY)
	local player = Players[iPlayer]
	if (player:IsEverAlive()) then
		if (player:HasPolicy(GameInfo.Policies["POLICY_UNIVERSAL_HEALTHCARE_F"].ID)) then
			addMaterialismBuilding(player, iX, iY)
		end
	end
end
GameEvents.PlayerCityFounded.Add(NQMP_Materialism_OnFoundCity)

function NQMP_Materialism_OnPolicyAdopted(playerID, policyID)

	local player = Players[playerID]
	if (policyID == GameInfo.Policies["POLICY_UNIVERSAL_HEALTHCARE_F"].ID) then
		for loopCity in player:Cities() do
			loopCity:SetNumRealBuilding(GameInfoTypes["BUILDING_MATERIALISM"], 1)
		end
	end

	if (player:IsAlive()) then
		if ((player:GetLateGamePolicyTree() == 10) or (player:GetLateGamePolicyTree() == 11)) then
			for loopCity in player:Cities() do
				if (loopCity:GetNumRealBuilding(GameInfoTypes["BUILDING_MATERIALISM"]) > 0) then
					loopCity:SetNumRealBuilding(GameInfoTypes["BUILDING_MATERIALISM"], 0);
				end
			end
		end
	end

end
GameEvents.PlayerAdoptPolicy.Add(NQMP_Materialism_OnPolicyAdopted)