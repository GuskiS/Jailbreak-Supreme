#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <cstrike>
#include <fun>
#include <jailbreak>

new g_pMyNewDay;
new g_szDayName[JAIL_MENUITEM];

public plugin_init()
{
	register_plugin("[JAIL] Knife day", JAIL_VERSION, JAIL_AUTHOR);

	formatex(g_szDayName, charsmax(g_szDayName), "%L", LANG_PLAYER, "JAIL_DAY1");
	g_pMyNewDay = jail_day_add(g_szDayName, "knife", 1);
}

public jail_freebie_join(id, event, type)
{
	if(type == GI_DAY && event == g_pMyNewDay)
	{
		set_player_attributes(id);
		return PLUGIN_HANDLED;
	}

	return PLUGIN_CONTINUE;
}

public jail_day_start(simon, day, dayname[])
{
	if(day == g_pMyNewDay)
	{
		begin_knifeday(simon);
		return PLUGIN_HANDLED;
	}

	return PLUGIN_CONTINUE;
}

public jail_day_end(simon, day, dayname[])
{
	if(day == g_pMyNewDay)
	{
		end_knifeday(simon);
		return PLUGIN_HANDLED;
	}

	return PLUGIN_CONTINUE;
}

begin_knifeday(simon)
{
	new num, id;
	static players[32];
	get_players(players, num, "a");

	for(--num; num >= 0; num--)
	{
		id = players[num];
		if(jail_get_playerdata(id, PD_FREEDAY)) continue;
		set_player_attributes(id);
	}

	server_event(simon, g_szDayName, 0);
	jail_celldoors(simon, TS_OPENED);
	jail_ham_all(true);	

	jail_set_globalinfo(GI_DAY, g_pMyNewDay);
	jail_set_globalinfo(GI_EVENTSTOP, true);
}

end_knifeday(simon)
{
	new num, id;
	static players[32];
	get_players(players, num);

	for(--num; num >= 0; num--)
	{
		id = players[num];
		set_player_glow(id, 0);
		jail_set_playerdata(id, PD_HAMBLOCK, false);
	}

	server_event(simon, g_szDayName, 1);
	jail_ham_all(false);
	jail_set_globalinfo(GI_DAY, false);
	jail_set_globalinfo(GI_EVENTSTOP, false);

	return PLUGIN_CONTINUE;
}

public set_player_attributes(id)
{
	strip_weapons(id);
	set_user_health(id, 100);

	if(cs_get_user_team(id) == CS_TEAM_T)
		set_player_glow(id, 1, 255, 0, 0, 30);
	else set_player_glow(id, 1, 0, 0, 255, 30);

	jail_player_crowbar(id, false);
	jail_set_playerdata(id, PD_HAMBLOCK, true);
}