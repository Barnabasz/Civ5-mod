-- Lua Script1
-- Author: Takhyon
-- DateCreated: 7/22/2018 5:14:30 PM
--------------------------------------------------------------
function AustriaAddDummyPolicy(iPlayer, iX, iY)
    for iPlayerLoop = 0, GameDefines.MAX_MAJOR_CIVS-1, 1 do
        local pPlayer = Players[iPlayerLoop]
        if (pPlayer:GetCivilizationType() == GameInfoTypes.CIVILIZATION_AUSTRIA) then
			if ((Map.GetPlot(iX, iY):GetPlotCity()) == pPlayer:GetCapitalCity()) then
				if (not pPlayer:HasPolicy(GameInfoTypes.DUMMY_POLICY_AUSTRIA)) then
					pPlayer:SetNumFreePolicies(1)
					pPlayer:SetNumFreePolicies(0)
					pPlayer:SetHasPolicy(GameInfoTypes.DUMMY_POLICY_AUSTRIA, true)
				end
			end
		end
    end
end
GameEvents.PlayerCityFounded.Add(AustriaAddDummyPolicy)

function CeltsAddDummyBuilding(iPlayer)
	local player = Players[iPlayer]
	if (player:IsEverAlive()) then
		local iteam = player:GetTeam()
		print(Teams[iteam]:IsHasTech(7))
		if (player:GetCivilizationType() == GameInfoTypes.CIVILIZATION_CELTS) then
			for pCity in player:Cities() do
				if (Teams[iteam]:IsHasTech(7)) then
					pCity:SetNumRealBuilding(GameInfoTypes["BUILDING_CELTS_DUMMY"], 0)
				else
					pCity:SetNumRealBuilding(GameInfoTypes["BUILDING_CELTS_DUMMY"], 1)
				end
			end
		end
	end
end
GameEvents.PlayerDoTurn.Add(CeltsAddDummyBuilding);

function addCeltsDummyBuilding(player, iX, iY)
	local plot = Map.GetPlot(iX, iY);
	local cCity = plot:GetPlotCity();
	local iteam = player:GetTeam()
	if (Teams[iteam]:IsHasTech(7)) then
		cCity:SetNumRealBuilding(GameInfoTypes["BUILDING_CELTS_DUMMY"], 0)
	else
		cCity:SetNumRealBuilding(GameInfoTypes["BUILDING_CELTS_DUMMY"], 1)
	end
end

function CeltsAddDummyBuilding_OnFoundCity(iPlayer, iX, iY)
	local player = Players[iPlayer]
	if (player:IsEverAlive()) then
		if (player:GetCivilizationType() == GameInfoTypes.CIVILIZATION_CELTS) then
			addCeltsDummyBuilding(player, iX, iY)
		end
	end
end
GameEvents.PlayerCityFounded.Add(CeltsAddDummyBuilding_OnFoundCity)

