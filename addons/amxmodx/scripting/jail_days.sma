#include <amxmodx>
#include <hamsandwich>
#include <jailbreak>

enum _:DAYSDATA
{
  DAY_NAME[JAIL_MENUITEM],
  DAY_CHAT[JAIL_CHATCOMMAND],
  DAY_AVAILABLE
}

new g_iTotalDays = 0;
new g_pDayForwardStart, g_pDayForwardEnd, g_pDayForwardChat, Array:g_aDays;

public plugin_init()
{
  register_plugin("[JAIL] Day menu base", JAIL_VERSION, JAIL_AUTHOR);

  set_client_commands("days", "jail_daysmenu_show");

  RegisterHamPlayer(Ham_Killed, "Ham_Killed_post", 1);
  g_aDays = ArrayCreate(DAYSDATA);

  g_pDayForwardStart = CreateMultiForward("jail_day_start", ET_STOP, FP_CELL, FP_CELL, FP_STRING);
  g_pDayForwardEnd = CreateMultiForward("jail_day_end", ET_STOP, FP_CELL, FP_CELL, FP_STRING);
  g_pDayForwardChat = CreateMultiForward("jail_day_command", ET_STOP, FP_CELL, FP_STRING);
}

public plugin_natives()
{
  register_library("jailbreak");
  register_native("jail_day_add", "_day_add");
  register_native("jail_day_update", "_day_update");
  register_native("jail_day_byname", "_day_byname");
  register_native("jail_day_byid", "_day_byid");
  register_native("jail_day_getname", "_day_getname");
  register_native("jail_day_getid", "_day_getid");
  register_native("jail_day_forceend", "_day_forceend");
}

public client_disconnect(id)
{
  if(!jail_get_globalinfo(GI_EVENTSTOP))
    day_end_check(1);
  else day_end_check(0);
}

public Ham_Killed_post(victim, killer, shouldgib)
{
  if(!jail_get_globalinfo(GI_EVENTSTOP))
    day_end_check(1);
}

public jail_gamemode(mode)
{
  if(mode == GAME_ENDED || mode == GAME_RESTARTING)
  {
    new day = jail_get_globalinfo(GI_DAY);
    if(day) day_end(day);
  }
}

public jail_chat_show(id)
{
  if(simon_or_admin(id) && is_user_alive(id) && !in_progress(id, GI_GAME))
  {
    new day;
    static command[32], split[32], ret, data[DAYSDATA];
    read_argv(0, command, charsmax(command));

    if(equal(command, "say") || equal(command, "say_team"))
    {
      read_argv(1, command, charsmax(command));
      strtok(command, split, charsmax(split), command, charsmax(command), '/');
      if((day = find_day(command)))
      {
        ArrayGetArray(g_aDays, day, data);
        ExecuteForward(g_pDayForwardChat, ret, id, command);
        if(day_equal(day))
          ExecuteForward(g_pDayForwardEnd, ret, id, day, data[DAY_NAME]);
        else if(!in_progress(id, GI_DAY))
        {
          jail_game_forceend(jail_get_globalinfo(GI_GAME));
          ExecuteForward(g_pDayForwardStart, ret, id, day, data[DAY_NAME]);
          if(ret && !equal(command, "fd")) jail_ask_freebie(day, GI_DAY);
        }
      }
    }
    else
    {
      strtok(command, split, charsmax(split), command, charsmax(command), '_');
      if((day = find_day(command)))
      {
        ArrayGetArray(g_aDays, day, data);
        ExecuteForward(g_pDayForwardChat, ret, id, command);
        if(day_equal(day))
          ExecuteForward(g_pDayForwardEnd, ret, id, day, data[DAY_NAME]);
        else if(!in_progress(id, GI_DAY))
        {
          jail_game_forceend(jail_get_globalinfo(GI_GAME));
          ExecuteForward(g_pDayForwardStart, ret, id, day, data[DAY_NAME]);
          if(ret && !equal(command, "fd")) jail_ask_freebie(day, GI_DAY);
        }
      }
      return PLUGIN_HANDLED;
    }
  }

  return PLUGIN_CONTINUE;
}

public jail_daysmenu_show(id)
{
  if(!is_user_alive(id) || !simon_or_admin(id) || in_progress(id, GI_GAME))
    return PLUGIN_HANDLED;

  if(!g_iTotalDays)
  {
    client_print_color(id, print_team_default, "%s %L", JAIL_TAG, id, "JAIL_NODAYSADDED");
    return PLUGIN_HANDLED;
  }

  new day = jail_get_globalinfo(GI_DAY), i;
  static data[DAYSDATA], name[JAIL_MENUITEM], num[3];
  formatex(name, charsmax(name), "%L", LANG_SERVER, "JAIL_DAYMENU");
  new iMenu = menu_create(name, "jail_daysmenu_handle");

  for(i = 1; i <= g_iTotalDays; i++)
  {
    ArrayGetArray(g_aDays, i, data);
    if(!data[DAY_AVAILABLE]) continue;
    if(!day)
    {
      formatex(name, charsmax(name), "%s\R\y", data[DAY_NAME]);
      num_to_str(i, num, charsmax(num));
      menu_additem(iMenu, name, num);
    }
    else if(day == i)
    {
      formatex(name, charsmax(name), "%L\R\r", LANG_SERVER, "JAIL_EVENTEND", data[DAY_NAME]);
      num_to_str(i, num, charsmax(num));
      menu_additem(iMenu, name, num);
    }
  }

  menu_display(id, iMenu, 0);
  return PLUGIN_CONTINUE;
}

public jail_daysmenu_handle(id, menu, item)
{
  if(item == MENU_EXIT || !is_user_alive(id) || !simon_or_admin(id) || in_progress(id, GI_GAME))
  {
    menu_destroy(menu);
    return PLUGIN_HANDLED;
  }

  new access, callback, num[3];
  menu_item_getinfo(menu, item, access, num, charsmax(num), _, _, callback);
  menu_destroy(menu);

  new dayID = str_to_num(num);
  static data[DAYSDATA];
  ArrayGetArray(g_aDays, dayID, data);

  new ret;
  if(in_progress_current(GI_DAY, dayID))
    ExecuteForward(g_pDayForwardEnd, ret, id, dayID, data[DAY_NAME]);
  else if(!in_progress(0, GI_DAY))
  {
    // jail_game_forceend(jail_get_globalinfo(GI_GAME));
    ExecuteForward(g_pDayForwardStart, ret, id, dayID, data[DAY_NAME]);
    if(ret) jail_ask_freebie(dayID, GI_DAY);
  }

  return PLUGIN_HANDLED;
}

public _day_add(plugin, params)
{
  if(params != 3)
    return -1;

  static data[DAYSDATA];
  get_string(1, data[DAY_NAME], charsmax(data[DAY_NAME]));
  get_string(2, data[DAY_CHAT], charsmax(data[DAY_CHAT]));
  data[DAY_AVAILABLE] = get_param(3);

  set_client_commands(data[DAY_CHAT], "jail_chat_show");

  ArrayPushArray(g_aDays, data);
  if(!g_iTotalDays)
    ArrayPushArray(g_aDays, data);

  g_iTotalDays++;
  return g_iTotalDays;
}

public _day_update(plugin, params)
{
  if(params != 4)
    return -1;

  static data[DAYSDATA];
  new day = get_param(1);
  get_string(2, data[DAY_NAME], charsmax(data[DAY_NAME]));
  get_string(3, data[DAY_CHAT], charsmax(data[DAY_CHAT]));
  data[DAY_AVAILABLE] = get_param(4);

  ArraySetArray(g_aDays, day, data);

  return 1;
}

public _day_byname(plugin, params)
{
  if(params != 3)
    return -1;

  static dayname[JAIL_MENUITEM];
  new id = get_param(1);
  get_string(2, dayname, charsmax(dayname));
  new value = get_param(3);

  return _byname(id, dayname, value);
}

public _day_byid(plugin, params)
{
  if(params != 3)
    return -1;

  new id = get_param(1);
  new dayid = get_param(2);
  new value = get_param(3);

  return _byid(id, dayid, value);
}

public _day_getname(plugin, params)
{
  if(params != 2)
    return -1;

  static data[DAYSDATA];
  new day = get_param(1);
  ArrayGetArray(g_aDays, day, data);
  set_string(2, data[DAY_NAME], charsmax(data[DAY_NAME]));

  return 1;
}

public _day_getid(plugin, params)
{
  if(params != 1)
    return -1;

  static dayname[JAIL_MENUITEM];
  get_string(1, dayname, charsmax(dayname));

  return _byname(0, dayname, 2);
}

public _day_forceend(plugin, params)
{
  if(params != 1)
    return -1;

  new day = get_param(1);
  if(day) day_end(day);
  else return -1;

  return 1;
}

_byname(id, dayname[], value)
{
  new ret;
  static data[DAYSDATA];
  for(new i = 1; i <= g_iTotalDays; i++)
    {
    ArrayGetArray(g_aDays, i, data);
    if(equal(dayname, data[DAY_NAME]))
    {
      if(value == 2)
        return i;

      if(value == 0)
      {
        jail_game_forceend(jail_get_globalinfo(GI_GAME));
        ExecuteForward(g_pDayForwardStart, ret, id, i, data[DAY_NAME]);
        if(ret) jail_ask_freebie(i, GI_DAY);
      }
      else if(value == 1)
        ExecuteForward(g_pDayForwardEnd, ret, id, i, data[DAY_NAME]);

      return ret;
    }
  }

  return -1;
}

_byid(id, dayid, value)
{
  new ret;
  static data[DAYSDATA];
  for(new i = 1; i <= g_iTotalDays; i++)
    {
    ArrayGetArray(g_aDays, i, data);
    if(i == dayid)
    {
      if(!value)
      {
        jail_game_forceend(jail_get_globalinfo(GI_GAME));
        ExecuteForward(g_pDayForwardStart, ret, id, i, data[DAY_NAME]);
        if(ret) jail_ask_freebie(i, GI_DAY);
      }
      else ExecuteForward(g_pDayForwardEnd, ret, id, i, data[DAY_NAME]);

      return ret;
    }
  }

  return -1;
}

day_end(day = 0)
{
  if(!day)
    day = jail_get_globalinfo(GI_DAY);

  if(day)
  {
    new ret;
    static data[DAYSDATA];
    ArrayGetArray(g_aDays, day, data);
    ExecuteForward(g_pDayForwardEnd, ret, 0, day, data[DAY_NAME]);
  }
}

day_end_check(val = 0)
{
  new numT, numCT;
  static players[32];
  get_players(players, numT, "ae", "TERRORIST");
  get_players(players, numCT, "ae", "CT");

  if(val)
  {
    if(numT < 2)
      day_end(0);
  }
  else
  {
    if(!numCT)
      day_end(0);
  }
}

find_day(cmd[])
{
  static data[DAYSDATA];
  new day;
  for(new i = 1; i <= g_iTotalDays; i++)
  {
    ArrayGetArray(g_aDays, i, data);
    if(equal(cmd, data[DAY_CHAT]))
    {
      day = i;
      break;
    }
  }

  return day;
}
