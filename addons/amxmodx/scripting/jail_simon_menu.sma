#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <hamsandwich>
#include <cs_teams_api>
#include <jailbreak>

new g_iPlayerPick[33];
new g_iBlindState[33];
enum MENU_SIMON
{
  MENU_TRANSFER,
  MENU_GIVEMIC,
  MENU_DAYS,
  MENU_GAMES,
  MENU_ALLOWNADES,
  MENU_REVERSE,
  MENU_BLIND,
  MENU_SKIN
}

const g_szMenuNames[][] =
{
  "JAIL_TRANSFER",
  "JAIL_GIVEMIC",
  "JAIL_DAYMENU",
  "JAIL_ALLOWNADES",
  "JAIL_GAMEMENU",
  "JAIL_REVERSE",
  "JAIL_BLIND",
  "JAIL_SKIN"
};

public plugin_init()
{
  register_plugin("[JAIL] Simon menu", JAIL_VERSION, JAIL_AUTHOR);

  set_client_commands("menu", "cmd_show_menu");
  set_client_commands("transfer", "transfer_show_menu");
  set_client_commands("reverse", "reverse_gameplay");
  set_client_commands("mic", "give_mic");
  set_client_commands("blind", "blind_show_menu");
}

public jail_gamemode(mode)
{
  if(mode == GAME_STARTED)
  {
    new num, id;
    static players[32];
    get_players(players, num);

    for(--num; num >= 0; num--)
    {
      id = players[num];
      g_iBlindState[id] = 0;
      g_iPlayerPick[id] = 0;
    }
  }
}

public cmd_show_menu(id)
{
  if(is_user_alive(id) && my_check(id))
  {
    static option[64], num[3];
    new menu = my_menu_create("JAIL_MENUMENU", "show_menu_handle");
    new cvar = get_pcvar_num(get_cvar_pointer("jail_prisoner_grenade");

    for(new i = 0; i < MENU_SIMON; i++)
    {
      if(i == MENU_ALLOWNADES && cvar) continue;

      formatex(num, charsmax(num), "%d", i);
      if(i == MENU_REVERSE)
        formatex(option, charsmax(option), "%L", id, g_szMenuNames[i], id, jail_get_globalinfo(GI_REVERSE) ? "JAIL_PRISONERS" : "JAIL_GUARDS");
      else formatex(option, charsmax(option), "%L", id, g_szMenuNames[i]);
      menu_additem(menu, option, num, 0);
    }

    menu_display(id, menu);
  }
}

public show_menu_handle(id, menu, item)
{
  new pick = my_menu_item(id, item, menu);
  if(pick == -1)
    return PLUGIN_HANDLED;

  switch(pick)
  {
    case MENU_TRANSFER:	transfer_show_menu(id);
    case MENU_GIVEMIC: give_mic(id);
    case MENU_DAYS: client_cmd(id, "jail_days");
    case MENU_GAMES: client_cmd(id, "jail_games");
    case MENU_ALLOWNADES: nades_show_menu(id);
    case MENU_REVERSE: reverse_gameplay(id);
    case MENU_BLIND: blind_show_menu(id);
    case MENU_SKIN: blind_show_menu(id);
  }

  return PLUGIN_HANDLED;
}

public give_mic(id)
{
  show_player_menu(id, 1, "ae", "MIC_transfer_show_menu_handle");
}

public reverse_gameplay(id)
{
  new reverse = !jail_get_globalinfo(GI_REVERSE);
  jail_set_globalinfo(GI_REVERSE, reverse);
  cmd_show_menu(id);

  static name[32];
  get_user_name(id, name, charsmax(name));
  client_print_color(0, print_team_default, "%s %L", JAIL_TAG, LANG_SERVER, "JAIL_REVERSE_C", name, LANG_SERVER, reverse ? "JAIL_PRISONERS" : "JAIL_GUARDS");
}

public blind_show_menu(id)
{
  show_player_menu(id, 1, "ae", "blind_show_menu_handle");
}

public skin_show_menu(id)
{
  show_player_menu(id, 1, "ae", "skin_show_menu_handle");
}

public transfer_show_menu(id)
{
  new menu = my_menu_create("JAIL_MENUMENU", "transfer_show_menu_handle");
  menu_additem(menu, "To T", "0", 0);
  menu_additem(menu, "To CT", "1", 0);
  menu_display(id, menu);
}

public nades_show_menu(id)
{
  if(is_user_alive(id))
  {
    new menu = my_menu_create("JAIL_ALLOWNADES", "nades_show_menu_handle");
    menu_additem(menu, "All T", "0", 0);
    menu_additem(menu, "Specific", "1", 0);
    menu_display(id, menu);
  }
}

public duration_show_menu(id, pick)
{
  new menu = my_menu_create("JAIL_MENUMENU", "duration_show_menu_handle");

  g_iPlayerPick[id] = pick;
  menu_additem(menu, "For this round", "1", 0);
  menu_additem(menu, "For ever", "2", 0);

  menu_display(id, menu);
}

public blind_show_menu_handle(id, menu, item)
{
  new userid = my_menu_item(id, item, menu);
  if(userid == -1)
    return PLUGIN_HANDLED;

  static name[2][32];
  set_user_blind(userid, !g_iBlindState[userid]);
  get_user_name(id, name[0], charsmax(name[]));
  get_user_name(userid, name[1], charsmax(name[]));
  client_print_color(0, print_team_default, "%s %L", JAIL_TAG, LANG_SERVER, "JAIL_BLIND_C", name[0], name[1]);

  return PLUGIN_HANDLED;
}

public transfer_show_menu_handle(id, menu, item)
{
  new pick = my_menu_item(id, item, menu);
  if(pick == -1)
    return PLUGIN_HANDLED;

  show_player_menu(id, pick, "ae", "TR_transfer_show_menu_handle");
  return PLUGIN_HANDLED;
}

public nades_show_menu_handle(id, menu, item)
{
  new pick = my_menu_item(id, item, menu);
  if(pick == -1)
    return PLUGIN_HANDLED;

  if(!pick)
  {
    static players[32], name[32];
    new num, i;
    get_players(players, num, "ae", "TERRORIST");

    for(--num; num >= 0; num--)
    {
      i = players[num];
      jail_set_playerdata(i, PD_REMOVEHE, !jail_get_playerdata(i, PD_REMOVEHE));
    }

    get_user_name(id, name, charsmax(name));
    client_print_color(0, print_team_default, "%s %L", JAIL_TAG, LANG_SERVER, "JAIL_ALLOWNADES_CA", name);
  }
  else show_player_menu(id, pick, "ae", "DO_nades_show_menu_handle");

  return PLUGIN_HANDLED;
}

public TR_transfer_show_menu_handle(id, menu, item)
{
  new pick = my_menu_item(id, item, menu);
  if(pick == -1)
    return PLUGIN_HANDLED;

  new CsTeams:team = cs_get_user_team(pick);
  static name[2][32];
  get_user_name(pick, name[0], charsmax(name[]));
  get_user_name(id, name[1], charsmax(name[]));

  if(team == CS_TEAM_T)
  {
    cs_set_player_team(pick, CS_TEAM_CT);
    client_print_color(0, print_team_default, "%s %L", JAIL_TAG, LANG_SERVER, "JAIL_TRANSFER_C", name[0], LANG_SERVER, "JAIL_GUARDS", name[1]);
  }
  else if(team == CS_TEAM_CT)
  {
    cs_set_player_team(pick, CS_TEAM_T);
    client_print_color(0, print_team_default, "%s %L", JAIL_TAG, LANG_SERVER, "JAIL_TRANSFER_C", name[0], LANG_SERVER, "JAIL_PRISONERS", name[1]);
  }
  strip_weapons(pick);
  ExecuteHamB(Ham_CS_RoundRespawn, pick);

  return PLUGIN_HANDLED;
}

public DO_nades_show_menu_handle(id, menu, item)
{
  new pick = my_menu_item(id, item, menu);
  if(pick == -1)
    return PLUGIN_HANDLED;

  static name[2][32];
  get_user_name(pick, name[0], charsmax(name[]));
  get_user_name(id, name[1], charsmax(name[]));

  jail_set_playerdata(pick, PD_REMOVEHE, !jail_get_playerdata(pick, PD_REMOVEHE));
  client_print_color(0, print_team_default, "%s %L", JAIL_TAG, LANG_SERVER, "JAIL_ALLOWNADES_C", name[0], name[1]);

  return PLUGIN_HANDLED;
}

public MIC_transfer_show_menu_handle(id, menu, item)
{
  new pick = my_menu_item(id, item, menu);
  if(pick == -1)
    return PLUGIN_HANDLED;

  if(jail_get_playerdata(pick, PD_TALK))
    print_voice_change(id, pick);
  else duration_show_menu(id, pick);
  return PLUGIN_HANDLED;
}

public duration_show_menu_handle(id, menu, item)
{
  new pick = my_menu_item(id, item, menu);
  if(pick == -1)
    return PLUGIN_HANDLED;

  print_voice_change(id, g_iPlayerPick[id]);
  if(pick == 2)
    jail_set_playerdata(g_iPlayerPick[id], PD_TALK_FOREVER, true);

  g_iPlayerPick[id] = 0;
  return PLUGIN_HANDLED;
}

public skin_show_menu_handle(id, menu, item)
{
  new user_id = my_menu_item(id, item, menu);
  if(user_id == -1)
    return PLUGIN_HANDLED;

  g_iPlayerPick[id] = my_menu_create("JAIL_MENUMENU", "PL_skin_show_menu_handle");

  formatex(option, charsmax(option), "%d", PS_GREEN);
  menu_additem(menu, "Green", option, 0);
  formatex(option, charsmax(option), "%d", PS_RED);
  menu_additem(menu, "Red", option, 0);
  formatex(option, charsmax(option), "%d", PS_BLUE);
  menu_additem(menu, "Blue", option, 0);
  formatex(option, charsmax(option), "%d", PS_PURPLE);
  menu_additem(menu, "Purple", option, 0);
  formatex(option, charsmax(option), "%d", PS_ORANGE);
  menu_additem(menu, "Orange", option, 0);

  menu_display(id, menu);
  return PLUGIN_HANDLED;
}

public PL_skin_show_menu_handle(id, menu, item)
{
  new pick = my_menu_item(id, item, menu);
  if(pick == -1 || !is_user_alive(g_iPlayerPick[id]))
    return PLUGIN_HANDLED;

  static name[2][32];
  set_player_model(g_iPlayerPick[id], JAIL_T_MODEL, pick);
  get_user_name(g_iPlayerPick[id], name[0], charsmax(name[]));
  get_user_name(id, name[1], charsmax(name[]));
  client_print_color(0, print_team_default, "%s %L", JAIL_TAG, LANG_SERVER, "JAIL_CHANGESKIN_C", name[1], name[0]);
  g_iPlayerPick[id] = 0;
  return PLUGIN_HANDLED;
}

///////////////////

stock print_voice_change(id, pick)
{
  static name[2][32];
  get_user_name(pick, name[0], charsmax(name[]));
  get_user_name(id, name[1], charsmax(name[]));
  jail_set_playerdata(pick, PD_TALK, !jail_get_playerdata(pick, PD_TALK));
  jail_set_playerdata(pick, PD_TALK_FOREVER, false);
  client_print_color(0, print_team_default, "%s %L", JAIL_TAG, LANG_SERVER, "JAIL_GIVEMIC_C", name[1], name[0]);
}

stock my_check(id)
{
  if(simon_or_admin(id) && !in_progress(id, GI_DAY) && !in_progress(id, GI_GAME))
    return 1;

  return 0;
}

stock set_user_blind(id, type)
{
  g_iBlindState[id] = type;
  if(type)
    type = 0x0004;
  else type = 0x0000;

  message_begin(MSG_ONE_UNRELIABLE, g_pMsgScreeFade, _, id);
  write_short(1 * 1<<12);
  write_short(4*1<<12);
  write_short(type);
  write_byte(0);
  write_byte(0);
  write_byte(0);
  write_byte(255);
  message_end();
}

stock show_player_menu(id, pick, status, handle[])
{
  new inum, i, menu = my_menu_create("JAIL_MENUMENU", handle);
  static players[32], data[3];
  get_players(players, inum, status, pick ? "TERRORIST" : "CT");

  for(--inum; inum >= 0; inum--)
  {
    i = players[inum];
    if(jail_get_playerdata(i, PD_FREEDAY)) continue;
    get_user_name(i, name, charsmax(name));
    num_to_str(i, data, charsmax(data));
    menu_additem(menu, name, data, 0);
  }

  menu_display(id, menu);
}

stock my_menu_create(name[], handle[])
{
  static option[64];
  formatex(option, charsmax(option), "%L", id, name);
  return menu_create(option, handle);
}

stock my_menu_item(id, item, menu)
{
  if(item == MENU_EXIT || !is_user_alive(id) || !my_check(id))
  {
    menu_destroy(menu);
    return -1;
  }

  new access, callback, num[3];
  menu_item_getinfo(menu, item, access, num, charsmax(num), _, _, callback);
  menu_destroy(menu);

  return str_to_num(num);
}
