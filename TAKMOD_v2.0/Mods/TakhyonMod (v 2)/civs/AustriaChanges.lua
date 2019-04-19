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