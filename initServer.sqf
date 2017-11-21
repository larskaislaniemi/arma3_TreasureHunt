#include "configParams.sqf";
#include "qb\qb_init.sqf";

["Initialize", [true, trh_cfg_maxPlayersPerGroup]] call BIS_fnc_dynamicGroups;

trh_gameStarted = false;
publicVariable "trh_gameStarted";

/* Mission start countdown */
[] spawn {
    trh_missionStartTime = time + trh_cfg_gameStartWaitTime;
    publicVariable "trh_missionStartTime";

    waitUntil { time >= trh_missionStartTime };
    waitUntil { !isNil "trh_treasure" };
    
    trh_gameStarted = true;
    publicVariable "trh_gameStarted";
};

/* Create treasure */
[] spawn {
    _treasureArray = selectRandom trh_cfg_treasurePool;
    _treasureClass = _treasureArray select 0;
    _treasureName = _treasureArray select 1;
    _treasureDescription = _treasureArray select 2;
    
    trh_cfg_treasureItemInfo = _treasureArray;
    trh_cfg_treasureItemClass = _treasureClass;
    trh_cfg_treasureItemName = _treasureName;
    trh_cfg_treasureItemDescription = _treasureDescription;
    publicVariable "trh_cfg_treasureItemClass";
    publicVariable "trh_cfg_treasureItemName";
    publicVariable "trh_cfg_treasureItemDescription";
    
    _pos = ["trh_mrk_treasure", trh_cfg_treasureRadius] call qb_fnc_getPosNearMarker;
    _pos = _pos + [0.0];
    trh_treasure = createVehicle [trh_cfg_treasureItemClass, [0,0,0], [], 2, "CAN_COLLIDE"];
    trh_treasure setVariable ["BIS_enableRandomization", false];
    
    publicVariable "trh_treasure";

    _building = nearestBuilding _pos;
    _buildingPos = selectRandom ([_building] call BIS_fnc_buildingPositions);

    trh_treasure setPos _buildingPos;
    [trh_treasure, trh_cfg_treasureItemName] call qb_fnc_pickObjInit;
    
    if (trh_cfg_debugLevel > 0) then {
        _mrk = createMarker ["trh_mrk_treasureVisible", _buildingPos];
        _mrk setMarkerType "hd_destroy";
        _mrk setMarkerColor "ColorRed";
    };
    
};

/* Treasure beacon AND winner test */
[] spawn {
    waitUntil { !isNil "trh_treasure" };
    waitUntil { !isNull trh_treasure };
    
    trh_extractionPointSet = false;
    trh_extractionPoint = [0,0,0];
    publicVariable "trh_extractionPointSet";
    publicVariable "trh_extractionPoint";
    
    while { true } do {
        waitUntil { trh_treasure getVariable ["pickObj_pickedUp", false] };
        _whoHasIt = trh_treasure getVariable "pickObj_whoHas";
        ["enable", [trh_treasure getVariable "pickObj_whoHas", 100, 15, "mrk_treasure"]] call qb_fnc_addBeacon;
        ["Default",["Beacon activated", "Treasure has been moved, beacon activated!"]] remoteExec ["bis_fnc_showNotification", 0, false];
        
        if (!trh_extractionPointSet) then {
            trh_extractionPointMarker = selectRandom trh_cfg_extractionPointMarkers;
            trh_extractionPoint = getMarkerPos trh_extractionPointMarker;
            trh_extractionPointSet = true;
            publicVariable "trh_extractionPointSet";
            publicVariable "trh_extractionPoint";
            
            trh_extractionPointMarker = createMarker ["trh_extract_final", trh_extractionPoint];
            trh_extractionPointMarker setMarkerType "hd_destroy";
            trh_extractionPointMarker setMarkerShape "ICON";
            trh_extractionPointMarker setMarkerColor "ColorGreen";
            
            trh_extractionPointMarkerHelper = createMarker ["trh_extract_final_helper", trh_extractionPoint];
            trh_extractionPointMarkerHelper setMarkerShape "ELLIPSE";
            trh_extractionPointMarkerHelper setMarkerBrush "Border";
            trh_extractionPointMarkerHelper setMarkerSize [trh_cfg_extractionRadius, trh_cfg_extractionRadius];
            trh_extractionPointMarkerHelper setMarkerColor "ColorGreen";
            
            ["Default",["Extraction point", "Treasure extraction point marked on the map"]] remoteExec ["bis_fnc_showNotification", 0, false];
            
            [] spawn {
                systemchat format ["%1", trh_extractionPoint];
                waitUntil {
                    _pos = [trh_treasure] call qb_fnc_pickObjGetPos;
                    (trh_extractionPoint distance2d _pos) < trh_cfg_extractionRadius
                };
                _winnerGrp = group (trh_treasure getVariable "pickObj_whoHas");
                _winners = "";
                {
                    _winners = _winners + "  " + (name _x);
                } forEach (units _winnerGrp);
                ["Default",["WINNER", format ["Winners are: %1", _winners]]] remoteExec ["bis_fnc_showNotification", 0, false];
                sleep 10;
                
                ["end1",true,true,true,true] remoteExec ["BIS_fnc_endMission", (units _winnerGrp), false];
                ["end2",false,true,true,true] remoteExec ["BIS_fnc_endMission", allPlayers - (units _winnerGrp), false];
                //["end3",false,true,true,true] remoteExec ["BIS_fnc_endMission", 2, false];
            };
        };
        
        waitUntil { not (trh_treasure getVariable ["pickObj_pickedUp", false]) or _whoHasIt != trh_treasure getVariable "pickObj_whoHas" };
        ["disable", [trh_treasure getVariable "pickObj_whoHas"]] call qb_fnc_addBeacon;
    };
};

/* Generate intel about treasure's location */
[] spawn {
    waitUntil { !isNil "trh_treasure" };
    waitUntil { !isNull trh_treasure };

    trh_intelPos = [];
    trh_intelUncertainty = [];
    trh_nIntelPos = trh_cfg_nDistinctIntelInfo;
    
    for "_i" from 1 to trh_nIntelPos do {
        _uncert = (random trh_cfg_intelInfoRandomUncertainty) + trh_cfg_intelInfoMinimumUncertainty;
        _pos = [trh_treasure, _uncert] call qb_fnc_getPosNearObject;
        trh_intelPos pushBack _pos;
        trh_intelUncertainty pushBack _uncert;
    };
    
    publicVariable "trh_intelPos";
    publicVariable "trh_intelUncertainty";
    publicVariable "trh_nIntelPos";
};


/*  Create cars. Weighted by city size. */
[] spawn {
    _pos = getMarkerPos "trh_mrk_taor";
    _radius = trh_cfg_carsRadius;
    _nTotalCars = trh_cfg_numOfCars;
    _towns = nearestLocations [_pos, ["NameVillage","NameCity","NameCityCapital"], _radius];
    _sizes = [];
    _areas = [];
    _nCars = [];
    
    _sum = 0;
    {
        _size = [position _x] call qb_fnc_calcCitySize;
        _sizes pushBack _size;
        _area = _size*_size;
        _areas pushBack _area;  
        _sum = _sum + _area;
    } forEach _towns;
    
    {
        _areas set [_forEachIndex, (_areas select _forEachIndex) / _sum];
        _nCars pushBack (floor ((_areas select _forEachIndex) * _nTotalCars));
    } forEach _towns;
    
    {
        _town = _x;
        _townRange = _sizes select _forEachIndex;
        for "_i" from 1 to (_nCars select _forEachIndex) do {
            _foundRoad = false;
            _finalPos = [0,0,0];
            while { !_foundRoad } do {
                _dir = random 360;
                _range = random (_townRange * trh_cfg_carsOutOfCityCoef);
                _setPos = position _town;
                _setPos = [(_setPos select 0)+_range*sin(_dir), (_setPos select 1)+_range*cos(_dir), 0];
                _roadSegs = _setPos nearRoads 50;
                if ((count _roadSegs) <= 0) then {
                    _foundRoad = false;
                    // no roads here
                } else {
                    _foundRoad = true;
                    _roadSeg = _roadSegs select 0;
                    _roadConnectedTo = roadsConnectedTo _roadSeg;
                    _direction = 0;
                    if (count _roadConnectedTo <= 0) then {
                        _direction = 0;
                    } else {
                        _connectedRoad = _roadConnectedTo select 0;
                        _direction = [_roadSeg, _connectedRoad] call BIS_fnc_DirTo;
                    };
                    _vehType = selectRandom trh_cfg_carPool;
                    _finalPos = getPos _roadSeg;
                    _veh = createVehicle [_vehType, _finalPos, [], 3, "NONE"];
                    _veh setVariable ["BIS_enableRandomization", false];
                    _veh setDir _direction;
                };
            };
            if (trh_cfg_debugLevel > 0) then {
                _mrk = createMarker [format ["trh_car_%2_%1", _forEachIndex, _i], _finalPos];
                _mrk setMarkerType "hd_unknown";
                _mrk setMarkerShape "ICON";
            };
        };
    } forEach _towns;
};

/* Create intel items, civilians. Weighted by city size. */
[] spawn {
    waitUntil { !isNil "trh_nIntelPos" };
    
    _pos = getMarkerPos "trh_mrk_taor";
    _radius = trh_cfg_intelItemRadius;
    _nTotalCivs = trh_cfg_numOfCivs;
    _nTotalIntelItems = trh_cfg_numOfIntelItems;
    _towns = nearestLocations [_pos, ["NameVillage","NameCity","NameCityCapital"], _radius];
    _sizes = [];
    _areas = [];
    _nCivs = [];
    _nIntelItems = [];
    
    _sum = 0;
    {
        _size = [position _x] call qb_fnc_calcCitySize;
        _sizes pushBack _size;
        _area = _size*_size;
        _areas pushBack _area;  
        _sum = _sum + _area;
    } forEach _towns;
    
    {
        _areas set [_forEachIndex, (_areas select _forEachIndex) / _sum];
        _nCivs pushBack (floor ((_areas select _forEachIndex) * _nTotalCivs));
        _nIntelItems pushBack (floor ((_areas select _forEachIndex) * _nTotalIntelItems));
    } forEach _towns;
    
    /* Create intel items */
    {
        _town = _x;
        _townRange = _sizes select _forEachIndex;
        for "_i" from 1 to (_nIntelItems select _forEachIndex) do {
            _dir = random 360;
            _range = random (_townRange * 1.5);
            _setPos = position _town;
            _setPos = [(_setPos select 0)+_range*sin(_dir), (_setPos select 1)+_range*cos(_dir), (_setPos select 2)];
            _building = nearestBuilding _setPos;
            _buildingPos = selectRandom ([_building] call BIS_fnc_buildingPositions);
            if (isNil "_buildingPos") then {
                _buildingPos = _setPos;
            };
            _veh = createVehicle ["Land_PCSet_01_screen_F", _buildingPos, [], 0, "NONE"];
            _veh2 = createVehicle ["Land_PCSet_01_case_F", [(_buildingPos select 0)+0.4, _buildingPos select 1, _buildingPos select 2], [], 0, "NONE"];
            _veh3 = createVehicle ["Land_PCSet_01_keyboard_F", [_buildingPos select 0, (_buildingPos select 1)+0.3, _buildingPos select 2], [], 0, "NONE"];
            _veh setVariable ["trh_intelInfoNumber", floor (random trh_nIntelPos), true];
            [_veh, ["Find and delete intel", {
                _target = _this select 0;
                _caller = _this select 1;
                _actId = _this select 2;
                
                _ns = group _caller;
                _ni = _target getVariable "trh_intelInfoNumber";
                
                if (_ni < 0) then {
                    //systemchat "Hmm, looks like the hard drive is empty...";
                    ["Hmm, looks like the hard drive is empty..."] remoteExec ["systemchat", _caller, false];
                } else {
                    if ((_ns getVariable "trh_gotIntel") find _ni < 0) then {
                        _prevN = _ns getVariable ["trh_nGotIntel", 0];
                        _prevI = _ns getVariable ["trh_gotIntel", []];
                        
                        _ns setVariable ["trh_nGotIntel", _prevN + 1, true];
                        _ns setVariable ["trh_gotIntel", _prevI + [_ni], true];
                        
                        _target setVariable ["trh_intelInfoNumber", -1, true];
                        
                        ["Great, found something interesting here!"] remoteExec ["systemchat", _caller, false];
                        //systemchat "Great, found something interesting here!";
                    } else {
                        ["There's nothing here we didn't already know"] remoteExec ["systemchat", _caller, false];
                        //systemchat "There's nothing here we didn't already know";
                    };
                };
            }, [], 5, true, true, "", "true", 6, false, ""]] remoteExec ["addAction", 0, true];
            
            if (trh_cfg_debugLevel > 0) then {
                _mrk = createMarker [format ["trh_intel_%2_%1", _forEachIndex, _i], _buildingPos];
                _mrk setMarkerType "hd_pickup";
                _mrk setMarkerShape "ICON";
            };
        };
    } forEach _towns;
    
    /* Create civilians */
    {
        _town = _x;
        _townRange = _sizes select _forEachIndex;
        for "_i" from 1 to (_nCivs select _forEachIndex) do {
            _dir = random 360;
            _range = random (_townRange * 1.5);
            _setPos = position _town;
            _setPos = [(_setPos select 0)+_range*sin(_dir), (_setPos select 1)+_range*cos(_dir), 0];
            
            _inHouse = false;
            if (random 1 < 0.5) then {
                _inHouse = true;
                _building = nearestBuilding _setPos;
                _buildingPos = selectRandom ([_building] call BIS_fnc_buildingPositions);
                if (isNil "_buildingPos") then {
                    _inHouse = false;
                    _buildingPos = _setPos;
                };
                _setPos = _buildingPos;
            };
            
            _grp = createGroup civilian;
            _unit = _grp createUnit [selectRandom trh_cfg_civPool, _setPos, [], 0, "NONE"];
            
            if (!_inHouse) then {
                [[_grp], _setPos, _townRange, 4] call qb_fnc_addPatrolWaypoints;
            };
            
            _unit setVariable ["trh_intelInfoNumber", floor (random trh_nIntelPos), true];
            [_unit, ["Ask about the treasure", {
                _target = _this select 0;
                _caller = _this select 1;
                _actId = _this select 2;
                
                if (!alive _target) then {
                    ["Looks like he is very much not alive any more..."] remoteExec ["systemchat", _caller, false];
                    //systemchat "Looks like he is very much not alive any more...";
                } else {
                    _ns = group _caller;
                    _ni = _target getVariable "trh_intelInfoNumber";
                    if (trh_cfg_debugLevel > 0) then { [format ["infonumber is %1", _ni]] remoteExec ["systemchat", _caller, false]; };
                    
                    //[format ["_ns/trh_gotIntel is %1", _ns getVariable "trh_gotIntel"]] remoteExec ["systemchat", _caller, false];
                    if ((_ns getVariable "trh_gotIntel") find _ni < 0) then {
                        _prevN = _ns getVariable ["trh_nGotIntel", 0];
                        _prevI = _ns getVariable ["trh_gotIntel", []];
                        
                        _ns setVariable ["trh_nGotIntel", _prevN + 1, true];
                        _ns setVariable ["trh_gotIntel", _prevI + [_ni], true];
                        
                        ["- [Incomprehensible muttering]   - Thanks, that was useful info!"] remoteExec ["systemchat", _caller, false];
                        //systemchat "- [Incomprehensible muttering]   - Thanks, that was useful info!";
                    } else {
                        ["- [Incomprehensible muttering]   - Thanks but we knew that already."] remoteExec ["systemchat", _caller, false];
                        //systemchat "- [Incomprehensible muttering]   - Thanks but we knew that already.";
                    };
                    
                    if (_target getVariable ["trh_hasExtraIntel", false]) then {
                        [_target getVariable "trh_extraIntel"] remoteExec ["systemchat", _caller, false];
                    };
                }; 
            }, [], 5, true, true, "", "true", 10, false, ""]] remoteExec ["addAction", 0, true];
            
            _unit addEventHandler ["FiredNear", {
                _unit = _this select 0;
                _vehicle = _this select 1;
                _distance = _this select 2;
                _weapon = _this select 3;
                _muzzle = _this select 4;
                _mode = _this select 5;
                _ammo = _this select 6;
                _gunner = _this select 7;
                
                _unit setVariable ["trh_hasExtraIntel", true, true];
                _hour = date select 3;
                _min = date select 4;
                _minStr = "";
                if (_min < 10) then { _minStr = format ["0%1", _min]; } else { _minStr = format ["%1", _min]; };
                if (_mode == "FullAuto") then {
                    _unit setVariable ["trh_extraIntel", format ["Also, somebody was firing an autorifle nearby, at %1:%2", _hour, _minStr], true];
                } else {
                    _unit setVariable ["trh_extraIntel", format ["Also, I heard shots fired nearby, at %1:%2", _hour, _minStr], true];
                }
            }];
            
            if (trh_cfg_debugLevel > 0) then {
                _mrk = createMarker [format ["trh_civ_%2_%1", _forEachIndex, _i], _setPos];
                _mrk setMarkerType "hd_warning";
                _mrk setMarkerShape "ICON";
            };
        };
    } forEach _towns;
};