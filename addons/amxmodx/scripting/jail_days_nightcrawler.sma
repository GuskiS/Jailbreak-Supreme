#include <amxmodx>
#include <cstrike>
#include <fakemeta>
#include <hamsandwich>
#include <fun>
#include <jailbreak>

new g_pMyNewDay, g_szDayName[JAIL_MENUITEM];
new Float:g_fWallOrigin[33][3], g_iPlayerCrawler[33], g_iSimonSteps;
new g_pAddToFullPackForward, g_pPlayerPreThinkForward;
new HamHook:g_pHamForwards[3], g_iRemoveFull;

public plugin_init()
{
	register_plugin("[JAIL] Nightcrawler day", JAIL_VERSION, JAIL_AUTHOR);
	DisableHamForward((g_pHamForwards[0] = RegisterHam(Ham_Touch, "worldspawn", "Ham_Touch_pre", 0)));
	DisableHamForward((g_pHamForwards[1] = RegisterHam(Ham_Touch, "func_wall", "Ham_Touch_pre", 0)));
	DisableHamForward((g_pHamForwards[2] = RegisterHam(Ham_TakeDamage, "player", "Ham_TakeDamage_pre", 0)));

	formatex(g_szDayName, charsmax(g_szDayName), "%L", LANG_PLAYER, "JAIL_DAY5");
	g_pMyNewDay = jail_day_add(g_szDayName, "nc", 1);
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
		start_nightcrawler(simon);
		return PLUGIN_HANDLED;
	}

	return PLUGIN_CONTINUE;
}

public jail_day_end(simon, day, dayname[])
{
	if(day == g_pMyNewDay)
	{
		end_nightcrawler(simon);
		return PLUGIN_HANDLED;
	}

	return PLUGIN_CONTINUE;
}

public Ham_TakeDamage_pre(id, inflictor, attacker, Float:damage, damagetype)
{
	if(damagetype & DMG_FALL && g_iPlayerCrawler[id])
		return HAM_SUPERCEDE;

	return HAM_IGNORED;
}

public Ham_Touch_pre(ent, id)
{
	if(!is_user_alive(id))
		return HAM_IGNORED;

	pev(id, pev_origin, g_fWallOrigin[id]);
	return HAM_IGNORED;
}

public Forward_AddToFullPack_post(es_handle, e, ent, host, hostflags, id, pSet) 
{
	static CsTeams:team;
	if(!team)
		team = get_reverse_state();

	if(id && cs_get_user_team(host) == cs_get_user_team(ent) && cs_get_user_team(ent) == team) 
	{
		if(!g_iRemoveFull)
		{
			set_es(es_handle, ES_RenderMode, kRenderTransTexture);
			set_es(es_handle, ES_RenderAmt, 255);
		}
		else
		{
			set_es(es_handle, ES_RenderMode, kRenderNormal);
			set_es(es_handle, ES_RenderAmt, 0);
		}
	}
}

public Forward_PlayerPreThink_pre(id)
{
	if(!g_iPlayerCrawler[id])
		return FMRES_IGNORED;

	static Float:origin[3];
	pev(id, pev_origin, origin);

	if(get_distance_f(origin, g_fWallOrigin[id]) > 25.0)
		return FMRES_IGNORED;

	if(pev(id, pev_flags) & FL_ONGROUND)
		return FMRES_IGNORED;

	new vel, button = pev(id, pev_button);
	if(button & IN_FORWARD)
		vel = 240;
	else if(button & IN_BACK)
		vel = -240;

	if(vel)
	{
		static Float:velocity[3];
		velocity_by_aim(id, vel, velocity);
		set_pev(id, pev_velocity, velocity);
	}

	return FMRES_IGNORED;
}

start_nightcrawler(simon)
{
	new num, id;
	static players[32];
	get_players(players, num, "a");
	my_registered_stuff(true);

	for(--num; num >= 0; num--)
	{
		id = players[num];
		if(jail_get_playerdata(id, PD_FREEDAY)) continue;
		set_player_attributes(id);
	}

	jail_celldoors(simon, TS_OPENED);
	server_event(simon, g_szDayName, 0);

	jail_ham_specific({1, 1, 1, 1, 1, 0, 1});
	jail_set_globalinfo(GI_EVENTSTOP, true);
	jail_set_globalinfo(GI_BLOCKDOORS, true);
	g_iSimonSteps = get_pcvar_num(get_cvar_pointer("jail_simon_steps"));
	if(g_iSimonSteps)
		set_pcvar_num(get_cvar_pointer("jail_simon_steps"), !g_iSimonSteps);

	jail_set_globalinfo(GI_DAY, g_pMyNewDay);
}

end_nightcrawler(simon)
{
	new num, id;
	static players[32];
	get_players(players, num);
	my_registered_stuff(false);
	jail_ham_all(false);

	for(--num; num >= 0; num--)
	{
		id = players[num];
		jail_set_playerdata(id, PD_HAMBLOCK, false);
		jail_set_playerdata(id, PD_INVISIBLE, false);

		strip_weapons(id);
		set_user_rendering(id);
		set_user_footsteps(id, 0);
		if(is_user_alive(id))
			cs_set_user_armor(id, 0, CsArmorType:CS_ARMOR_NONE);
		g_iPlayerCrawler[id] = false;
	}

	server_event(simon, g_szDayName, 1);
	jail_set_globalinfo(GI_DAY, false);
	jail_set_globalinfo(GI_BLOCKDOORS, false);
	jail_set_globalinfo(GI_EVENTSTOP, false);
	server_cmd("mp_footsteps 1");
	if(g_iSimonSteps)
		set_pcvar_num(get_cvar_pointer("jail_simon_steps"), g_iSimonSteps);
}

my_registered_stuff(val)
{
	if(val)
	{
		g_iRemoveFull = false;
		g_pAddToFullPackForward	= register_forward(FM_AddToFullPack, "Forward_AddToFullPack_post", 1);
		g_pPlayerPreThinkForward = register_forward(FM_PlayerPreThink, "Forward_PlayerPreThink_pre", 0);
		for(new i = 0; i < sizeof(g_pHamForwards); i++)
			EnableHamForward(g_pHamForwards[i]);
	}
	else
	{
		g_iRemoveFull = true;
		unregister_forward(FM_AddToFullPack, g_pAddToFullPackForward, 1);
		unregister_forward(FM_PlayerPreThink, g_pPlayerPreThinkForward, 0);
		for(new i = 0; i < sizeof(g_pHamForwards); i++)
			DisableHamForward(g_pHamForwards[i]);
	}
}

public set_player_attributes(id)
{
	jail_player_crowbar(id, false);

	strip_weapons(id);
	set_user_health(id, 100);

	jail_set_playerdata(id, PD_HAMBLOCK, true);
	if(cs_get_user_team(id) == get_reverse_state())
	{								
		jail_set_playerdata(id, PD_INVISIBLE, true);
		set_user_rendering(id, kRenderFxGlowShell, 0, 0, 0, kRenderTransAlpha, 0);
		set_user_footsteps(id, 1);
		g_iPlayerCrawler[id] = true;
		cs_set_user_armor(id, 100, CsArmorType:CS_ARMOR_VESTHELM);
	}
	else
	{
		ham_give_weapon(id, "weapon_m4a1", 1);
		ham_give_weapon(id, "weapon_deagle");
		
		cs_set_user_bpammo(id, CSW_M4A1, 180);
		cs_set_user_bpammo(id, CSW_DEAGLE, 35);
	}

}