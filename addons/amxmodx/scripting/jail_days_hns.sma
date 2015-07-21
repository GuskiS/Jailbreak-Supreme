#include <amxmodx>
#include <hamsandwich>
#include <fakemeta>
#include <engine>
#include <fun>
#include <cstrike>
#include <jailbreak>
#include <timer_controller>

#define TASK_BEGIN 1111

new g_pMyNewDay, g_iTimeOnClock, cvar_hns_time_delay, cvar_hns_distance;
new g_pPlayerPreThinkForward, g_pAddToFullPackForward;
new g_szDayName[JAIL_MENUITEM], g_iFrozen[33], g_iHNS[33][2], g_iSimonSteps;

public plugin_init()
{
  register_plugin("[JAIL] HNS day", JAIL_VERSION, JAIL_AUTHOR);

  cvar_hns_time_delay = register_cvar_file("jail_hns_time_delay", "60.0",   "Time before start of HNS day. (Default: 60.0)");
  cvar_hns_distance   = register_cvar_file("jail_hns_distance",   "300.0",  "Radius in which seekers can see. (Default: 300.0)");

  formatex(g_szDayName, charsmax(g_szDayName), "%L", LANG_PLAYER, "JAIL_DAY9");
  g_pMyNewDay = jail_day_add(g_szDayName, "hns", 1);
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
    start_hns(simon);
    return PLUGIN_HANDLED;
  }

  return PLUGIN_CONTINUE;
}

public jail_day_end(simon, day, dayname[])
{
  if(day == g_pMyNewDay)
  {
    end_hns(simon);
    return PLUGIN_HANDLED;
  }

  return PLUGIN_CONTINUE;
}

public Forward_PlayerPreThink_pre(id)
{
  if(!g_iFrozen[id] || !is_user_alive(id))
    return;

  set_user_maxspeed(id, -1.0);
  set_pev(id, pev_velocity, Float:{0.0, 0.0, 0.0});

  new flags = pev(id, pev_flags);
  if(!(flags & FL_ONGROUND))
    set_pev(id, pev_flags, (flags | FL_ONGROUND));
}

public Forward_AddToFullPack_post(es_handle, e, ent, host, hostflags, player, pSet)
{
  if(player) // to player
  {
    if(!g_iHNS[host][0] && !g_iHNS[host][1])
      return;

    static CsTeams:team, Float:distance, CsTeams:hostTeam, CsTeams:playerTeam;
    if(!team)
      team = get_reverse_state();
    if(!distance)
      distance = get_pcvar_float(cvar_hns_distance);

    hostTeam = cs_get_user_team(host);
    playerTeam = cs_get_user_team(ent);

    if(hostTeam == playerTeam)
    {
      if(hostTeam != team && g_iHNS[host][1])
        addtofull_set(es_handle, kRenderTransTexture, 255);
    }
    else
    {
      if(entity_range(host, ent) < distance)
      {
        if(hostTeam != team && is_user_alive(host))
        {
          set_es(es_handle, ES_RenderFx, kRenderFxGlowShell);
          set_es(es_handle, ES_RenderColor, {255, 0, 0});
          set_es(es_handle, ES_RenderAmt, 30);
        }
        else if(g_iHNS[host][0])
          addtofull_set(es_handle, kRenderTransTexture, 255);
      }
    }
  }
}

stock addtofull_set(es_handle, mode, amt)
{
  //set_es(es_handle, ES_RenderColor, {0, 0, 0});
  set_es(es_handle, ES_RenderMode, mode);
  set_es(es_handle, ES_RenderAmt, amt);
}

public begin_hns()
{
  RoundTimerSet(0, g_iTimeOnClock);

  new num, id, CsTeams:team = get_reverse_state();
  static players[32];
  get_players(players, num, "a");
  unregister_forward(FM_PlayerPreThink, g_pPlayerPreThinkForward);

  for(--num; num >= 0; num--)
  {
    id = players[num];
    if(team == cs_get_user_team(id))
    {
      g_iFrozen[id] = false;
      cs_reset_user_maxspeed(id);
    }
  }
}

start_hns(simon)
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

  server_event(simon, g_szDayName, false);
  jail_celldoors(simon, TS_OPENED);

  jail_set_globalinfo(GI_DAY, g_pMyNewDay);
  my_registered_stuff(true);
  //jail_set_globalinfo(GI_EVENTSTOP, true);

  g_iTimeOnClock = RoundTimerGet()-floatround(jail_get_roundtime());
  RoundTimerSet(0, get_pcvar_num(cvar_hns_time_delay));
  set_task(get_pcvar_float(cvar_hns_time_delay), "begin_hns", TASK_BEGIN);

  jail_ham_specific({1, 1, 1, 1, 1, 0, 1});

  g_iSimonSteps = get_pcvar_num(get_cvar_pointer("jail_simon_steps"));
  if(g_iSimonSteps)
    set_pcvar_num(get_cvar_pointer("jail_simon_steps"), !g_iSimonSteps);
}

end_hns(simon)
{
  RoundTimerSet(0, g_iTimeOnClock);

  new num, id;
  static players[32];
  get_players(players, num);
  if(task_exists(TASK_BEGIN))
    remove_task(TASK_BEGIN);

  for(--num; num >= 0; num--)
  {
    id = players[num];
    g_iFrozen[id] = false;
    g_iHNS[id][0] = false;
    g_iHNS[id][1] = false;

    strip_weapons(id);
    jail_set_playerdata(id, PD_HAMBLOCK, false);
    jail_set_playerdata(id, PD_INVISIBLE, false);
    set_user_rendering(id);
    cs_reset_user_maxspeed(id);
  }

  server_event(simon, g_szDayName, true);
  my_registered_stuff(false);
  jail_ham_all(false);
  jail_set_globalinfo(GI_DAY, false);
  //jail_set_globalinfo(GI_EVENTSTOP, false);
  if(g_iSimonSteps)
    set_pcvar_num(get_cvar_pointer("jail_simon_steps"), g_iSimonSteps);

  return PLUGIN_CONTINUE;
}

my_registered_stuff(val)
{
  if(val)
  {
    g_pAddToFullPackForward	= register_forward(FM_AddToFullPack, "Forward_AddToFullPack_post", 1);
    g_pPlayerPreThinkForward = register_forward(FM_PlayerPreThink, "Forward_PlayerPreThink_pre", 0);
  }
  else
  {
    unregister_forward(FM_AddToFullPack, g_pAddToFullPackForward, 1);
    unregister_forward(FM_PlayerPreThink, g_pPlayerPreThinkForward, 0);
  }
}

public set_player_attributes(id)
{
  strip_weapons(id);

  if(get_reverse_state() == cs_get_user_team(id))
  {
    g_iFrozen[id] = true;
    g_iHNS[id][0] = true;
    ham_give_weapon(id, "weapon_m4a1", 1);
    cs_set_user_bpammo(id, CSW_M4A1, 180);
    ham_give_weapon(id, "weapon_deagle");
    cs_set_user_bpammo(id, CSW_DEAGLE, 35);
  }
  else
  {
    g_iHNS[id][1] = true;
    set_user_rendering(id, kRenderFxGlowShell, 0, 0, 0, kRenderTransAlpha, 0);
    jail_set_playerdata(id, PD_INVISIBLE, true);
  }

  jail_player_crowbar(id, false);
  jail_set_playerdata(id, PD_HAMBLOCK, true);
}
