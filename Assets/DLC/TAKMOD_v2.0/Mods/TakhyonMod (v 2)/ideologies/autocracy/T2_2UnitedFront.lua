-- Lua Script1
-- Author: Takhyon
-- DateCreated: 6/9/2018 8:10:15 PM
--------------------------------------------------------------

function NQMP_Autocracy_T2_United_Front_OnAdoptPolicy(iPlayer)

	local pPlayer = Players[iPlayer];
	local pPromotion = GameInfoTypes.PROMOTION_UNITED_FRONT;

	if (pPlayer:IsAlive()) then
		if ((pPlayer:GetLateGamePolicyTree() == 10) or (pPlayer:GetLateGamePolicyTree() == 9)) then
			for pUnit in pPlayer:Units() do
					if pUnit:IsHasPromotion(pPromotion) then
						pUnit:SetHasPromotion(pPromotion, false);
				end
			end
		end
	end
end
GameEvents.PlayerAdoptPolicy.Add(NQMP_Autocracy_T2_United_Front_OnAdoptPolicy);