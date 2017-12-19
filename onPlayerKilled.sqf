[] spawn { 
    _allowedUnits = units group player;
    _allowedAlive = {alive _x} count _allowedUnits;
    if (_allowedAlive > 0) then {
        sleep 2;
        ["Initialize", [player, [], _allowedUnits, false, false, false, false, false, false, false, true]] call EGSpectator_qbmod;
        ["Default",["Dead!", "You are now following your squad member."]] call bis_fnc_showNotification;
        waitUntil { {alive _x} count _allowedUnits < 1 };
        ["Terminate"] call EGSpectator_qbmod;
    };
    if (!trh_gameEnded) then {
        ["Default",["All Dead!", "Your whole group is dead."]] call bis_fnc_showNotification;
        sleep 2;
        ["end1",false,true,true,true] remoteExec ["BIS_fnc_endMission", player, true];
    };
};


/*
Full Control

In case you would like to control when a player starts / stops spectating, you can use the built-in functions to do exactly that.
If you wish to start the spectator mode, you can execute the following function:

Param1: A string describing the action to be taken by the spectator function
Param2: The custom arguments that are sent to the spectator function

["Initialize", [player, [], true, true, true, true, true, true, true, true]] call BIS_fnc_EGSpectator;

The custom array for Initialize function can contain:
_this select 0 : The target player object
_this select 1 : Whitelisted sides, empty means all
             2   Whitelisted units
_this select 2 : Whether AI can be viewed by the spectator
_this select 3 : Whether Free camera mode is available
_this select 4 : Whether 3th Person Perspective camera mode is available
_this select 5 : Whether to show Focus Info stats widget
_this select 6 : Whether or not to show camera buttons widget
_this select 7 : Whether to show controls helper widget
_this select 8 : Whether to show header widget
_this select 9 : Whether to show entities / locations lists

If the spectator mode is active and you would like to terminate it, run the following function:
//["Terminate"] call BIS_fnc_EGSpectator;

*/