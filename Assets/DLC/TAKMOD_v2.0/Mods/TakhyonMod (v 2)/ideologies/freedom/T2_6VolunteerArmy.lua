-- Lua Script1
-- Author: Takhyon
-- DateCreated: 6/9/2018 8:10:15 PM
--------------------------------------------------------------

function NQMP_Freedom_T2_Volunteer_Army_OnAdoptPolicy(iPlayer)

	local pPlayer = Players[iPlayer];
	local pPromotion = GameInfoTypes.PROMOTION_VOLUNTEER_ARMY;

	if (pPlayer:IsAlive()) then
		if ((pPlayer:GetLateGamePolicyTree() == 10) or (pPlayer:GetLateGamePolicyTree() == 11)) then
			for pUnit in pPlayer:Units() do
					if pUnit:IsHasPromotion(pPromotion) then
						pUnit:SetHasPromotion(pPromotion, false);
				end
			end
		end
	end
end
GameEvents.PlayerAdoptPolicy.Add(NQMP_Freedom_T2_Volunteer_Army_OnAdoptPolicy);