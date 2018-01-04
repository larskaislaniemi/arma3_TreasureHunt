 
trh2_cfg_debugLevel = "Debug" call BIS_fnc_getParamValue;
trh2_cfg_numOfCivs = "NumOfCivs" call BIS_fnc_getParamValue;
trh2_cfg_numOfIntelItems = "NumOfIntelItems" call BIS_fnc_getParamValue;
trh2_cfg_numOfCars = "NumOfCars" call BIS_fnc_getParamValue;
trh2_cfg_viewDistance = "ViewDistance" call BIS_fnc_getParamValue;

trh2_cfg_carsRadius = 2000;
trh2_cfg_carsOutOfCityCoef = 3.0;

trh2_cfg_intelInfoRandomUncertainty = 200;
trh2_cfg_intelInfoMinimumUncertainty = 200;
trh2_cfg_safeZoneRadius = 1500;
trh2_cfg_safeZoneSpawnRadius = 30;
trh2_cfg_waitStartTime = 30;
trh2_cfg_haloSafety = 150;
trh2_cfg_haloElev = 1000;
trh2_cfg_treasurePool = [
    ["Land_Sleeping_bag_blue_folded_F", "blue sleeping bag", "Comfy blue sleeping bag."],
    ["Land_Microwave_01_F", "microwave oven", "(850 watts!)"],
    ["Land_WaterCooler_01_new_F", "water cooler", "How cool is that!"]
];
trh2_cfg_treasureRadius = 1300;
trh2_cfg_intelItemRadius = 1500;
trh2_cfg_extractionPointMarkers = [
    "trh2_extract_1", 
    "trh2_extract_2", 
    "trh2_extract_3"
];
trh2_cfg_extractionRadius = 50;
trh2_cfg_maxPlayersPerGroup = 3;
trh2_cfg_nDistinctIntelInfo = 100;
trh2_cfg_carPool = [
    "C_Hatchback_01_F",
    "C_Offroad_02_unarmed_F",
    "C_Offroad_01_F",
    "C_Quadbike_01_F",
    "C_Van_01_fuel_F",
    "C_Van_01_transport_F",
    "C_Van_02_medevac_F",
    "C_Van_02_transport_F",
    "C_Truck_02_transport_F",
    "I_MRAP_03_F",
    "B_MRAP_01_F"
];
trh2_cfg_civPercInside = 0.3;
trh2_cfg_civPool = [
    "C_IDAP_Man_AidWorker_01_F",
    "C_IDAP_Man_AidWorker_02_F",
    "C_IDAP_Man_AidWorker_03_F",
    "C_IDAP_Man_AidWorker_05_F",
    "C_IDAP_Man_AidWorker_06_F",
    "C_man_p_beggar_F",
    "C_Man_casual_1_F",
    "C_Man_casual_2_F",
    "C_Man_casual_3_F",
    "C_Man_Fisherman_01_F",
    "C_Man_polo_1_F",
    "C_Man_polo_2_F",
    "C_Man_polo_3_F",
    "C_Man_polo_4_F",
    "C_Man_polo_5_F",
    "C_Man_polo_6_F",
    "C_man_shorts_1_F",
    "C_Story_Mechanic_01_F",
    "C_Nikos_aged",
    "C_Orestes"
];
trh2_cfg_debug = trh2_cfg_debugLevel;
