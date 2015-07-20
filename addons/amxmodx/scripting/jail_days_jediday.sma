#include <amxmodx>
#include <cstrike>
#include <fakemeta>
#include <hamsandwich>
#include <fun>
#include <jailbreak>

#define LINUX_WEAPON_OFF			4
#define m_pPlayer					41
#define MIN_DISTANCE				90
#define MAX_DISTANCE				140

enum _:GRAB_INFO
{
  GRAB_GRABBED,
  GRAB_GRABBER,
  GRAB_LEN,
  GRAB_THROWN
}

new const g_szOldSounds[][] =
{
  "weapons/knife_deploy1.wav",	// Deploy Sound (knife_deploy1.wav)
  "weapons/knife_hit1.wav",		// Hit 1 (knife_hit1.wav)
  "weapons/knife_hit2.wav",		// Hit 2 (knife_hit2.wav)
  "weapons/knife_hit3.wav",		// Hit 3 (knife_hit3.wav)
  "weapons/knife_hit4.wav",		// Hit 4 (knife_hit4.wav)
  "weapons/knife_hitwall1.wav",	// Hit Wall (knife_hitwall1.wav)
  "weapons/knife_slash1.wav",		// Slash 1 (knife_slash1.wav)
  "weapons/knife_slash2.wav",		// Slash 2 (knife_slash2.wav)
  "weapons/knife_stab.wav"		// Stab (knife_stab.wav)
};

new const g_szNewSounds[][] =
{
  "suprjail/jedi_deploy1.wav",	// Deploy Sound (knife_deploy1.wav)
  "suprjail/jedi_hit1.wav",		// Hit 1 (knife_hit1.wav)
  "suprjail/jedi_hit2.wav",		// Hit 2 (knife_hit2.wav)
  "suprjail/jedi_hit3.wav",		// Hit 3 (knife_hit3.wav)
  "suprjail/jedi_hit4.wav",		// Hit 4 (knife_hit4.wav)
  "suprjail/jedi_hitwall1.wav",	// Hit Wall (knife_hitwall1.wav)
  "suprjail/jedi_slash1.wav",		// Slash 1 (knife_slash1.wav)
  "suprjail/jedi_slash2.wav",		// Slash 2 (knife_slash2.wav)
  "suprjail/jedi_stab.wav"		// Stab (knife_stab.wav)
};

new g_iPlayerData[33][GRAB_INFO];

new g_pMyNewDay, g_szDayName[JAIL_MENUITEM], g_pSprite, g_iKiller[33];
new HamHook:g_pHamHooks[2], g_pForwardPlayerPreThink, g_pForwardEmitSound;
new const g_szJediKnife[][] = {"models/suprjail/p_jedi.mdl", "models/suprjail/v_jedi.mdl", "models/suprjail/p_jedi_red.mdl", "models/suprjail/v_jedi_red.mdl"};
new cvar_jedi_maxspeed, cvar_jedi_gravity, cvar_jedi_hp;
new Float:g_fDefaultMaxSpeed, g_iCTHP, g_iTHP;

public plugin_precache()
{
  g_pSprite = precache_model("sprites/lgtning.spr");
  for(new i = 0; i < sizeof(g_szJediKnife); i++)
    precache_model(g_szJediKnife[i]);
  for(new i = 0; i < sizeof(g_szNewSounds); i++)
    precache_sound(g_szNewSounds[i]);
}

public plugin_init()
{
  register_plugin("[JAIL] Jedi day", JAIL_VERSION, JAIL_AUTHOR);

  cvar_jedi_maxspeed  = my_register_cvar("jail_jedi_maxspeed",  "290.0",  "Jedi speed. (Default: 290.0)");
  cvar_jedi_gravity   = my_register_cvar("jail_jedi_gravity",   "0.5",    "Jedi gravity. (Default: 0.5)");
  cvar_jedi_hp        = my_register_cvar("jail_jedi_hp",        "50",     "Jedi health. (Default: 50)");

  DisableHamForward((g_pHamHooks[0] = RegisterHamPlayer(Ham_Killed, "Ham_Killed_pre", 0)));
  DisableHamForward((g_pHamHooks[1] = RegisterHam(Ham_Item_Deploy, "weapon_knife", "Ham_Item_Deploy_post", 1)));

  formatex(g_szDayName, charsmax(g_szDayName), "%L", LANG_PLAYER, "JAIL_DAY7");
  g_pMyNewDay = jail_day_add(g_szDayName, "jedi", 1);
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
    start_jediday(simon);
    return PLUGIN_HANDLED;
  }

  return PLUGIN_CONTINUE;
}

public jail_day_end(simon, day, dayname[])
{
  if(day == g_pMyNewDay)
  {
    end_jediday(simon);
    return PLUGIN_HANDLED;
  }

  return PLUGIN_CONTINUE;
}

public Forward_PlayerPreThink_pre(id)
{
  if(!is_user_alive(id))
    return FMRES_IGNORED;

  //Search for a target
  new target;
  if(g_iPlayerData[id][GRAB_GRABBED] == -1)
  {
    new Float:orig[3], Float:ret[3];
    get_view_pos(id, orig);
    ret = vel_by_aim(id, 9999);

    ret[0] += orig[0];
    ret[1] += orig[1];
    ret[2] += orig[2];
    target = traceline(orig, ret, id, ret);

    if(is_user_alive(target))
    {
      if(is_grabbed(target, id))
        return FMRES_IGNORED;
      set_grabbed(id, target);
    }
  }

  //If they've grabbed something
  target = g_iPlayerData[id][GRAB_GRABBED];
  if(!is_user_alive(target))
  {
    unset_grabbed(id);
    return FMRES_IGNORED;
  }
  else grab_think(id);

  return FMRES_IGNORED;
}

public Forward_EmitSound_pre(id, channel, sample[])
{
  if(!is_user_connected(id) || !jail_get_playerdata(id, PD_HAMBLOCK))
    return FMRES_IGNORED;

  if(equal(sample, "common/wpn_denyselect.wav"))
  {
    new target, body;
    get_user_aiming(id, target, body, MAX_DISTANCE);
    if(is_user_alive(target) && (cs_get_user_team(id) == get_reverse_state() || g_iKiller[id])
    && cs_get_user_team(target) != cs_get_user_team(id) && jail_get_playerdata(id, PD_HAMBLOCK))
    {
      if(g_iPlayerData[target][GRAB_GRABBED] == id)
        unset_grabbed(target);
      else g_iPlayerData[id][GRAB_GRABBED] = -1;
    }
  }
  else
  {
    for(new i = 0; i < sizeof g_szNewSounds; i++)
    {
      if(equal(sample, g_szOldSounds[i]))
      {
        emit_sound(id, channel, g_szNewSounds[i], 1.0, ATTN_NORM, 0, PITCH_NORM);
        return FMRES_SUPERCEDE;
      }
    }
  }

  return FMRES_IGNORED;
}

public Ham_Player_ResetMaxSpeed_post(id)
{
  if(is_user_alive(id))
    set_user_maxspeed(id, get_pcvar_float(cvar_jedi_maxspeed));

  return HAM_HANDLED;
}

public Ham_Item_Deploy_post(ent)
{
  new id = get_weapon_owner(ent);
  if(is_user_alive(id) && jail_get_playerdata(id, PD_HAMBLOCK))
  {
    if(cs_get_user_team(id) == CS_TEAM_CT)
    {
      set_pev(id, pev_weaponmodel2, g_szJediKnife[0]);
      set_pev(id, pev_viewmodel2, g_szJediKnife[1]);
    }
    else
    {
      set_pev(id, pev_weaponmodel2, g_szJediKnife[2]);
      set_pev(id, pev_viewmodel2, g_szJediKnife[3]);
    }
  }
}

public Ham_Killed_pre(victim, killer, shouldgib)
{
  if(!is_user_connected(victim))
    return HAM_IGNORED;

  new type = g_iPlayerData[victim][GRAB_THROWN];
  if(!type)
    type = g_iPlayerData[victim][GRAB_GRABBER];
  if(!is_user_connected(killer) && type)
  {
    SetHamParamEntity(2, type);
    SetHamParamInteger(3, 2);
    killer = type;
  }

  if(cs_get_user_team(victim) == get_reverse_state())
    if(is_user_connected(killer))
      g_iKiller[killer] = true;

  unset_grabbed(victim);
  return HAM_IGNORED;
}

start_jediday(simon)
{
  calculate_hp(g_iCTHP, g_iTHP);
  new num, id;
  static players[32];
  get_players(players, num, "a");

  my_ham_hooks(true);
  for(--num; num >= 0; num--)
  {
    id = players[num];
    if(jail_get_playerdata(id, PD_FREEDAY)) continue;
    set_player_attributes(id);
  }

  g_fDefaultMaxSpeed = get_cvar_float("sv_maxspeed");
  set_cvar_float("sv_maxspeed", get_pcvar_float(cvar_jedi_maxspeed));
  server_event(simon, g_szDayName, false);
  jail_set_globalinfo(GI_BLOCKDOORS, true);
  jail_set_globalinfo(GI_EVENTSTOP, true);
  jail_celldoors(simon, TS_OPENED);

  jail_ham_specific({1, 1, 1, 1, 1, 0, 1});
  jail_set_globalinfo(GI_DAY, g_pMyNewDay);
}

end_jediday(simon)
{
  new num, id;
  static players[32];
  get_players(players, num);

  my_ham_hooks(false);
  for(--num; num >= 0; num--)
  {
    id = players[num];
    set_user_gravity(id);
    jail_set_playerdata(id, PD_HAMBLOCK, false);
    g_iKiller[id] = false;
    set_all_info(id, false);
    if(get_user_health(id) > 100)
      set_user_health(id, 100);

    cs_reset_user_maxspeed(id);
    set_player_glow(id, 0);
    destroy_beam(id);
    if(!is_user_bot(id))
      ExecuteHamB(Ham_Item_Deploy, fm_find_ent_by_owner(-1, "weapon_knife", id));
  }

  set_cvar_float("sv_maxspeed", g_fDefaultMaxSpeed);
  server_event(simon, g_szDayName, true);
  jail_ham_all(false);
  jail_set_globalinfo(GI_BLOCKDOORS, false);
  jail_set_globalinfo(GI_EVENTSTOP, false);
  jail_set_globalinfo(GI_DAY, false);
}

public set_player_attributes(id)
{
  strip_weapons(id);
  jail_player_crowbar(id, false);
  jail_set_playerdata(id, PD_HAMBLOCK, true);

  new CsTeams:team = cs_get_user_team(id);
  set_all_info(id, false);
  if(get_reverse_state() == team)
  {
    cs_reset_user_maxspeed(id, get_pcvar_float(cvar_jedi_maxspeed));
    set_user_gravity(id, get_pcvar_float(cvar_jedi_gravity));
  }

  if(team == CS_TEAM_CT)
    set_user_health(id, g_iCTHP);
  else set_user_health(id, g_iTHP);

  if(!is_user_bot(id))
    ExecuteHamB(Ham_Item_Deploy, fm_find_ent_by_owner(-1, "weapon_knife", id));
}

set_all_info(id, val)
{
  for(new i = 0; i < GRAB_INFO; i++)
    g_iPlayerData[id][i] = val;
}

my_ham_hooks(val)
{
  if(val)
  {
    for(new i = 0; i < sizeof(g_pHamHooks); i++)
      EnableHamForward(g_pHamHooks[i]);

    g_pForwardPlayerPreThink = register_forward(FM_PlayerPreThink, "Forward_PlayerPreThink_pre", 0);
    g_pForwardEmitSound = register_forward(FM_EmitSound, "Forward_EmitSound_pre", 0);
  }
  else
  {
    for(new i = 0; i < sizeof(g_pHamHooks); i++)
      DisableHamForward(g_pHamHooks[i]);

    unregister_forward(FM_PlayerPreThink, g_pForwardPlayerPreThink, 0);
    unregister_forward(FM_EmitSound, g_pForwardEmitSound, 0);
  }
}

public grab_think(id) //id of the grabber
{
  if(cs_get_user_team(id) != get_reverse_state() && !g_iKiller[id])
    return;

  new button = pev(id, pev_button);
  new target = g_iPlayerData[id][GRAB_GRABBED];
  if(!(button & IN_USE))
  {
    unset_grabbed(id);
    g_iPlayerData[target][GRAB_THROWN] = id;
    return;
  }

  //Keep grabbed clients from sticking to ladders
  if(pev(target, pev_movetype) == MOVETYPE_FLY && !(pev(target, pev_button) & IN_JUMP))
    client_cmd(target, "+jump;wait;-jump");

  //Move targeted client
  new Float:tmpvec[3], Float:tmpvec2[3], Float:torig[3], Float:tvel[3];
  get_view_pos(id, tmpvec);
  tmpvec2 = vel_by_aim(id, g_iPlayerData[id][GRAB_LEN]);

  pev(target, pev_origin, torig);
  new force = 6;

  tvel[0] = ((tmpvec[0] + tmpvec2[0]) - torig[0]) * force;
  tvel[1] = ((tmpvec[1] + tmpvec2[1]) - torig[1]) * force;
  tvel[2] = ((tmpvec[2] + tmpvec2[2]) - torig[2]) * force;

  set_pev(target, pev_velocity, tvel);
}

//Grabs onto someone
public set_grabbed(id, target)
{
  g_iPlayerData[target][GRAB_GRABBER] = id;
  g_iPlayerData[id][GRAB_GRABBED] = target;
  new Float:torig[3], Float:orig[3];
  pev(target, pev_origin, torig);
  pev(id, pev_origin, orig);

  g_iPlayerData[id][GRAB_LEN] = floatround(get_distance_f(torig, orig));
  if(g_iPlayerData[id][GRAB_LEN] < MIN_DISTANCE)
    g_iPlayerData[id][GRAB_LEN] = MIN_DISTANCE;

  new colors[3], CsTeams:team = get_reverse_state();
  if(g_iKiller[id])
    team = cs_get_user_team(id);

  if(team == CS_TEAM_CT)
    colors[2] = 255;
  else colors[0] = 255;

  set_player_glow(target, 1, colors[0], colors[1], colors[2], 30);
  make_beam(id, target, colors[0], colors[1], colors[2]);
}

public is_grabbed(target, grabber)
{
  new num, id;
  static players[32];
  get_players(players, num);

  for(--num; num >= 0; num--)
  {
    id = players[num];
    if(g_iPlayerData[id][GRAB_GRABBED] == target)
    {
      unset_grabbed(grabber);
      return 1;
    }
  }

  return 0;
}

public unset_grabbed(id)
{
  new target = g_iPlayerData[id][GRAB_GRABBED];
  if(target > 0)
  {
    g_iPlayerData[target][GRAB_GRABBER] = 0;
    g_iPlayerData[target][GRAB_THROWN] = 0;
    if(is_user_connected(target))
      set_player_glow(target, 0);
    destroy_beam(target);
  }
  g_iPlayerData[id][GRAB_GRABBED] = 0;
}

get_weapon_owner(ent)
  return get_pdata_cbase(ent, m_pPlayer, LINUX_WEAPON_OFF);

traceline( const Float:vStart[3], const Float:vEnd[3], const pIgnore, Float:vHitPos[3] )
{
  engfunc(EngFunc_TraceLine, vStart, vEnd, 0, pIgnore, 0);
  get_tr2(0, TR_vecEndPos, vHitPos);
  return get_tr2(0, TR_pHit);
}

get_view_pos(const id, Float:vViewPos[3])
{
  new Float:vOfs[3];
  pev(id, pev_origin, vViewPos);
  pev(id, pev_view_ofs, vOfs);

  vViewPos[0] += vOfs[0];
  vViewPos[1] += vOfs[1];
  vViewPos[2] += vOfs[2];
}

Float:vel_by_aim(id, speed = 1)
{
  new Float:v1[3], Float:vBlah[3];
  pev(id, pev_v_angle, v1);
  engfunc(EngFunc_AngleVectors, v1, v1, vBlah, vBlah);

  v1[0] *= speed;
  v1[1] *= speed;
  v1[2] *= speed;

  return v1;
}

calculate_hp(&ctHP, &tHP)
{
  new numCT, numT;
  new hp = get_pcvar_num(cvar_jedi_hp);
  static players[32];
  get_players(players, numT, "ae", "TERRORIST");
  get_players(players, numCT, "ae", "CT");

  if(numCT && numT)
  {
    if(numT > numCT)
    {
      ctHP = ((numT/numCT)*hp);
      tHP = hp;
    }
    else if(numT < numCT)
    {
      ctHP = hp;
      tHP = ((numCT/numT)*hp);
    }
    else
    {
      ctHP = hp;
      tHP = hp;
    }
  }
  else
  {
    ctHP = hp;
    tHP = hp;
  }
}

make_beam(id, target, r, g, b)
{
  message_begin(MSG_BROADCAST, SVC_TEMPENTITY);
  write_byte(TE_BEAMENTS);
  write_short(id);
  write_short(target);
  write_short(g_pSprite);
  write_byte(0);
  write_byte(10);
  write_byte(99999999);
  write_byte(50);
  write_byte(0);
  write_byte(r);
  write_byte(g);
  write_byte(b);
  write_byte(255);
  write_byte(0);
  message_end();
}

destroy_beam(id)
{
  message_begin(MSG_BROADCAST, SVC_TEMPENTITY);
  write_byte(TE_KILLBEAM);
  write_short(id);
  message_end();
}
