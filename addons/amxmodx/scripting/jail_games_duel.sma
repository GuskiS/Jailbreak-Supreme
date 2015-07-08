#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <cstrike>
#include <fun>
#include <jailbreak>

#if defined JAIL_HAMBOTS
#include <cs_ham_bots_api>
#endif

#define EXTRA_DUEL 1000

#define LINUX_WEAPON_OFF			4
#define LINUX_PLAYER_OFF			5
#define m_pPlayer					41
#define m_iClip						51
#define m_fInReload					54
#define m_flNextAttack				83

enum _:DUEL_WHO
{
	DW_A,
	DW_B,
	DW_TYPE
}

enum _:DUELS
{
	DUEL_BOX = 0,
	DUEL_PISTOL,
	DUEL_SCOUT,
	DUEL_NADE,
	DUEL_AWP,
	DUEL_FD,
	DUEL_END
}

new const g_iDuelCSW[] =
{
	CSW_KNIFE,
	CSW_DEAGLE,
	CSW_SCOUT,
	CSW_HEGRENADE,
	CSW_AWP,
	0,
	0
};

new const g_szDuelWeap[][] =
{
	"weapon_knife",
	"weapon_deagle",
	"weapon_scout",
	"weapon_hegrenade",
	"weapon_awp",
	"",
	""
};

new const g_szDuelNames[][] =
{
	"JAIL_GAME1_MENU1",
	"JAIL_GAME1_MENU2",
	"JAIL_GAME1_MENU3",
	"JAIL_GAME1_MENU4",
	"JAIL_GAME1_MENU5",
	"JAIL_DAY0",
	""
};

new g_iExtraDuels, Array:g_aDuels;
new g_pDuelForwardStart, g_pDuelForwardEnd;
new g_pMyNewGame, g_iMode, g_iDuelCounter, HamHook:g_pHamForwards[4];
new g_szGameName[JAIL_MENUITEM], g_iPlayerDueling[DUEL_WHO];
new const g_szMacGyver[] = "suprjail/macgyver.wav";

public plugin_precache()
{
	precache_sound(g_szMacGyver);
	g_aDuels = ArrayCreate(JAIL_MENUITEM);
}

public plugin_init()
{
	register_plugin("[JAIL] Duel", JAIL_VERSION, JAIL_AUTHOR);

	RegisterHam(Ham_Killed, "player", "Ham_Killed_post", 1);

	DisableHamForward((g_pHamForwards[0] = RegisterHam(Ham_Item_PostFrame, "weapon_deagle", "Ham_Item_PostFrame_pre", 0)));
	DisableHamForward((g_pHamForwards[1] = RegisterHam(Ham_Item_PostFrame, "weapon_scout", "Ham_Item_PostFrame_pre", 0)));
	DisableHamForward((g_pHamForwards[2] = RegisterHam(Ham_Item_PostFrame, "weapon_awp", "Ham_Item_PostFrame_pre", 0)));
	DisableHamForward((g_pHamForwards[3] = RegisterHam(Ham_TakeDamage, "player", "Ham_TakeDamage_pre", 0)));

#if defined JAIL_HAMBOTS
	RegisterHamBots(Ham_Killed, "Ham_Killed_post", 1);
#endif

	formatex(g_szGameName, charsmax(g_szGameName), "%L", LANG_PLAYER, "JAIL_GAME1");
	g_pMyNewGame = jail_game_add(g_szGameName, "duel", 1);
	set_client_commands("lr", "menu_lr");

	g_pDuelForwardStart = CreateMultiForward("jail_duel_start", ET_STOP, FP_CELL, FP_CELL, FP_CELL, FP_CELL); // duel, DA, DB
	g_pDuelForwardEnd = CreateMultiForward("jail_duel_end", ET_STOP, FP_CELL, FP_CELL, FP_CELL, FP_CELL);
}

public plugin_natives()
{
	register_library("jailbreak");
	register_native("jail_duel_add", "_duel_add");
	register_native("jail_duel_lastrequest", "_duel_lastrequest");
}

public client_disconnect(id)
{
	if(is_duelist(id))
		end_duel(0);
	else check_lr(1);
}

public grenade_throw(id, entity, nade)
{
	if(pev_valid(entity))
	{
		if(nade == CSW_HEGRENADE && is_user_alive(id) && is_duelist(id) && g_iPlayerDueling[DW_TYPE] == DUEL_NADE)
			cs_set_user_bpammo(id, g_iDuelCSW[DUEL_NADE], 2);
	}
}

public jail_game_start(simon, game, gamename[])
{
	if(game == g_pMyNewGame)
	{
		menu_duel(simon);
		return PLUGIN_HANDLED;
	}

	return PLUGIN_CONTINUE;
}

public jail_game_end(simon, game, gamename[])
{
	if(game == g_pMyNewGame)
	{
		g_iPlayerDueling[DW_TYPE] = DUEL_END;
		end_duel(simon);
		return PLUGIN_HANDLED;
	}

	return PLUGIN_CONTINUE;
}

public jail_gamemode(mode)
{
	if(mode == GAME_ENDED)
	{
		new num, id;
		static players[32];
		get_players(players, num);

		for(--num; num >= 0; num--)
		{
			id = players[num];
			give_it_one(id, 0, 0);
		}
		reset_it_all();
		g_iMode = 0;
	}
}

public Ham_Killed_post(victim, killer, shouldgib)
{
	if(is_duelist(victim))
	{
		new mode = g_iMode;
		end_duel(0);
		if(mode)
		{
			check_lr();
			return;
		}
	}
	else check_lr();
}

public Ham_Item_PostFrame_pre(ent) 
{
	if(!pev_valid(ent))
		return HAM_IGNORED;

	new id = get_weapon_owner(ent);
	if(!is_user_connected(id) || !is_duelist(id))
		return HAM_IGNORED;

	if(get_pdata_float(ent, m_fInReload, LINUX_WEAPON_OFF) && (get_pdata_float(id, m_flNextAttack, LINUX_PLAYER_OFF) <= 0.0))
	{
		cs_set_user_bpammo(id, get_user_weapon(id), 1);
		set_pdata_int(ent, m_iClip, 1, LINUX_WEAPON_OFF);
		set_pdata_float(ent, m_fInReload, 0.0, LINUX_WEAPON_OFF);
	}

	return HAM_HANDLED;
}

public Ham_TakeDamage_pre(victim, inflictor, attacker, Float:damage, DamageBits)
{
	if(is_user_alive(attacker))
	{
		new CsTeams:attackerTeam = cs_get_user_team(attacker), CsTeams:victimTeam = cs_get_user_team(victim);
		if(attackerTeam == victimTeam && attackerTeam == CS_TEAM_T && is_user_connected(victim))
		{
			damage /= 0.35;
			SetHamParamFloat(4, damage);
			return HAM_HANDLED;
		}
	}

	return HAM_IGNORED;
}

public menu_lr(id)
{
	if(is_user_alive(id) && cs_get_user_team(id) == CS_TEAM_T)
		check_lr();
}

public menu_duel(id)
{
	if(my_check(id))
	{
		static menu, option[JAIL_MENUITEM];
		menu = menu_create(g_szGameName, "menu_duel_handle");

		new data[5];
		for(new i = 0; i < DUEL_FD+g_iMode; i++)
		{
			formatex(option, charsmax(option), "%L", id, g_szDuelNames[i]);
			num_to_str(i, data, charsmax(data));
			menu_additem(menu, option, data, 0);
		}

		if(g_iExtraDuels)
		{
			for(new i = 1; i <= g_iExtraDuels; i++)
			{
				ArrayGetArray(g_aDuels, i, option);

				num_to_str(i+EXTRA_DUEL, data, charsmax(data));
				menu_additem(menu, option, data, 0);
			}
		}

		menu_display(id, menu);
	}

	return PLUGIN_HANDLED;
}

public menu_duel_handle(id, menu, item)
{
	if(item == MENU_EXIT || !is_user_alive(id) || !my_check(id))
	{
		menu_destroy(menu);
		reset_it_all();
		return PLUGIN_HANDLED;
	}

	new access, callback, num[5];
	menu_item_getinfo(menu, item, access, num, charsmax(num), _, _, callback);
	menu_destroy(menu);

	g_iPlayerDueling[DW_TYPE] = str_to_num(num);
	if(g_iPlayerDueling[DW_TYPE] < DUEL_FD || g_iPlayerDueling[DW_TYPE] > EXTRA_DUEL)
		players_menu(id, g_iMode ? "CT" : "TERRORIST");
	else start_duel(id);

	return PLUGIN_HANDLED;
}

public players_menu(id, team[])
{
	if(my_check(id))
	{
		static name[32], data[3], menu;
		menu = menu_create(g_szGameName, "players_menu_handle");

		new num, i;
		static players[32];
		get_players(players, num, "ae", team);

		for(--num; num >= 0; num--)
		{
			i = players[num];
			if(is_duelist(i) || jail_get_playerdata(i, PD_FREEDAY)) continue;
			get_user_name(i, name, charsmax(name));
			num_to_str(i, data, charsmax(data));
			menu_additem(menu, name, data, 0);
		}
		menu_display(id, menu);
	}
}

public players_menu_handle(id, menu, item)
{
	if(item == MENU_EXIT || !is_user_alive(id) || !my_check(id))
	{
		menu_destroy(menu);
		reset_it_all();
		return PLUGIN_HANDLED;
	}

	new access, callback, num[3], player;
	menu_item_getinfo(menu, item, access, num, charsmax(num), _, _, callback);
	menu_destroy(menu);

	if(!g_iMode)
	{
		player = str_to_num(num);
		g_iPlayerDueling[g_iDuelCounter++] = player;
		jail_set_playerdata(player, PD_HAMBLOCK, true);

		if(g_iDuelCounter == 2)
		{
			g_iDuelCounter = 0;
			static name[2][32];
			get_user_name(g_iPlayerDueling[0], name[0], charsmax(name[]));
			get_user_name(g_iPlayerDueling[1], name[1], charsmax(name[]));
			ColorChat(0, NORMAL, "%s %L", JAIL_TAG, LANG_PLAYER, "JAIL_GAME1_EXTRA1", name[0], duel_name(LANG_PLAYER), name[1]);
			start_duel(id);
		}
		else players_menu(id, "TERRORIST");
	}
	else
	{
		player = str_to_num(num);
		g_iPlayerDueling[DW_A] = id;
		g_iPlayerDueling[DW_B] = player;
		jail_set_playerdata(id, PD_HAMBLOCK, true);
		jail_set_playerdata(player, PD_HAMBLOCK, true);

		static name[2][32];
		get_user_name(id, name[0], charsmax(name[]));
		get_user_name(player, name[1], charsmax(name[]));

		ColorChat(0, NORMAL, "%s %L", JAIL_TAG, LANG_PLAYER, "JAIL_GAME1_EXTRA1", name[0], duel_name(LANG_PLAYER), name[1]);
		start_duel(id);
	}

	return PLUGIN_HANDLED;
}

public start_duel(id)
{
	new duel = g_iPlayerDueling[DW_TYPE];

	switch(duel)
	{
		case DUEL_END: end_duel(id);
		case DUEL_FD:
		{
			jail_set_playerdata(id, PD_NEXTFD, true);
			end_duel(id);
			jail_set_winner(2);
		}
		default:
		{
			jail_set_globalinfo(GI_EVENTSTOP, true);
			server_event(id, duel_name(LANG_PLAYER), 0);
			set_cvar_num("mp_friendlyfire", 1);
			jail_set_globalinfo(GI_GAME, g_pMyNewGame);
			jail_set_globalinfo(GI_NOFREEBIES, true);
			client_cmd(0, "spk ^"%s^"", g_szMacGyver);
			give_it_one(g_iPlayerDueling[DW_A], 1, duel);
			give_it_one(g_iPlayerDueling[DW_B], 1, duel);

			if(duel > EXTRA_DUEL)
			{
				new ret;
				ExecuteForward(g_pDuelForwardStart, ret, id, duel-EXTRA_DUEL, g_iPlayerDueling[DW_A], g_iPlayerDueling[DW_B]);
				return;
			}

			my_registered_stuff(true);
			jail_ham_all(true);
		}
	}
}

public end_duel(id)
{
	new duel = g_iPlayerDueling[DW_TYPE];
	if(duel == DUEL_END && jail_get_globalinfo(GI_DUEL))
	{
		duel = jail_get_globalinfo(GI_DUEL)+EXTRA_DUEL;
		g_iPlayerDueling[DW_TYPE] = duel;
	}
	
	new AID = g_iPlayerDueling[DW_A], BID = g_iPlayerDueling[DW_B];
	if(!is_user_alive(AID))
	{
		AID = g_iPlayerDueling[DW_B];
		BID = g_iPlayerDueling[DW_A];
	}

	switch(duel)
	{
		case DUEL_END: server_event(id, g_szGameName, 1);
		case DUEL_FD:
		{
			static name[32];
			get_user_name(id, name, charsmax(name));
			ColorChat(0, NORMAL, "%s %L", JAIL_TAG, LANG_PLAYER, "JAIL_GAME1_EXTRA3", name, LANG_PLAYER, "JAIL_DAY0");
		}
		default:
		{
			if(duel == DUEL_NADE)
				move_grenade();
				//remove_entity_name("grenade"); crash

			static name[2][32];
			get_user_name(AID, name[0], charsmax(name[]));
			get_user_name(BID, name[1], charsmax(name[]));
			if(duel > EXTRA_DUEL)
			{
				new ret;
				ExecuteForward(g_pDuelForwardEnd, ret, id, duel-EXTRA_DUEL, AID, BID);
				ColorChat(0, NORMAL, "%s %L", JAIL_TAG, LANG_PLAYER, "JAIL_GAME1_EXTRA2", name[0], duel_name(LANG_PLAYER), name[1]);
				null_everything();

				return;
			}
			else ColorChat(0, NORMAL, "%s %L", JAIL_TAG, LANG_PLAYER, "JAIL_GAME1_EXTRA2", name[0], duel_name(LANG_PLAYER), name[1]);
		}
	}

	reset_it_all();
}

public give_it_one(id, value, duel)
{
	if(is_user_alive(id))
		strip_weapons(id);

	if(is_user_connected(id))
	{
		if(value)
		{
			set_player_glow(id, 1, random_num(1, 255), random_num(1, 255), random_num(1, 255), 30);
			set_user_health(id, 100);
			cs_set_user_armor(id, 0, CS_ARMOR_NONE);
			jail_player_crowbar(id, false);

			switch(duel)
			{
				case DUEL_PISTOL, DUEL_SCOUT, DUEL_AWP: give_duel_weaps(id, duel, g_szDuelWeap[duel]);
				case DUEL_NADE:
				{
					jail_set_playerdata(id, PD_REMOVEHE, false);
					ham_give_weapon(id, g_szDuelWeap[duel]);
				}
			}
		}
		else
		{
			jail_set_playerdata(id, PD_HAMBLOCK, false);
			if(is_user_connected(id) && !get_pcvar_num(get_cvar_pointer("jail_prisoner_grenade")) && cs_get_user_team(id) == CS_TEAM_T)
				jail_set_playerdata(id, PD_REMOVEHE, true);
			set_player_glow(id, 0);
		}
	}
}

null_everything()
{
	jail_set_globalinfo(GI_EVENTSTOP, false);
	jail_set_globalinfo(GI_NOFREEBIES, false);
	set_cvar_num("mp_friendlyfire", 0);
	jail_game_update(g_pMyNewGame, g_szGameName, "duel", 1);
	jail_set_globalinfo(GI_GAME, false);

	give_it_one(g_iPlayerDueling[DW_A], 0, 0);
	give_it_one(g_iPlayerDueling[DW_B], 0, 0);
	g_iPlayerDueling[DW_A] = 0;
	g_iPlayerDueling[DW_B] = 0;
	g_iPlayerDueling[DW_TYPE] = 0;
	g_iDuelCounter = 0;
	jail_set_globalinfo(GI_FREEPASS, false);
}

reset_it_all()
{
	jail_ham_all(false);
	my_registered_stuff(false);
	null_everything();
}

my_registered_stuff(val)
{
	if(val)
	{
		for(new i = 0; i < sizeof(g_pHamForwards); i++)
			EnableHamForward(g_pHamForwards[i]);
	}
	else
	{
		for(new i = 0; i < sizeof(g_pHamForwards); i++)
			DisableHamForward(g_pHamForwards[i]);
	}
}

stock give_duel_weaps(id, duel, weapon[])
{
	new weap = ham_give_weapon(id, weapon);
	cs_set_user_bpammo(id, g_iDuelCSW[duel], 1);
	cs_set_weapon_ammo(weap, 1);
}

stock is_duelist(id)
{
	if(id == g_iPlayerDueling[DW_A] || id == g_iPlayerDueling[DW_B])
		return 1;

	return 0;
}

stock get_weapon_owner(ent)
	return get_pdata_cbase(ent, m_pPlayer, LINUX_WEAPON_OFF);

stock my_check(id)
{
	if(jail_get_globalinfo(GI_FREEPASS) == id || simon_or_admin(id))
		return 1;

	return 0;
}

stock check_lr(val=0)
{
	if(jail_get_globalinfo(GI_EVENTSTOP) || jail_get_gamemode() != GAME_STARTED)
		return;

	new num, id;
	static players[32];
	get_players(players, num, "ae", "TERRORIST");
	if(num == 1)
	{
		id = players[0];
		get_players(players, num, "a");
		if(num > 1 && !is_duelist(id))
		{
			if(!jail_get_playerdata(id, PD_WANTED))
			{
				g_iMode = 1;
				jail_game_update(g_pMyNewGame, g_szGameName, "duel", 0);
				jail_day_forceend(jail_get_globalinfo(GI_DAY));
				jail_game_forceend(jail_get_globalinfo(GI_GAME));
				jail_set_globalinfo(GI_FREEPASS, id);

				menu_duel(id);
				return;
			}
			else ColorChat(id, NORMAL, "%s %L", JAIL_TAG, id, "JAIL_GAME1_EXTRA4");
		}
	}
	if(!val)
		g_iMode = 0;
}

stock duel_name(id = LANG_PLAYER)
{
	new duel = g_iPlayerDueling[DW_TYPE];
	static duelname[JAIL_MENUITEM];
	if(duel < DUEL_END)
		formatex(duelname, charsmax(duelname), "%L", id, g_szDuelNames[duel]);
	else ArrayGetArray(g_aDuels, duel-EXTRA_DUEL, duelname);

	return duelname;
}

public _duel_add(plugin, params)
{
	if(params != 1)
		return -1;

	static data[JAIL_MENUITEM];
	get_string(1, data, charsmax(data));

	ArrayPushArray(g_aDuels, data);
	if(!g_iExtraDuels)
		ArrayPushArray(g_aDuels, data);

	g_iExtraDuels++;
	return g_iExtraDuels;
}

public _duel_lastrequest(plugin, params)
	check_lr(1);