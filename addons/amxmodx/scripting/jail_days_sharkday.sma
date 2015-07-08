#include <amxmodx>
#include <cstrike>
#include <fakemeta>
#include <hamsandwich>
#include <fun>
#include <jailbreak>

new g_pMyNewDay, g_szDayName[JAIL_MENUITEM];

public plugin_init()
{
	register_plugin("[JAIL] Shark day", JAIL_VERSION, JAIL_AUTHOR);

	formatex(g_szDayName, charsmax(g_szDayName), "%L", LANG_PLAYER, "JAIL_DAY4");
	g_pMyNewDay = jail_day_add(g_szDayName, "shark", 1);
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
		start_sharkday(simon);
		return PLUGIN_HANDLED;
	}

	return PLUGIN_CONTINUE;
}

public jail_day_end(simon, day, dayname[])
{
	if(day == g_pMyNewDay)
	{
		end_sharkday(simon);
		return PLUGIN_HANDLED;
	}

	return PLUGIN_CONTINUE;
}

start_sharkday(simon)
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

	if(cvar_exists("amx_autounstuck"))
		set_cvar_num("amx_autounstuck", 0);

	jail_ham_specific({1, 1, 1, 1, 1, 0, 1});
	jail_set_globalinfo(GI_BLOCKDOORS, true);
	jail_set_globalinfo(GI_EVENTSTOP, true);

	jail_set_globalinfo(GI_DAY, g_pMyNewDay);
}

end_sharkday(simon)
{
	new num, id;
	static players[32];
	get_players(players, num);

	for(--num; num >= 0; num--)
	{
		id = players[num];
		jail_set_playerdata(id, PD_HAMBLOCK, false);

		strip_weapons(id);
		if(get_user_noclip(id))
		{
			set_user_noclip(id, false);
			if(is_user_alive(id))
			{
				ExecuteHamB(Ham_CS_RoundRespawn, id);
				cs_set_user_armor(id, 0, CsArmorType:CS_ARMOR_NONE);
			}
		}
	}

	if(cvar_exists("amx_autounstuck"))
		set_cvar_num("amx_autounstuck", 1);
	server_event(simon, g_szDayName, true);
	jail_set_globalinfo(GI_BLOCKDOORS, false);
	jail_set_globalinfo(GI_EVENTSTOP, false);
	jail_ham_all(false);
	jail_set_globalinfo(GI_DAY, false);
}

public set_player_attributes(id)
{
	jail_player_crowbar(id, false);
	jail_set_playerdata(id, PD_HAMBLOCK, true);

	strip_weapons(id);
	set_user_health(id, 100);
	if(cs_get_user_team(id) != get_reverse_state())
	{
		ham_give_weapon(id, "weapon_awp", 1);
		cs_set_user_bpammo(id, CSW_AWP, 30);
	}
	else
	{
		set_user_noclip(id, true);
		cs_set_user_armor(id, 100, CsArmorType:CS_ARMOR_VESTHELM);
	}
}