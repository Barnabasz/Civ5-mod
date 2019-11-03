-- Lua Script1
-- Author: Takhyon
-- DateCreated: 7/1/2018 5:44:49 PM
--------------------------------------------------------------

-- Remove Embarkation Promotions from Helicopter Gunship units.
-- This code is needed in a situation where a player upgrades Anti-Tank Guns into Helicopter Gunships.
-- Otherwise Helicopters would continue to have Embarkation promo and not work as intended anymore...

function NQMP_HelicopterGunship_RemoveEmbarkation(iPlayer)

	local pPlayer = Players[iPlayer];
	local pUnitID = GameInfo.Units.UNIT_HELICOPTER_GUNSHIP.ID
	local pPromotion1 = GameInfoTypes.PROMOTION_EMBARKATION
	local pPromotion2 = GameInfoTypes.PROMOTION_ALLWATER_EMBARKATION
	local pPromotion3 = GameInfoTypes.PROMOTION_DEFENSIVE_EMBARKATION

    if (pPlayer:IsAlive()) then
		if (pPlayer:GetCurrentEra() > 5) then
			for pUnit in pPlayer:Units() do
				if (pUnit:GetUnitType() == pUnitID) then
					if (pUnit:IsHasPromotion(pPromotion1) or pUnit:IsHasPromotion(pPromotion2) or pUnit:IsHasPromotion(pPromotion3)) then
						pUnit:SetHasPromotion(pPromotion1, false)
						pUnit:SetHasPromotion(pPromotion2, false)
						pUnit:SetHasPromotion(pPromotion3, false)
					end
				end
			end
		end
	end
end
GameEvents.PlayerDoTurn.Add(NQMP_HelicopterGunship_RemoveEmbarkation);