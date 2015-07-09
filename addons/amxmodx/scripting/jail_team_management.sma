#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <cs_teams_api>
#include <jailbreak>

#define m_fGameHUDInitialized	349
#define m_iNumSpawns			365
#define m_iVGUI					510
#define TEAM_MENU		"#Team_Select_Spect"
#pragma dynamic 32768
new cvar_change_team, cvar_ct_max, cvar_ct_ratio;
new g_pMsgVGUIMenu, g_pMsgShowMenu;

public plugin_init()
{
  register_plugin("[JAIL] Team management", JAIL_VERSION, JAIL_AUTHOR);

  cvar_change_team = register_cvar("jail_change_team", "3"); // 0=noone, 1=admins, 2=ct, 3=admins+ct, 4=all
  cvar_ct_max = register_cvar("jail_ct_max", "7");
  cvar_ct_ratio = register_cvar("jail_ct_ratio", "3");

  register_clcmd("jointeam", "cmd_block");
  register_clcmd("joinclass", "cmd_block");

  g_pMsgVGUIMenu = get_user_msgid("VGUIMenu");
  g_pMsgShowMenu = get_user_msgid("ShowMenu");
  register_message(g_pMsgVGUIMenu, "Message_VGUIMenu");
  register_message(g_pMsgShowMenu, "Message_ShowMenu");
}

public client_putinserver(id)
{
  if(jail_get_gamemode() == GAME_STARTED && !is_user_bot(id))
  {
    static freeday;
    if(!freeday)
    {
      static day[JAIL_MENUITEM];
      formatex(day, charsmax(day), "%L", LANG_SERVER, "JAIL_DAY0");
      freeday = jail_day_getid(day);
    }

    if(jail_get_globalinfo(GI_DAY) != freeday)
    {
      if(jail_get_globalinfo(GI_DAYCOUNT) > 1)
        set_pdata_int(id, m_iNumSpawns, 1);
    }
    else if(jail_get_globalinfo(GI_DAYCOUNT) == 1)
      jail_set_playerdata(id, PD_FREEDAY, true);
  }
}

public jail_gamemode(mode)
{
  if(mode == GAME_STARTED)
  {
    new num, id;
    static players[32];
    get_players(players, num, "bh");
    for(--num; num >= 0; num--)
    {
      id = players[num];
      set_pdata_int(id, m_iNumSpawns, 1);
    }
  }
}

public Message_VGUIMenu(msgid, dest, id)
{
  show_my_menu(id);
  return PLUGIN_HANDLED;
}

public Message_ShowMenu(msgid, dest, id)
{
  new msgarg1 = get_msg_arg_int(1);

  if(msgarg1 != 531 && msgarg1 != 563)
    return PLUGIN_CONTINUE;

  show_my_menu(id);
  return PLUGIN_HANDLED;
}

public cmd_block(id)
  return PLUGIN_HANDLED;

public show_my_menu(id)
{
  if(cant_change(id))
    return PLUGIN_HANDLED;

  static menu;

  menu = menu_create("Select a team", "show_my_menu_handle");

  menu_additem(menu, "Prisoners team", "0", 0);
  menu_additem(menu, "Guards team", "1", 0);
  menu_addblank(menu, 1);
  menu_addblank(menu, 1);
  menu_additem(menu, "Specatator", "2", 0);

  menu_display(id, menu);

  return PLUGIN_HANDLED;
}

public show_my_menu_handle(id, menu, item)
{
  if(item == MENU_EXIT || cant_change(id))
  {
    menu_destroy(menu);
    return PLUGIN_HANDLED;
  }

  new access, callback, num[3];
  menu_item_getinfo(menu, item, access, num, charsmax(num), _, _, callback);
  menu_destroy(menu);

  new key = str_to_num(num);
  team_select(id, key);

  return PLUGIN_HANDLED;
}

public team_select(id, key)
{
  new CsTeams:team = cs_get_user_team(id);

  switch(key)
  {
    case(0):
    {
      if(team == CS_TEAM_T || cant_change(id))
        return PLUGIN_HANDLED;

      team_join(id, CS_TEAM_T);
    }
    case(1):
    {
      if(team == CS_TEAM_CT || cant_change(id))
        return PLUGIN_HANDLED;

      if(ct_max(id))
        team_join(id, CS_TEAM_CT);
    }
    case(2):
    {
      user_silentkill(id);
      team_join(id, CS_TEAM_SPECTATOR);
    }
  }
  return PLUGIN_HANDLED;
}

public team_join(id, CsTeams:team)
{
  switch(team)
  {
    case CS_TEAM_SPECTATOR:
    {
      dllfunc(DLLFunc_ClientPutInServer, id);
      set_pdata_int(id, m_fGameHUDInitialized, 1);
      engclient_cmd(id, "jointeam", "6");
      cs_set_player_team(id, team);
    }
    case CS_TEAM_T, CS_TEAM_CT:
    {
      engclient_cmd(id, "jointeam", (team == CS_TEAM_CT) ? "2" : "1");
      engclient_cmd(id, "joinclass", "1");
      cs_set_player_team(id, team);
    }
  }

  menu_cancel(id);
  show_menu(id, 0, "^n", 1);
}

public cant_change(id)
{
  if(!is_user_connected(id))
    return PLUGIN_HANDLED;

  new cvar = get_pcvar_num(cvar_change_team);
  if(cvar == 0)
  {
    client_print(id, print_center, "%L", id, "JAIL_CANTCHANGE");
    return PLUGIN_HANDLED;
  }
  else if(cvar == 4)
    return PLUGIN_CONTINUE;
  else
  {
    new CsTeams:team = cs_get_user_team(id);
    if(is_user_alive(id) && team == CS_TEAM_T && ct_max(id))
      return PLUGIN_CONTINUE;
    else
    {
      if(team != CS_TEAM_UNASSIGNED && team != CS_TEAM_SPECTATOR)
      {
        if(cvar == 3)
        {
          if(team == CS_TEAM_CT || is_jail_admin(id))
            return PLUGIN_CONTINUE;
        }
        else if(cvar == 2)
        {
          if(team == CS_TEAM_CT)
            return PLUGIN_CONTINUE;
        }
        else if(cvar == 1)
        {
          if(is_jail_admin(id))
            return PLUGIN_CONTINUE;
        }
      }
      else return PLUGIN_CONTINUE;
    }
  }

  client_print(id, print_center, "%L", id, "JAIL_CANTCHANGE");
  return PLUGIN_HANDLED;
}

public ct_max(id)
{
  new num, limit;
  new players[32];
  get_players(players, num, "e", "CT");
  get_players(players, limit, "e", "TERRORIST");

  limit = limit/get_pcvar_num(cvar_ct_ratio);
  if(limit < 2)
    limit = 2;
  else if(limit > get_pcvar_num(cvar_ct_max))
    limit = get_pcvar_num(cvar_ct_max);

  if(num >= limit && !admin_check(id))
  {
    client_print(id, print_center, "%L", id, "JAIL_CTLIMIT", limit);
    return 0;
  }

  return 1;
}

public admin_check(id)
{
  new cvar = get_pcvar_num(cvar_change_team);
  if(is_jail_admin(id) && (cvar == 3 || cvar == 1))
    return 1;

  return 0;
}
