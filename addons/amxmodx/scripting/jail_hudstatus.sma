#include <amxmodx>
#include <engine>
#include <cstrike>
#include <jailbreak>

new const Float:g_fHudLocation[][2] =
{
	{-1.0,	0.6},
	{ 0.1,	0.2},	// LEFT
	{ 0.73,	0.2}	// RIGHT
};
//RGB
new const g_iPlayerColors[][3] =
{
	{0, 255, 0},	// SIMON
	{255, 0, 0},	// WANTED
	{255, 140, 0}	// NORMAL
};

new g_pHudSync[3];

public plugin_init()
{
	register_plugin("[JAIL] Hud & Status", JAIL_VERSION, JAIL_AUTHOR);

	register_event("StatusValue", "Event_StatusValue_S", "be", "1=2", "2!0");
	register_event("StatusValue", "Event_StatusValue_H", "be", "1=1", "2=0");

	for(new i = 0; i < sizeof(g_pHudSync); i++)
		g_pHudSync[i] = CreateHudSyncObj();
}

public client_putinserver(id)
	if(!task_exists(id))
		set_task(2.0, "show_screen", id, _, _, "b");

public client_disconnect(id)
{
	if(task_exists(id))
		remove_task(id);
}

public Event_StatusValue_S(id)
{
	if(!is_user_connected(id) || my_ultimate_check())
		return;

	new pid = read_data(2), color;
	if(jail_get_playerdata(pid, PD_INVISIBLE) && cs_get_user_team(id) != cs_get_user_team(pid))
		return;

	if(jail_get_playerdata(pid, PD_SIMON))
		color = 0;
	else if(jail_get_playerdata(pid, PD_WANTED))
		color = 1;
	else color = 2;

	static name[32];
	get_user_name(pid, name, charsmax(name));

	new hp = get_user_health(pid);
	set_hudmessage(g_iPlayerColors[color][0], g_iPlayerColors[color][1], g_iPlayerColors[color][2], g_fHudLocation[0][0], g_fHudLocation[0][1], 0, 0.0, 1.1, 0.0, 0.0, -1);
	ShowSyncHudMsg(id, g_pHudSync[0], "%s [HP %d]", name, hp);
}

public Event_StatusValue_H(id)
	ClearSyncHud(id, g_pHudSync[0]);

public show_screen(alive)
{
	if(my_ultimate_check() || jail_get_globalinfo(GI_HIDEHUD))
		return;

// LEFT SIDE
	new len, simon, killer;
	new num, id, numA;
	static players[32];
	const SIZE = 512;
	static msg[SIZE+1], name[2][32];
	get_players(players, num, "e", "TERRORIST");

	if((simon = jail_get_globalinfo(GI_SIMON)))
	{
		get_user_name(simon, name[0], charsmax(name[]));
		len += formatex(msg[len], SIZE - len, "%L^n^n", alive, "JAIL_SHOW_SIMON", name[0]);
	}
	else if((killer = jail_get_globalinfo(GI_KILLEDSIMON)))
	{
		new simon = jail_get_playerdata(killer, PD_KILLEDSIMON);
		get_user_name(killer, name[0], charsmax(name[]));
		get_user_name(simon, name[1], charsmax(name[]));
		len += formatex(msg[len], SIZE - len, "%L^n^n", alive, "JAIL_SHOW_KILLEDSIMON", name[0], name[1]);
	}

	if(jail_get_globalinfo(GI_WANTED))
	{
		len += formatex(msg[len], SIZE - len, "^n%L^n", alive, "JAIL_SHOW_WANTED");

		get_players(players, num, "a");
		for(--num; num >= 0; num--)
		{
			id = players[num];
			if(jail_get_playerdata(id, PD_WANTED))
			{
				get_user_name(id, name[0], charsmax(name[]));
				len += formatex(msg[len], SIZE - len, "%s^n", name[0]);
			}
		}
	}

	static dayname[JAIL_MENUITEM];
	if(!dayname[0]) formatex(dayname, charsmax(dayname), "%L", LANG_SERVER, "JAIL_DAY0");

	if(jail_get_globalinfo(GI_DAY) != jail_day_getid(dayname))
	{
		new check;
		get_players(players, num, "a");
		for(--num; num >= 0; num--)
		{
			id = players[num];
			if(jail_get_playerdata(id, PD_FREEDAY))
			{
				if(!check)
				{
					len += formatex(msg[len], SIZE - len, "^n%L^n", alive, "JAIL_SHOW_FREEBIES");
					check = true;
				}

				get_user_name(id, name[0], charsmax(name[]));
				len += formatex(msg[len], SIZE - len, "%s^n", name[0]);
			}
		}
	}

	get_players(players, num, "e", "TERRORIST");
	get_players(players, numA, "ae", "TERRORIST");
	if(numA)
		len += formatex(msg[len], SIZE - len, "^n%L: %d/%d", alive, "JAIL_PRISONERS", numA, num);

	set_hudmessage(g_iPlayerColors[2][0], g_iPlayerColors[2][1], g_iPlayerColors[2][2], g_fHudLocation[1][0], g_fHudLocation[1][1], 0, 0.0, 2.1, 0.0, 0.0, -1);
	ShowSyncHudMsg(alive, g_pHudSync[1], "%s", msg);
	len = 0;
	msg[0] = '^0';

// RIGHT SIDE
	new event, eventName[JAIL_MENUITEM];
	if((event = jail_get_globalinfo(GI_DAYCOUNT)))
		len += formatex(msg[len], SIZE - len, "%L^n", alive, "JAIL_SHOW_COUNT", event);

	if((event = jail_get_globalinfo(GI_DAY)))
	{
		jail_day_getname(event, eventName);
		len += formatex(msg[len], SIZE - len, "%L^n", alive, "JAIL_SHOW_DAY", eventName);
	}

	if((event = jail_get_globalinfo(GI_GAME)))
	{
		jail_game_getname(event, eventName);
		len += formatex(msg[len], SIZE - len, "%L^n", alive, "JAIL_SHOW_GAME", eventName);
	}

	set_hudmessage(g_iPlayerColors[0][0], g_iPlayerColors[0][1], g_iPlayerColors[0][2], g_fHudLocation[2][0], g_fHudLocation[2][1], 0, 0.0, 2.1, 0.0, 0.0, -1);
	ShowSyncHudMsg(alive, g_pHudSync[2], "%s", msg);

	msg[0] = '^0';
}

my_ultimate_check()
{
	if(jail_get_gamemode() != GAME_STARTED && jail_get_gamemode() != GAME_ENDED && jail_get_gamemode() != GAME_PREPARING)
		return 1;

	return 0;
}