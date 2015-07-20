#include <amxmodx>
#include <hamsandwich>
#include <fakemeta>
#include <fun>
#include <cstrike>
#include <jailbreak>
#include <timer_controller>

#define TASK_BEGIN 1111

new g_pMyNewDay, g_iTimeOnClock, cvar_prot_time_delay;
new g_szDayName[JAIL_MENUITEM];

new const g_szGiveWeap[][] =
{
  "weapon_ak47",
  "weapon_m4a1",
  "weapon_awp",
  "weapon_m249"
};

new const g_szNameWeap[][] =
{
  "CV-47",
  "M4A1",
  "Magnum",
  "ES M249"
};

new const g_iAmmoWeap[] =
{
  180,
  180,
  40,
  200
};

public plugin_init()
{
  register_plugin("[JAIL] Protection day", JAIL_VERSION, JAIL_AUTHOR);

  cvar_prot_time_delay = my_register_cvar("jail_prot_time_delay", "15.0", "Time before start of Protection day. (Default: 15.0)");

  formatex(g_szDayName, charsmax(g_szDayName), "%L", LANG_PLAYER, "JAIL_DAY2");
  g_pMyNewDay = jail_day_add(g_szDayName, "prot", 1);
}

public jail_freebie_join(id, event, type)
{
  if(type == GI_DAY && event == g_pMyNewDay)
  {
    set_player_attributes(id);
    return PLUGIN_HANDLED;
  }

  return PLUGIN_CONTINUE;
}

public jail_day_start(simon, day, dayname[])
{
  if(day == g_pMyNewDay)
  {
    begin_protection(simon);
    return PLUGIN_HANDLED;
  }

  return PLUGIN_CONTINUE;
}

public jail_day_end(simon, day, dayname[])
{
  if(day == g_pMyNewDay)
  {
    end_protection(simon);
    return PLUGIN_HANDLED;
  }

  return PLUGIN_CONTINUE;
}

public show_weapon_menu(id)
{
  if(is_user_alive(id))
  {
    static menu, option[64], data[3];
    menu = menu_create(g_szDayName, "show_weapon_menu_handle");

    for(new i = 0; i < sizeof(g_szNameWeap); i++)
    {
      formatex(option, charsmax(option), "%s", g_szNameWeap[i]);
      num_to_str(i, data, charsmax(data));
      menu_additem(menu, option, data, 0);
    }

    menu_display(id, menu);
  }
}

public show_weapon_menu_handle(id, menu, item)
{
  if(item == MENU_EXIT || !is_user_alive(id))
  {
    menu_destroy(menu);
    return PLUGIN_HANDLED;
  }

  new access, callback, num[3];
  menu_item_getinfo(menu, item, access, num, charsmax(num), _, _, callback);
  menu_destroy(menu);

  new pick = str_to_num(num);
  ham_give_weapon(id, g_szGiveWeap[pick]);
  ham_give_weapon(id, "weapon_deagle");
  cs_set_user_bpammo(id, get_weaponid(g_szGiveWeap[pick]), g_iAmmoWeap[pick]);
  cs_set_user_bpammo(id, CSW_DEAGLE, 35);

  return PLUGIN_HANDLED;
}

public begin_protection(simon)
{
  new num, id;
  static players[32];
  get_players(players, num, "a");

  for(--num; num >= 0; num--)
  {
    id = players[num];
    if(jail_get_playerdata(id, PD_FREEDAY)) continue;
    set_player_attributes(id);
  }

  server_event(simon, g_szDayName, 0);

  jail_set_globalinfo(GI_DAY, g_pMyNewDay);
  jail_set_globalinfo(GI_EVENTSTOP, true);
  jail_set_globalinfo(GI_BLOCKDOORS, true);
  g_iTimeOnClock = RoundTimerGet()-floatround(jail_get_roundtime());
  RoundTimerSet(0, get_pcvar_num(cvar_prot_time_delay));
  set_task(get_pcvar_float(cvar_prot_time_delay), "start_protection", TASK_BEGIN);
  jail_ham_specific({1, 1, 1, 1, 1, 0, 1});
}

public start_protection()
{
  jail_celldoors(0, TS_OPENED);
  RoundTimerSet(0, g_iTimeOnClock);
}

public end_protection(simon)
{
  RoundTimerSet(0, g_iTimeOnClock);

  new num, id;
  static players[32];
  get_players(players, num);
  if(task_exists(TASK_BEGIN))
    remove_task(TASK_BEGIN);

  for(--num; num >= 0; num--)
  {
    id = players[num];
    jail_set_playerdata(id, PD_HAMBLOCK, false);
  }

  server_event(simon, g_szDayName, 1);
  jail_ham_all(false);
  jail_set_globalinfo(GI_BLOCKDOORS, false);
  jail_set_globalinfo(GI_DAY, false);
  jail_set_globalinfo(GI_EVENTSTOP, false);

  return PLUGIN_CONTINUE;
}

public set_player_attributes(id)
{
  strip_weapons(id);
  set_user_health(id, 100);

  show_weapon_menu(id);
  jail_player_crowbar(id, false);
  jail_set_playerdata(id, PD_HAMBLOCK, true);
}
