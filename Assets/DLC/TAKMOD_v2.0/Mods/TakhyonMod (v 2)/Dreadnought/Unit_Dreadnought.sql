----------------------------------------------------
-- Enhanced Modern Warfare
-- New unit: Dreadnought
-- Author: Infixo
-- Feb 16, 2017: Created
----------------------------------------------------

----------------------------------------------------
-- ArtDef
----------------------------------------------------

INSERT INTO ArtDefine_UnitInfos (Type, DamageStates, Formation)
VALUES ('ART_DEF_UNIT_DREADNOUGHT', 3, '');

INSERT INTO ArtDefine_UnitMemberInfos (Type, Scale , Domain, Model, MaterialTypeTag, MaterialTypeSoundOverrideTag)
VALUES ('ART_DEF_UNIT_MEMBER_DREADNOUGHT', 0.085, 'Sea', 'Dreadnought_Generic.fxsxml', 'METAL', 'METALLRG');

INSERT INTO ArtDefine_UnitInfoMemberInfos (UnitInfoType, UnitMemberInfoType, NumMembers)
VALUES ('ART_DEF_UNIT_DREADNOUGHT', 'ART_DEF_UNIT_MEMBER_DREADNOUGHT', 1);

INSERT INTO ArtDefine_UnitMemberCombats (
	UnitMemberType,
	EnableActions, DisableActions,
	HasShortRangedAttack, HasLeftRightAttack, HasRefaceAfterCombat, HasIndependentWeaponFacing, RushAttackFormation)
VALUES (
	'ART_DEF_UNIT_MEMBER_DREADNOUGHT',
	'Idle Attack RunCharge AttackCity Bombard Death BombardDefend Run Fortify CombatReady AttackSurfaceToAir', '',
	1, 1, 0, 1, '');

INSERT INTO ArtDefine_UnitMemberCombatWeapons
	(UnitMemberType, "Index", SubIndex, ID, VisKillStrengthMin, VisKillStrengthMax, ProjectileSpeed, HitEffect, WeaponTypeTag, WeaponTypeSoundOverrideTag)
VALUES
	('ART_DEF_UNIT_MEMBER_DREADNOUGHT', 0, 0, '', 25, 50, NULL, 'ART_DEF_VEFFECT_ARTILLERY_IMPACT_$(TERRAIN)', 'EXPLOSIVE', 'EXPLOSION1TON'),
	('ART_DEF_UNIT_MEMBER_DREADNOUGHT', 1, 0, '', 25, 50, NULL, 'ART_DEF_VEFFECT_ARTILLERY_IMPACT_$(TERRAIN)', 'BULLETHC', 'BULLETHC');

INSERT INTO ArtDefine_StrategicView (StrategicViewType, TileType, Asset)
VALUES ('ART_DEF_UNIT_DREADNOUGHT', 'Unit', 'SV_Dreadnought.dds');

----------------------------------------------------
-- Icons
-- Shared atlas: ICON_ATLAS_EMW
----------------------------------------------------

-- Infixo: don't know how to put file name - is "Art" folder necessary?
--INSERT INTO IconTextureAtlases
--	(Atlas, IconSize, Filename, IconsPerRow, IconsPerColumn)
--VALUES
--	('UNIT_DREADNOUGHT_FLAG_ATLAS', 32, 'UnitFlag_Dreadnought.dds', '1', '1');

----------------------------------------------------
-- Unit
----------------------------------------------------

INSERT INTO UnitClasses (Type, Description, MaxPlayerInstances, DefaultUnit)
VALUES ('UNITCLASS_DREADNOUGHT', 'TXT_KEY_UNIT_DREADNOUGHT', -1, 'UNIT_DREADNOUGHT');

INSERT INTO Units
	(Type, Class, Domain, CombatClass, PrereqTech, ObsoleteTech, DefaultUnitAI,
	Description, Civilopedia, Strategy, Help,
	Cost, FaithCost, ExtraMaintenanceCost, Combat, Moves, RangedCombat, Range, AirInterceptRange, BaseSightRange,
	MilitarySupport, MilitaryProduction, Pillage, IgnoreBuildingDefense, Mechanized,
	AdvancedStartCost, MinAreaSize, XPValueAttack, XPValueDefense, MoveRate,
	BaseLandAirDefense, SpecialCargo, DomainCargo, PurchaseCooldown,
	UnitArtInfo, UnitFlagAtlas, UnitFlagIconOffset, IconAtlas, PortraitIndex)
VALUES
	('UNIT_DREADNOUGHT', 'UNITCLASS_DREADNOUGHT', 'DOMAIN_SEA', 'UNITCOMBAT_NAVALRANGED', 'TECH_RADIO', 'TECH_ELECTRONICS', 'UNITAI_ASSAULT_SEA',
	'TXT_KEY_UNIT_DREADNOUGHT', 'TXT_KEY_UNIT_DREADNOUGHT_PEDIA', 'TXT_KEY_UNIT_DREADNOUGHT_STRATEGY', 'TXT_KEY_UNIT_DREADNOUGHT_HELP',
	1300, 800, 0, 39, 4, 55, 1, 0, 2, 
	1, 1, 1, 1, 1,
	60, 10, 3, 3, 'BOAT',
	20, NULL, NULL, 1,
	'ART_DEF_UNIT_DREADNOUGHT', 'FLAG_ATLAS_ENW', 2, 'ICON_ATLAS_ENW', 2);

INSERT INTO UnitGameplay2DScripts (UnitType, SelectionSound, FirstSelectionSound)
VALUES ('UNIT_DREADNOUGHT', 'AS2D_SELECT_BATTLESHIP', 'AS2D_BIRTH_BATTLESHIP');

DELETE FROM Unit_ClassUpgrades WHERE UnitType = 'UNIT_CRUISER';
INSERT INTO Unit_ClassUpgrades (UnitType, UnitClassType)
VALUES ('UNIT_CRUISER', 'UNITCLASS_DREADNOUGHT');
INSERT INTO Unit_ClassUpgrades (UnitType, UnitClassType)
VALUES ('UNIT_DREADNOUGHT', 'UNITCLASS_BATTLESHIP');

----------------------------------------------------
-- Promotions
-- No special promos
----------------------------------------------------

INSERT INTO Unit_FreePromotions (UnitType, PromotionType)
VALUES
	('UNIT_DREADNOUGHT', 'PROMOTION_ONLY_DEFENSIVE'),
	('UNIT_DREADNOUGHT', 'PROMOTION_NAVAL_RANGE'),
	('UNIT_DREADNOUGHT', 'PROMOTION_CAN_MOVE_AFTER_ATTACKING');

----------------------------------------------------
-- Other features
----------------------------------------------------

INSERT INTO Unit_ResourceQuantityRequirements (UnitType, ResourceType, Cost)
VALUES ('UNIT_DREADNOUGHT', 'RESOURCE_IRON', 1);

INSERT INTO Unit_BuildingClassPurchaseRequireds (UnitType, BuildingClassType)
VALUES ('UNIT_DREADNOUGHT','BUILDINGCLASS_SEAPORT');

----------------------------------------------------
-- AI
----------------------------------------------------

INSERT INTO Technology_Flavors (TechType, FlavorType, Flavor)
VALUES
	('TECH_RADIO', 'FLAVOR_NAVAL', 10),
	('TECH_RADIO', 'FLAVOR_NAVAL_RECON', 5);

INSERT INTO Unit_AITypes (UnitType, UnitAIType)
VALUES
	('UNIT_DREADNOUGHT', 'UNITAI_ASSAULT_SEA'),
	('UNIT_DREADNOUGHT', 'UNITAI_RESERVE_SEA'),
	('UNIT_DREADNOUGHT', 'UNITAI_ESCORT_SEA');

INSERT INTO Unit_Flavors (UnitType, FlavorType, Flavor)
VALUES
	('UNIT_DREADNOUGHT', 'FLAVOR_NAVAL', 55),
	('UNIT_DREADNOUGHT', 'FLAVOR_NAVAL_RECON', 30);

----------------------------------------------------
-- Text (en_US)
----------------------------------------------------

INSERT INTO Language_en_US (Tag, Text)
VALUES ('TXT_KEY_UNIT_DREADNOUGHT', 'Dreadnought');

-- Pedia: Historical Info (bottom)
INSERT INTO Language_en_US (Tag, Text)
VALUES ('TXT_KEY_UNIT_DREADNOUGHT_PEDIA', 'The Dreadnought was the predominant type of battleship in the early 20th century. It''s design had two revolutionary features: an "all-big-gun" armament scheme, with more heavy-calibre guns than previous ships, and steam turbine propulsion.  The first of its kind, the Royal Navy''s "Dreadnought" mounted ten 12-inch (305 mm) guns. The US Navy was the first to adopt oil-firing, deciding to do so in 1910 and ordering oil-fired boilers for the Nevada class, in 1911. Other major navies retained mixed coal-and-oil firing until the end of World War I.[NEWLINE]Within five years of the commissioning of "Dreadnought", a new generation of more powerful "super-dreadnoughts" was being built. The first super-dreadnoughts are generally considered to be the British "Orion" class. What made them ''super'' was the introduction of the heavier 13.5-inch (343 mm) guns and the placement of all the main armament on the centreline. In 1917, the Japanese "Nagato" class was ordered, the first dreadnoughts to mount 16-inch (406 mm) guns, making them arguably the most powerful warships in the world.');

-- Pedia: Strategy (middle)
INSERT INTO Language_en_US (Tag, Text)
VALUES ('TXT_KEY_UNIT_DREADNOUGHT_STRATEGY', 'The Dreadnought is capable of firing at 2-tile range distance, however it needs LoS. Very strong at offense, weaker at defense. It requires [ICON_RES_IRON] Iron to be built.');

-- Pedia: Game Info (top)
INSERT INTO Language_en_US (Tag, Text)
VALUES ('TXT_KEY_UNIT_DREADNOUGHT_HELP', 'Powerful naval ranged unit with 2-tile range attacks. It requires [ICON_RES_IRON] Iron to be built.');
