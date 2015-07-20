#include <amxmodx>
#include <cstrike>
#include <engine>
#include <fakemeta>
#include <hamsandwich>
#include <timer_controller>
#include <jailbreak>

#define TASK_ROUNDTIME 1111
#define TASK_GIVERANDOM 2222

new g_iGameMode, g_iFreeday[JAIL_MENUITEM];
new g_iPlayerData[33][PLAYERDATA], g_iHideBody[33];
new g_iGlobalInfo[GLOBALINFO];
new Float:g_fFreezeTime, Float:g_fRoundTime, Float:g_fRoundStart;
new cvar_preparation_time, cvar_simon_steps, cvar_crowbar_count, cvar_roundtime, cvar_pick_time, cvar_pick_what;
new Trie:g_tCvarsToFile, g_iTrieSize;
new g_pGameModeForward;

public plugin_init()
{
  register_plugin("JailBreak Supreme", JAIL_VERSION, JAIL_AUTHOR);
  register_cvar("jail_server_version", JAIL_VERSION, FCVAR_SERVER|FCVAR_EXTDLL|FCVAR_SPONLY);

  cvar_preparation_time   = mynew_register_cvar("jail_preparation_time",  "5",  "Time before game actually starts in seconds (Default: 5)");
  cvar_pick_time          = mynew_register_cvar("jail_pick_time",         "30", "Time in which simon should be picked. (Default: 30)");
  cvar_pick_what          = mynew_register_cvar("jail_pick_what",         "3",  "0-none, 1-random simon, 2-freeday, 3-random 1 or 2. (Default: 3)");
  cvar_roundtime          = mynew_register_cvar("jail_roundtime",         "10", "Default roundtime in minutes. (Default: 10)");
  cvar_crowbar_count      = mynew_register_cvar("jail_crowbar_count",     "1",  "Number of crowbars. (Default: 1)");
  cvar_simon_steps        = mynew_register_cvar("jail_simon_steps",       "1",  "Show simon steps. (Default: 1)");
  mynew_register_cvar("jail_admin_access",      "1",  "Can admin do things without being simon. (Default: 1)");

  set_msg_block(get_user_msgid("ClCorpse"), BLOCK_SET);
  register_event("ClCorpse", "Message_ClCorpse", "a", "10=0");
  register_event("TextMsg", "Event_RestartRound", "a", "2&#Game_C", "2&#Game_w");
  register_event("HLTV", "Event_NewRound", "a", "1=0", "2=0");
  register_logevent("Event_StartRound", 2, "1=Round_Start");
  register_logevent("Event_EndRound", 2, "1=Round_End");

  //RegisterHam(Ham_Spawn, "player", "Ham_Spawn_post", 1);
  RegisterHamPlayer(Ham_Killed, "Ham_Killed_pre", 0);
  RegisterHamPlayer(Ham_Killed, "Ham_Killed_post", 1);
  RegisterHamPlayer(Ham_TakeDamage, "Ham_TakeDamage_pre", 0);

  set_client_commands("simon", "set_player_simon");

  g_pGameModeForward = CreateMultiForward("jail_gamemode", ET_IGNORE, FP_CELL);
  register_dictionary("jailbreak.txt");
}

public plugin_natives()
{
  register_library("jailbreak");
  register_native("jail_get_gamemode", "_get_gamemode");
  register_native("jail_set_gamemode", "_set_gamemode");
  register_native("jail_get_playerdata", "_get_playerdata");
  register_native("jail_set_playerdata", "_set_playerdata");
  register_native("jail_get_globalinfo", "_get_globalinfo");
  register_native("jail_set_globalinfo", "_set_globalinfo");
  register_native("jail_get_roundtime", "_get_roundtime");
  register_native("jail_player_crowbar", "_player_crowbar");
  register_native("jail_register_cvar",	"_register_cvar");
}

public plugin_cfg()
{
  TrieDestroy(g_tCvarsToFile);
  auto_exec_config(JAIL_CONFIGFILE, true);
  g_fRoundTime = get_pcvar_float(cvar_roundtime);
}

public plugin_end()
{
  jail_game_forceend(get_global_info(GI_GAME));
  jail_day_forceend(get_global_info(GI_DAY));
}

public client_disconnect(id)
{
  if(get_player_data(id, PD_WANTED))
    set_global_info(GI_WANTED, get_global_info(GI_WANTED)-1);

  reset_user_one(id);
}

public client_putinserver(id)
{
  reset_user_one(id);
  set_task(11.0, "startup_info", id);
}

public jail_day_start()
{
  remove_my_tasks(1, 0);
}

public jail_game_start()
{
  remove_my_tasks(1, 0);
}

public startup_info(id)
{
  client_print_color(id, print_team_default, "%s Mod created by ^3%s^1, ^4skype:guskis1^1, version: ^3%s^1!", JAIL_TAG, JAIL_AUTHOR, JAIL_VERSION);
}

public Event_RestartRound()
{
  if(get_game_mode() != GAME_RESTARTING)
  {
    reset_user_all();
    reset_global_info();
    set_global_info(GI_DAYCOUNT, 0);
    set_game_mode(GAME_RESTARTING);
  }
}

public Event_EndRound()
{
  if(get_game_mode() != GAME_ENDED)
  {
    set_game_mode(GAME_ENDED);
  }
}

public Event_NewRound()
{
  if(get_game_mode() != GAME_PREPARING)
  {
    set_global_info(GI_DAYCOUNT, get_global_info(GI_DAYCOUNT)+1);
    new cvar = get_pcvar_num(cvar_preparation_time);
    if(!cvar)
      set_pcvar_num(cvar_preparation_time, cvar = 1);
    g_fFreezeTime = float(cvar);
    set_task(0.1, "set_timer");

    g_fRoundTime = get_pcvar_float(cvar_roundtime);
    g_fRoundStart = get_gametime();
    reset_user_all();
    reset_global_info();

    set_game_mode(GAME_PREPARING);
  }
}

public set_timer()
  RoundTimerSet(0, get_pcvar_num(cvar_preparation_time));

public Event_StartRound()
{
  remove_my_tasks(1, 1);

  if(get_pcvar_num(cvar_pick_what))
    set_task(get_pcvar_float(cvar_pick_time)+get_pcvar_float(cvar_preparation_time), "set_player_pick", TASK_GIVERANDOM+get_pcvar_num(cvar_pick_what));
  set_task(get_pcvar_float(cvar_preparation_time), "do_the_magic", TASK_ROUNDTIME);
}

public do_the_magic()
{
  RoundTimerSet(floatround(g_fRoundTime));

  new num, id;
  static players[32];
  get_players(players, num, "ae", "TERRORIST");
  new cvar = get_pcvar_num(cvar_crowbar_count);
  if(cvar > 0 && num > 1)
  {
    for(new i = 0; i < cvar; i++)
    {
      id = 0;
      if(i >= num)
        break;

      while(id == 0)
      {
        id = players[random(num)];
        if(get_player_data(id, PD_CROWBAR))
          id = 0;
      }

      set_player_data(id, PD_CROWBAR, true);
      ExecuteHamB(Ham_Item_Deploy, find_ent_by_owner(-1, "weapon_knife", id));
    }
  }

  set_game_mode(GAME_STARTED);
}

public set_player_pick(taskid)
{
  new randomnum;
  if(get_pcvar_num(cvar_pick_what) == 3)
    randomnum = random_num(1, 2);
  else randomnum = get_pcvar_num(cvar_pick_what);

  switch(randomnum)
  {
    case 1:
    {
      new num, id;
      static players[32];
      get_players(players, num, "ae", "CT");
      if(num)
      {
        id = players[random(num)];
        set_player_simon(id);
      }
    }
    case 2:
    {
      if(!g_iFreeday[0])
        formatex(g_iFreeday, charsmax(g_iFreeday), "%L", LANG_PLAYER, "JAIL_DAY0");
      jail_day_byname(0, g_iFreeday, 0);
    }
  }
}

public set_player_simon(id)
{
  if(is_user_alive(id))
  {
    if(cs_get_user_team(id) == CS_TEAM_CT)
    {
      static name[32];
      new simon = get_global_info(GI_SIMON);
      if(!simon)
      {
        remove_my_tasks(1, 0);
        set_user_simon(id, true, false, true);
      }
      else
      {
        if(simon == id)
          set_user_simon(id, false, false, true);
        else
        {
          get_user_name(simon, name, charsmax(name));
          client_print_color(id, print_team_default, "%s %L", JAIL_TAG, id, "JAIL_SIMON_ALREADY", name);
        }
      }
    }
    else client_print_color(id, print_team_default, "%s %L", JAIL_TAG, id, "JAIL_MUSTBECT");
  }
}

public Ham_Killed_pre(victim, killer, shouldgib)
{
  if(!is_user_connected(victim))
    return HAM_IGNORED;

  if(get_player_data(victim, PD_SIMON))
  {
    //set_global_info(GI_CANTSIMON, true);
    set_user_simon(victim, false, killer, true);
  }
  else if(get_player_data(victim, PD_WANTED))
  {
    set_global_info(GI_WANTED, get_global_info(GI_WANTED)-1);
    set_player_data(victim, PD_WANTED, false);
  }

  return HAM_IGNORED;
}

public Ham_Killed_post(victim, killer, shouldgib)
  if(shouldgib == 2)
    g_iHideBody[victim] = true;

public Ham_TakeDamage_pre(victim, inflictor, attacker, Float:damage, DamageBits)
{
  if(is_user_alive(attacker))
  {
    if(get_t_attack_ct(attacker, victim) && !get_player_data(attacker, PD_HAMBLOCK))
    {
      if(!g_iFreeday[0])
        formatex(g_iFreeday, charsmax(g_iFreeday), "%L", LANG_PLAYER, "JAIL_DAY0");

      new fd = jail_game_getid(g_iFreeday);
      if(fd != get_global_info(GI_DAY) && get_player_data(attacker, PD_FREEDAY))
        jail_player_freebie(attacker, false, false);

      set_player_data(attacker, PD_WANTED, true);
      set_global_info(GI_WANTED, get_global_info(GI_WANTED)+1);
      entity_set_int(attacker, EV_INT_skin, 1);
      set_player_data(attacker, PD_SKIN, 1);
      if(get_global_info(GI_FREEPASS) == attacker)
        set_global_info(GI_FREEPASS, 0);
    }

    if(attacker == inflictor && get_user_weapon(attacker) == CSW_KNIFE && get_player_data(attacker, PD_CROWBAR) && cs_get_user_team(victim) != cs_get_user_team(attacker))
    {
      SetHamParamFloat(4, damage * 25.0);
      return HAM_HANDLED;
    }
  }

  return HAM_IGNORED;
}

public client_PostThink(id)
{
  if(get_global_info(GI_SIMON) != id || !get_pcvar_num(cvar_simon_steps) || !is_user_alive(id) ||	!(entity_get_int(id, EV_INT_flags) & FL_ONGROUND) || entity_get_int(id, EV_ENT_groundentity))
    return PLUGIN_CONTINUE;

  static Float:originNew[3], Float:originLast[3];
  entity_get_vector(id, EV_VEC_origin, originNew);
  if(get_distance_f(originNew, originLast) < 32.0)
    return PLUGIN_CONTINUE;

  xs_vec_copy(originNew, originLast);
  if(entity_get_int(id, EV_INT_button) & IN_DUCK)
    originNew[2] -= 18.0;
  else originNew[2] -= 36.0;

  message_begin(MSG_BROADCAST, SVC_TEMPENTITY);
  write_byte(TE_WORLDDECAL);
  write_coord(floatround(originNew[0]));
  write_coord(floatround(originNew[1]));
  write_coord(floatround(originNew[2]));
  write_byte(105);
  message_end();

  return PLUGIN_CONTINUE;
}

public Message_ClCorpse()
{
  if(get_game_mode() != GAME_STARTED)
    return;

  new id = read_data(12);
  if(g_iHideBody[id])
    return;

  static Float:origin[3], model[32];
  read_data(1, model, charsmax(model));
  origin[0] = read_data(2)/128.0;
  origin[1] = read_data(3)/128.0;
  origin[2] = read_data(4)/128.0;
  new seq = read_data(9);

  create_body(id, origin, model, seq);
}

public create_body(id, Float:origin[3], model[], seq)
{
  new ent = create_entity("info_target");
  entity_set_string(ent, EV_SZ_classname, "dead_body");

  static out[64];
  formatex(out, charsmax(out), "models/player/%s/%s.mdl", model, model);
  entity_set_model(ent, out);
  entity_set_origin(ent, origin);

  static Float:angle[3];
  entity_get_vector(id, EV_VEC_angles, angle);

  entity_set_float(ent, EV_FL_frame, 255.0);
  entity_set_int(ent, EV_INT_sequence, seq);
  entity_set_vector(ent, EV_VEC_angles, angle);
  entity_set_int(ent, EV_INT_movetype, MOVETYPE_FLY);
  entity_set_int(ent, EV_INT_solid, SOLID_TRIGGER);

  entity_set_int(ent, EV_INT_skin, get_player_data(id, PD_SKIN));
  entity_set_int(ent, EV_INT_iuser1, id);
}

//MYFUNC
stock mynew_register_cvar(name[], string[], description[], flags = 0, Float:fvalue = 0.0)
{
  new_register_cvar(name, string, description);
  return register_cvar(name, string, flags, fvalue);
}

stock new_register_cvar(name[], string[], description[], plug[] = "jail_main.amxx")
{
  static path[96];
  if(!path[0])
  {
    get_localinfo("amxx_configsdir", path, charsmax(path));
    format(path, charsmax(path), "%s/%s", path, JAIL_CONFIGFILE);
  }

  new file;
  if(!g_tCvarsToFile)
    g_tCvarsToFile = TrieCreate();

  if(!file_exists(path))
  {
    file = fopen(path, "wt");
    if(!file)
      return 0;

    fprintf(file, "// Server specific.^n");
    fprintf(file, "%-32s %-8s // %-32s // %s^n", "mp_tkpunish", "0",				plug, "Disables TeamKill punishments");
    fprintf(file, "%-32s %-8s // %-32s // %s^n", "mp_friendlyfire", "0",			plug, "Disables friendly fire");
    fprintf(file, "%-32s %-8s // %-32s // %s^n", "mp_limitteams", "0",				plug, "Disables team limits");
    fprintf(file, "%-32s %-8s // %-32s // %s^n", "mp_autoteambalance", "0",			plug, "Disables team limits");
    fprintf(file, "%-32s %-8s // %-32s // %s^n", "mp_freezetime", "0",				plug, "Disables freeze time on round start");
    fprintf(file, "%-32s %-8s // %-32s // %s^n", "mp_playerid", "2",				plug, "Disables team info when aiming on player");
    fprintf(file, "%-32s %-8s // %-32s // %s^n", "sv_allktalk", "1",				plug, "Enables alltalk");
    fprintf(file, "%-26s %-14s // %-32s // %s^n", "amx_statscfg", "off PlayerName",	plug, "Disables player name when aiming on player");
    fprintf(file, "^n");
    fprintf(file, "// Mod specific.^n");
  }
  else
  {
    file = fopen(path, "rt");
    if(!file)
      return 0;

    //if(!TrieGetSize(g_tCvarsToFile))
    if(!g_iTrieSize)
    {
      new newline[48];
      static line[128];
      while(!feof(file))
      {
        fgets(file, line, charsmax(line));
        if(line[0] == ';' || !line[0])
          continue;

        parse(line, newline, charsmax(newline));
        remove_quotes(newline);
        #if AMXX_VERSION_NUM >= 183
          TrieSetCell(g_tCvarsToFile, newline, 1, false);
        #else
          TrieSetCell(g_tCvarsToFile, newline, 1);
        #endif
        g_iTrieSize++;
      }
    }
    fclose(file);
    file = fopen(path, "at");
  }

  if(!TrieKeyExists(g_tCvarsToFile, name))
  {
    fprintf(file, "%-32s %-8s // %-32s // %s^n", name, string, plug, description);
    #if AMXX_VERSION_NUM >= 183
      TrieSetCell(g_tCvarsToFile, name, 1, false);
    #else
      TrieSetCell(g_tCvarsToFile, name, 1);
    #endif
    g_iTrieSize++;
  }

  fclose(file);
  return 1;
}

stock get_game_mode()
  return g_iGameMode;

stock set_game_mode(value)
{
  if(value == GAME_RESTARTING)
    log_amx("[JAIL] Game has restarted :(");

  g_iGameMode = value;
  new ret;
  ExecuteForward(g_pGameModeForward, ret, value);
}

stock get_player_data(id, pd)
  return g_iPlayerData[id][pd];

stock set_player_data(id, pd, value)
{
  if(pd == PD_SIMON && get_player_data(id, pd))
    set_user_simon(id, value, 0);
  else g_iPlayerData[id][pd] = value;
}

stock get_global_info(gi)
  return g_iGlobalInfo[gi];

stock set_global_info(gi, value)
  g_iGlobalInfo[gi] = value;

stock Float:get_roundtime()
  return get_gametime() - g_fRoundStart - g_fFreezeTime;

stock set_user_simon(id, value, killer=0, print=0)
{
  set_global_info(GI_SIMON, value ? id : 0);
  g_iPlayerData[id][PD_SIMON] = value;
  if(is_user_connected(killer))
  {
    g_iPlayerData[killer][PD_KILLEDSIMON] = id;
    set_global_info(GI_KILLEDSIMON, killer);
  }

  if(print)
  {
    static name[32];
    get_user_name(id, name, charsmax(name));
    client_print_color(0, print_team_default, "%s %L", JAIL_TAG, LANG_SERVER, value ? "JAIL_SIMON_YES" : "JAIL_SIMON_NO", name);
  }
}

stock reset_user_all()
{
  new num, id;
  static players[32];
  get_players(players, num);

  for(--num; num >= 0; num--)
  {
    id = players[num];
    reset_user_one(id);
  }
}

stock reset_user_one(id)
{
  new i;
  for(i = 0; i < PLAYERDATA; i++)
  {
    if(i == PD_NEXTFD || i == PD_TALK_FOREVER) continue;
    if(i == PD_TALK && get_player_data(id, PD_TALK_FOREVER)) continue;
    set_player_data(id, i, 0);
    g_iHideBody[id] = false;
  }

  if(task_exists(id))
    remove_task(id);
}

stock reset_global_info()
{
  remove_my_tasks(1, 1);
  remove_entity_name("dead_body");

  new i;
  for(i = 0; i < GLOBALINFO; i++)
  {
    if(i == GI_DAYCOUNT) continue;
    set_global_info(i, 0);
  }
}

stock remove_my_tasks(v1, v2)
{
  if(v1)
  {
    if(task_exists(TASK_GIVERANDOM+get_pcvar_num(cvar_pick_what)))
      remove_task(TASK_GIVERANDOM+get_pcvar_num(cvar_pick_what));
  }

  if(v2)
  {
    if(task_exists(TASK_ROUNDTIME))
      remove_task(TASK_ROUNDTIME);
  }
}

stock xs_vec_copy(const Float:vecIn[], Float:vecOut[])
{
  vecOut[0] = vecIn[0];
  vecOut[1] = vecIn[1];
  vecOut[2] = vecIn[2];
}

stock get_t_attack_ct(attacker, victim)
{
  if(cs_get_user_team(attacker) == CS_TEAM_T && cs_get_user_team(victim) == CS_TEAM_CT)
    return 1;

  return 0;
}

//API
public _get_playerdata(plugin, params)
{
  if(params != 2)
    return -1;

  new id = get_param(1);
  new pd = get_param(2);

  return get_player_data(id, pd);
}

public _set_playerdata(plugin, params)
{
  if(params != 3)
    return -1;

  new id = get_param(1);
  new pd = get_param(2);
  new value = get_param(3);
  set_player_data(id, pd, value);

  return 1;
}

public _get_globalinfo(plugin, params)
{
  if(params != 1)
    return -1;

  new gi = get_param(1);
  return get_global_info(gi);
}

public _set_globalinfo(plugin, params)
{
  if(params != 2)
    return -1;

  new gi = get_param(1);
  new value = get_param(2);
  set_global_info(gi, value);

  return 1;
}

public _get_gamemode()
  return get_game_mode();

public _set_gamemode(plugin, params)
{
  if(params != 1)
    return -1;

  new value = get_param(1);
  set_game_mode(value);
  return value;
}

public Float:_get_roundtime()
  return get_roundtime();


public _player_crowbar(plugin, params)
{
  if(params != 2)
    return -1;

  new id = get_param(1);
  new value = get_param(2);

  set_player_data(id, PD_CROWBAR, value);
  if(get_user_weapon(id) == CSW_KNIFE && !is_user_bot(id) && is_user_alive(id))
    ExecuteHamB(Ham_Item_Deploy, find_ent_by_owner(-1, "weapon_knife", id));

  return value;
}

public _register_cvar(plugin, params)
{
  if(params != 3)
    return -1;

  static name[48], string[16], pluginname[48], description[128];
  get_string(1, name, charsmax(name));
  get_string(2, string, charsmax(string));
  get_string(3, description, charsmax(description));
  get_plugin(plugin, pluginname, charsmax(pluginname));

  return new_register_cvar(name, string, description, pluginname);
}
