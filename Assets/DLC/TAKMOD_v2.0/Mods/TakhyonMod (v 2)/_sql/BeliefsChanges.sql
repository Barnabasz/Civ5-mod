-- Insert SQL Rules Here 
ALTER TABLE Beliefs ADD FlatFaithPerCitizenBorn INTEGER DEFAULT 0;
ALTER TABLE Beliefs ADD AllowsFaithGiftsToMinors BOOLEAN DEFAULT false;
ALTER TABLE Beliefs ADD MissionaryExtraSpreads INTEGER DEFAULT 0;
ALTER TABLE Beliefs ADD NumFreeSettlers INTEGER DEFAULT 0;
ALTER TABLE Beliefs ADD GoldenAgeTurns INTEGER DEFAULT 0;
ALTER TABLE Beliefs ADD FaithPerCityStateThisReligion INTEGER DEFAULT 0;
ALTER TABLE Beliefs ADD SpreadModifierOwnedCities INTEGER DEFAULT 0;
ALTER TABLE Beliefs ADD SpreadModifierUnownedCities INTEGER DEFAULT 0;
ALTER TABLE Beliefs ADD DeusVult BOOLEAN DEFAULT false;
ALTER TABLE Beliefs ADD ExtraTradeRoutes INTEGER DEFAULT 0;
ALTER TABLE Beliefs ADD FaithPerForeignTradeRoute INTEGER DEFAULT 0;