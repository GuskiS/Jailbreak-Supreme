#include <amxmodx>
#include <fun>
#include <jailbreak>

new g_pMyNewGame, cvar_box_players;
new g_szGameName[JAIL_MENUITEM];

public plugin_init()
{
  register_plugin("[JAIL] Box", JAIL_VERSION, JAIL_AUTHOR);

  cvar_box_players = register_cvar("jail_box_players", "6");

  formatex(g_szGameName, charsmax(g_szGameName), "%L", LANG_PLAYER, "JAIL_GAME0");
  g_pMyNewGame = jail_game_add(g_szGameName, "box", 1);
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
    cmd_box_on(simon);
    return PLUGIN_HANDLED;
  }

  return PLUGIN_CONTINUE;
}

public jail_game_end(simon, game, gamename[])
{
  if(game == g_pMyNewGame)
  {
    cmd_box_off(simon);
    return PLUGIN_HANDLED;
  }

  return PLUGIN_CONTINUE;
}

public cmd_box_on(id)
{
  new num, i;
  static players[32];
  get_players(players, num, "ae", "TERRORIST");

  if(num <= get_pcvar_num(cvar_box_players))
  {
    for(--num; num >= 0; num--)
    {
      i = players[num];
      if(jail_get_playerdata(i, PD_FREEDAY)) continue;
      set_player_attributes(i);
    }

    server_event(id, g_szGameName, 0);
    set_cvar_num("mp_friendlyfire", 1);
    jail_set_globalinfo(GI_GAME, g_pMyNewGame);
  }
  else client_print_color(id, print_team_default, "%s %L", JAIL_TAG, id, "JAIL_GAME0_TOOMUCH", num, get_pcvar_num(cvar_box_players));

  return PLUGIN_HANDLED;
}

public cmd_box_off(id)
{
  server_event(id, g_szGameName, 1);
  set_cvar_num("mp_friendlyfire", 0);
  jail_set_globalinfo(GI_GAME, 0);
  jail_ham_all(0);
}

public set_player_attributes(id)
{
  jail_set_playerdata(id, PD_HAMBLOCK, true);
  set_user_health(id, 100);
}
