-- Lua Script1
-- Author: Takhyon
-- DateCreated: 6/9/2018 1:01:02 PM
--------------------------------------------------------------

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

function NQMP_UniversalSuffrage_OnPolicyAdopted(playerID, policyID)

	local player = Players[playerID]
	if ((policyID == GameInfo.Policies["POLICY_UNIVERSAL_SUFFRAGE"].ID) or player:HasPolicy(GameInfo.Policies["POLICY_UNIVERSAL_SUFFRAGE"].ID)) then
		NQMP_UpdateUniversalSuffrage(playerID)
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
GameEvents.PlayerAdoptPolicy.Add(NQMP_UniversalSuffrage_OnPolicyAdopted)