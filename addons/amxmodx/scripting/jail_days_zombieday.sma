#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <hamsandwich>
#include <cstrike>
#include <fun>
#include <cs_teams_api>
#include <jailbreak>
#include <timer_controller>

#define XO_WEAPON			4
#define m_pPlayer			41
#define m_fPainShock		108
#define TASK_BEGIN			1111

new const g_szGiveWeap[][] =
{
  "weapon_ak47",
  "weapon_m4a1",
  "weapon_awp",
  "weapon_m249",
  "weapon_m3"
};

new const g_szNameWeap[][] =
{
  "CV-47",
  "M4A1",
  "Magnum",
  "ES M249",
  "M3"
};

new const g_iAmmoWeap[] =
{
  180,
  180,
  40,
  200,
  40
};

const UNIT_SECOND = (1<<12);
new g_pMyNewDay, g_szDayName[JAIL_MENUITEM];
new g_pMsgScreenFade, g_pMsgDamage, g_pMsgScreenShake, g_pMsgScoreAttrib, g_pMsgDeathMsg;
new g_iInfected[33], CsTeams:g_iPlayerTeam[33], g_iFirstZombie[33];
new cvar_zombie_time_delay, cvar_zombie_health, cvar_zombie_speed, cvar_zombie_gravity, g_iTimeOnClock;
new HamHook:g_pHamHooks[5];
new const g_szModelZombie[] = "heal_zm_v1";
new const g_szModelHands[] = "models/suprjail/v_hands_z.mdl";
new const g_szSoundsScream[][] = {"scientist/c1a0_sci_catscream.wav", "scientist/scream01.wav"};

public plugin_precache()
{
  precache_model(g_szModelHands);
  new model[64];
  formatex(model, charsmax(model), "models/player/%s/%s.mdl", g_szModelZombie, g_szModelZombie);
  precache_model(model);
  precache_sound(g_szSoundsScream[0]);
  precache_sound(g_szSoundsScream[1]);
}

public plugin_init()
{
  register_plugin("[JAIL] Zombie day", JAIL_VERSION, JAIL_AUTHOR);

  cvar_zombie_time_delay = register_cvar("jail_zombie_time_delay", "20.0");
  cvar_zombie_health = register_cvar("jail_zombie_health", "450");
  cvar_zombie_speed = register_cvar("jail_zombie_speed", "300.0");
  cvar_zombie_gravity = register_cvar("jail_zombie_gravity", "0.65");

  DisableHamForward((g_pHamHooks[0] = RegisterHamPlayer(Ham_TraceAttack, "Ham_TraceAttack_pre", 0)));
  DisableHamForward((g_pHamHooks[1] = RegisterHamPlayer(Ham_TakeDamage, "Ham_TakeDamage_pre", 0)));
  DisableHamForward((g_pHamHooks[2] = RegisterHamPlayer(Ham_TakeDamage, "Ham_TakeDamage_post", 1)));
  DisableHamForward((g_pHamHooks[3] = RegisterHam(Ham_Item_Deploy, "weapon_knife", "Ham_Item_Deploy_post", 1)));
  DisableHamForward((g_pHamHooks[4] = RegisterHamPlayer(Ham_Killed, "Ham_Killed_pre", 0)));

  formatex(g_szDayName, charsmax(g_szDayName), "%L", LANG_PLAYER, "JAIL_DAY10");
  g_pMyNewDay = jail_day_add(g_szDayName, "zm", 1);

  g_pMsgScreenFade = get_user_msgid("ScreenFade");
  g_pMsgDeathMsg = get_user_msgid("DeathMsg");
  g_pMsgScoreAttrib = get_user_msgid("ScoreAttrib");
  g_pMsgScreenShake = get_user_msgid("ScreenShake");
  g_pMsgDamage = get_user_msgid("Damage");
}

public client_disconnect(id)
{
  g_iInfected[id] = false;
  g_iFirstZombie[id] = false;
  g_iPlayerTeam[id] = CsTeams:0;
  if(day_equal(g_pMyNewDay))
    end_check();
}

public jail_day_start(simon, day, dayname[])
{
  if(day == g_pMyNewDay)
  {
    start_zombieday(simon);
    return PLUGIN_HANDLED;
  }

  return PLUGIN_CONTINUE;
}

public jail_day_end(simon, day, dayname[])
{
  if(day == g_pMyNewDay)
  {
    end_zombieday(simon, 0);
    return PLUGIN_HANDLED;
  }

  return PLUGIN_CONTINUE;
}

public Ham_TraceAttack_pre(victim, attacker, Float:damage, Float:direction[3], tracehandle, damagebits)
{
  if(is_user_connected(victim) && is_user_connected(attacker) && victim != attacker)
  {
    if(g_iInfected[victim] && g_iInfected[attacker] || !g_iInfected[victim] && !g_iInfected[attacker])
      return HAM_SUPERCEDE;

    if(!g_iInfected[victim] && g_iInfected[attacker])
    {
      make_deathmessage(attacker, victim);
      make_player_infected(victim);

      return HAM_SUPERCEDE;
    }
  }

  return HAM_IGNORED;
}

public Ham_TakeDamage_pre(victim, inflictor, attacker, Float:damage, bits)
{
  if(is_user_connected(victim) && is_user_connected(attacker) && victim != attacker)
  {
    if(bits & (1 << 24))
    {
      if(g_iInfected[victim] && g_iInfected[attacker] || !g_iInfected[victim] && !g_iInfected[attacker])
        return HAM_SUPERCEDE;
    }
  }

  return HAM_IGNORED;
}

public Ham_TakeDamage_post(victim, inflictor, attacker, Float:damage, bits)
{
  if(is_user_alive(victim) && g_iInfected[victim])
    set_pdata_float(victim, m_fPainShock, 1.0);
}

public Ham_Item_Deploy_post(ent)
{
  if(!is_valid_ent(ent))
    return;

  new id = get_pdata_cbase(ent, m_pPlayer, XO_WEAPON);
  if(is_user_alive(id) && g_iInfected[id])
  {
    entity_set_string(id, EV_SZ_viewmodel, g_szModelHands);
    entity_set_string(id, EV_SZ_weaponmodel, "");
  }
}

public Ham_Killed_pre(victim, killer, shouldgib)
{
  if(!is_user_connected(victim))
    return HAM_IGNORED;

  g_iInfected[victim] = false;
  end_check();
  return HAM_IGNORED;
}

public weapon_menu_show(id)
{
  if(is_user_alive(id) && !g_iInfected[id])
  {
    static menu, option[64], data[3];
    menu = menu_create(g_szDayName, "weapon_menu_handle");

    for(new i = 0; i < sizeof(g_szNameWeap); i++)
    {
      formatex(option, charsmax(option), "%s", g_szNameWeap[i]);
      num_to_str(i, data, charsmax(data));
      menu_additem(menu, option, data, 0);
    }

    menu_display(id, menu);
  }
}

public weapon_menu_handle(id, menu, item)
{
  if(item == MENU_EXIT || !is_user_alive(id) || g_iInfected[id])
  {
    menu_destroy(menu);
    return PLUGIN_HANDLED;
  }

  new access, callback, num[3];
  menu_item_getinfo(menu, item, access, num, charsmax(num), _, _, callback);
  menu_destroy(menu);

  new pick = str_to_num(num);
  ham_give_weapon(id, g_szGiveWeap[pick]);
  ham_give_weapon(id, "weapon_deagle");
  cs_set_user_bpammo(id, get_weaponid(g_szGiveWeap[pick]), g_iAmmoWeap[pick]);
  cs_set_user_bpammo(id, CSW_DEAGLE, 35);

  return PLUGIN_HANDLED;
}

public begin_zombieday()
{
  RoundTimerSet(0, g_iTimeOnClock);

  new num, zombie, id;
  static players[32];
  get_players(players, num, "a");

  zombie = num / 5;
  if(zombie < 2)
  {
    if(num > 5)
      zombie = 2;
    else if(num)
      zombie = 1;
  }

  if(!zombie)
  {
    end_zombieday(0, 0);
    return;
  }

  while(zombie)
  {
    id = players[random(num)];
    if(!g_iFirstZombie[id] && !jail_get_playerdata(id, PD_FREEDAY))
    {
      g_iFirstZombie[id] = true;
      make_player_infected(id, 2);
      zombie--;
    }
  }

  ColorChat(0, NORMAL, "%s %L", JAIL_TAG, LANG_PLAYER, "JAIL_DAY10_EXTRA1");

  new i;
  get_players(players, num, "a");
  for(--num; num >= 0; num--)
  {
    i = players[num];
    if(g_iFirstZombie[i]) continue;
    cs_set_player_team(i, CS_TEAM_CT);
  }
}

start_zombieday(simon)
{
  new num, id;
  static players[32];
  get_players(players, num, "a");

  for(--num; num >= 0; num--)
  {
    id = players[num];
    jail_player_crowbar(id, false);
    jail_set_playerdata(id, PD_HAMBLOCK, true);
    jail_set_playerdata(id, PD_REMOVEHE, false);

    strip_weapons(id);
    weapon_menu_show(id);
    g_iPlayerTeam[id] = cs_get_user_team(id);
  }

  my_registered_stuff(true);
  jail_set_globalinfo(GI_EVENTSTOP, true);
  server_event(simon, g_szDayName, false);
  jail_celldoors(simon, TS_OPENED);

  jail_ham_specific({0, 0, 1, 1, 1, 1, 1});
  set_lights("e");

  jail_set_globalinfo(GI_DAY, g_pMyNewDay);

  g_iTimeOnClock = RoundTimerGet()-floatround(jail_get_roundtime());
  RoundTimerSet(0, get_pcvar_num(cvar_zombie_time_delay));
  set_task(get_pcvar_float(cvar_zombie_time_delay), "begin_zombieday", TASK_BEGIN);
}

end_zombieday(simon, type = 0)
{
  if(task_exists(TASK_BEGIN))
  {
    RoundTimerSet(0, g_iTimeOnClock);
    remove_task(TASK_BEGIN);
  }

  new num, id, cvar = get_pcvar_num(get_cvar_pointer("jail_prisoner_grenade")), CsTeams:team;
  static players[32];
  get_players(players, num);

  for(--num; num >= 0; num--)
  {
    id = players[num];
    jail_set_playerdata(id, PD_HAMBLOCK, false);
    team = cs_get_user_team(id);
    if(!cvar && team == CS_TEAM_T)
      jail_set_playerdata(id, PD_REMOVEHE, true);

    cs_reset_user_maxspeed(id);
    set_user_gravity(id, 1.0);
    if(g_iInfected[id])
      make_screenfade(id, 0);
    g_iInfected[id] = false;
    g_iFirstZombie[id] = false;

    if(g_iPlayerTeam[id])
    {
      cs_set_player_team(id, g_iPlayerTeam[id]);
      g_iPlayerTeam[id] = CsTeams:0;
    }

    if(!is_user_bot(id))
      ExecuteHamB(Ham_Item_Deploy, find_ent_by_owner(-1, "weapon_knife", id));

    if(is_user_alive(id))
    {
      if(get_user_health(id) > 100)
        set_user_health(id, 100);

      cs_reset_user_model(id);
      if(team == CS_TEAM_CT)
        cs_set_user_model(id, JAIL_CT_MODEL);
      else if(team == CS_TEAM_T)
        cs_set_user_model(id, JAIL_T_MODEL);

      entity_set_int(id, EV_INT_skin, jail_get_playerdata(id, PD_SKIN));
      ExecuteHamB(Ham_CS_RoundRespawn, id);
    }

    set_task(0.1, "remove_weaps", id);
  }

  jail_set_globalinfo(GI_DAY, false);
  jail_set_globalinfo(GI_EVENTSTOP, false);
  if(!type)
  {
    static servername[64];
    get_cvar_string("hostname" , servername, charsmax(servername));
    ColorChat(0, NORMAL, "%s %L", JAIL_TAG, LANG_PLAYER, "JAIL_DAY10_EXTRA3", servername);
    jail_celldoors(simon, TS_CLOSED);
    //jail_set_winner(2);
    final_end_check();
  }
  else
  {
    jail_set_winner(1);
    ColorChat(0, NORMAL, "%s %L", JAIL_TAG, LANG_PLAYER, "JAIL_DAY10_EXTRA2");
  }

  set_lights("#OFF");
  server_event(simon, g_szDayName, true);
  my_registered_stuff(false);
  jail_ham_all(false);
}

public remove_weaps(id)
  strip_weapons(id);

make_player_infected(id, mul = 1)
{
  g_iInfected[id] = true;
  strip_weapons(id);
  if(!is_user_bot(id))
    ExecuteHamB(Ham_Item_Deploy, find_ent_by_owner(-1, "weapon_knife", id));

  set_user_health(id, get_pcvar_num(cvar_zombie_health) * mul);
  set_user_gravity(id, get_pcvar_float(cvar_zombie_gravity));
  cs_reset_user_maxspeed(id, get_pcvar_float(cvar_zombie_speed));

  cs_set_player_team(id, CS_TEAM_T);
  cs_reset_user_model(id);
  cs_set_user_model(id, g_szModelZombie);
  emit_sound(id, CHAN_VOICE, g_szSoundsScream[random_num(0, charsmax(g_szSoundsScream))], 1.0, ATTN_NORM, 0, PITCH_NORM);
  make_screenfade(id, SF_FADE_IN + SF_FADE_ONLYONE);
  infection_effects(id);

  end_check();
}

end_check()
{
  new num, id, count, alive;
  static players[32];
  get_players(players, num, "a");
  alive = num;
  for(--num; num >= 0; num--)
  {
    id = players[num];
    if(g_iInfected[id])
      count++;
  }

  //log_amx("COUNT %d == %d ALIVE", count, alive);
  if(count == alive || !alive)
    end_zombieday(0, 1);
  else if(!count && alive)
    end_zombieday(0, 0);
}

final_end_check()
{
  new numT, numCT;
  static players[32];
  get_players(players, numT, "ae", "TERRORIST");
  get_players(players, numCT, "ae", "CT");

  if(!numT)
    jail_set_winner(2);
  else if(!numCT)
    jail_set_winner(1);
}

make_deathmessage(attacker, victim)
{
  message_begin(MSG_BROADCAST, g_pMsgDeathMsg);
  write_byte(attacker); // killer
  write_byte(victim); // victim
  write_byte(0); // headshot flag
  write_string("knife"); // killer's weapon
  message_end();

  message_begin(MSG_BROADCAST, g_pMsgScoreAttrib);
  write_byte(victim); // id
  write_byte(0); // attrib
  message_end();
}

make_screenfade(id, type)
{
  message_begin(MSG_ONE_UNRELIABLE, g_pMsgScreenFade, _, id);
  write_short(10000); //duration
  write_short(0); //hold
  write_short(type); //flags (SF_FADE_IN + SF_FADE_ONLYONE) (SF_FADEOUT)
  write_byte(255); //r
  write_byte(0); //g
  write_byte(0); //b
  write_byte(30); //a
  message_end();
}

infection_effects(id)
{
  // From ZP.
  message_begin(MSG_ONE_UNRELIABLE, g_pMsgScreenShake, _, id);
  write_short(UNIT_SECOND*4); // amplitude
  write_short(UNIT_SECOND*2); // duration
  write_short(UNIT_SECOND*10); // frequency
  message_end();

  message_begin(MSG_ONE_UNRELIABLE, g_pMsgDamage, _, id);
  write_byte(0); // damage save
  write_byte(0); // damage take
  write_long(DMG_NERVEGAS); // damage type - DMG_RADIATION
  write_coord(0); // x
  write_coord(0); // y
  write_coord(0); // z
  message_end();

  new origin[3];
  get_user_origin(id, origin);

  message_begin(MSG_PVS, SVC_TEMPENTITY, origin);
  write_byte(TE_IMPLOSION); // TE id
  write_coord(origin[0]); // x
  write_coord(origin[1]); // y
  write_coord(origin[2]); // z
  write_byte(128); // radius
  write_byte(20); // count
  write_byte(3); // duration
  message_end();

  message_begin(MSG_PVS, SVC_TEMPENTITY, origin);
  write_byte(TE_PARTICLEBURST); // TE id
  write_coord(origin[0]); // x
  write_coord(origin[1]); // y
  write_coord(origin[2]); // z
  write_short(50); // radius
  write_byte(70); // color
  write_byte(3); // duration (will be randomized a bit)
  message_end();

  message_begin(MSG_PVS, SVC_TEMPENTITY, origin);
  write_byte(TE_DLIGHT); // TE id
  write_coord(origin[0]); // x
  write_coord(origin[1]); // y
  write_coord(origin[2]); // z
  write_byte(20); // radius
  write_byte(255); // r
  write_byte(0); // g
  write_byte(0); // b
  write_byte(2); // life
  write_byte(0); // decay rate
  message_end();
}

my_registered_stuff(val)
{
  if(val)
  {
    for(new i = 0; i < sizeof(g_pHamHooks); i++)
      EnableHamForward(g_pHamHooks[i]);
  }
  else
  {
    for(new i = 0; i < sizeof(g_pHamHooks); i++)
      DisableHamForward(g_pHamHooks[i]);
  }
}
