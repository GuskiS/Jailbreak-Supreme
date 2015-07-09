#include <amxmodx>
#include <engine>
#include <hamsandwich>
#include <jailbreak>
#include <timer_controller>

#define TASK_FREEDAY 1111
#define TASK_FREEBIE 2222

new g_pMyNewDay, g_iTimeOnClock, cvar_freeday_time;
new g_szDayName[JAIL_MENUITEM];
new const g_szBrassBell[] = "suprjail/brass_bell_C.wav";
new g_pForwardFreebieJoin, g_iFreebieInfo[33][2]; // 0-event, 1-type

public plugin_precache()
{
  precache_sound(g_szBrassBell);
}

public plugin_init()
{
  register_plugin("[JAIL] Freeday", JAIL_VERSION, JAIL_AUTHOR);

  cvar_freeday_time = register_cvar("jail_freeday_time", "60");

  RegisterHamPlayer(Ham_Killed, "Ham_Killed_pre", 0);

  formatex(g_szDayName, charsmax(g_szDayName), "%L", LANG_PLAYER, "JAIL_DAY0");
  g_pMyNewDay = jail_day_add(g_szDayName, "fd", 1);

  g_pForwardFreebieJoin = CreateMultiForward("jail_freebie_join", ET_STOP, FP_CELL, FP_CELL, FP_CELL); // ID, event, type
}

public plugin_natives()
{
  register_library("jailbreak");
  register_native("jail_player_freebie", "_player_freebie");
  register_native("jail_ask_freebie", "_ask_freebie");
}

public client_disconnect(id)
{
  end_freeday(id);
}

public jail_gamemode(mode)
{
  if(mode == GAME_STARTED)
  {
    new num, id;
    static players[32];
    get_players(players, num, "ae", "TERRORIST");

    if(num > 1)
    {
      if(jail_get_globalinfo(GI_DAYCOUNT) == 1)
        jail_day_byname(0, g_szDayName, 0);
    }
    else if(num == 1)
      jail_duel_lastrequest();

    if(jail_get_globalinfo(GI_DAY) != g_pMyNewDay)
    {
      for(--num; num >= 0; num--)
      {
        id = players[num];
        if(jail_get_playerdata(id, PD_NEXTFD))
        {
          begin_freeday_one(id, SKIN_FREEDAY, true, true);
          set_task(get_pcvar_float(cvar_freeday_time), "end_freeday", id);
          jail_set_playerdata(id, PD_NEXTFD, false);
        }
      }
    }
  }
}

public jail_day_start(simon, day, dayname[])
{
  if(day == g_pMyNewDay)
  {
    if(simon) cmd_freeday_menu(simon);
    else begin_freeday_all(simon);
    return PLUGIN_HANDLED;
  }

  return PLUGIN_CONTINUE;
}

public jail_day_end(simon, day, dayname[])
{
  if(day == g_pMyNewDay)
    return end_freeday(TASK_FREEDAY+simon);

  return PLUGIN_CONTINUE;
}

public Ham_Killed_pre(victim, killer, shouldgib)
{
  if(task_exists(victim))
    remove_task(victim);
}

public end_freeday(taskid)
{
  if(task_exists(taskid))
    remove_task(taskid);

  if(!is_user_connected(taskid))
  {
    if(day_equal(g_pMyNewDay))
    {
      client_cmd(0, "spk ^"%s^"", g_szBrassBell);
      RoundTimerSet(0, g_iTimeOnClock);

      new num, id;
      static players[32];
      get_players(players, num, "ae", "TERRORIST");

      for(--num; num >= 0; num--)
      {
        id = players[num];
        begin_freeday_one(id, jail_get_playerdata(id, PD_SKIN), false, false);
        if(task_exists(id+TASK_FREEDAY))
          remove_task(id+TASK_FREEDAY);
      }

      server_event(taskid-TASK_FREEDAY, g_szDayName, 1);
      jail_set_globalinfo(GI_DAY, false);
      jail_set_globalinfo(GI_NOFREEBIES, false);

      return PLUGIN_HANDLED;
    }
  }
  else
  {
    if(jail_get_playerdata(taskid, PD_FREEDAY))
    {
      begin_freeday_one(taskid, jail_get_playerdata(taskid, PD_SKIN), false, false);
      static name[32];
      get_user_name(taskid, name, charsmax(name));
      ColorChat(0, NORMAL, "%s %L", JAIL_TAG, LANG_SERVER, "JAIL_DAY0_EXTRA2", g_szDayName, name);
      //jail_set_globalinfo(GI_DAY, 0);
      return PLUGIN_HANDLED;
    }
  }

  return PLUGIN_CONTINUE;
}

public cmd_freeday_menu(id)
{
  if(!in_progress(0, GI_DAY) || day_equal(g_pMyNewDay))
  {
    if(simon_or_admin(id))
    {
      static menu, option[JAIL_MENUITEM];
      menu = menu_create(g_szDayName, "cmd_freeday_menu_handle");

      if(!in_progress(0, GI_DAY))
      {
        formatex(option, charsmax(option), "%L", id, "JAIL_DAY0_MENU1");
        menu_additem(menu, option, "1", 0);
        formatex(option, charsmax(option), "%L", id, "JAIL_DAY0_MENU2");
        menu_additem(menu, option, "2", 0);
      }
      else
      {
        formatex(option, charsmax(option), "%L", id, "JAIL_EVENTEND", g_szDayName);
        menu_additem(menu, option, "3", 0);
      }

      menu_display(id, menu);
    }
  }
  else ColorChat(id, NORMAL, "%s %L", JAIL_TAG, id, "JAIL_DAYALREADY");

  return PLUGIN_HANDLED;
}

public cmd_freeday_menu_handle(id, menu, item)
{
  if(item == MENU_EXIT || !is_user_alive(id) || !simon_or_admin(id))
  {
    menu_destroy(menu);
    return PLUGIN_HANDLED;
  }

  new access, callback, num[3];
  menu_item_getinfo(menu, item, access, num, charsmax(num), _, _, callback);
  menu_destroy(menu);

  new pick = str_to_num(num);
  switch(pick)
  {
    case 1:	cmd_freeday_one(id);
    case 2: begin_freeday_all(id);
    case 3: end_freeday(id+TASK_FREEDAY);
  }

  return PLUGIN_HANDLED;
}

public cmd_freeday_one(id)
{
  if(!in_progress(0, GI_DAY) || day_equal(g_pMyNewDay))
  {
    if(simon_or_admin(id))
    {
      static name[32], data[3], menu;
      menu = menu_create(g_szDayName, "cmd_freeday_one_handle");

      new num, i;
      static players[32];
      get_players(players, num, "ae", "TERRORIST");

      for(--num; num >= 0; num--)
      {
        i = players[num];
        if(jail_get_playerdata(i, PD_FREEDAY)) continue;
        get_user_name(i, name, charsmax(name));
        num_to_str(i, data, charsmax(data));
        menu_additem(menu, name, data, 0);
      }
      menu_display(id, menu);
    }
  }
}

public cmd_freeday_one_handle(id, menu, item)
{
  if(item == MENU_EXIT || !is_user_alive(id) || !simon_or_admin(id))
  {
    menu_destroy(menu);
    return PLUGIN_HANDLED;
  }

  new access, callback, num[3], player;
  menu_item_getinfo(menu, item, access, num, charsmax(num), _, _, callback);
  menu_destroy(menu);

  player = str_to_num(num);
  begin_freeday_one(player, SKIN_FREEDAY, true, true);
  set_task(get_pcvar_float(cvar_freeday_time), "end_freeday", player);

  static nameS[32], nameP[32];
  get_user_name(id, nameS, charsmax(nameS));
  get_user_name(player, nameP, charsmax(nameP));
  ColorChat(0, NORMAL, "%s %L", JAIL_TAG, LANG_SERVER, "JAIL_DAY0_EXTRA1", nameS, nameP, g_szDayName);

  cmd_freeday_one(id);

  return PLUGIN_HANDLED;
}

begin_freeday_all(simon)
{
  new num, id;
  static players[32];
  get_players(players, num, "ae", "TERRORIST");

  for(--num; num >= 0; num--)
  {
    id = players[num];
    begin_freeday_one(id, SKIN_FREEDAY, true, false);
  }

  client_cmd(0, "spk ^"%s^"", g_szBrassBell);
  server_event(simon, g_szDayName, false);
  jail_celldoors(simon, TS_OPENED);

  g_iTimeOnClock = RoundTimerGet()-floatround(jail_get_roundtime());
  RoundTimerSet(0, get_pcvar_num(cvar_freeday_time));
  jail_set_globalinfo(GI_DAY, g_pMyNewDay);
  jail_set_globalinfo(GI_NOFREEBIES, true);
  set_task(get_pcvar_float(cvar_freeday_time), "end_freeday", TASK_FREEDAY+simon);
}

begin_freeday_one(id, skin, value, print)
{
  jail_set_playerdata(id, PD_FREEDAY, value);
  if(is_user_alive(id))
    entity_set_int(id, EV_INT_skin, skin);

  if(print)
    ColorChat(id, NORMAL, "%s %L", JAIL_TAG, id, "JAIL_DAY0_AWARDED", g_szDayName);
}

public ask_freebies(event, type)
{
  if(day_equal(g_pMyNewDay))
    return;

  new num, id;
  static players[32];
  get_players(players, num, "ae", "TERRORIST");

  for(--num; num >= 0; num--)
  {
    id = players[num];
    if(jail_get_playerdata(id, PD_FREEDAY))
    {
      g_iFreebieInfo[id][0] = event;
      g_iFreebieInfo[id][1] = type;
      ask_freebies_show(id, event, type);
    }
  }
}

public ask_freebies_show(id, event, type)
{
  set_task(5.0, "close_menu", id+TASK_FREEBIE);
  static menu, option[JAIL_MENUITEM], eventname[JAIL_MENUITEM];
  if(type == GI_GAME) jail_game_getname(event, eventname);
  else jail_day_getname(event, eventname);

  formatex(option, charsmax(option), "%L", id, "JAIL_DAY0_JOIN", eventname);
  menu = menu_create(option, "ask_freebies_handle");

  formatex(option, charsmax(option), "Yes");
  menu_additem(menu, option, "1", 0);
  formatex(option, charsmax(option), "No");
  menu_additem(menu, option, "0", 0);

  menu_display(id, menu);

  return PLUGIN_HANDLED;
}

public ask_freebies_handle(id, menu, item)
{
  if(task_exists(id+TASK_FREEBIE))
    remove_task(id+TASK_FREEBIE);

  if(item == MENU_EXIT || !is_user_alive(id))
  {
    menu_destroy(menu);
    return PLUGIN_HANDLED;
  }

  new access, callback, num[3], pick;
  menu_item_getinfo(menu, item, access, num, charsmax(num), _, _, callback);
  menu_destroy(menu);

  pick = str_to_num(num);
  if(pick)
  {
    new ret;
    ExecuteForward(g_pForwardFreebieJoin, ret, id, g_iFreebieInfo[id][0], g_iFreebieInfo[id][1]);
    if(ret) end_freeday(id);
  }

  return PLUGIN_HANDLED;
}

public close_menu(taskid)
{
  new id = taskid - TASK_FREEBIE;
  menu_cancel(id);
  show_menu(id, 0, "^n", 1);
}

public _player_freebie(plugin, params)
{
  if(params != 3)
    return -1;

  new id = get_param(1);
  new val = get_param(2);
  if(task_exists(id))
    remove_task(id);

  begin_freeday_one(id, val ? SKIN_FREEDAY : jail_get_playerdata(id, PD_SKIN), val, val ? get_param(3) : 0);

  return 1;
}

public _ask_freebie(plugin, params)
{
  if(params != 2)
    return -1;

  if(!jail_get_globalinfo(GI_NOFREEBIES))
  {
    ask_freebies(get_param(1), get_param(2));
    return 1;
  }

  return 0;
}
