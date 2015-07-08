#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <hamsandwich>
#include <cs_teams_api>
#include <jailbreak>

public plugin_init()
{
	register_plugin("[JAIL] Simon menu", JAIL_VERSION, JAIL_AUTHOR);

	set_client_commands("menu", "cmd_show_menu");
	set_client_commands("transfer", "transfer_show_menu");
	set_client_commands("reverse", "reverse_gameplay");
	set_client_commands("mic", "give_mic");
}

public cmd_show_menu(id)
{
	if(is_user_alive(id))
	{
		if(my_check(id))
		{
			static menu, option[64];
			formatex(option, charsmax(option), "%L", id, "JAIL_MENUMENU");
			menu = menu_create(option, "show_menu_handle");

			formatex(option, charsmax(option), "%L", id, "JAIL_TRANSFER");
			menu_additem(menu, option, "1", 0);
			formatex(option, charsmax(option), "%L", id, "JAIL_GIVEMIC");
			menu_additem(menu, option, "2", 0);
			formatex(option, charsmax(option), "%L", id, "JAIL_DAYMENU");
			menu_additem(menu, option, "3", 0);
			formatex(option, charsmax(option), "%L", id, "JAIL_GAMEMENU");
			menu_additem(menu, option, "4", 0);
			if(!get_pcvar_num(get_cvar_pointer("jail_prisoner_grenade")))
			{
				formatex(option, charsmax(option), "%L", id, "JAIL_ALLOWNADES");
				menu_additem(menu, option, "5", 0);
			}
			formatex(option, charsmax(option), "%L", id, "JAIL_REVERSE", id, jail_get_globalinfo(GI_REVERSE) ? "JAIL_PRISONERS" : "JAIL_GUARDS");
			menu_additem(menu, option, "6", 0);
			if(is_jail_admin(id))
			{
				formatex(option, charsmax(option), "%L", id, "BALL_BALLMENU");
				menu_additem(menu, option, "7", 0);
			}

			menu_display(id, menu);
		}
	}
}

public show_menu_handle(id, menu, item)
{
	if(item == MENU_EXIT || !is_user_alive(id) || !my_check(id))
	{
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}

	new access, callback, num[3];
	menu_item_getinfo(menu, item, access, num, charsmax(num), _, _, callback);
	menu_destroy(menu);

	new pick = str_to_num(num);
	switch(pick)
	{
		case 1:	transfer_show_menu(id);
		case 2: give_mic(id);
		case 3: client_cmd(id, "jail_days");
		case 4: client_cmd(id, "jail_games");
		case 5: nades_show_menu(id);
		case 6:	reverse_gameplay(id);
		case 7:	client_cmd(id, "jail_ball");
	}

	return PLUGIN_HANDLED;
}

public give_mic(id)
{
	if(my_check(id))
		show_player_menu(id, 1, "MIC_transfer_show_menu_handle");
}

public reverse_gameplay(id)
{
	if(my_check(id))
	{
		jail_set_globalinfo(GI_REVERSE, !jail_get_globalinfo(GI_REVERSE));
		cmd_show_menu(id);
		static name[32];
		get_user_name(id, name, charsmax(name));
		ColorChat(0, NORMAL, "%s %L", JAIL_TAG, LANG_SERVER, "JAIL_REVERSE_C", name, LANG_SERVER, jail_get_globalinfo(GI_REVERSE) ? "JAIL_PRISONERS" : "JAIL_GUARDS");
	}
}

public transfer_show_menu(id)
{
	if(my_check(id))
	{
		static menu, option[64];
		formatex(option, charsmax(option), "%L", id, "JAIL_MENUMENU");
		menu = menu_create(option, "transfer_show_menu_handle");

		formatex(option, charsmax(option), "To T");
		menu_additem(menu, option, "0", 0);
		formatex(option, charsmax(option), "To CT");
		menu_additem(menu, option, "1", 0);

		menu_display(id, menu);
	}
}

public nades_show_menu(id)
{
	if(is_user_alive(id))
	{
		if(my_check(id))
		{
			static menu, option[64];
			formatex(option, charsmax(option), "%L", id, "JAIL_ALLOWNADES");
			menu = menu_create(option, "nades_show_menu_handle");

			formatex(option, charsmax(option), "All T");
			menu_additem(menu, option, "0", 0);
			formatex(option, charsmax(option), "Specific");
			menu_additem(menu, option, "1", 0);

			menu_display(id, menu);
		}
	}
}

public transfer_show_menu_handle(id, menu, item)
{
	if(item == MENU_EXIT || !is_user_alive(id) || !my_check(id))
	{
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}

	new access, callback, num[3];
	menu_item_getinfo(menu, item, access, num, charsmax(num), _, _, callback);
	menu_destroy(menu);

	new pick = str_to_num(num);
	show_player_menu(id, pick, "TR_transfer_show_menu_handle");

	return PLUGIN_HANDLED;
}

public nades_show_menu_handle(id, menu, item)
{
	if(item == MENU_EXIT || !is_user_alive(id) || !my_check(id))
	{
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}

	new access, callback, num[3];
	menu_item_getinfo(menu, item, access, num, charsmax(num), _, _, callback);
	menu_destroy(menu);

	new pick = str_to_num(num);
	if(!pick)
	{
		static players[32], name[32];
		new num, i;
		get_players(players, num, "ae", "TERRORIST");

		for(--num; num >= 0; num--)
		{
			i = players[num];
			jail_set_playerdata(i, PD_REMOVEHE, !jail_get_playerdata(i, PD_REMOVEHE));
		}

		get_user_name(id, name, charsmax(name));
		ColorChat(0, NORMAL, "%s %L", JAIL_TAG, LANG_SERVER, "JAIL_ALLOWNADES_CA", name);
	}
	else show_player_menu(id, pick, "DO_nades_show_menu_handle");

	return PLUGIN_HANDLED;
}

public show_player_menu(id, pick, handle[])
{
	static name[32], data[3], newmenu;
	formatex(name, charsmax(name), "%L", id, "JAIL_MENUMENU");
	newmenu = menu_create(name, handle);
	static players[32];
	new inum, i;
	get_players(players, inum, "ae", pick ? "TERRORIST" : "CT");

	for(--inum; inum >= 0; inum--)
	{
		i = players[inum];
		if(jail_get_playerdata(i, PD_FREEDAY)) continue;
		get_user_name(i, name, charsmax(name));
		num_to_str(i, data, charsmax(data));
		menu_additem(newmenu, name, data, 0);
	}

	menu_display(id, newmenu);
}

public TR_transfer_show_menu_handle(id, menu, item)
{
	if(item == MENU_EXIT || !is_user_alive(id) || !my_check(id))
	{
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}

	new access, callback, num[3];
	menu_item_getinfo(menu, item, access, num, charsmax(num), _, _, callback);
	menu_destroy(menu);

	new pick = str_to_num(num), CsTeams:team = cs_get_user_team(pick);
	static name[2][32];
	get_user_name(pick, name[0], charsmax(name[]));
	get_user_name(id, name[1], charsmax(name[]));

	if(team == CS_TEAM_T)
	{
		cs_set_player_team(pick, CS_TEAM_CT);
		ColorChat(0, NORMAL, "%s %L", JAIL_TAG, LANG_SERVER, "JAIL_TRANSFER_C", name[0], LANG_SERVER, "JAIL_GUARDS", name[1]);
	}
	else if(team == CS_TEAM_CT)
	{
		cs_set_player_team(pick, CS_TEAM_T);
		ColorChat(0, NORMAL, "%s %L", JAIL_TAG, LANG_SERVER, "JAIL_TRANSFER_C", name[0], LANG_SERVER, "JAIL_PRISONERS", name[1]);
	}
	strip_weapons(pick);
	ExecuteHamB(Ham_CS_RoundRespawn, pick);
	

	return PLUGIN_HANDLED;
}

public DO_nades_show_menu_handle(id, menu, item)
{
	if(item == MENU_EXIT || !is_user_alive(id) || !my_check(id))
	{
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}

	new access, callback, num[3];
	menu_item_getinfo(menu, item, access, num, charsmax(num), _, _, callback);
	menu_destroy(menu);

	new pick = str_to_num(num);
	static name[2][32];
	get_user_name(pick, name[0], charsmax(name[]));
	get_user_name(id, name[1], charsmax(name[]));

	jail_set_playerdata(pick, PD_REMOVEHE, !jail_get_playerdata(pick, PD_REMOVEHE));
	ColorChat(0, NORMAL, "%s %L", JAIL_TAG, LANG_SERVER, "JAIL_ALLOWNADES_C", name[0], name[1]);

	return PLUGIN_HANDLED;
}

public MIC_transfer_show_menu_handle(id, menu, item)
{
	if(item == MENU_EXIT || !is_user_alive(id) || !my_check(id))
	{
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}

	new access, callback, num[3];
	menu_item_getinfo(menu, item, access, num, charsmax(num), _, _, callback);
	menu_destroy(menu);

	new pick = str_to_num(num);
	static name[2][32];
	get_user_name(pick, name[0], charsmax(name[]));
	get_user_name(id, name[1], charsmax(name[]));
	jail_set_playerdata(pick, PD_TALK, !jail_get_playerdata(pick, PD_TALK));
	ColorChat(0, NORMAL, "%s %L", JAIL_TAG, LANG_SERVER, "JAIL_GIVEMIC_C", name[1], name[0]);

	return PLUGIN_HANDLED;
}

my_check(id)
{
	if(simon_or_admin(id) && !in_progress(id, GI_DAY) && !in_progress(id, GI_GAME))
		return 1;

	return 0;
}