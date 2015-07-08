#include <amxmodx>
#include <jailbreak>
#include <round_terminator>
#include <timer_controller>

#define TASK_ROUNDEND 1111

new g_iWonGame;
new g_pWonForward;

new const g_szWinner[][] =
{
	"",
	"JAIL_TWIN",
	"JAIL_CTWIN"
};

public plugin_init()
{
	register_plugin("[JAIL] Round winner", JAIL_VERSION, JAIL_AUTHOR);

	register_message(get_user_msgid("TextMsg"), "Message_Winner");
	g_pWonForward = CreateMultiForward("jail_winner", ET_IGNORE, FP_CELL);
}

public plugin_natives()
{
	register_library("jailbreak");
	register_native("jail_get_winner", "_get_winner");
	register_native("jail_set_winner", "_set_winner");
}

public jail_gamemode(mode)
{
	if(mode != GAME_STARTED && task_exists(TASK_ROUNDEND))
		remove_task(TASK_ROUNDEND);

	switch(mode)
	{
		case GAME_RESTARTING: g_iWonGame = false;
		case GAME_PREPARING:
		{
			set_task(6.0, "End_Round_False", TASK_ROUNDEND, _, _, "b");
			g_iWonGame = false;
		}
	}
}

public client_disconnect(id)
{
	if(get_winner())
		End_Round_False(id);
}

public End_Round_False(taskid)
{
	if(jail_get_gamemode() == GAME_STARTED || jail_get_gamemode() == GAME_UNSET)
	{
		#if !defined JAIL_HAMBOTS
		if(taskid != TASK_ROUNDEND)
			TerminateRound(RoundEndType_TeamExtermination, 1, MapType_Bomb);
		else
		{
			if(!jail_get_globalinfo(GI_DAY) && !jail_get_globalinfo(GI_GAME))
			{
				if(RoundTimerGet()-floatround(jail_get_roundtime()) < 6)
					TerminateRound(RoundEndType_TeamExtermination, 1, MapType_Bomb);
			}
		}
		#endif
	}
}

public get_winner()
{
	new who, num;
	static players[32];

	get_players(players, num, "ae", "TERRORIST");
	if(num <= 0)
		return who = 2;
	get_players(players, num, "ae", "CT");
	if(num <= 0)
		return who = 1;

	return who;
}

public Message_Winner(msgid, dest, id)
{
	if(jail_get_gamemode() != GAME_STARTED || g_iWonGame)
		return PLUGIN_CONTINUE;
	
	static message[20];
	get_msg_arg_string(2, message, charsmax(message));
	if(equal(message, "#Terrorists_Win") || equal(message, "#CTs_Win"))
	{
		new who;
		if(equal(message, "#Terrorists_Win"))
			who = 1;
		else if(equal(message, "#CTs_Win"))
			who = 2;

		if(!who)
			who = get_winner();

		if(who)
		{
			g_iWonGame = who;
			static out[32];
			formatex(out, charsmax(out), "%L", LANG_PLAYER, g_szWinner[g_iWonGame]);
			set_msg_arg_string(2, out);

			new ret;
			ExecuteForward(g_pWonForward, ret, g_iWonGame);

			return PLUGIN_HANDLED;
		}
	}

	return PLUGIN_CONTINUE;
}

public _get_winner()
	return g_iWonGame;

public _set_winner(plugin, params)
{
	if(params != 1)
		return -1;

	new team = get_param(1);
	if(team != 1 && team != 2)
		return -1;
#if !defined JAIL_HAMBOTS
	g_iWonGame = team;

	TerminateRound(RoundEndType_TeamExtermination, team);
#endif
	return team;
}