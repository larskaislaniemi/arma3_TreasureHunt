/* 
 * TRH2
 */
#include "qb\qb_init.sqf";
#include "configParams.sqf";


/* HELPER FUNCTIONS */

trh2_fnc_message = {
    _this spawn {
        params ["_layer", ["_texts", [""]], ["_size", 3], ["_color", "#FFFFFF"], ["_durations", [4]]];
        
        {
            _layer cutText [
                format ["<t size=%1 color='%2'>%3</t>", _size, _color, _x], 
                "PLAIN DOWN", 0.5, true, true
            ];
            sleep (_durations select _forEachIndex);
            _layer cutFadeOut 0.2;
        } forEach _texts;
    };
};

trh2_fnc_alert = {
    _this spawn {
        params ["_layer", ["_texts", [""]], ["_size", 3], ["_color", "#FF0000"], ["_durations", [5]]];
        
        {
            _layer cutText [
                format ["<t size=%1 color='%2'>%3</t>", _size, _color, _x], 
                "PLAIN", 0.5, true, true
            ];
            sleep (_durations select _forEachIndex);
            _layer cutFadeOut 0.2;
        } forEach _texts;
    };
};


trh2_fnc_pubVarAllCli = {
    /* This function effectively does the same as publicVariable, except that
       1) Unlike publicVariable, this will trigger publicVariableEventHandler on 
          server, even if called from server (useful for player hosted sessions)
    */
    _var = _this select 0;
    
    publicVariable _var;
    
    if (isServer and hasInterface) then {
        (owner player) publicVariableClient _var;
    };
    //{
    //    (owner _x) publicVariableClient _var;
    //} forEach allPlayers;
}; 

trh2_fnc_playersInGame = {
    _ret = [];
    
    if (trh2_status_started) then {
        {
            if ((alive _x) and (_x getVariable "trh2_player_inGame") and !(_x getVariable "trh2_player_isSafe") and !(_x getVariable "trh2_player_dead")) then {
                _ret pushBack _x;
            };
        } forEach allPlayers;
    };
    
    _ret
};

trh2_fnc_groupsInGame = { 
    _ret = [];
    
    {
        if ({ alive _x and !(_x getVariable ["trh2_player_dead", true]) } count units _x > 0) then { 
            _ret pushBackUnique _x;
        };
    } forEach allGroups;
    
    _ret

}; 


/* Function to generate intel info */
trh2_fnc_generateIntel = {
    trh2_status_srv_generateIntel = true;
    trh2_intelPos = [];
    trh2_intelUncertainty = [];
    trh2_nIntelPos = trh2_cfg_nDistinctIntelInfo;
    if (trh2_cfg_debug > 2) then { systemchat format ["generateIntel: treasure pos is %1", getPos trh2_treasure]; };
    
    for "_i" from 1 to trh2_nIntelPos do {
        _uncert = (random trh2_cfg_intelInfoRandomUncertainty) + trh2_cfg_intelInfoMinimumUncertainty;
        _pos = [trh2_treasure, _uncert] call qb_fnc_getPosNearObject;
        trh2_intelPos pushBack _pos;
        trh2_intelUncertainty pushBack _uncert;
    };
    
    ["trh2_intelPos"] call trh2_fnc_pubVarAllCli;
    ["trh2_intelUncertainty"] call trh2_fnc_pubVarAllCli;
    ["trh2_nIntelPos"] call trh2_fnc_pubVarAllCli;
    trh2_status_srv_generateIntel = false;
};    

/* Function to create the treasure */
trh2_fnc_createTreasure = {
    trh2_status_srv_createTreasure = true;
    _treasureArray = selectRandom trh2_cfg_treasurePool;
    _treasureClass = _treasureArray select 0;
    _treasureName = _treasureArray select 1;
    _treasureDescription = _treasureArray select 2;
    
    trh2_cfg_treasureItemInfo = _treasureArray;
    trh2_cfg_treasureItemClass = _treasureClass;
    trh2_cfg_treasureItemName = _treasureName;
    trh2_cfg_treasureItemDescription = _treasureDescription;
    publicVariable "trh2_cfg_treasureItemClass";
    publicVariable "trh2_cfg_treasureItemName";
    publicVariable "trh2_cfg_treasureItemDescription";
    
    _buildingPosFound = false;
    
    trh2_treasure = createVehicle [trh2_cfg_treasureItemClass, [0,0,0], [], 2, "CAN_COLLIDE"];
    trh2_treasure setVariable ["BIS_enableRandomization", false, true];
    ["trh2_treasure"] call trh2_fnc_pubVarAllCli;
    _buildingPos = [0,0,0];
    
    while { !_buildingPosFound } do {
        _pos = ["trh2_mrk_taor", trh2_cfg_treasureRadius] call qb_fnc_getPosNearMarker;

        _building = nearestBuilding _pos;
        
        _buildingPositions = [_building] call BIS_fnc_buildingPositions;
        
        if (count _buildingPositions <= 0) then {
            _buildingPosFound = false;
        } else {
            _buildingPos = selectRandom _buildingPositions;
            if (_buildingPos select 2 >= 0.0) then {
                _buildingPosFound = true;
            } else {
                // building pos in underground
                _buildingPosFound = false;
            };
        };
    };
    
    trh2_treasure setPos _buildingPos;
    if (trh2_cfg_debug > 2) then { systemchat format ["createTreasure: pos is %1/%2", getPos trh2_treasure, _buildingPos]; };
    [trh2_treasure, trh2_cfg_treasureItemName, { 
        trh2_event_treasurePickedUp = true; ["trh2_event_treasurePickedUp"] call trh2_fnc_pubVarAllCli;
    }] call qb_fnc_pickObjInit;
    if (trh2_cfg_debug > 2) then { systemchat format ["createTreasure: pos is %1", getPos trh2_treasure]; };
    
    trh2_treasurePlaced = true;
    ["trh2_treasurePlaced"] call trh2_fnc_pubVarAllCli;
    trh2_status_srv_createTreasure = false;
};

/* Function to create the cars */
/*  Create cars. Weighted by city size. */
trh2_fnc_createCars = {
    trh2_status_srv_createCars = true;
    trh2_createdCars = [];
    
    _pos = getMarkerPos "trh2_mrk_taor";
    _radius = trh2_cfg_carsRadius;
    _nTotalCars = trh2_cfg_numOfCars;
    _towns = nearestLocations [_pos, ["NameVillage","NameCity","NameCityCapital"], _radius];
    _sizes = [];
    _areas = [];
    _nCars = [];
    
    if (trh2_cfg_debug > 2) then { systemchat format ["createCars: Found %1 towns", count _towns]; };
    
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
        if (trh2_cfg_debug > 2) then { systemchat format ["createCars: Town %1", _forEachIndex]; };
        _town = _x;
        _townRange = _sizes select _forEachIndex;
        for "_i" from 1 to (_nCars select _forEachIndex) do {
            _foundRoad = false;
            _finalPos = [0,0,0];
            while { !_foundRoad } do {
                _setPos = [position _town, _townRange * trh2_cfg_carsOutOfCityCoef] call qb_fnc_getPosNearPos;
                _roadSegs = [_setPos select 0, _setPos select 1] nearRoads 50;
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
                    _vehType = selectRandom trh2_cfg_carPool;
                    _finalPos = getPos _roadSeg;
                    _veh = createVehicle [_vehType, _finalPos, [], 3, "NONE"];
                    _veh setVariable ["BIS_enableRandomization", false, true];
                    _veh setDir _direction;
                    trh2_createdCars pushBack _veh;
                };
            };
        };
    } forEach _towns;
    
    if (trh2_cfg_debug > 0) then { systemchat "Generating cars done"; };
    trh2_status_srv_createCars = false;
};


/* Create intel items, civilians. Weighted by city size. */
trh2_fnc_createCivsAndItems = {
    trh2_status_srv_createCivsAndItems = true;
    trh2_createdCivs = [];
    trh2_createdItems = [];
    
    _pos = getMarkerPos "trh2_mrk_taor";
    _radius = trh2_cfg_intelItemRadius;
    _nTotalCivs = trh2_cfg_numOfCivs;
    _nTotalIntelItems = trh2_cfg_numOfIntelItems;
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
            _setPos = [position _town, _townRange * 1.5] call qb_fnc_getPosNearPos;
            _building = nearestBuilding _setPos;
            _buildingPos = selectRandom ([_building] call BIS_fnc_buildingPositions);
            if (isNil "_buildingPos") then {
                _buildingPos = _setPos;
            };
            _veh = createVehicle ["Land_PCSet_01_screen_F", _buildingPos, [], 0, "NONE"];
            _veh2 = createVehicle ["Land_PCSet_01_case_F", [(_buildingPos select 0)+0.4, _buildingPos select 1, _buildingPos select 2], [], 0, "NONE"];
            _veh3 = createVehicle ["Land_PCSet_01_keyboard_F", [_buildingPos select 0, (_buildingPos select 1)+0.3, _buildingPos select 2], [], 0, "NONE"];
            _veh setVariable ["trh2_intelInfoNumber", floor (random trh2_nIntelPos), true];
            trh2_createdItems pushBack _veh; trh2_createdItems pushBack _veh2; trh2_createdItems pushBack _veh3;
            [_veh, ["Find and delete intel", {
                _target = _this select 0;
                _caller = _this select 1;
                _actId = _this select 2;
                
                _ns = group _caller;
                if (isNull _ns) exitWith { false };
                _ni = _target getVariable "trh2_intelInfoNumber";
                
                if (_ni < 0) then {
                    [_caller, format ["Found a computer here but looks like the hard drive is formatted..."]] remoteExec ["groupChat", units _ns, false];
                } else {
                    if ((_ns getVariable "trh2_gotIntel") find _ni < 0) then {
                        _prevN = _ns getVariable ["trh2_nGotIntel", 0];
                        _prevI = _ns getVariable ["trh2_gotIntel", []];
                        
                        _ns setVariable ["trh2_nGotIntel", _prevN + 1, true];
                        _ns setVariable ["trh2_gotIntel", _prevI + [_ni], true];
                        
                        _target setVariable ["trh2_intelInfoNumber", -1, true];
                        
                        [_caller, format ["Found a computer with something interesting in it!"]] remoteExec ["groupChat", units _ns, false];
                    } else {
                        [_caller, format ["Found a computer but there's nothing here we didn't already know"]] remoteExec ["groupChat", units _ns, false];
                    };
                };
            }, [], 5, true, true, "", "true", 6, false, ""]] remoteExec ["addAction", 0, true];
        };
    } forEach _towns;
    
    /* Create civilians */
    {
        _town = _x;
        _townRange = _sizes select _forEachIndex;
        for "_i" from 1 to (_nCivs select _forEachIndex) do {
            _setPos = [position _town, _townRange * 1.5] call qb_fnc_getPosNearPos;
            
            _inHouse = false;
            if (random 1 < trh2_cfg_civPercInside) then {
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
            _unit = _grp createUnit [selectRandom trh2_cfg_civPool, _setPos, [], 0, "NONE"];
            trh2_createdCivs pushBack _unit;
            
            if (!_inHouse) then {
                [[_grp], _setPos, _townRange, 4] call qb_fnc_addPatrolWaypoints;
            };
            
            _unit setVariable ["trh2_intelInfoNumber", floor (random trh2_nIntelPos), true];
            [_unit, ["Ask about the treasure", {
                _target = _this select 0;
                _caller = _this select 1;
                _actId = _this select 2;
                
                if (!alive _target) then {
                    [_caller, format ["You guys ever try to talk to dead people?"]] remoteExec ["groupChat", units _ns, false];
                } else {
                    _ns = group _caller;
                    if (isNull _ns) exitWith { false };
                    _ni = _target getVariable "trh2_intelInfoNumber";
                    
                    if ((_ns getVariable "trh2_gotIntel") find _ni < 0) then {
                        _prevN = _ns getVariable ["trh2_nGotIntel", 0];
                        _prevI = _ns getVariable ["trh2_gotIntel", []];
                        
                        _ns setVariable ["trh2_nGotIntel", _prevN + 1, true];
                        _ns setVariable ["trh2_gotIntel", _prevI + [_ni], true];
                        
                        [_caller, format ["Got something from this one civ here!"]] remoteExec ["groupChat", units _ns, false];
                    } else {
                        [_caller, format ["These civs are just plain useless. Nothing new to tell us."]] remoteExec ["groupChat", units _ns, false];
                    };
                    
                    if (_target getVariable ["trh2_hasExtraIntel", false]) then {
                        [_caller, format ["Also, this civ told me that %1", _target getVariable "trh2_extraIntel"]] remoteExec ["groupChat", units _ns, false];
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
                
                _unit setVariable ["trh2_hasExtraIntel", true, true];
                _hour = date select 3;
                _min = date select 4;
                _minStr = "";
                if (_min < 10) then { _minStr = format ["0%1", _min]; } else { _minStr = format ["%1", _min]; };
                if (_mode == "FullAuto") then {
                    _unit setVariable ["trh2_extraIntel", format ["somebody was firing an autorifle nearby, at %1:%2.", _hour, _minStr], true];
                } else {
                    _unit setVariable ["trh2_extraIntel", format ["he heard shots fired nearby, at %1:%2", _hour, _minStr], true];
                }
            }];
        };
    } forEach _towns;
    
    if (trh2_cfg_debug > 0) then { systemchat "Generating civs/items done"; };
    trh2_status_srv_createCivsAndItems = false;
};



/* 
   ---------------------
   ---- SERVER SIDE ---- 
   ---------------------
*/

if (isServer) then {
    trh2_status_srv_generateIntel = false;
    trh2_status_srv_createTreasure = false;
    trh2_status_srv_createCars = false;
    trh2_status_srv_createCivsAndItems = false;
    trh2_status_srv_gameRestart = false;
    trh2_status_srv_EH_treasurePickedUp = false;
    trh2_status_srv_broadcastWinners = false;
    trh2_status_srv_EH_treasureInExtraction = false;

    trh2_cmd_restart = true; ["trh2_cmd_restart"] call trh2_fnc_pubVarAllCli;
    trh2_status_started = false; ["trh2_status_started"] call trh2_fnc_pubVarAllCli;
    trh2_status_finished = false; ["trh2_status_finished"] call trh2_fnc_pubVarAllCli;
    trh2_status_treasureFound = false; ["trh2_status_treasureFound"] call trh2_fnc_pubVarAllCli;
    trh2_status_startTime = time + trh2_cfg_waitStartTime; ["trh2_status_startTime"] call trh2_fnc_pubVarAllCli;
    trh2_treasurePlaced = false; ["trh2_treasurePlaced"] call trh2_fnc_pubVarAllCli;
    trh2_treasure = objNull; ["trh2_treasure"] call trh2_fnc_pubVarAllCli;
    trh2_extractionPointSet = false; ["trh2_extractionPointSet"] call trh2_fnc_pubVarAllCli;
    trh2_extractionPoint = [0,0,0]; ["trh2_extractionPoint"] call trh2_fnc_pubVarAllCli;
    trh2_status_finished_reason = ""; ["trh2_status_finished_reason"] call trh2_fnc_pubVarAllCli;
    trh2_bc_gameover = false; ["trh2_bc_gameover"] call trh2_fnc_pubVarAllCli;
    
    ["Initialize", [true, trh2_cfg_maxPlayersPerGroup]] call BIS_fnc_dynamicGroups;    
    
    /* DEBUG INFO */
    
    [] spawn {
        if (trh2_cfg_debug > 0) then {
            while { true } do {
                sleep 5;
                //systemchat format ["Players safe: %1", {_x getVariable "trh2_player_isSafe"} count allPlayers];
            };
        };
    };
    
    
    /* GAME RESTART */
    
    if (trh2_cfg_debug > 0) then { systemchat "Spawning: Game restart" };
    [] spawn {
        trh2_createdCars = []; trh2_createdCivs = []; trh2_createdItems = [];
        while { true } do {
            waitUntil { trh2_cmd_restart };
            trh2_status_srv_gameRestart = true;
            ["trh2_cmd_restart"] call trh2_fnc_pubVarAllCli;
            trh2_status_startTime = time + trh2_cfg_waitStartTime; ["trh2_status_startTime"] call trh2_fnc_pubVarAllCli;
            trh2_status_finished = true; ["trh2_status_finished"] call trh2_fnc_pubVarAllCli;
            trh2_status_started = false; ["trh2_status_started"] call trh2_fnc_pubVarAllCli;
            trh2_status_treasureFound = false; ["trh2_status_treasureFound"] call trh2_fnc_pubVarAllCli;
            trh2_status_finished_reason = ""; ["trh2_status_finished_reason"] call trh2_fnc_pubVarAllCli;
            trh2_bc_gameover = false; ["trh2_status_finished_reason"] call trh2_fnc_pubVarAllCli;

            {
                _x setVariable ["trh2_player_inGame", false, true];
            } forEach allPlayers;
            
            { deleteVehicle _x; } forEach trh2_createdCars;
            { deleteVehicle _x; } forEach trh2_createdCivs;
            { deleteVehicle _x; } forEach trh2_createdItems;
            trh2_createdCars = []; trh2_createdCivs = []; trh2_createdItems = [];
            
            if (trh2_treasurePlaced) then {
                [trh2_treasure] call qb_fnc_pickObjForceDrop;
                ["disable", [trh2_treasure]] call qb_fnc_addBeacon;
                deleteVehicle trh2_treasure;
                trh2_treasurePlaced = false; ["trh2_treasurePlaced"] call trh2_fnc_pubVarAllCli;
            };
            
            if (trh2_extractionPointSet) then {
                trh2_extractionPointSet = false;
                ["trh2_extractionPointSet"] call trh2_fnc_pubVarAllCli;
                deleteMarker trh2_extractionPointMarker;
                deleteMarker trh2_extractionPointMarkerHelper;
            };
            
            
            if (trh2_cfg_debug > 1) then { systemchat "Restart: Cleared old stuff" };
            
            [] spawn trh2_fnc_createTreasure;
            waitUntil { trh2_treasurePlaced };
            if (trh2_cfg_debug > 1) then { systemchat "Restart: Treasure placed" };
            [] call trh2_fnc_generateIntel;
            if (trh2_cfg_debug > 1) then { systemchat "Restart: Generated intel" };
            [] spawn trh2_fnc_createCars;
            [] spawn trh2_fnc_createCivsAndItems;
            
            waitUntil { time > trh2_status_startTime };
            trh2_cmd_restart = false; ["trh2_cmd_restart"] call trh2_fnc_pubVarAllCli;
            trh2_status_finished = false; ["trh2_status_finished"] call trh2_fnc_pubVarAllCli;
            trh2_status_started = true; ["trh2_status_started"] call trh2_fnc_pubVarAllCli;
            if (trh2_cfg_debug > 1) then { systemchat "Restart: Game started" };
            trh2_status_srv_gameRestart = false;
        };
    };
    
    
    /* FORCE PLAYERS INSIDE SAFE ZONE if game not started */
    [] spawn {
        while { true } do {
            waitUntil { !trh2_status_started };
            {
                if (_x distance2D (getMarkerPos "trh2_mrk_safezone") > trh2_cfg_safeZoneRadius) then {
                    _x setPos (["trh2_mrk_safezone", trh2_cfg_safeZoneSpawnRadius] call qb_fnc_getPosNearMarker);
                };
            } forEach allPlayers;
        };
    };
    
        
    /* TREASURE FOUND/PICKED/DROPPED VARIABLE AND BEACON */
    
    if (trh2_cfg_debug > 0) then { systemchat "Spawning: Treasure pick up EH" };
    "trh2_event_treasurePickedUp" addPublicVariableEventHandler {
        trh2_status_srv_EH_treasurePickedUp = true;
        _value = _this select 1;
        
        if (_value and !trh2_status_treasureFound) then {
            trh2_event_treasurePickedUp = false;
            trh2_status_treasureFound = true; ["trh2_status_treasureFound"] call trh2_fnc_pubVarAllCli;
            ["enable", [trh2_treasure, 100, 15, "mrk_beacon", qb_fnc_pickObjGetPos]] call qb_fnc_addBeacon;
            if (!trh2_status_finished and !trh2_bc_gameover) then {
                ["Default",["Beacon activated", "Treasure has been moved, beacon activated!"]] remoteExec ["bis_fnc_showNotification", (call trh2_fnc_playersInGame), false];
            };
        };
        trh2_status_srv_EH_treasurePickedUp = false;
    };

    /* BROADCAST WINNERS */
    
    [] spawn {
        while { true } do {
            waitUntil { !trh2_cmd_restart and trh2_status_finished and trh2_status_started and trh2_status_finished_reason != "" and !trh2_bc_gameover };
            trh2_status_srv_broadcastWinners = true;
            _winners = [];
            _winnerNames = [];
            trh2_bc_gameover = true; 
            trh2_bc_result = trh2_status_finished_reason;
            
            if (trh2_status_finished_reason == "alldead") then {
                _winners = [];
                _winnerNames = [];
            };
            if (trh2_status_finished_reason == "onegroupleft") then {
                _winners = units trh2_status_finished_details;
                _winnerNames = ""; { _winnerNames = _winnerNames + "  " + (name _x); } forEach _winners;
            };
            if (trh2_status_finished_reason == "extraction") then {
                _winners = units trh2_status_finished_details;
                _winnerNames = ""; { _winnerNames = _winnerNames + "  " + (name _x); } forEach _winners;
            };
            
            trh2_bc_winners = _winners;
            trh2_bc_winnerNames = _winnerNames;
            
            ["trh2_bc_result"] call trh2_fnc_pubVarAllCli; 
            ["trh2_bc_winners"] call trh2_fnc_pubVarAllCli; 
            ["trh2_bc_winnerNames"] call trh2_fnc_pubVarAllCli; 
            ["trh2_bc_gameover"] call trh2_fnc_pubVarAllCli; 
            
            sleep 15;
            trh2_cmd_restart = true; ["trh2_cmd_restart"] call trh2_fnc_pubVarAllCli;
            trh2_status_srv_broadcastWinners = false;
        };
    };
    
    
    /* TREASURE FOUND BUT EVERYONE DIED AFTER THAT */
    
    if (trh2_cfg_debug > 0) then { systemchat "Spawning: All dead" };
    [] spawn {
        while { true } do {
            waitUntil { trh2_status_started and trh2_status_treasureFound and !trh2_status_srv_gameRestart and !trh2_status_srv_broadcastWinners };
            trh2_status_srv_treasureFoundEveryoneDied = true;
            if (count (call trh2_fnc_playersInGame) < 1 and !trh2_status_finished) then {
                // WE HAVE A WINNER (no one!)
                trh2_status_finished_reason = "alldead";
                trh2_status_finished_details = 0;
                trh2_status_finished = true;
                ["trh2_status_finished"] call trh2_fnc_pubVarAllCli;
            };
            trh2_status_srv_treasureFoundEveryoneDied = false;
            sleep 3;
        };
    };
    
    
    /* TREASURE FOUND, ONLY ONE GROUP LEFT? */
    
    if (trh2_cfg_debug > 0) then { systemchat "Spawning: Only one group left win" };
    [] spawn {
        while { true } do {
            waitUntil { trh2_status_started and trh2_status_treasureFound and !trh2_status_srv_gameRestart and !trh2_status_srv_broadcastWinners };
            trh2_status_srv_treasureFoundOneGroupLeft = true;
            _grps = call trh2_fnc_groupsInGame;
            if (count _grps == 1) then {
                if ((trh2_treasure getVariable ["pickObj_whoHas", objNull]) in (units (_grps select 0))) then {
                    // WE HAVE A WINNER
                    trh2_status_finished_reason = "onegroupleft";
                    trh2_status_finished_details = _grps select 0;
                    trh2_status_finished = true;
                    ["trh2_status_finished"] call trh2_fnc_pubVarAllCli;
                };
            };
            trh2_status_srv_treasureFoundOneGroupLeft = false;
            sleep 3;
        };
    };
    
    
    /* TREASURE IN EXTRACTION AREA? */
    
    if (trh2_cfg_debug > 0) then { systemchat "Spawning: Treasure in extraction EH" };
    "trh2_event_manInExtractionArea" addPublicVariableEventHandler {
        trh2_status_srv_EH_treasureInExtraction = true;
        if (trh2_status_started and trh2_status_treasureFound and trh2_extractionPointSet and !trh2_status_srv_gameRestart and !trh2_status_srv_broadcastWinners) then {
            {
                if (
                    (_x distance trh2_extractionPoint < trh2_cfg_extractionRadius) and 
                    (trh2_treasure getVariable ["pickObj_pickedUp", false]) and 
                    (trh2_treasure getVariable ["pickObj_whoHas", objNull] == _x)
                ) then {
                    // WE HAVE A WINNER
                    trh2_status_finished_reason = "extraction";
                    trh2_status_finished_details = group _x;
                    trh2_status_finished = true;
                    ["trh2_status_finished"] call trh2_fnc_pubVarAllCli;
                };
            } forEach allPlayers;
        };
        trh2_status_srv_EH_treasureInExtraction = false;
    };
    
    
    /* EXTRACTION POINT MARKER */
    
    if (trh2_cfg_debug > 0) then { systemchat "Spawning: Draw extraction point" };
    [] spawn {
        while { true } do {
            waitUntil { trh2_status_started and !trh2_extractionPointSet };
            waitUntil { trh2_status_treasureFound or trh2_status_finished };
            trh_status_srv_extractionPointMarker = true;

            if (trh2_status_treasureFound) then {
                trh2_extractionPointMarkerName = selectRandom trh2_cfg_extractionPointMarkers;
                trh2_extractionPoint = getMarkerPos trh2_extractionPointMarkerName; ["trh2_extractionPoint"] call trh2_fnc_pubVarAllCli;
                trh2_extractionPointSet = true; ["trh2_extractionPointSet"] call trh2_fnc_pubVarAllCli;
                
                trh2_extractionPointMarker = createMarker ["trh2_extract_final", trh2_extractionPoint];
                trh2_extractionPointMarker setMarkerType "hd_destroy";
                trh2_extractionPointMarker setMarkerShape "ICON";
                trh2_extractionPointMarker setMarkerColor "ColorGreen";
                
                trh2_extractionPointMarkerHelper = createMarker ["trh2_extract_final_helper", trh2_extractionPoint];
                trh2_extractionPointMarkerHelper setMarkerShape "ELLIPSE";
                trh2_extractionPointMarkerHelper setMarkerBrush "Border";
                trh2_extractionPointMarkerHelper setMarkerSize [trh2_cfg_extractionRadius, trh2_cfg_extractionRadius];
                trh2_extractionPointMarkerHelper setMarkerColor "ColorGreen";

                sleep 3;
                if (!trh2_status_finished and !trh2_bc_gameover) then {
                    ["Default",["Extraction point", "Treasure extraction point marked on the map"]] remoteExec ["bis_fnc_showNotification", (call trh2_fnc_playersInGame), false];
                };
            };
            trh_status_srv_extractionPointMarker = false;
            sleep 5;
        };
    };

    
    /* REMOVE ANY USER MARKERS ON GLOBAL AND SIDE CHAT MAPS */
    
    if (trh2_cfg_debug > 0) then { systemchat "Spawning: Prevent global markers" };
    [] spawn {
        private ["_allMarkers"];
        while { true } do {
            {
                private ["_mrkType"];
                _mrkType = toArray _x;
                _mrkType resize 15;
                if (toString _mrkType == "_USER_DEFINED #") then {
                    private ["_strArr"];
                    _strArr = _x splitString "/";
                    _channelId = parseNumber (_strArr select 2);
                    if (_channelId != 3) then {
                        deleteMarker _x;
                    };
                };
            } forEach allMapMarkers;
            sleep 1;
        };
    };

    trh2_server_initialized = true;
    publicVariable "trh2_server_initialized";
};




/* 
   ---------------------
   ---- CLIENT SIDE ---- 
   ---------------------
*/

if (hasInterface) then {
    EGSpectator_qbmod = compile preprocessFileLineNumbers "EGSpect_mod\EGSpectator.sqf";

    waitUntil { !isNull player };
    player allowDamage false;
    player setVariable ["trh2_player_isSafe", true, true];
    player setVariable ["trh2_player_score", 0, true];
    player setVariable ["trh2_player_dead", false, true];
    player setVariable ["trh2_player_inGame", false, true];
    player setVariable ["trh2_player_justJoined", true, true];

    ["InitializePlayer", [player, true]] call BIS_fnc_dynamicGroups;
    ["SetPrivateState", [group player, true]] remoteExec ["BIS_fnc_dynamicGroups", 2, false]; // TODO, is grou pplayer valid here
    
    setViewDistance trh2_cfg_viewDistance;

    waitUntil { !isNil "trh2_server_initialized" };

    
    /* SAFE ZONE */
    
    [] spawn {
        while { true } do {
            waitUntil { player distance (getMarkerPos "trh2_mrk_safezone") > trh2_cfg_safeZoneRadius };
            player setVariable ["trh2_player_isSafe", false, true];
            
            waitUntil { player distance (getMarkerPos "trh2_mrk_safezone") <= trh2_cfg_safeZoneRadius };
            player setVariable ["trh2_player_isSafe", true, true];
        };
    };
    
    [] spawn {
        _isSafe = true;
        while { true } do {
            if ((player getVariable ["trh2_player_isSafe", true]) or (player getVariable ["trh2_player_dead", false])) then {
                player allowDamage false;
                if (!_isSafe) then {
                    _isSafe = true;
                };
            } else {
                player allowDamage true;
                if (_isSafe) then {
                    if (trh2_status_started) then {
                        ["vulnerable", ["You are now vulnerable"]] call trh2_fnc_alert;
                    };
                    _isSafe = false;
                };
            };
        };
    };
    
    
    /* SHOW TIME UNTIL GAME STARTS */
    
    [] spawn {
        while { true } do {
            if (!trh2_status_started and trh2_status_finished) then {
                if (trh2_status_startTime > time) then {
                    systemchat format ["Round starts in %1 seconds", round (trh2_status_startTime - time)];
                } else {
                    systemchat format ["Round will start soon, still generating objects..."];
                };
            };
            sleep 5;
        };
    };
    
    
    /* SHOW INFO IF TREASURE FOUND AND NOT YET IN GAME */
    
    [] spawn {
        while { true } do {
            waitUntil { !(player getVariable "trh2_player_inGame") and trh2_status_treasureFound and !trh2_cmd_restart };
            hint parseText "<t size=3 color='#FF0000'>Treasure has already been found. Wait for next round.</t>";
            sleep 30;
        };
    };
    
    
    /* GAME STARTED */
    
    "trh2_cmd_restart" addPublicVariableEventHandler {
        hint parseText "<t size=3 color='#0000FF'>New round starts ...</t>";
        
    };
    
    "trh2_status_started" addPublicVariableEventHandler {
        _value = _this select 1;
        if (_value) then {
            _ns = group player;
            _ns setVariable ["trh2_nGotIntel", 0, true];
            _ns setVariable ["trh2_gotIntel", [], true];
            
            ["gamestatus", ["Game started. You can HALO jump in."]] call trh2_fnc_alert;
            
            player setVariable ["trh2_player_justJoined", false, true];
        };
    };


    /* GAME FINISHED */
    
    "trh2_status_finished" addPublicVariableEventHandler {
        _value = _this select 1;
        if (_value and !trh2_cmd_restart) then {
            _ns = group player;
            _ns setVariable ["trh2_nGotIntel", 0, true];
            _ns setVariable ["trh2_gotIntel", [], true];
            
            if (!(player getVariable "trh2_player_justJoined")) then {
                ["gameover", ["Game over"]] call trh2_fnc_alert;
            };
            
            player setVariable ["trh2_player_dead", false, true];
        };
        
    };
    
    
    /* RESULTS BROADCASTED */
    "trh2_bc_gameover" addPublicVariableEventHandler {
        _value = _this select 1;
        _text1 = "";
        _text2 = "";
        
        if (!_value) exitWith { false };
        
        _iwin = false;
        _text1 = "You lost.";
        if (player in trh2_bc_winners) then {
            _iwin = true;
            _text1 = "You won.";
        };

        if (trh2_bc_result == "alldead") then {
            //["Default",["All dead", "Everyone died"]] call bis_fnc_showNotification;
            _text2 = "Everyone died.";
        };
        
        if (trh2_bc_result == "onegroupleft") then {
            if (_iwin) then { _text2 = "You are the only group left alive"; ["Default",["You win", "You are the only group left alive"]] call bis_fnc_showNotification; }  
            else            { _text2 = format ["Winners are: %1", trh2_bc_winnerNames]; ["Default",["You lose", format ["Winners are: %1", trh2_bc_winnerNames]]] call bis_fnc_showNotification; };
        };
        
        if (trh2_bc_result == "extraction") then {
            if (_iwin) then { _text2 = "Treasure succesfully retrieved!"; ["Default",["You win", "Congratulations"]] call bis_fnc_showNotification; }
            else            { _text2 = format ["Winners are: %1", trh2_bc_winnerNames]; ["Default",["You lose", format ["Winners are: %1", trh2_bc_winnerNames]]] call bis_fnc_showNotification; };
        };

        ["gameover", ["Game over", _text1, _text2], 4, "#FF0000", [3,3,8]] call trh2_fnc_message;
        
    };

    
    /* WINNER TRIGGER */
    
    [] spawn {
        while { true } do {
            waitUntil { trh2_extractionPointSet or trh2_status_finished };
            waitUntil { (player distance trh2_extractionPoint < trh2_cfg_extractionRadius) or trh2_status_finished };
            if (!trh2_status_finished and !trh2_cmd_restart) then {
                trh2_event_manInExtractionArea = true; publicVariableServer "trh2_event_manInExtractionArea";
            };
            sleep 5;
        };
    };
    
    
    /* GROUP MEMBER MARKERS ON MAP */

    [] spawn {
        _prevMembers = [];
        _groupChanged = true;
        _mrkrs = [];
        while { true } do {
            if (_groupChanged) then {
                {
                    deleteMarkerLocal (_x select 1);
                } forEach _mrkrs;
                _mrkrs = [];
                
                _grp = group player;
                if (isNull _grp) then {
                    _prevMembers = [player];
                } else {
                    _prevMembers = units _grp;
                };

                {
                    _name = format ["%1", name _x];
                    _mrk = createMarkerLocal [format ["mrk_%1", _name], _x];
                    _mrk setMarkerColorLocal "ColorGreen";
                    _mrk setMarkerTextLocal _name;
                    _mrk setMarkerTypeLocal "mil_dot";
                    _mrkrs pushBack [_x, _mrk];
                } forEach _prevMembers;
                
                _groupChanged = false;        
            } else {
                _grp = group player;
                _curMembers = [];
                if (isNull _grp) then {
                    _curMembers = [player];
                } else {
                    _curMembers = units _grp;
                };
                if (_curMembers isEqualTo _prevMembers) then {
                    {   
                        _color = "ColorGreen";
                        if ((_x select 0) getVariable ["trh2_player_dead", false]) then {
                            _color = "ColorRed";
                        };
                        _pos = getPos (_x select 0);
                        (_x select 1) setMarkerPosLocal [_pos select 0, _pos select 1];
                        (_x select 1) setMarkerColorLocal _color;
                    } forEach _mrkrs;
                } else {
                    _groupChanged = true;
                    _prevMembers = [];
                    {
                        _prevMembers pushBack _x;
                    } forEach _curMembers;
                };
            };
            sleep 1;
        };
        {
            deleteMarkerLocal (_x select 1);
        } forEach _mrkrs;
        _mrkrs = [];
    };
    
    
    /* SET/RESET RATINGS */

    [] spawn {
        while { true } do {
            waitUntil { rating player != (player getVariable "trh2_player_score") };
            player addRating (-1.0)*(rating player);
            player addRating (player getVariable "trh2_player_score");
        };
    };
    
    
    /* INTEL RELATED */

    /* Reset gathered intel to zero at start */
    (group player) setVariable ["trh2_nGotIntel", 0, true];
    (group player) setVariable ["trh2_gotIntel", [], true];

    /* Refill player's pockets regularly with group's intel. Thus, if incapacited player is looted of intel,
       and then revived, his pockets won't be empty next time somebody tries to loot him. */
    [] spawn {
        while { (lifeState player == "INJURED" or lifeState player == "HEALTHY") and !(player getVariable ["trh2_player_dead", false]) } do {
            player setVariable ["trh2_intelPocketsEmptied", false, true];
            sleep 5;
        };
    };
    
    /* Add action for others to dig my intel once I am dead/unconc. */
    [player, ["Dig for intel", {
        _target = _this select 0;
        _caller = _this select 1;
        _actId = _this select 2;
        
        _ns = group _target;
        if (isNull _ns) exitWith { false };
        
        _nsme = group _caller;
        if (isNull _nsme) exitwith { false };
        
        if (_ns == _nsme) then {
            //if (lifeState _target == "INCAPACITATED") then {
            //    [_caller, format ["Guys, I emptied %1's pockets of intel but didn't bother to revive him. Haha.", name _target]] remoteExec ["groupChat", units _nsme, false];
            //} else {
            [_caller, format ["Emptied %1's pockets of all intel.", name _target]] remoteExec ["groupChat", units _nsme, false];
            //};
            _target setVariable ["trh2_intelPocketsEmptied", true, true];
        } else {
            if (_target getVariable ["trh2_intelPocketsEmptied", false]) then {
                [_caller, format ["Found a dead enemy soldier but his pockets are already emptied."]] remoteExec ["groupChat", units _nsme, false];
            } else {
                _counti = _ns getVariable ["trh2_nGotIntel", 0];
                if (_counti > 0) then {
                    _oldIntelCount = _nsme getVariable ["trh2_nGotIntel", 0];
                    for "_i" from 0 to (_counti-1) do {
                        _newarr = [] + (_nsme getVariable ["trh2_gotIntel", []]);
                        _newarr pushBackUnique ((_ns getVariable ["trh2_gotIntel", []]) select _i);
                        _nsme setVariable ["trh2_gotIntel", _newarr, true];
                        _nsme setVariable ["trh2_nGotIntel", count _newarr, true];
                    };
                    _newIntelCount = _nsme getVariable ["trh2_nGotIntel", 0];
                    if (_newIntelCount > _oldIntelCount) then {
                        [_caller, format ["Found a dead enemy with %1 pieces of intel with him. Sweet.", _newIntelCount - _oldIntelCount]] remoteExec ["groupChat", units _nsme, false];
                    } else {
                        [_caller, format ["Found a dead enemy soldier but he had nothing we didn't already know."]] remoteExec ["groupChat", units _nsme, false];
                    };
                } else {
                    [_caller, format ["Found a dead enemy but he seems to got no intel with him."]] remoteExec ["groupChat", units _nsme, false];
                };
                _target setVariable ["trh2_intelPocketsEmptied", true, true];
            };
        };
    }, [], 5, true, true, "", "(vehicle _this == _this) AND (_target != _this) AND (_target getVariable [""trh2_player_dead"", false])", 5, false, ""]] remoteExec ["addAction", 0, true];

    
    /* INVENTORY MENU FOR DEAD PLAYERS */

    [player, ["Loot", {
        _target = _this select 0;
        _caller = _this select 1;
        _actId = _this select 2;
        
        _gwh = createVehicle ["groundWeaponHolder", position _target, [], 0, "CAN_COLLIDE"];
        
        { _gwh addWeaponCargoGlobal [_x, 1]; } forEach (weapons _target);
        { _gwh addMagazineCargoGlobal [_x, 1]; } forEach (magazines _target);
        { _gwh addItemCargoGlobal [_x, 1]; } forEach (items _target);
        _gwh addItemCargoGlobal [backpack _target, 1];
        _gwh addItemCargoGlobal [uniform _target, 1];
        _gwh addItemCargoGlobal [vest _target, 1];
        _gwh addItemCargoGlobal [goggles _target, 1];
        _gwh addItemCargoGlobal [headgear _target, 1];
        { _gwh addItemCargoGlobal [_x, 1]; } forEach (backpackItems _target);
        { _gwh addItemCargoGlobal [_x, 1]; } forEach (assignedItems _target);
        
        [_target] remoteExec ["removeAllWeapons", _target];
        [_target] remoteExec ["removeAllItems", _target];
        [_target] remoteExec ["removeBackpack", _target];
        { [_target, _x] remoteExec ["removeMagazines", _target] } forEach magazines _target;
        [_target] remoteExec ["removeHeadgear", _target];
        [_target] remoteExec ["removeGoggles", _target];
        [_target] remoteExec ["removeVest", _target];
        [_target] remoteExec ["removeUniform", _target];
        [_target] remoteExec ["removeAllAssignedItems", _target];
    }, [], 5, true, true, "", "(vehicle _this == _this) AND (_target != _this) AND (_target getVariable [""trh2_player_dead"", false])", 5, false, ""]] remoteExec ["addAction", 0, true];
    
    
    /* REFRESH GATHERED INTEL ON MAP */
    
    [] spawn {
        _nDrawnIntel = 0;
        _lastDrawn = time;
        
        while { true } do {
            _ns = group player;
            if (!isNull _ns) then {
                waitUntil { 
                    (_nDrawnIntel != _ns getVariable ["trh2_nGotIntel", 0]) OR (time - _lastDrawn > 20)
                };
                _lastDrawn = time;
                _nOldDrawnIntel = _nDrawnIntel;
                _nDrawnIntel = _ns getVariable ["trh2_nGotIntel", 0];
                
                if (_nDrawnIntel < _nOldDrawnIntel) then {
                    for "_i" from 1 to _nOldDrawnIntel do {
                        _markerName = format ["trh2_localmrk_intel_%1", _i];
                        deleteMarkerLocal _markerName;
                    };
                };

                for "_i" from 1 to _nDrawnIntel do {
                    _markerName = format ["trh2_localmrk_intel_%1", _i];
                    _iIntel = (_ns getVariable "trh2_gotIntel") select (_i - 1);
                    _pos = trh2_intelPos select _iIntel;
                    _unc = trh2_intelUncertainty select _iIntel;
                    
                    //deleteMarkerLocal _markerName;
                    createMarkerLocal [_markerName, _pos];
                    _markerName setMarkerShapeLocal "ELLIPSE";
                    _markerName setMarkerBrushLocal "Border";
                    _markerName setMarkerSizeLocal [_unc, _unc];
                    _markerName setMarkerAlphaLocal 1.0;
                    _markerName setMarkerColorLocal "ColorRed";
                };
            } else {
                sleep 5;
            };
        };
    };
    
    
    /* PREVENT FORCE RESPAWN */
    
    /* From: https://forums.bistudio.com/forums/topic/206086-solved-prevent-player-from-force-respawn-when-incapacitated/ */
    /*player addEventHandler["Dammaged",{
        params ["_unit", "", "_damage","","_hitPoint","_source"];
        
        if (
            alive _unit && {
                _damage >= 1 && {
                    _unit getVariable ["#rev_enabled", false] && {
                        _hitPoint == "Incapacitated" && {
                            _unit getVariable ["#rev_state", 0] isEqualTo 2
                        }
                    }
                }
            }
        ) then {
            if ( vehicle _unit isEqualTo _unit ) then {
                _nul = [ _unit ] spawn { 
                    params[ "_unit" ];
                    
                    waitUntil{ !( _unit getVariable [ "#rev_actionID_respawn", -1 ] isEqualTo -1 ) };
                
                    _actionID = _unit getVariable [ "#rev_actionID_respawn", -1 ];
                    [ _unit, _actionID ] call BIS_fnc_holdActionRemove;
                    ["",false,_unit] call BIS_fnc_reviveOnForcingRespawn;
                    _unit setVariable ["#revF", false, true];
                    
                    waitUntil{ !( lifeState _unit == "Incapacitated" ) };
                    _unit setVariable [ "#rev_actionID_respawn", -1 ];
                }; 
            };
        };
    }];*/

        
    /* HALO JUMP */
    /* Halo jump (thanks to MGI_HALO script!) */
    _haloActionId = player addAction ["<t color='#ff2222'>HALO jump</t>", {
        private ["_bpk"];
        
        openmap [true, false];
        mapAnimAdd [0, 0.25, getMarkerPos "trh2_mrk_taor"];
        mapAnimCommit;
        
        //titleText["Select Map Position", "PLAIN"];
        _bpk = createVehicle ["WeaponHolderSimulated", getPosATL player, [], 0, "CAN_COLLIDE"];
        if (backpack player !="") then {
            _bpk addBackpackCargoGlobal [backpack player, 1];
            [_bpk] spawn {
                ["chute_bpk", "onEachFrame", {
                    private ["_bpk"];
                    _bpk = _this select 0;
                    if (!isNull _bpk) then {
                        call {
                            if (stance player == "UNDEFINED") exitWith {
                                _bpk attachTo [player,[-0.1,-0.05,-0.7],'leaning_axis'];
                                [_bpk,0,-180,0,0,0,0] remoteExec ["fnc_orient"]
                            };
                            if (stance player == "STAND") exitWith {
                                _bpk attachTo [player,[-0.1,0.75,-0.05],'leaning_axis'];
                                [_bpk,0,-90,0,0,0,0] remoteExec ["fnc_orient"]
                            };
                        };
                    };
                }, [_this select 0]] call BIS_fnc_addStackedEventHandler;
            };
        };
        
        [_bpk] onMapSingleClick {
            _bpk = _this select 0;
            player setPos [_pos select 0, _pos select 1, trh2_cfg_haloElev];
            if (player distance2d (getMarkerPos "trh2_mrk_safezone") > trh2_cfg_safeZoneRadius) then {
                player setVariable ["trh2_player_inGame", true, true];
            };
            [player, [missionNamespace, 'playerInventory']] call BIS_fnc_saveInventory;
            player setVariable ['MGI_ammo1',player ammo (primaryWeapon player)];
            player setVariable ['MGI_ammo2',player ammo (handgunWeapon player)];
            player setVariable ['MGI_ammo3',player ammo (secondaryWeapon player)];
            player setVariable ['MGI_mags',magazinesAmmoFull player];
            player setVariable ['MGI_weapon',currentWeapon player];
            removeBackpackGlobal player;
            player addBackpack 'B_parachute';
            openmap [false,false];
            [_bpk] spawn {
                _bpk = _this select 0;
                waitUntil {(getpos player select 2) < trh2_cfg_haloSafety or isTouchingGround player};
                if (!isTouchingGround player) then { player action ['OpenParachute', player] };
                waitUntil {isTouchingGround player};
                if (!isnull _bpk) then {
                    detach _bpk;
                    deleteVehicle _bpk;
                };
                sleep 2;
                if (alive player) then {
                    [player, [missionNamespace, 'playerInventory']] call BIS_fnc_loadInventory;
                    { player removeMagazine _x } forEach magazines player;
                    player setAmmo [primaryWeapon player, 0];
                    player setAmmo [handGunWeapon player, 0];
                    player setAmmo [secondaryWeapon player, 0];
                    { 
                        if (((player getVariable 'MGI_mags') select _foreachindex select 3) <= 0) then {
                            player addMagazine [_x select 0,_x select 1];
                        };
                    } forEach (player getVariable 'MGI_mags');
                    player setAmmo [primaryWeapon player,player getVariable 'MGI_ammo1'];
                    player setAmmo [handGunWeapon player,player getVariable  'MGI_ammo2'];
                    player setAmmo [secondaryWeapon player,player getVariable 'MGI_ammo3'];
                    player selectWeapon (player getVariable 'MGI_weapon');
                };
           }
           onMapSingleClick '';
           false
        }  
    }, nil, 5, true, true, "", "(vehicle _this == _this) and !trh2_status_treasureFound and trh2_status_started and (player getVariable 'trh2_player_isSafe') and !(player getVariable ['trh2_player_inGame', false])"];



    /* HANDLE DAMAGE (DEAD) */
    
    [] spawn {
        //waitUntil { !isNil { player getVariable "bis_revive_ehHandleDamage" } };
        //player removeEventHandler ["HandleDamage", player getVariable "bis_revive_ehHandleDamage" ];
        //player removeAllEventHandlers "HandleDamage";
        
        // by caddrel, https://forums.bistudio.com/forums/topic/199665-damage-handling-scripts-broken-since-166-update/?tab=comments#comment-3191125
        
        player addEventHandler ["HandleDamage", {
            params ["_unit", "_hitSelect", "_amountOfDamage", "_source", "_projectile", "_hitPartIndex", "_instigator", "_hitPoint"];
            
            if (_amountOfDamage > 0.85) then {
                _amountOfDamage = 0.85;
            };

            _amountOfDamage
        }];
    };
    
    [] spawn {
        while { true } do {
            waitUntil { !(player getVariable ["trh2_player_dead", true]) };
            waitUntil { damage player >= 0.85 };
            player setDamage 0.85;
            
            player setVariable ["trh2_player_dead", true, true];
            hint parseText "<t size=4 color='#FF0000'>You died</t>";
            // TODO: spectating available from mouse menu?
            player setUnconscious true;
            
            _grp = group player;
            _allowedUnits = [];
            if (!(isNull _grp)) then {
                _allowedUnits = units _grp - [player];
                if (count _allowedUnits > 0) then {
                    ["Initialize", [player, [], _allowedUnits, false, false, false, false, false, false, false, true]] call EGSpectator_qbmod;
                    player setVariable ["trh2_player_spectating", true, true];
                };
            };

            [] spawn {
                waitUntil { !(player getVariable ["trh2_player_dead", false]) };
                if (player getVariable ["trh2_player_spectating", false]) then {
                    ["Terminate"] call EGSpectator_qbmod;
                };
                player setUnconscious false;
                player setDamage 0;
                {
                    player setHit [_x, 0.0];
                } forEach ((getAllHitPointsDamage player) select 1);
                player switchMove "";
            };
        };
    };
    
    
    /* INSTRUCTIONS */
    
    player addAction ["(Show treasure photo)", {
        if (!trh2_treasurePlaced) then {
            [
                "treasurelooks", 
                [
                    "Treasure has not yet been placed"
                ], 
                3, "#FFFFFF", [4]
            ] call trh2_fnc_message;
        } else {
            [
                "treasurelooks", 
                [
                    format ["Your treasure today is: %1 <img size=5 image='%2'/>", trh2_cfg_treasureItemName, ( ConfigFile >> "CfgVehicles" >> typeOf trh2_treasure >> "editorPreview" ) call BIS_fnc_GetCfgData]
                ], 
                3, "#FFFFFF", [6]
            ] call trh2_fnc_message;
        };
    }, [], 0, false, true, "", "!(isNil ""trh2_treasurePlaced"")"];
    
    
    [] spawn {
        player createDiaryRecord ["Diary", ["Instructions", "
<font size='32'>Treasure Hunt</font><br/>
<br/>
<br/>

<font size='18'>Your mission</font><br/>
- Find the treasure<br/>
- Take it to the extraction point<br/>
<br/>
Check Map - Briefing - Treasure to find out what your treasure looks like.<br/>
<br/>
<font size='18'>How to do it</font><br/><br/>
1 TEAM UP with max. three fighters per group (press U and invite friends; you can also change your group's name here).<br/><br/>
2 GATHER YOUR GEAR at the supply boxes.<br/><br/>
3 HALO JUMP IN once the mission starts. Use your mouse menu and choose your location. Area of operations is marked with a blue circle on your map.<br/><br/>
4 FIND INTEL by talking to the locals and by scanning through the computers you find in the houses. Intel you find will be marked on your map.<br/><br/>
5 FOLLOW THE BEACON. If you are not the lucky one to find the treasure first, follow the beacon emitted by the treasure to find whoever is carrying it...<br/><br/>
6 REACH THE EXTRACTION POINT, once you have got the treasure (if you haven't got it, prevent anyone having the treasure reaching the extraction point!). The extraction point is marked on the map with a green cross once the treasure is picked up first time by anyone.<br/><br/>
<br/>
Note: This server is still very much in beta stage. Any issues and feedback, please see the GitHub page at https://github.com/larskaislaniemi/arma3_TreasureHunt<br/>
<br/>

GOOD LUCK!<br/>
        "]];

        [
            "instruction", 
            [
                "Welcome to Treasure Hunt!", 
                "Be sure to check out the instructions in Map-&gt;Briefing",
                "Photo of today's treasure available using mouse scroll menu"
            ], 
            3, "#0000FF", [3,6,5]
        ] call trh2_fnc_message;
    };
};