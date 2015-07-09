#include <amxmodx>
#include <hamsandwich>
#include <jailbreak>

enum _:GAMESDATA
{
    GAME_NAME[JAIL_MENUITEM],
    GAME_CHAT[JAIL_CHATCOMMAND],
  GAME_AVAILABLE
}

new g_iTotalGames = 0;
new g_pGameForwardStart, g_pGameForwardEnd, g_pGameForwardChat, Array:g_aGames;

public plugin_init()
{
  register_plugin("[JAIL] Game menu base", JAIL_VERSION, JAIL_AUTHOR);

  set_client_commands("games", "jail_gamesmenu_show");

  RegisterHamPlayer(Ham_Killed, "Ham_Killed_post", 1);
  g_aGames = ArrayCreate(GAMESDATA);

  g_pGameForwardStart = CreateMultiForward("jail_game_start", ET_STOP, FP_CELL, FP_CELL, FP_STRING);
  g_pGameForwardEnd = CreateMultiForward("jail_game_end", ET_STOP, FP_CELL, FP_CELL, FP_STRING);
  g_pGameForwardChat = CreateMultiForward("jail_game_command", ET_STOP, FP_CELL, FP_STRING);
}

public plugin_natives()
{
  register_library("jailbreak");
  register_native("jail_game_add", "_game_add");
  register_native("jail_game_update", "_game_update");
  register_native("jail_game_byname", "_game_byname");
  register_native("jail_game_byid", "_game_byid");
  register_native("jail_game_getname", "_game_getname");
  register_native("jail_game_getid", "_game_getid");
  register_native("jail_game_forceend", "_game_forceend");
}

public client_disconnect(id)
{
  if(!jail_get_globalinfo(GI_EVENTSTOP))
    game_end_check(1);
  else game_end_check(0);
}

public Ham_Killed_post(victim, killer, shouldgib)
{
  if(!jail_get_globalinfo(GI_EVENTSTOP))
    game_end_check(1);
}

public jail_gamemode(mode)
{
  if(mode == GAME_ENDED || mode == GAME_RESTARTING)
  {
    new game = jail_get_globalinfo(GI_GAME);
    if(game) game_end(game);
  }
}

public jail_chat_show(id)
{
  if(simon_or_admin(id) && is_user_alive(id) && !in_progress(id, GI_DAY))
  {
    new game;
    static command[32], split[32], ret, data[GAMESDATA];
    read_argv(0, command, charsmax(command));

    if(equal(command, "say") || equal(command, "say_team"))
    {
      read_argv(1, command, charsmax(command));
      strtok(command, split, charsmax(split), command, charsmax(command), '/');
      if((game = find_game(command)))
      {
        ArrayGetArray(g_aGames, game, data);
        ExecuteForward(g_pGameForwardChat, ret, id, command);
        if(game_equal(game))
          ExecuteForward(g_pGameForwardEnd, ret, id, game, data[GAME_NAME]);
        else if(!in_progress(id, GI_GAME))
        {
          jail_game_forceend(jail_get_globalinfo(GI_GAME));
          ExecuteForward(g_pGameForwardStart, ret, id, game, data[GAME_NAME]);
          if(ret) jail_ask_freebie(game, GI_GAME);
        }
      }
    }
    else
    {
      strtok(command, split, charsmax(split), command, charsmax(command), '_');
      if((game = find_game(command)))
      {
        ArrayGetArray(g_aGames, game, data);
        ExecuteForward(g_pGameForwardChat, ret, id, command);
        if(game_equal(game))
          ExecuteForward(g_pGameForwardEnd, ret, id, game, data[GAME_NAME]);
        else if(!in_progress(id, GI_GAME))
        {
          jail_game_forceend(jail_get_globalinfo(GI_GAME));
          ExecuteForward(g_pGameForwardStart, ret, id, game, data[GAME_NAME]);
          if(ret) jail_ask_freebie(game, GI_GAME);
        }
      }
      return PLUGIN_HANDLED;
    }
  }
  return PLUGIN_CONTINUE;
}

public jail_gamesmenu_show(id)
{
  if(!is_user_alive(id) || !simon_or_admin(id) || in_progress(id, GI_DAY))
    return PLUGIN_HANDLED;

  if(!g_iTotalGames)
  {
    ColorChat(id, NORMAL, "%s %L", JAIL_TAG, id, "JAIL_NOGAMESADDED");
    return PLUGIN_HANDLED;
  }

  new game = jail_get_globalinfo(GI_GAME), i;
  static data[GAMESDATA], name[JAIL_MENUITEM], num[3];
  formatex(name, charsmax(name), "%L", LANG_SERVER, "JAIL_GAMEMENU");
  new iMenu = menu_create(name, "jail_gamesmenu_handle");

  for(i = 1; i <= g_iTotalGames; i++)
    {
    ArrayGetArray(g_aGames, i, data);
    if(!data[GAME_AVAILABLE]) continue;
    if(!game)
    {
      formatex(name, charsmax(name), "%s\R\r", data[GAME_NAME]);
      num_to_str(i, num, charsmax(num));
      menu_additem(iMenu, name, num);
    }
    else if(game == i)
    {
      formatex(name, charsmax(name), "%L\R\r", LANG_SERVER, "JAIL_EVENTEND", data[GAME_NAME]);
      num_to_str(i, num, charsmax(num));
      menu_additem(iMenu, name, num);
    }
    }

  menu_display(id, iMenu, 0);
  return PLUGIN_CONTINUE;
}

public jail_gamesmenu_handle(id, menu, item)
{
  if(item == MENU_EXIT || !is_user_alive(id) || !simon_or_admin(id) || in_progress(id, GI_DAY))
  {
    menu_destroy(menu);
    return PLUGIN_HANDLED;
  }

  new access, callback, num[3];
  menu_item_getinfo(menu, item, access, num, charsmax(num), _, _, callback);
  menu_destroy(menu);

  new gameID = str_to_num(num);
  static data[GAMESDATA];
  ArrayGetArray(g_aGames, gameID, data);

  new ret;
  if(!in_progress(0, GI_GAME))
  {
    ExecuteForward(g_pGameForwardStart, ret, id, gameID, data[GAME_NAME]);
    if(ret) jail_ask_freebie(gameID, GI_GAME);
  }
  else ExecuteForward(g_pGameForwardEnd, ret, id, gameID, data[GAME_NAME]);

  return PLUGIN_HANDLED;
}

public _game_add(plugin, params)
{
  if(params != 3)
    return -1;

  static data[GAMESDATA];
  get_string(1, data[GAME_NAME], charsmax(data[GAME_NAME]));
  get_string(2, data[GAME_CHAT], charsmax(data[GAME_CHAT]));
  data[GAME_AVAILABLE] = get_param(3);

  set_client_commands(data[GAME_CHAT], "jail_chat_show");

  ArrayPushArray(g_aGames, data);
  if(!g_iTotalGames)
    ArrayPushArray(g_aGames, data);

  g_iTotalGames++;
  return g_iTotalGames;
}

public _game_update(plugin, params)
{
  if(params != 4)
    return -1;

  static data[GAMESDATA];
  new game = get_param(1);
  get_string(2, data[GAME_NAME], charsmax(data[GAME_NAME]));
  get_string(3, data[GAME_CHAT], charsmax(data[GAME_CHAT]));
  data[GAME_AVAILABLE] = get_param(4);

  ArraySetArray(g_aGames, game, data);

  return 1;
}

public _game_byname(plugin, params)
{
  if(params != 3)
    return -1;

  static gamename[JAIL_MENUITEM];
  new id = get_param(1);
  get_string(2, gamename, charsmax(gamename));
  new value = get_param(3);

  return _byname(id, gamename, value);
}

public _game_byid(plugin, params)
{
  if(params != 3)
    return -1;

  new id = get_param(1);
  new gameid = get_param(2);
  new value = get_param(3);

  return _byid(id, gameid, value);
}

public _game_getname(plugin, params)
{
  if(params != 2)
    return -1;

  static data[GAMESDATA];
  new game = get_param(1);
  ArrayGetArray(g_aGames, game, data);
  set_string(2, data[GAME_NAME], charsmax(data[GAME_NAME]));

  return 1;
}

public _game_getid(plugin, params)
{
  if(params != 1)
    return -1;

  static gamename[JAIL_MENUITEM];
  get_string(1, gamename, charsmax(gamename));

  return _byname(0, gamename, 2);
}

public _game_forceend(plugin, params)
{
  if(params != 1)
    return -1;

  new game = get_param(1);
  if(game) game_end(game);
  else return -1;

  return 1;
}

_byname(id, gamename[], value)
{
  new ret;
  static data[GAMESDATA];
  for(new i = 1; i <= g_iTotalGames; i++)
    {
    ArrayGetArray(g_aGames, i, data);
    if(equal(gamename, data[GAME_NAME]))
    {
      if(value == 2)
        return i;

      if(value == 0)
      {
        ExecuteForward(g_pGameForwardStart, ret, id, i, data[GAME_NAME]);
        if(ret) jail_ask_freebie(i, GI_GAME);
      }
      else if(value == 1)
        ExecuteForward(g_pGameForwardEnd, ret, id, i, data[GAME_NAME]);

      return ret;
    }
  }

  return -1;
}

_byid(id, gameid, value)
{
  new ret;
  static data[GAMESDATA];
  for(new i = 1; i <= g_iTotalGames; i++)
    {
    ArrayGetArray(g_aGames, i, data);
    if(i == gameid)
    {
      if(!value)
      {
        ExecuteForward(g_pGameForwardStart, ret, id, i, data[GAME_NAME]);
        if(ret) jail_ask_freebie(i, GI_GAME);
      }
      else ExecuteForward(g_pGameForwardEnd, ret, id, i, data[GAME_NAME]);

      return ret;
    }
  }

  return -1;
}

game_end(game = 0)
{
  if(!game)
    game = jail_get_globalinfo(GI_GAME);

  if(game)
  {
    new ret;
    static data[GAMESDATA];
    ArrayGetArray(g_aGames, game, data);
    ExecuteForward(g_pGameForwardEnd, ret, 0, game, data[GAME_NAME]);
  }
}

game_end_check(val = 0)
{
  new numT, numCT;
  static players[32];
  get_players(players, numT, "ae", "TERRORIST");
  get_players(players, numCT, "ae", "CT");

  if(val)
  {
    if(numT < 2)
      game_end(0);
  }
  else
  {
    if(!numCT)
      game_end(0);
  }
}

find_game(cmd[])
{
  static data[GAMESDATA];
  new game;
  for(new i = 1; i <= g_iTotalGames; i++)
  {
    ArrayGetArray(g_aGames, i, data);
    if(equal(cmd, data[GAME_CHAT]))
    {
      game = i;
      break;
    }
  }

  return game;
}
