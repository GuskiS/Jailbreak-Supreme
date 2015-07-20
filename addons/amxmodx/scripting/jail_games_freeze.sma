#include <amxmodx>
#include <cstrike>
#include <fun>
#include <fakemeta>
#include <hamsandwich>
#include <jailbreak>
#include <timer_controller>

#define TASK_BEGIN 1111

new g_pMyNewGame, g_szGameName[JAIL_MENUITEM];
new g_iFreezer[33], g_iFrozen[33], cvar_freeze_maxspeed, Float:g_fDefaultMaxSpeed;
new HamHook:g_pHamForwards[3], cvar_freeze_time_delay, g_iTimeOnClock;
new g_pPlayerPreThinkForward;

public plugin_init()
{
  register_plugin("[JAIL] Freeze game", JAIL_VERSION, JAIL_AUTHOR);

  cvar_freeze_maxspeed    = my_register_cvar("jail_freeze_maxspeed",    "330.0",  "Freeze speed for catchers. (Default: 330.0)");
  cvar_freeze_time_delay  = my_register_cvar("jail_freeze_time_delay",  "30.0",   "Time before start of Freeze game. (Default: 30.0)");

  DisableHamForward((g_pHamForwards[0] = RegisterHamPlayer(Ham_Touch, "Ham_Touch_pre", 0)));
  DisableHamForward((g_pHamForwards[1] = RegisterHamPlayer(Ham_TraceAttack, "Ham_TraceAttack_pre", 0)));
  DisableHamForward((g_pHamForwards[2] = RegisterHamPlayer(Ham_Killed, "Ham_Killed_pre", 0)));

  formatex(g_szGameName, charsmax(g_szGameName), "%L", LANG_PLAYER, "JAIL_GAME3");
  g_pMyNewGame = jail_game_add(g_szGameName, "freeze", 1);
}

public client_disconnect(id)
{
  g_iFreezer[id] = false;
  g_iFrozen[id] = false;

  if(game_equal(g_pMyNewGame))
    check_frozen();
}

public jail_freebie_join(id, event, type)
{
  if(type == GI_GAME && event == g_pMyNewGame)
  {
    set_player_attributes(id);
    return PLUGIN_HANDLED;
  }

  return PLUGIN_CONTINUE;
}

public jail_game_start(simon, game, gamename[])
{
  if(game == g_pMyNewGame)
  {
    start_freezetag(simon);
    return PLUGIN_HANDLED;
  }

  return PLUGIN_CONTINUE;
}

public jail_game_end(simon, game, gamename[])
{
  if(game == g_pMyNewGame)
  {
    end_freezetag(simon);
    return PLUGIN_HANDLED;
  }

  return PLUGIN_CONTINUE;
}

public Ham_Killed_pre(victim, killer)
  check_frozen();

public Ham_Touch_pre(ent, id)
{
  if(is_user_alive(ent) && is_user_alive(id))
  {
    if(jail_get_playerdata(id, PD_HAMBLOCK) && jail_get_playerdata(ent, PD_HAMBLOCK))
    {
      new CsTeams:teamENT = cs_get_user_team(ent), CsTeams:teamID = cs_get_user_team(id);
      if(teamENT != teamID)
      {
        if(g_iFreezer[id] && !g_iFrozen[ent])
        {
          g_iFrozen[ent] = true;
          set_player_glow(ent, 1, 0, 0, 255, 30);
          check_frozen();
        }
      }
      else
      {
        if(teamID != get_reverse_state() && g_iFrozen[ent])
        {
          g_iFrozen[ent] = false;
          set_player_glow(ent, 0);
          cs_reset_user_maxspeed(ent);
        }
      }
    }
  }
}

public Ham_TraceAttack_pre(victim, attacker, Float:damage, Float:direction[3], tracehandle, damagebits)
{
  if(is_user_connected(victim) && is_user_connected(attacker))
    if(jail_get_playerdata(attacker, PD_HAMBLOCK) && jail_get_playerdata(victim, PD_HAMBLOCK))
      return HAM_SUPERCEDE;

  return HAM_IGNORED;
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

public begin_freezetag()
{
  RoundTimerSet(0, g_iTimeOnClock);

  new num, id, CsTeams:team = get_reverse_state(), Float:speed = get_pcvar_float(cvar_freeze_maxspeed);
  static players[32];
  get_players(players, num, "a");

  for(--num; num >= 0; num--)
  {
    id = players[num];
    if(cs_get_user_team(id) == team && jail_get_playerdata(id, PD_HAMBLOCK))
    {
      g_iFrozen[id] = false;
      cs_reset_user_maxspeed(id, speed);
    }
  }
}

start_freezetag(simon)
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

  g_fDefaultMaxSpeed = get_cvar_float("sv_maxspeed");
  set_cvar_float("sv_maxspeed", get_pcvar_float(cvar_freeze_maxspeed));

  server_event(simon, g_szGameName, false);
  jail_celldoors(simon, TS_OPENED);

  jail_set_globalinfo(GI_GAME, g_pMyNewGame);
  jail_ham_specific({1, 1, 1, 1, 1, 0, 1});

  g_iTimeOnClock = RoundTimerGet()-floatround(jail_get_roundtime());
  RoundTimerSet(0, get_pcvar_num(cvar_freeze_time_delay));
  set_task(get_pcvar_float(cvar_freeze_time_delay), "begin_freezetag", TASK_BEGIN);

  return PLUGIN_HANDLED;
}

public set_player_attributes(id)
{
  strip_weapons(id);
  jail_set_playerdata(id, PD_HAMBLOCK, true);
  if(cs_get_user_team(id) == get_reverse_state())
  {
    g_iFreezer[id] = true;
    g_iFrozen[id] = true;
    set_user_godmode(id, true);
  }
}

end_freezetag(simon)
{
  if(task_exists(TASK_BEGIN))
  {
    RoundTimerSet(0, g_iTimeOnClock);
    remove_task(TASK_BEGIN);
  }

  new num, id;
  static players[32];
  get_players(players, num);

  for(--num; num >= 0; num--)
  {
    id = players[num];

    jail_set_playerdata(id, PD_HAMBLOCK, false);
    g_iFreezer[id] = false;
    g_iFrozen[id] = false;
    set_player_glow(id, 0);

    if(is_user_alive(id))
    {
      set_user_godmode(id, false);
      cs_reset_user_maxspeed(id);
      ExecuteHamB(Ham_CS_RoundRespawn, id);
    }
  }

  my_registered_stuff(false);
  set_cvar_float("sv_maxspeed", g_fDefaultMaxSpeed);

  server_event(simon, g_szGameName, true);
  jail_celldoors(simon, TS_CLOSED);

  jail_set_globalinfo(GI_GAME, false);
  jail_ham_all(false);
}

my_registered_stuff(val)
{
  if(val)
  {
    for(new i = 0; i < sizeof(g_pHamForwards); i++)
      EnableHamForward(g_pHamForwards[i]);

    g_pPlayerPreThinkForward = register_forward(FM_PlayerPreThink, "Forward_PlayerPreThink_pre", 0);
  }
  else
  {
    for(new i = 0; i < sizeof(g_pHamForwards); i++)
      DisableHamForward(g_pHamForwards[i]);

    unregister_forward(FM_PlayerPreThink, g_pPlayerPreThinkForward, 0);
  }
}

check_frozen()
{
  new num, num2, id, count, CsTeams:team = get_reverse_state();
  static players[32];
  get_players(players, num, "ae", team != CS_TEAM_T ? "TERRORIST" : "CT");
  num2 = num;

  for(--num; num >= 0; num--)
  {
    id = players[num];
    if(g_iFrozen[id])
      count++;
  }

  if(count == num2)
    jail_game_byname(0, g_szGameName, 1);
}
