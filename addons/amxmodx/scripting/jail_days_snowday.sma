#include <amxmodx>
#include <hamsandwich>
#include <fakemeta>
#include <cstrike>
#include <engine>
#include <jailbreak>

#define XO_WEAPON			4
#define m_pPlayer			41
#define m_flTimeWeaponIdle	48

new g_pTextMsgForward, g_pSendAudioForward;
new g_pTextMsgID, g_pSendAudioID, g_pSprite;
new HamHook:g_pHamForwards[3];
new cvar_snowday_velocity;
new g_pMyNewDay, g_szDayName[JAIL_MENUITEM];
new const g_szModels[][] = {"models/suprjail/v_snowball.mdl", "models/suprjail/p_snowball.mdl", "models/suprjail/w_snowball.mdl"};

public plugin_precache()
{
  for(new i = 0; i < sizeof(g_szModels); i++)
    precache_model(g_szModels[i]);

  g_pSprite = precache_model("sprites/blood.spr");
  precache_sound("player/pl_snow1.wav");
}

public plugin_init()
{
  register_plugin("[JAIL] Snow day", JAIL_VERSION, JAIL_AUTHOR);

  cvar_snowday_velocity = register_cvar_file("jail_snowday_velocity", "1300", "Snowballs velocity. (Default: 1300)");
  g_pTextMsgID = get_user_msgid("TextMsg");
  g_pSendAudioID = get_user_msgid("SendAudio");

  DisableHamForward((g_pHamForwards[0] = RegisterHam(Ham_Think, "grenade", "Ham_Think_pre", 0)));
  DisableHamForward((g_pHamForwards[1] = RegisterHam(Ham_Touch, "grenade", "Ham_Touch_pre", 0)));
  DisableHamForward((g_pHamForwards[2] = RegisterHam(Ham_Item_Deploy, "weapon_hegrenade", "Ham_Item_Deploy_post", 1)));

  formatex(g_szDayName, charsmax(g_szDayName), "%L", LANG_PLAYER, "JAIL_DAY3");
  g_pMyNewDay = jail_day_add(g_szDayName, "snow", 1);
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
    start_snowday(simon);
    return PLUGIN_HANDLED;
  }

  return PLUGIN_CONTINUE;
}

public jail_day_end(simon, day, dayname[])
{
  if(day == g_pMyNewDay)
  {
    end_snowday(simon);
    return PLUGIN_HANDLED;
  }

  return PLUGIN_CONTINUE;
}

public Ham_Think_pre(ent)
  return HAM_SUPERCEDE;

public Ham_Touch_pre(ent, other)
{
  if(!is_valid_ent(ent))
    return HAM_IGNORED;

  if(is_user_alive(other))
  {
    if(jail_get_playerdata(other, PD_HAMBLOCK))
    {
      new owner = entity_get_edict(ent, EV_ENT_owner);
      //ExecuteHamB(Ham_Killed, other, owner, 0);
      ExecuteHamB(Ham_TakeDamage, other, ent, owner, 300.0, (1 << 24));
    }
  }

  if(is_valid_ent(ent))
  {
    emit_sound(ent, CHAN_AUTO, "player/pl_snow1.wav", 1.0, ATTN_NORM, 0, PITCH_NORM);
    static Float:origin[3];
    entity_get_vector(ent, EV_VEC_origin, origin);
    sw_effect(origin);
    remove_entity(ent);
  }

  return HAM_SUPERCEDE;
}

public Ham_Item_Deploy_post(ent)
{
  if(!is_valid_ent(ent))
    return;

  new id = get_pdata_cbase(ent, m_pPlayer, XO_WEAPON);
  if(is_user_alive(id))
  {
    entity_set_string(id, EV_SZ_viewmodel, g_szModels[0]);
    entity_set_string(id, EV_SZ_weaponmodel, g_szModels[1]);
  }
}

public grenade_throw(id, ent, nade)
{
  if(nade == CSW_HEGRENADE && is_user_alive(id) && day_equal(g_pMyNewDay))
  {
    cs_set_user_bpammo(id, CSW_HEGRENADE, 2);
    static Float:velocity[3];
    VelocityByAim(id, get_pcvar_num(cvar_snowday_velocity), velocity);
    entity_set_vector(ent, EV_VEC_velocity, velocity);

    if(entity_get_float(ent, EV_FL_dmgtime) != 0.0)
      entity_set_model(ent, g_szModels[2]);
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

start_snowday(simon)
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

  server_event(simon, g_szDayName, 0);
  jail_celldoors(simon, TS_OPENED);
  jail_ham_specific({1, 1, 1, 1, 1, 0, 0});
  set_cvar_num("mp_friendlyfire", 1);

  jail_set_globalinfo(GI_DAY, g_pMyNewDay);
}

end_snowday(simon)
{
  new num, id;
  static players[32];
  get_players(players, num);

  for(--num; num >= 0; num--)
  {
    id = players[num];
    jail_set_playerdata(id, PD_HAMBLOCK, false);
    if(cs_get_user_team(id) == CS_TEAM_T)
      jail_set_playerdata(id, PD_REMOVEHE, true);

    strip_weapons(id);
    ham_give_weapon(id, "weapon_knife", 1);
  }

  server_event(simon, g_szDayName, 1);
  my_registered_stuff(false);
  set_cvar_num("mp_friendlyfire", 0);
  jail_ham_all(false);
  jail_set_globalinfo(GI_DAY, false);
  //remove_entity_name("grenade"); crash
  move_grenade();
}

public set_player_attributes(id)
{
  jail_player_crowbar(id, false);
  jail_set_playerdata(id, PD_HAMBLOCK, true);
  jail_set_playerdata(id, PD_REMOVEHE, false);

  strip_weapons(id);
  ham_give_weapon(id, "weapon_hegrenade", 1);
}

my_registered_stuff(val)
{
  if(val)
  {
    g_pTextMsgForward	= register_message(g_pTextMsgID, "Block_Text");
    g_pSendAudioForward = register_message(g_pSendAudioID, "Block_Audio");
    for(new i = 0; i < sizeof(g_pHamForwards); i++)
      EnableHamForward(g_pHamForwards[i]);
  }
  else
  {
    unregister_message(g_pTextMsgID, g_pTextMsgForward);
    unregister_message(g_pSendAudioID, g_pSendAudioForward);
    for(new i = 0; i < sizeof(g_pHamForwards); i++)
      DisableHamForward(g_pHamForwards[i]);
  }
}

sw_effect(Float:fOrigin[3])
{
  new origin[3];
  FVecIVec(fOrigin, origin);

  message_begin(MSG_BROADCAST, SVC_TEMPENTITY);
  write_byte(TE_BLOODSPRITE);
  write_coord(origin[0]);
  write_coord(origin[1]);
  write_coord(origin[2]);
  write_short(g_pSprite);
  write_short(g_pSprite);
  write_byte(160);
  write_byte(10);
  message_end();
}
