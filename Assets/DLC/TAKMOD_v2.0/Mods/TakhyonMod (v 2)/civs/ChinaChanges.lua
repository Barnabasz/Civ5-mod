-- Lua Script1
-- Author: Takhyon
-- DateCreated: 7/24/2018 7:28:30 PM
--------------------------------------------------------------
function ChinaAddDummyPolicy(iPlayer, iX, iY)
    for iPlayerLoop = 0, GameDefines.MAX_MAJOR_CIVS-1, 1 do
        local pPlayer = Players[iPlayerLoop]
        if (pPlayer:GetCivilizationType() == GameInfoTypes.CIVILIZATION_CHINA) then
			if ((Map.GetPlot(iX, iY):GetPlotCity()) == pPlayer:GetCapitalCity()) then
				if (not pPlayer:HasPolicy(GameInfoTypes.DUMMY_POLICY_CHINA)) then
					pPlayer:SetNumFreePolicies(1)
					pPlayer:SetNumFreePolicies(0)
					pPlayer:SetHasPolicy(GameInfoTypes.DUMMY_POLICY_CHINA, true)
				end
			end
		end
    end
end
GameEvents.PlayerCityFounded.Add(ChinaAddDummyPolicy)