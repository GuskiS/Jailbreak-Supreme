#include <amxmodx>
#include <engine>
#include <cstrike>
#include <fakemeta>
#include <hamsandwich>
#include <jailbreak>

enum _: PICK_ORDER
{
  PICK_WEAPON,
  PICK_AMMO
}
new g_iPlayerPick[33][PICK_ORDER];

new const g_szPriWeap[] =
{
  CSW_SCOUT,
  CSW_MAC10,
  CSW_M249,
  CSW_M3,
  CSW_AWP,
  CSW_AK47,
  CSW_M4A1
};

new const g_szPriAmmo[] =
{
  90,
  100,
  200,
  32,
  30,
  90,
  90
};

public plugin_init()
{
  register_plugin("[JAIL] Weapons menu", JAIL_VERSION, JAIL_AUTHOR);

  set_client_commands("weapons", "weapons_show_menu");
}

public weapons_show_menu(id)
{
  if(is_user_alive(id))
  {
    g_iPlayerPick[id][PICK_WEAPON] = -1;
    g_iPlayerPick[id][PICK_AMMO] = -1;
    new menu = my_menu_create(id, "JAIL_MENUMENU", "weapons_show_menu_handle");
    static name[32], num[3];
    for(new i = 0; i < sizeof(g_szPriWeap); i++)
    {
      get_weaponname(g_szPriWeap[i], name, charsmax(name));
      formatex(num, charsmax(num), "%d", i);
      menu_additem(menu, name, num, 0);
    }

    menu_display(id, menu);
  }
}

public weapons_show_menu_handle(id, menu, item)
{
  new pick = my_menu_item(id, item, menu);
  if(pick == -1)
    return PLUGIN_HANDLED;

  g_iPlayerPick[id][PICK_WEAPON] = pick;
  new newmenu = my_menu_create(id, "JAIL_MENUMENU", "ammo_show_menu_handle");
  menu_additem(newmenu, "No ammo", "0", 0);
  menu_additem(newmenu, "Full ammo", "1", 0);
  menu_display(id, newmenu);

  return PLUGIN_HANDLED;
}

public ammo_show_menu_handle(id, menu, item)
{
  new pick = my_menu_item(id, item, menu);
  if(pick == -1)
    return PLUGIN_HANDLED;

  g_iPlayerPick[id][PICK_AMMO] = pick;
  new newmenu = my_menu_create(id, "JAIL_MENUMENU", "choose_show_menu_handle");
  menu_additem(newmenu, "All T", "0", 0);
  menu_additem(newmenu, "Specific", "1", 0);
  menu_display(id, newmenu);

  return PLUGIN_HANDLED;
}

public choose_show_menu_handle(id, menu, item)
{
  new pick = my_menu_item(id, item, menu);
  if(pick == -1)
    return PLUGIN_HANDLED;

  if(!pick)
  {
    new num, i;
    static players[32];
    get_players(players, num, "ae", "TERRORIST");

    for(--num; num >= 0; num--)
    {
      i = players[num];
      give_weapons_from(id, i);
    }

    static name[33];
    get_user_name(id, name, charsmax(name));
    client_print_color(0, print_team_default, "%s %L", JAIL_TAG, LANG_SERVER, "JAIL_WEAPONS_CA", name);
  }
  else show_player_menu(id, pick, "ae", "choosen_show_menu_handle");

  return PLUGIN_HANDLED;
}

public choosen_show_menu_handle(id, menu, item)
{
  new user_id = my_menu_item(id, item, menu);
  if(user_id == -1)
    return PLUGIN_HANDLED;

  static name[2][33];
  give_weapons_from(id, user_id);
  get_user_name(id, name[0], charsmax(name[]));
  get_user_name(user_id, name[1], charsmax(name[]));
  client_print_color(0, print_team_default, "%s %L", JAIL_TAG, LANG_SERVER, "JAIL_WEAPONS_C", name[0], name[1]);
  return PLUGIN_HANDLED;
}

public give_weapons_from(id, user_id)
{
  new weapon = g_iPlayerPick[id][PICK_WEAPON];
  new ammo = g_iPlayerPick[id][PICK_AMMO];
  if(weapon > -1)
  {
    static name[33];
    get_weaponname(g_szPriWeap[weapon], name, charsmax(name));
    strip_weapons(user_id);
    new weapon_ent = ham_give_weapon(user_id, name, 1);

    if(ammo > -1)
      cs_set_user_bpammo(user_id, g_szPriWeap[weapon], g_szPriAmmo[weapon]);
    else if(is_valid_ent(weapon_ent))
      cs_set_weapon_ammo(weapon_ent, 0);
  }
}

////////////////////////////////////////////
stock my_check(id)
{
  if(simon_or_admin(id) && !in_progress(id, GI_DAY) && !in_progress(id, GI_GAME))
    return 1;

  return 0;
}

stock my_menu_create(id, name[], handle[])
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
