#if defined _jail_const_included
  #endinput
#endif
#define _jail_const_included

#if AMXX_VERSION_NUM >= 183
    #define ColorChat client_print_color
    #define NORMAL print_team_default
    #define GREY print_team_grey
    #define RED print_team_red
    #define BLUE print_team_blue
    #define GREEN print_team_green
#else
    #include <colorchat>
	#define JAIL_HAMBOTS
#endif

#define JAIL_VERSION	"1.1.2"
#define JAIL_AUTHOR		"GuskiS"
#define JAIL_TAG		"^x03[^x04JailBreak^x03]^x01"

#define JAIL_CT_MODEL	"gign"
#define JAIL_T_MODEL	"suprjail_t"
stock const g_szKnifeModel[][] = {"models/suprjail/p_crowbar.mdl", "models/suprjail/v_crowbar.mdl", "models/suprjail/v_hands.mdl"};
#define JAIL_MENUITEM		64 // Max length of days name.
#define JAIL_CHATCOMMAND	16 // Max length of days name.

#define JAIL_ADMIN_ACCESS ADMIN_LEVEL_B // N

#define day_equal(%0) jail_get_globalinfo(GI_DAY) == %0
#define game_equal(%0) jail_get_globalinfo(GI_GAME) == %0
#define duel_equal(%0) jail_get_globalinfo(GI_DUEL) == %0

#pragma semicolon 1

enum _:PLAYERDATA
{
	PD_SIMON,
	PD_KILLEDSIMON,
	PD_WANTED,
	PD_CROWBAR,
	PD_FREEDAY,
	PD_SKIN,
	PD_NEXTFD,
	PD_HAMBLOCK,
	PD_TALK,
	PD_REMOVEHE,
	PD_INVISIBLE
}

enum _:GLOBALINFO
{
	//GI_CANTSIMON,
	GI_SIMON,
	GI_DUEL,
	GI_GAME,
	GI_DAY,
	GI_WANTED,
	GI_KILLEDSIMON,
	GI_DAYCOUNT,
	GI_FREEPASS,
	GI_REVERSE,
	GI_BLOCKDOORS,
	GI_HIDEHUD,
	GI_EVENTSTOP,
	GI_NOFREEBIES
}

enum _:GAMEMODE
{
	GAME_UNSET,
	GAME_PREPARING,
	GAME_RESTARTING,
	GAME_STARTED,
	GAME_ENDED
}

enum _:SKINS_PRISONERS
{
	SKIN_FREEDAY,
	SKIN_WANTED,
	SKIN_RANDOM1,
	SKIN_RANDOM2,
	SKIN_RANDOM3
}

enum _:SKINS_GUARDS
{
	SKIN_SIMON,
	SKIN_RANDOM1,
	SKIN_RANDOM2
}

enum _:HAM_ENABLE_BLOCK
{
	HEB_TRACEATTACK,
	HEB_TAKEDAMAGE,
	HEB_TOUCH1,
	HEB_TOUCH2,
	HEB_USE,
	HEB_SPAWNWEAPS,
	HEB_REGENAPHP
}

// Door state toggle, use 0 and 1
enum _:TOGGLE_STATE
{
	TS_OPENED,		// opened	0
	TS_CLOSED,		// closed	1
	TS_OPENING,		// opening	2
	TS_CLOSING		// closing	3
}