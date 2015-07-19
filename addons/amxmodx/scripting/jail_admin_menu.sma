#include <amxmodx>
#include <engine>
#include <hamsandwich>
#include <jailbreak>

enum _:MENU_ADMIN
{
  MENU_BALL,
  MENU_REVIVE,
  MENU_BLOCK
}

new const g_szMenuNames[][] = {
  "BALL_BALLMENU",
  "JAIL_REVIVE",
  "JAIL_BLOCKMENU"
};

public plugin_init()
{
  register_plugin("[JAIL] Admin menu", JAIL_VERSION, JAIL_AUTHOR);

  set_client_commands("admin", "cmd_show_menu");
  set_client_commands("revive", "revive_show_menu");
}

public cmd_show_menu(id)
{
  if(is_user_alive(id) && my_check(id))
  {
    static menu, option[64], num[3];
    formatex(option, charsmax(option), "%L", id, "JAIL_MENUMENU");
    menu = menu_create(option, "show_menu_handle");

    for(new i = 0; i < MENU_ADMIN; i++)
    {
      formatex(num, charsmax(num), "%d", i);
      formatex(option, charsmax(option), "%L", id, g_szMenuNames[i]);
      menu_additem(menu, option, num, 0);
    }

    menu_display(id, menu);
  }
}

public show_menu_handle(id, menu, item)
{
  if(item == MENU_EXIT || !is_user_alive(id) || !my_check(id))
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
    case MENU_BALL:	client_cmd(id, "jail_ball");
    case MENU_REVIVE:	revive_show_menu(id);
    case MENU_BLOCK:	client_cmd(id, "block");
  }

  return PLUGIN_HANDLED;
}

public revive_show_menu(id)
{
  if(is_jail_admin(id))
    show_player_menu(id, 1, "be", "revive_show_menu_handle");
}

public revive_show_menu_handle(id, menu, item)
{
  if(item == MENU_EXIT || !is_user_alive(id) || !my_check(id))
  {
    menu_destroy(menu);
    return PLUGIN_HANDLED;
  }

  new access, callback, num[3];
  menu_item_getinfo(menu, item, access, num, charsmax(num), _, _, callback);
  menu_destroy(menu);

  new userid = str_to_num(num);
  static name[2][32];
  get_user_name(id, name[0], charsmax(name[]));
  get_user_name(userid, name[1], charsmax(name[]));

  if(!is_user_alive(userid))
  {
    ExecuteHamB(Ham_CS_RoundRespawn, userid);
    client_print_color(0, print_team_default, "%s %L", JAIL_TAG, LANG_SERVER, "JAIL_REVIVE_C", name[0], name[1]);
  }
  else client_print_color(id, print_team_default, "%s %L", JAIL_TAG, id, "JAIL_REVIVE_CA", name[1]);

  return PLUGIN_HANDLED;
}

my_check(id)
{
  if(is_jail_admin(id) && !in_progress(id, GI_DAY) && !in_progress(id, GI_GAME))
    return 1;

  return 0;
}
