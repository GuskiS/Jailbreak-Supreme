#include <amxmodx>
#include <fakemeta>
#include <cstrike>
#include <fun>
#include <hamsandwich>
#include <jailbreak>

new g_pMyNewDay;
new g_szDayName[JAIL_MENUITEM];

public plugin_init()
{
	register_plugin("[JAIL] Sparta day", JAIL_VERSION, JAIL_AUTHOR);

	formatex(g_szDayName, charsmax(g_szDayName), "%L", LANG_PLAYER, "JAIL_DAY8");
	g_pMyNewDay = jail_day_add(g_szDayName, "sparta", 1);
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
		begin_spartaday(simon);
		return PLUGIN_HANDLED;
	}

	return PLUGIN_CONTINUE;
}

public jail_day_end(simon, day, dayname[])
{
	if(day == g_pMyNewDay)
	{
		end_spartaday(simon);
		return PLUGIN_HANDLED;
	}

	return PLUGIN_CONTINUE;
}

begin_spartaday(simon)
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

end_spartaday(simon)
{
	new num, id;
	static players[32];
	get_players(players, num);

	for(--num; num >= 0; num--)
	{
		id = players[num];
		jail_set_playerdata(id, PD_HAMBLOCK, false);
		if(is_user_alive(id))
			strip_weapons(id);
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

	if(cs_get_user_team(id) != get_reverse_state())
	{
		ham_give_weapon(id, "weapon_deagle", 1);
		give_item(id, "weapon_shield");
		cs_set_user_bpammo(id, CSW_DEAGLE, 35);
	}
	else
	{
		ham_give_weapon(id, "weapon_m4a1", 1);
		cs_set_user_bpammo(id, CSW_M4A1, 180);
	}

	jail_player_crowbar(id, false);
	jail_set_playerdata(id, PD_HAMBLOCK, true);
}