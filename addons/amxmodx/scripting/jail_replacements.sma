#include <amxmodx>
#include <hamsandwich>
#include <fakemeta>
#include <engine>
#include <cstrike>
#include <jailbreak>

#define LINUX_WEAPON_OFF			4
#define LINUX_PLAYER_OFF			5
#define m_pPlayer					41
#pragma dynamic 6144

new const g_szCrowbarSound[][] = {"weapons/cbar_hitbod2.wav", "weapons/cbar_hitbod1.wav", "weapons/cbar_miss1.wav"};
new cvar_remove_money, cvar_prisoner_grenade;

public plugin_precache()
{
  new i;
  for(i = 0; i <= charsmax(g_szKnifeModel); i++)
    precache_model(g_szKnifeModel[i]);

  for(i = 0; i <= charsmax(g_szCrowbarSound); i++)
    precache_sound(g_szCrowbarSound[i]);

  //needs improvements.
  new model[40];
  formatex(model, charsmax(model), "models/player/%s/%s.mdl", JAIL_CT_MODEL, JAIL_CT_MODEL);
  precache_model(model);
  formatex(model, charsmax(model), "models/player/%s/%s.mdl", JAIL_T_MODEL, JAIL_T_MODEL);
  precache_model(model);
}

public plugin_init()
{
  register_plugin("[JAIL] Replacements", JAIL_VERSION, JAIL_AUTHOR);

  cvar_remove_money = register_cvar("jail_remove_money", "1");
  cvar_prisoner_grenade = register_cvar("jail_prisoner_grenade", "0");
  register_message(get_user_msgid("TextMsg"), "Message_Block");
  register_event("TeamInfo", "Event_TeamInfo", "a");
  register_forward(FM_EmitSound, "Forward_EmitSound_pre", 0);
  register_forward(FM_GetGameDescription, "Forward_GetGameDescription_pre", 0);

  RegisterHam(Ham_Item_Deploy, "weapon_knife", "Ham_Knife_Deploy_post", 1);
  RegisterHam(Ham_Item_Deploy, "weapon_hegrenade", "Ham_Grenade_Deploy_post", 1);
  RegisterHamPlayer(Ham_Spawn, "Ham_Spawn_post", 1);
}

public jail_gamemode(mode)
{
  if(mode == GAME_ENDED)
  {
    new num, id;
    static players[32];
    get_players(players, num, "a");
    for(--num; num >= 0; num--)
    {
      id = players[num];
      menu_cancel(id);
      show_menu(id, 0, "^n", 1);
    }
    jail_celldoors(0, TS_CLOSED);
  }
}

public plugin_cfg()
{
  if(get_pcvar_num(cvar_remove_money))
    set_msg_block(get_user_msgid("Money"), BLOCK_SET);
}

public Event_TeamInfo()
{
  new id = read_data(1);

  if(!is_user_connected(id))
    return PLUGIN_CONTINUE;

  if(jail_get_playerdata(id, PD_HAMBLOCK))
    return PLUGIN_CONTINUE;

  static team[32];
  read_data(2, team, charsmax(team));


  switch(team[0])
  {
    case 'C': set_player_model(id, JAIL_CT_MODEL, 0);
    case 'T': set_player_model(id, JAIL_T_MODEL, random(3)+2);
  }

  return PLUGIN_CONTINUE;
}

public Message_Block(msgid, dest, id)
{
  if(get_msg_args() > 1)
  {
    static message[128];
    get_msg_arg_string(2, message, charsmax(message));
    if(equal(message, "#Killed_Teammate") || equal(message, "#Game_teammate_kills") || equal(message, "#Game_teammate_attack") || equal(message, "#C4_Plant_At_Bomb_Spot"))
      return PLUGIN_HANDLED;
  }

  return PLUGIN_CONTINUE;
}

public Forward_GetGameDescription_pre()
{
  forward_return(FMV_STRING, "JailBreak Supreme");
  return FMRES_SUPERCEDE;
}

public Forward_EmitSound_pre(id, channel, sample[])
{
  if(!is_user_connected(id))
    return FMRES_IGNORED;

  if(equal(sample, "weapons/knife_", 14) && cs_get_user_team(id) == CS_TEAM_T)
  {
    static model[32];
    entity_get_string(id, EV_SZ_viewmodel, model, charsmax(model));
    if(equal(model, g_szKnifeModel[2]) || equal(model, g_szKnifeModel[1]))
    {
      switch(sample[17])
      {
        case('b'): emit_sound(id, CHAN_WEAPON, g_szCrowbarSound[0], 1.0, ATTN_NORM, 0, PITCH_NORM);
        case('w'): emit_sound(id, CHAN_WEAPON, g_szCrowbarSound[1], 1.0, ATTN_NORM, 0, PITCH_NORM);
        case('1', '2', '3', '4'): emit_sound(id, CHAN_WEAPON, g_szCrowbarSound[0], 1.0, ATTN_NORM, 0, PITCH_NORM);
        case('s'): emit_sound(id, CHAN_WEAPON, g_szCrowbarSound[2], 1.0, ATTN_NORM, 0, PITCH_NORM);
      }
      return FMRES_SUPERCEDE;
    }
  }

  return FMRES_IGNORED;
}

public Ham_Spawn_post(id)
{
  if(is_user_alive(id) && jail_get_gamemode() != GAME_UNSET)
  {
    ham_give_weapon(id, "weapon_knife");
    if(cs_get_user_team(id) == CS_TEAM_CT)
    {
      set_player_model(id, JAIL_CT_MODEL, 0);
    }
    else if(cs_get_user_team(id) == CS_TEAM_T)
    {
      strip_weapons(id);
      if(!jail_get_playerdata(id, PD_FREEDAY))
        set_player_model(id, JAIL_T_MODEL, random(3)+2);
      else set_player_model(id, JAIL_T_MODEL, SKIN_FREEDAY);

      if(!get_pcvar_num(cvar_prisoner_grenade))
        jail_set_playerdata(id, PD_REMOVEHE, true);

      if(!is_user_bot(id))
        ExecuteHamB(Ham_Item_Deploy, find_ent_by_owner(-1, "weapon_knife", id));
    }
  }
}

public Ham_Knife_Deploy_post(ent)
{
  new id = get_weapon_owner(ent);
  if(cs_get_user_team(id) == CS_TEAM_T)
  {
    if(!is_user_bot(id))
      if(cs_get_user_shield(id))
        return;

    if(jail_get_playerdata(id, PD_CROWBAR))
    {
      entity_set_string(id, EV_SZ_viewmodel, g_szKnifeModel[1]);
      entity_set_string(id, EV_SZ_weaponmodel, g_szKnifeModel[0]);
    }
    else
    {
      entity_set_string(id, EV_SZ_viewmodel, g_szKnifeModel[2]);
      entity_set_string(id, EV_SZ_weaponmodel, "");
    }
  }
}

public Ham_Grenade_Deploy_post(ent)
{
  if(pev_valid(ent))
  {
    new id = get_weapon_owner(ent);
    if(is_user_alive(id) && cs_get_user_team(id) == CS_TEAM_T && is_user_alive(id) && !get_pcvar_num(cvar_prisoner_grenade) && jail_get_playerdata(id, PD_REMOVEHE))
    {
      cs_set_user_bpammo(id, CSW_HEGRENADE, 0);
      engclient_cmd(id, "lastinv");
    }
  }
}

get_weapon_owner(ent)
  return get_pdata_cbase(ent, m_pPlayer, LINUX_WEAPON_OFF);

set_player_model(id, model[], skin)
{
  static oldModel[20];
  cs_get_user_model(id, oldModel, charsmax(oldModel));
  if(!equal(oldModel, model))
  {
    cs_reset_user_model(id);
    cs_set_user_model(id, model);
  }

  entity_set_int(id, EV_INT_skin, skin);
  jail_set_playerdata(id, PD_SKIN, skin);
}
