#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <cstrike>
#include <engine>
#include <jailbreak>

#define XO_WEAPON					4
#define m_pPlayer					41

enum
{
	SEQ_IDLE,
	SEQ_FIRE,
	SEQ_RELOAD,
	SEQ_DRAW
}

new g_pMyNewDuel, g_szDuelName[JAIL_MENUITEM], g_iDuelist[2];

new cvar_rpg_velocity, cvar_rpg_multi;
new g_pRocketFollowSpr, Float:g_fBlockDeploy[33], g_iGrenadeExplode[33], g_iNadeMode[33];
new const g_szRPGModels[][] = {"models/suprjail/v_rpg.mdl", "models/p_rpg.mdl", "models/rpgrocket.mdl"};
new const g_szRPGSounds[] = {"weapons/rocketfire1.wav"};
new HamHook:g_pHamForwards[7], g_pForwardUpdateClientData, g_pForwardAddToFullPack, g_pMessageTextMsg, g_pMessageSendAudio;
new g_pMsg_TextMsg, g_pMsg_SendAudio;

public plugin_precache()
{
	for(new i = 0; i < sizeof(g_szRPGModels); i++)
		precache_model(g_szRPGModels[i]);
	precache_sound(g_szRPGSounds);

	g_pRocketFollowSpr = precache_model("sprites/smoke.spr");
}

public plugin_init()
{
	register_plugin("[JAIL] Duel extra: RPG", JAIL_VERSION, JAIL_AUTHOR);

	cvar_rpg_velocity = register_cvar("jail_rpg_velocity", "800");
	cvar_rpg_multi = register_cvar("jail_rpg_multi", "1.1");

	DisableHamForward((g_pHamForwards[0] = RegisterHam(Ham_Think, "grenade", "Ham_Think_pre", 1)));
	DisableHamForward((g_pHamForwards[1] = RegisterHam(Ham_Think, "grenade", "Ham_Think_post", 1)));
	DisableHamForward((g_pHamForwards[2] = RegisterHam(Ham_Touch, "grenade", "Ham_Touch_pre", 0)));
	DisableHamForward((g_pHamForwards[3] = RegisterHam(Ham_TakeDamage, "player", "Ham_TakeDamage_pre", 0)));
	DisableHamForward((g_pHamForwards[4] = RegisterHam(Ham_Item_Deploy, "weapon_hegrenade", "Ham_Item_Deploy_post", 1)));
	DisableHamForward((g_pHamForwards[5] = RegisterHam(Ham_Weapon_PrimaryAttack, "weapon_hegrenade", "Ham_PrimaryAttack_pre", 0)));
	DisableHamForward((g_pHamForwards[6] = RegisterHam(Ham_Weapon_SecondaryAttack, "weapon_hegrenade", "Ham_SecondaryAttack_post", 1)));

	g_pMsg_TextMsg = get_user_msgid("TextMsg");
	g_pMsg_SendAudio = get_user_msgid("SendAudio");

	formatex(g_szDuelName, charsmax(g_szDuelName), "%L", LANG_PLAYER, "JAIL_DUEL0");
	g_pMyNewDuel = jail_duel_add(g_szDuelName);
}

public jail_duel_start(simon, duel, AID, BID)
{
	if(duel == g_pMyNewDuel)
	{
		g_iDuelist[0] = AID;
		g_iDuelist[1] = BID;
		start_duel();
		return PLUGIN_HANDLED;
	}

	return PLUGIN_CONTINUE;
}

public jail_duel_end(simon, duel, AID, BID)
{
	if(duel == g_pMyNewDuel)
	{
		end_duel();
		return PLUGIN_HANDLED;
	}

	return PLUGIN_CONTINUE;
}

public grenade_throw(id, ent, nade)
{
	if(is_valid_ent(ent))
	{
		if(duel_equal(g_pMyNewDuel) && nade == CSW_HEGRENADE && is_user_alive(id) && is_duelist(id))
		{
			static Float:velocity[3];
			VelocityByAim(id, get_pcvar_num(cvar_rpg_velocity), velocity);
			entity_set_vector(ent, EV_VEC_velocity, velocity);

			beam_follow(ent);
			entity_set_model(ent, g_szRPGModels[2]);
			cs_set_user_bpammo(id, CSW_HEGRENADE, 2);

			emit_sound(ent, CHAN_WEAPON, g_szRPGSounds, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);

			entity_set_float(ent, EV_FL_dmgtime, get_gametime() + 999999.0);
			entity_set_float(ent, EV_FL_nextthink, get_gametime());

			if(g_iNadeMode[id] == -1)
			{
				g_iNadeMode[id] = ent;
				attach_view(id, ent);
			}
		}
	}
}

public Forward_AddToFullPack_post(es_handle, e, ent, host, hostflags, id, pSet) 
{
	if(id && is_duelist(ent))
	{
		new seq = get_es(es_handle, ES_Sequence);
		if(seq > 55 && seq < 60)
		{
			seq -= 14;
			if(seq >= 44)
				seq++;

			set_es(es_handle, ES_Sequence, seq);
		}
	}
}

public Forward_UpdateClientData_post(id, sendweapons, cd_handle)
{
	if(!is_user_alive(id) || get_user_weapon(id) != CSW_HEGRENADE || !is_duelist(id))
		return FMRES_IGNORED;

	if(!g_fBlockDeploy[id] && get_cd(cd_handle, CD_WeaponAnim) == SEQ_RELOAD)
		g_fBlockDeploy[id] = halflife_time() + 2.0;
	
	if(g_fBlockDeploy[id] > halflife_time())
	{
		set_cd(cd_handle, CD_WeaponAnim, SEQ_RELOAD);
		set_cd(cd_handle, CD_flNextAttack, g_fBlockDeploy[id]+1.0);
	}
	else if(g_fBlockDeploy[id])
	{
		g_fBlockDeploy[id] = 0.0;
		set_cd(cd_handle, CD_WeaponAnim, SEQ_IDLE);
	}

	if(!g_fBlockDeploy[id] && get_cd(cd_handle, CD_WeaponAnim) == SEQ_DRAW)
		set_cd(cd_handle, CD_WeaponAnim, SEQ_IDLE);
	
	return FMRES_HANDLED;
}

public Ham_Think_pre(ent)
{
	if(!is_valid_ent(ent) || GetGrenadeType(ent) != CSW_HEGRENADE)
		return HAM_IGNORED;

	new id = entity_get_edict(ent, EV_ENT_owner);
	if(!is_duelist(id))
		return HAM_IGNORED;

	static Float:velocity[3], Float:angles[3];
	VelocityByAim(id, get_pcvar_num(cvar_rpg_velocity), velocity);
	entity_set_vector(ent, EV_VEC_velocity, velocity);

	if(!is_valid_ent(g_iNadeMode[id]))
		vector_to_angle(velocity, angles);
	else entity_get_vector(id, EV_VEC_v_angle, angles);
	entity_set_vector(ent, EV_VEC_angles, angles);
	entity_set_float(ent, EV_FL_nextthink, get_gametime());

	if(g_iGrenadeExplode[id] != ent)
		return HAM_SUPERCEDE;

	return HAM_HANDLED;
}
public Ham_Think_post(ent)
{
	if(!is_valid_ent(ent) || GetGrenadeType(ent) != CSW_HEGRENADE)
		return HAM_IGNORED;

	new id = entity_get_edict(ent, EV_ENT_owner);
	if(!is_duelist(id))
		return HAM_IGNORED;

	if(g_iGrenadeExplode[id] == ent)
	{
		g_iGrenadeExplode[id] = false;

		if(is_valid_ent(g_iNadeMode[id]))
		{
			attach_view(id, id);
			g_iNadeMode[id] = -1;
		}
	}

	return HAM_HANDLED;
}

public Ham_Touch_pre(ent, id)
{
	if(!is_valid_ent(ent) || GetGrenadeType(ent) != CSW_HEGRENADE)
		return HAM_IGNORED;

	new owner = entity_get_edict(ent, EV_ENT_owner);
	if(!is_duelist(owner))
		return HAM_IGNORED;

	entity_set_float(ent, EV_FL_dmgtime, get_gametime());
	g_iGrenadeExplode[owner] = ent;
	call_think(ent);

	return HAM_HANDLED;
}

public Ham_TakeDamage_pre(victim, inflictor, attacker, Float:damage, bits)
{
	if(is_duelist(attacker) && is_duelist(victim) && bits & (1 << 24))
	{
		damage *= get_pcvar_float(cvar_rpg_multi);
		SetHamParamFloat(4, damage);
		return HAM_HANDLED;
	}

	return HAM_IGNORED;
}

public Ham_Item_Deploy_post(ent)
{
	if(!is_valid_ent(ent))
		return;

	new id = get_pdata_cbase(ent, m_pPlayer, XO_WEAPON);
	if(is_user_alive(id) && is_duelist(id))
	{
		entity_set_string(id, EV_SZ_viewmodel, g_szRPGModels[0]);
		entity_set_string(id, EV_SZ_weaponmodel, g_szRPGModels[1]);
	}
}

public Ham_PrimaryAttack_pre(ent)
{
	if(!is_valid_ent(ent))
		return HAM_IGNORED;

	new id = get_pdata_cbase(ent, m_pPlayer, XO_WEAPON);
	if(is_valid_ent(g_iNadeMode[id]))
		return HAM_SUPERCEDE;

	if(is_duelist(id) && g_fBlockDeploy[id] && g_fBlockDeploy[id] > halflife_time())
		return HAM_SUPERCEDE;

	return HAM_IGNORED;
}

public Ham_SecondaryAttack_post(ent)
{
	if(!is_valid_ent(ent))
		return;

	new id = get_pdata_cbase(ent, m_pPlayer, XO_WEAPON);
	static Float:time;
	if(is_duelist(id) && time < get_gametime())
	{
		if(g_iNadeMode[id])
		{
			if(is_valid_ent(g_iNadeMode[id]))
				attach_view(id, id);
			g_iNadeMode[id] = 0;
			client_print(id, print_center, "%L", id, "JAIL_DUEL0_EXTRA1");
		}
		else
		{
			g_iNadeMode[id] = -1;
			client_print(id, print_center, "%L", id, "JAIL_DUEL0_EXTRA2");
		}
		time = get_gametime() + 0.5;
	}
}

public Block_Text()
{
	if(get_msg_args() != 5 || get_msg_argtype(3) != ARG_STRING || get_msg_argtype(5) != ARG_STRING)
		return PLUGIN_CONTINUE;
	
	static message[20];
	get_msg_arg_string(5, message, charsmax(message));
	if(equal(message, "#Fire_in_the_hole"))
		return PLUGIN_HANDLED;

	return PLUGIN_CONTINUE;
}

public Block_Audio()
{
	if(get_msg_args() != 3 || get_msg_argtype(2) != ARG_STRING)
		return PLUGIN_CONTINUE;

	static sound[20];
	get_msg_arg_string(2, sound, charsmax(sound));
	if(equal(sound[1], "!MRAD_FIREINHOLE"))
		return PLUGIN_HANDLED;

	return PLUGIN_CONTINUE;
}

stock beam_follow(ent)
{
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY);
	write_byte(TE_BEAMFOLLOW);
	write_short(ent);
	write_short(g_pRocketFollowSpr);
	write_byte(30);
	write_byte(3);
	write_byte(255);
	write_byte(255);
	write_byte(255);
	write_byte(255);
	message_end();
}

stock GetGrenadeType(ent)
{
	if (get_pdata_int(ent, 96) & (1<<8))
		return CSW_C4;

	new bits = get_pdata_int(ent, 114);
	if (bits & (1<<0))
		return CSW_HEGRENADE;
	else if (bits & (1<<1))
		return CSW_SMOKEGRENADE;
	else if (!bits)
		return CSW_FLASHBANG;

	return 0;
}

start_duel()
{
	my_registered_stuff(true);
	jail_set_globalinfo(GI_DUEL, g_pMyNewDuel);
	give_duel(g_iDuelist[0], true);
	give_duel(g_iDuelist[1], true);
	jail_ham_all(true);
}

end_duel()
{
	jail_set_globalinfo(GI_DUEL, false);
	give_duel(g_iDuelist[0], false);
	give_duel(g_iDuelist[1], false);
	g_iDuelist[0] = false;
	g_iDuelist[1] = false;
	my_registered_stuff(false);
	jail_ham_all(false);
	//remove_entity_name("grenade"); crash
	move_grenade();
}

give_duel(id, val)
{
	strip_weapons(id);
	if(val)
	{
		jail_set_playerdata(id, PD_REMOVEHE, false);
		ham_give_weapon(id, "weapon_hegrenade", true);
	}
	else
	{
		g_iGrenadeExplode[id] = false;
		g_iNadeMode[id] = false;
		attach_view(id, id);
	}
}

my_registered_stuff(val)
{
	if(val)
	{
		g_pForwardAddToFullPack	= register_forward(FM_AddToFullPack, "Forward_AddToFullPack_post", 1);
		g_pForwardUpdateClientData = register_forward(FM_UpdateClientData, "Forward_UpdateClientData_post", 1);
		g_pMessageTextMsg = register_message(g_pMsg_TextMsg, "Block_Text");
		g_pMessageSendAudio = register_message(g_pMsg_SendAudio, "Block_Audio");
		for(new i = 0; i < sizeof(g_pHamForwards); i++)
			EnableHamForward(g_pHamForwards[i]);
	}
	else
	{
		unregister_forward(FM_AddToFullPack, g_pForwardAddToFullPack, 1);
		unregister_forward(FM_UpdateClientData, g_pForwardUpdateClientData, 1);
		unregister_message(g_pMsg_TextMsg, g_pMessageTextMsg);
		unregister_message(g_pMsg_SendAudio, g_pMessageSendAudio);
		for(new i = 0; i < sizeof(g_pHamForwards); i++)
			DisableHamForward(g_pHamForwards[i]);
	}
}

is_duelist(id)
{
	if(id == g_iDuelist[0] || id == g_iDuelist[1])
		return 1;

	return 0;
}