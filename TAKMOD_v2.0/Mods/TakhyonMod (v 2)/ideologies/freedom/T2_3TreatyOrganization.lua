-- Treaty Organization
-- Author: Fruitstrike, Modified by Takhyon
-- DateCreated: 5/8/2018 10:37:07 PM
--------------------------------------------------------------

function NQMP_UpdateTreatyOrganization(iPlayer)
	local player = Players[iPlayer]
	for pCity in player:Cities() do
		if (pCity:GetNumRealBuilding(GameInfoTypes["BUILDING_TREATY_DUMMY"]) > 1) then
			pCity:SetNumRealBuilding(GameInfoTypes["BUILDING_TREATY_DUMMY"], 1)
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

function NQMP_TreatyOrganization_OnPolicyAdopted(playerID, policyID)

	local player = Players[playerID]
	if ((policyID == GameInfo.Policies["POLICY_TREATY_ORGANIZATION"].ID) or player:HasPolicy(GameInfo.Policies["POLICY_TREATY_ORGANIZATION"].ID)) then
		NQMP_UpdateTreatyOrganization(playerID)
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
GameEvents.PlayerAdoptPolicy.Add(NQMP_TreatyOrganization_OnPolicyAdopted)

function NQMP_TreatyOrganization_PlayerDoTurn(iPlayer)
	
	local player = Players[iPlayer]
	if (player:IsEverAlive()) then
		if (player:HasPolicy(GameInfo.Policies["POLICY_TREATY_ORGANIZATION"].ID)) then
			NQMP_UpdateTreatyOrganization(iPlayer)
		end
	end

end
GameEvents.PlayerDoTurn.Add(NQMP_TreatyOrganization_PlayerDoTurn);