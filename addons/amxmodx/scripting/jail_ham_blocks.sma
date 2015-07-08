#include <amxmodx>
#include <engine>
#include <hamsandwich>
#include <cstrike>
#include <jailbreak>

enum _:HAM_REGENERATION
{
	HEB_HEALTH,
	HEB_ARMOR,
	HEB_OTHER
}

new HamHook:g_hhEnabledBlocks[HAM_ENABLE_BLOCK];
new HamHook:g_hhRegenBlocks[HAM_REGENERATION];
new Trie:g_tWeaponGivers, g_iButtons[10];

#if defined JAIL_HAMBOTS
#include <cs_ham_bots_api>
new g_hhEnabledBlocksBots[HAM_ENABLE_BLOCK];
#endif

public plugin_precache()
{
	g_tWeaponGivers = TrieCreate();
}

public plugin_init()
{
	register_plugin("[JAIL] Block hams", JAIL_VERSION, JAIL_AUTHOR);

	g_hhEnabledBlocks[HEB_TRACEATTACK] = RegisterHam(Ham_TraceAttack, "player", "Ham_TraceAttack_pre", 0);
	g_hhEnabledBlocks[HEB_TAKEDAMAGE] = RegisterHam(Ham_TakeDamage, "player", "Ham_TakeDamage_pre", 0);
	g_hhEnabledBlocks[HEB_TOUCH1] = RegisterHam(Ham_Touch, "weaponbox", "Ham_Touch_pre", 0);
	g_hhEnabledBlocks[HEB_TOUCH2] = RegisterHam(Ham_Touch, "armoury_entity", "Ham_Touch_pre", 0);
	g_hhEnabledBlocks[HEB_USE] = RegisterHam(Ham_Use, "func_button", "Ham_Use_pre", 0);
	g_hhEnabledBlocks[HEB_SPAWNWEAPS] = RegisterHam(Ham_Spawn, "weaponbox", "Ham_Spawn_post", 1);

	g_hhRegenBlocks[HEB_HEALTH] = RegisterHam(Ham_Use, "func_healthcharger", "Ham_BlockCharge_pre", 0);
	g_hhRegenBlocks[HEB_ARMOR] = RegisterHam(Ham_Use, "func_recharge", "Ham_BlockCharge_pre", 0);
	g_hhRegenBlocks[HEB_OTHER] = RegisterHam(Ham_TakeHealth, "player", "Ham_TakeHealth_pre", 0);

#if defined JAIL_HAMBOTS
	g_hhEnabledBlocksBots[HEB_TRACEATTACK] = RegisterHamBots(Ham_TraceAttack, "Ham_TraceAttack_pre", 0);
	g_hhEnabledBlocksBots[HEB_TAKEDAMAGE] = RegisterHamBots(Ham_TakeDamage, "Ham_TakeDamage_pre", 0);
	//g_hhEnabledBlocksBots[HEB_TOUCH1] = RegisterHam(Ham_Touch, "weaponbox", "Ham_Touch_pre", 0);
	//g_hhEnabledBlocksBots[HEB_TOUCH2] = RegisterHam(Ham_Touch, "armoury_entity", "Ham_Touch_pre", 0);
	//g_hhEnabledBlocksBots[HEB_USE] = RegisterHam(Ham_Use, "func_button", "Ham_Use_pre", 0);
#endif

	register_clcmd("drop", "cmd_drop");
	ham_disable_all();
	setup_weapongiver();
}

public cmd_drop(id)
{
	if(jail_get_playerdata(id, PD_HAMBLOCK))
		return PLUGIN_HANDLED;

	return PLUGIN_CONTINUE;
}

public plugin_natives()
{
	register_library("jailbreak");
	register_native("jail_ham_specific", "_ham_specific");
	register_native("jail_ham_all", "_ham_all");
}

public pfn_keyvalue(ent)
{
	if(!is_valid_ent(ent))
		return PLUGIN_CONTINUE;

	static classname[32], keyname[32], value[32];
	copy_keyvalue(classname, charsmax(classname), keyname, charsmax(keyname), value, charsmax(value));
	if(!equal(classname, "multi_manager"))
		return PLUGIN_CONTINUE;

	TrieSetCell(g_tWeaponGivers, keyname, ent);
	return PLUGIN_CONTINUE;
}

public Ham_Touch_pre(ent, id)
{
	if(is_valid_ent(ent) && is_user_alive(id))
	{
		if(jail_get_playerdata(id, PD_HAMBLOCK))
			return HAM_SUPERCEDE;
	}

	return HAM_IGNORED;
}

public Ham_TraceAttack_pre(victim, attacker, Float:damage, Float:direction[3], tracehandle, damagebits)
{
	if(is_user_connected(victim) && is_user_connected(attacker) && victim != attacker)
	{
		new CsTeams:teamA = cs_get_user_team(attacker), CsTeams:teamV = cs_get_user_team(victim);
		if(teamA == CS_TEAM_CT && teamV == CS_TEAM_CT)
			return HAM_SUPERCEDE;

		new attHam = jail_get_playerdata(attacker, PD_HAMBLOCK), vicHam = jail_get_playerdata(victim, PD_HAMBLOCK);
		if(!attHam && vicHam || attHam && !vicHam || (!attHam && !vicHam && teamV == teamA))
			return HAM_SUPERCEDE;
	}

	return HAM_IGNORED;
}

public Ham_TakeDamage_pre(victim, inflictor, attacker, Float:damage, bits)
{
	if(is_user_connected(victim) && is_user_connected(attacker) && victim != attacker)
	{
		new CsTeams:teamA = cs_get_user_team(attacker), CsTeams:teamV = cs_get_user_team(victim);
		if(teamA == CS_TEAM_CT && teamV == CS_TEAM_CT)
			return HAM_SUPERCEDE;

		if(bits & (1 << 24))
		{
			new attHam = jail_get_playerdata(attacker, PD_HAMBLOCK), vicHam = jail_get_playerdata(victim, PD_HAMBLOCK);
			if(!attHam && vicHam || attHam && !vicHam || (!attHam && !vicHam && teamV == teamA))
				return HAM_SUPERCEDE;
		}
	}

	return HAM_IGNORED;
}

public Ham_TakeHealth_pre(id, Float:health, bits)
{
	if(jail_get_playerdata(id, PD_HAMBLOCK) && health > 0.0)
		return HAM_SUPERCEDE;

	return HAM_IGNORED;
}

public Ham_BlockCharge_pre(ent, id, idactivator, type, Float:value)
{
	if(jail_get_playerdata(id, PD_HAMBLOCK))
		return HAM_SUPERCEDE;

	return HAM_IGNORED;
}

public Ham_Use_pre(ent, id, idactivator, type, Float:value)
{
	if(type == 2 && value == 1.0)
	{
		if(is_user_alive(id) && !jail_get_playerdata(id, PD_HAMBLOCK))
			return HAM_IGNORED;

		static name[32];
		entity_get_string(ent, EV_SZ_target, name, charsmax(name));
		new newent, i, button;
		while((newent = find_ent_by_tname(newent, name)))
		{
			entity_get_string(newent, EV_SZ_classname, name, charsmax(name));
			for(i = 0; i < sizeof(g_iButtons); i++)
			{
				button = g_iButtons[i];
				if(button == newent)
					return HAM_SUPERCEDE;
			}
		}
	}

	return HAM_IGNORED;
}

public Ham_Spawn_post(ent)
{
	entity_set_int(ent, EV_INT_flags, FL_KILLME);
	call_think(ent);
}

public _ham_all(plugin, params)
{
	if(params != 1)
		return -1;

	new value = get_param(1);
	value == 0 ? ham_disable_all() : ham_enable_all();

	return 1;
}

public _ham_specific(plugin, params)
{
	if(params != 1)
		return -1;

	new ham[HAM_ENABLE_BLOCK];
	get_array(1, ham, HAM_ENABLE_BLOCK);
	ham_specific(ham);

	return 1;
}

public disable_spawn(i)
	DisableHamForward(g_hhEnabledBlocks[i]);

stock ham_disable_all()
{
	for(new i = 0; i < HAM_ENABLE_BLOCK; i++)
	{
		if(i == HEB_SPAWNWEAPS)
			set_task(0.1, "disable_spawn", i);
		else if(i == HEB_REGENAPHP)
		{
			for(new j = 0; j < HAM_REGENERATION; j++)
				DisableHamForward(g_hhRegenBlocks[j]);
		}
		else DisableHamForward(g_hhEnabledBlocks[i]);

		#if defined JAIL_HAMBOTS
		DisableHamForwardBots(g_hhEnabledBlocksBots[i]);
		#endif
	}
}

stock ham_enable_all()
{
	for(new i = 0; i < HAM_ENABLE_BLOCK; i++)
	{
		if(i == HEB_REGENAPHP)
		{
			for(new j = 0; j < HAM_REGENERATION; j++)
				EnableHamForward(g_hhRegenBlocks[j]);
		}
		else EnableHamForward(g_hhEnabledBlocks[i]);

		#if defined JAIL_HAMBOTS
		EnableHamForwardBots(g_hhEnabledBlocksBots[i]);
		#endif
	}
}

stock ham_specific(ham[])
{
	for(new i = 0; i < HAM_ENABLE_BLOCK; i++)
	{
		//log_amx("%d. HAM %d", i, ham[i]);
		if(ham[i] == 1)
		{
			if(i == HEB_REGENAPHP)
			{
				for(new j = 0; j < HAM_REGENERATION; j++)
					EnableHamForward(g_hhRegenBlocks[j]);
			}
			else EnableHamForward(g_hhEnabledBlocks[i]);
			#if defined JAIL_HAMBOTS
			EnableHamForwardBots(g_hhEnabledBlocksBots[i]);
			#endif
		}
		else if(ham[i] == 0)
		{
			if(i == HEB_SPAWNWEAPS)
				set_task(0.1, "disable_spawn");
			else if(i == HEB_REGENAPHP)
			{
				for(new j = 0; j < HAM_REGENERATION; j++)
					DisableHamForward(g_hhRegenBlocks[j]);
			}
			else DisableHamForward(g_hhEnabledBlocks[i]);
			#if defined JAIL_HAMBOTS
			DisableHamForwardBots(g_hhEnabledBlocksBots[i]);
			#endif
		}
	}
}

stock setup_weapongiver()
{
	static info[32];
	new ent, newent, pos;
	while((pos <= sizeof(g_iButtons)) && (ent = find_ent_by_class(ent, "game_player_equip")))
	{
		entity_get_string(ent, EV_SZ_targetname, info, charsmax(info));
		if(!info[0])
			continue;

		if(TrieKeyExists(g_tWeaponGivers, info))
			TrieGetCell(g_tWeaponGivers, info, newent);
		else newent = find_ent_by_target(0, info);
		//log_amx("TEST %s, %d", info, newent);

		if(is_valid_ent(newent) && (in_array(newent, g_iButtons, sizeof(g_iButtons)) < 0))
		{
			g_iButtons[pos] = newent;
			pos++;
			//break;
		}
	}

	TrieDestroy(g_tWeaponGivers);
}

stock in_array(needle, data[], size)
{
	new i;
	for(i = 0; i < size; i++)
		if(data[i] == needle)
			return i;
	return -1;
}