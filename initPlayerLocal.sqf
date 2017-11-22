#include "configParams.sqf";
#include "qb\qb_init.sqf";

waitUntil { !isNull player };
player allowDamage false;

waitUntil { !isNil "trh_missionStartTime" };


/* Player groups */
_myGrp = createGroup resistance;
[player] joinSilent grpNull;
[player] joinSilent _myGrp;

["InitializePlayer", [player, true]] call BIS_fnc_dynamicGroups;
["SetPrivateState", [group player, true]] remoteExec ["BIS_fnc_dynamicGroups", 2, false];

waitUntil { !isNil "trh_treasure" };

/* Create Diary Records */

_treasureIcon = format ["%1", ( ConfigFile >> "CfgVehicles" >> typeOf trh_treasure >> "editorPreview" ) call BIS_fnc_GetCfgData ];

player createDiaryRecord ["Diary", ["Treasure", format ["
<font size='32'>The treasure</font><br/>
<br/>
<br/>
is: %1. %2
<br/>
<br/>
<font image='%3'></font>
", trh_cfg_treasureItemName, trh_cfg_treasureItemDescription, _treasureIcon]  ]];

player createDiaryRecord ["Diary", ["Instructions", "
<font size='32'>Treasure Hunt</font><br/>
<br/>
<br/>

<font size='18'>Your mission</font><br/>
- Find the treasure<br/>
- Take it to the extraction point<br/>
<br/>

<font size='18'>How to do it</font><br/><br/>
1 TEAM UP with max. three fighters per group (press U and invite friends; you can also change your group's name here).<br/><br/>
2 GATHER YOUR GEAR at the supply boxes.<br/><br/>
3 HALO JUMP IN once the mission starts. Use your mouse menu and choose your location. Area of operations is marked with a blue circle on your map.<br/><br/>
4 FIND INTEL by talking to the locals and by scanning through the computers you find in the houses.<br/><br/>
5 FOLLOW THE BEACON. If you are not the lucky one to find the treasure first, follow the beacon emitted by the treasure. Steal it. Note that the beacon is only activated when the treasure is being carried by someone else!<br/><br/>
6 REACH THE EXTRACTION POINT, once you have got the treasure (if you haven't got it, prevent anyone having the treasure reaching the extraction point!). The extraction point is marked on the map with a green cross once the treasure is picked up first time by anyone.<br/><br/>
<br/>
Notes: 1) If you draw on map while on global chat channel, everybody will see your drawings! 2) This server is still very much in beta stage. Any issues and feedback, please see the GitHub page at https://github.com/larskaislaniemi/arma3_TreasureHunt<br/>
<br/>

GOOD LUCK!<br/>
"]];






[] spawn {
    titleText ["Welcome! See Map -> Briefing for instructions.", "BLACK", -1, true, true];
    sleep 3;
    titleFadeOut 2;
};

/* Allow damage only after game start */
[] spawn {
    
    waitUntil { trh_gameStarted };
    
    waitUntil { player distance (getMarkerPos "trh_mrk_premission") > 2000 };
    
    player setVariable ["trh_player_inGame", true, true];
    player allowDamage true;
};


/* Let the player know if treasure is already found */
[] spawn {
    waitUntil { trh_treasureFound };
    if (player distance (getMarkerPos "trh_mrk_premission") < 1000) then {
        ["LongMessage",["Too late!", "The treasure has already been found. Wait for the next round to join the game."]] call bis_fnc_showNotification;
    };
};


/* Show time counter */
[] spawn {
    waitUntil { trh_missionStartTime - time < 40 };
    if (trh_missionStartTime - time > 20) then { hint "Game starts in 40 seconds"; };

    waitUntil { trh_missionStartTime - time < 20 };
    if (trh_missionStartTime - time > 10) then { hint "Game starts in 20 seconds"; };

    waitUntil { trh_missionStartTime - time < 10 };
    if (trh_missionStartTime - time > 0) then { hint "Game starts in 10 seconds"; };

    waitUntil { trh_missionStartTime - time < 0 };
    if (time - trh_missionStartTime < 20) then { 
        ["Default",["START!", "Game started! Use menu to HALO jump."]] call bis_fnc_showNotification;
    } else {
        if (!trh_treasureFound) then {
            ["Default",["HURRY!", format ["Game has started %1 seconds ago! Use menu to HALO jump before somebody finds the treasure.", (time - trh_missionStartTime)]]] call bis_fnc_showNotification;
        };
    };
    //systemchat "Game started!";
};


/* HALO jump after game start */
[] spawn {
    fnc_orient = {
        _obj = _this select 0;
        _y = _this select 1;
        _p = _this select 2;
        _r = _this select 3;
        _a = _this select 4;
        _b = _this select 5;
        _c = _this select 6;
        _obj setVectorDirAndUp [
            [ sin _y * cos _p,cos _y * cos _p,sin _p],
            [[ sin _r,-sin _p,cos _r * cos _p],-_y] call BIS_fnc_rotateVector2D
        ]
    };
         
    waitUntil { trh_gameStarted };

    /* Halo jump (thanks to MGI_HALO script!) */
    _haloActionId = player addAction ["<t color='#ff2222'>HALO jump</t>", {
        private ["_bpk"];
        
        openmap [true, false];
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
            player setPos [_pos select 0, _pos select 1, trh_cfg_haloElev];
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
                waitUntil {(getpos player select 2) < trh_cfg_haloSafety or isTouchingGround player};
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
    }, nil, 5, true, true, "", "(vehicle _this == _this) and (((_this distance (getMarkerPos ""trh_mrk_premission"") < 1000) and (not trh_treasureFound)) or (trh_cfg_debugLevel > 2))"];
    
    if (trh_cfg_debugLevel == 0) then {
        waitUntil { player getVariable ["trh_player_inGame", false] };
        player removeAction _haloActionId;
    };
};


/* Reset gathered intel to zero at start */
if (player == leader group player) then {
    (group player) setVariable ["trh_nGotIntel", 0, true];
    (group player) setVariable ["trh_gotIntel", [], true];
};


/* Debugging: Get intel */
if (trh_cfg_debugLevel > 0) then {
    player addAction ["Get Intel", {
        _ns = group player;

        _i = random trh_nIntelPos;
        
        if ((_ns getVariable ["trh_gotIntel", []]) find _i < 0) then {
            _prevN = _ns getVariable ["trh_nGotIntel", 0];
            _prevI = _ns getVariable ["trh_gotIntel", []];
            
            _ns setVariable ["trh_nGotIntel", _prevN + 1, true];
            _ns setVariable ["trh_gotIntel", _prevI + [_i], true];
        };
        systemchat format ["Num of intel: %1", _ns getVariable ["trh_nGotIntel", "invalid"]];
    }, [], 4, false, false, "", "true", 3, false, ""];
};

/* To copy intel over if player's group changes */ /* BUGGY */
[] spawn {
    _prevGroup = group player;
    
    while { true } do {
        waitUntil { _prevGroup != (group player) };
        
        if ((!isNull prevGroup) and (!isNull (group player))) then {
            {
                _newArr = (group player) getVariable ["trh_gotIntel", []];
                _newArr pushBackUnique _x;
                (group player) setVariable ["trh_gotIntel", _newArr, true];
                (group player) setVariable ["trh_nGotIntel", count _newArr, true];
            } forEach (_prevGroup getVariable ["trh_gotIntel", []]);
        } else {
            sleep 5;
        };
        
        if (!isNull (group player)) then {
            _prevGroup = group player;
        };
    };
};

/* Loop to refresh gathered intel on map */
[] spawn {
    _nDrawnIntel = 0;
    _lastDrawn = time;
    
    while { true } do {
        _ns = group player;
        if (!isNull _ns) then {
            waitUntil { 
                (_nDrawnIntel != _ns getVariable ["trh_nGotIntel", 0]) OR (time - _lastDrawn > 20)
            };
            _lastDrawn = time;
            _nDrawnIntel = _ns getVariable ["trh_nGotIntel", 0];

            for "_i" from 1 to _nDrawnIntel do {
                _markerName = format ["trh_localmrk_intel_%1", _i];
                _iIntel = (_ns getVariable "trh_gotIntel") select (_i - 1);
                _pos = trh_intelPos select _iIntel;
                _unc = trh_intelUncertainty select _iIntel;
                
                //deleteMarkerLocal _markerName;
                createMarkerLocal [_markerName, _pos];
                _markerName setMarkerShapeLocal "ELLIPSE";
                _markerName setMarkerBrushLocal "Border";
                _markerName setMarkerSizeLocal [_unc, _unc];
                _markerName setMarkerAlphaLocal 0.7;
                _markerName setMarkerColorLocal "ColorRed";
            };
        } else {
            sleep 5;
        };
    };
};

/* Add action for others to dig my intel once I am dead/unconc. */
[player, ["Dig for intel", {
    _target = _this select 0;
    _caller = _this select 1;
    _actId = _this select 2;
    
    _ns = group _target; // TODO: Check for grpNull
    _nsme = group _caller;
    
    if (group _target == group _caller) then {
        if (lifeState _target == "INCAPACITATED") then {
            [format ["Guys, I emptied %1's pockets of intel but didn't bother to revive him. Haha.", name _target]] remoteExec ["systemchat", _caller, false];
        } else {
            ["Let's not leave these documents in his pockets."] remoteExec ["systemchat", _caller, false];
        };
        _ns setVariable ["trh_intelPocketsEmptied", true, true];
    } else {
        if (_ns getVariable ["trh_intelPocketsEmptied", false]) then {
            ["Looks like somebody emptied his pockets already."] remoteExec ["systemchat", _caller, false];
        } else {
            _counti = _ns getVariable ["trh_nGotIntel", 0];
            if (_counti > 0) then {
                _oldIntelCount = _nsme getVariable ["trh_nGotIntel", 0];
                for "_i" from 0 to (_counti-1) do {
                    _newarr = [] + (_nsme getVariable ["trh_gotIntel", []]);
                    _newarr pushBackUnique ((_ns getVariable ["trh_gotIntel", []]) select _i);
                    _nsme setVariable ["trh_gotIntel", _newarr, true];
                    _nsme setVariable ["trh_nGotIntel", count _newarr, true];
                };
                _newIntelCount = _nsme getVariable ["trh_nGotIntel", 0];
                if (_newIntelCount > _oldIntelCount) then {
                    [format ["Got %1 pieces of new intel here!", _newIntelCount - _oldIntelCount]] remoteExec ["systemchat", _caller, false];
                } else {
                    ["He had nothing we didn't already know."] remoteExec ["systemchat", _caller, false];
                };
            } else {
                ["His pockets are empty."] remoteExec ["systemchat", _caller, false];
            };
            _ns setVariable ["trh_intelPocketsEmptied", true, true];
        };
    };
}, [], 5, true, true, "", "(vehicle _this == _this) AND (_target != _this) AND (lifeState _target != ""HEALTHY"") AND (lifeState _target != ""INJURED"")", 5, false, ""]] remoteExec ["addAction", 0, true];
    
/* Refill player's pockets regularly with group's intel. Thus, if incapacited player is looted of intel,
   and then revived, his pockets won't be empty next time somebody tries to loot him. */
[] spawn {
    while { alive player } do {
        sleep 15;
        if ((lifeState player == "HEALTHY") OR (lifeState player == "INJURED")) then {
            player setVariable ["trh_intelPocketsEmptied", false, true];
        };
    };
};         

         
/* Debugging: Manually refresh intel info */
if (trh_cfg_debugLevel > 0) then {
    player addAction ["Refresh intel on map", {
        _ns = group player;
        
        for "_i" from 1 to (_ns getVariable "trh_nGotIntel") do {
            try {
                _markerName = format ["trh_localmrk_intel_%1", _i];
                _iIntel = (_ns getVariable "trh_gotIntel") select (_i - 1);
                _pos = trh_intelPos select _iIntel;
                _unc = trh_intelUncertainty select _iIntel;
                
                createMarkerLocal [_markerName, _pos];
                _markerName setMarkerShapeLocal "ELLIPSE";
                _markerName setMarkerBrushLocal "Border";
                _markerName setMarkerSizeLocal [_unc, _unc];
                _markerName setMarkerAlphaLocal 0.5;
                _markerName setMarkerColorLocal "ColorRed";
            } catch {
            };
        };
    }, [], 4, false, false, "", "true", 3, false, ""];
};