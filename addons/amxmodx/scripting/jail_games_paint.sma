#include <amxmodx>
#include <fakemeta>
#include <xs>
#include <jailbreak>

new g_pMyNewGame, g_szGameName[JAIL_MENUITEM];
new g_pPlayerPreThinkForward, g_pSprite;
new g_iThePainter, Float:g_fPaintersOrigin[3], g_iPainting, g_iPainterCounter;

public plugin_precache()
  g_pSprite = precache_model("sprites/lgtning.spr");

public plugin_init()
{
  register_plugin("[JAIL] Painting game", JAIL_VERSION, JAIL_AUTHOR);

  formatex(g_szGameName, charsmax(g_szGameName), "%L", LANG_PLAYER, "JAIL_GAME4");
  g_pMyNewGame = jail_game_add(g_szGameName, "paint", 1);
}

public jail_game_start(simon, game, gamename[])
{
  if(game == g_pMyNewGame)
  {
    start_paint(simon);
    return PLUGIN_HANDLED;
  }

  return PLUGIN_CONTINUE;
}

public jail_game_end(simon, game, gamename[])
{
  if(game == g_pMyNewGame)
  {
    end_paint(simon);
    return PLUGIN_HANDLED;
  }

  return PLUGIN_CONTINUE;
}

public Forward_PlayerPreThink_pre(id)
{
  if(g_iThePainter != id)
    return FMRES_IGNORED;

  new button = pev(id, pev_button);
  if(button & IN_USE)
  {
    if(g_iPainterCounter++ > 5)
    {
      if(!is_aiming_at_sky(id))
      {
        static Float:origin[3], Float:distance;
        origin = g_fPaintersOrigin;
        if(!g_iPainting)
        {
          fm_get_aim_origin(id, g_fPaintersOrigin);
          move_toward_client(id, g_fPaintersOrigin);
          g_iPainting = true;
          return FMRES_IGNORED;
        }

        fm_get_aim_origin(id, g_fPaintersOrigin);
        move_toward_client(id, g_fPaintersOrigin);
        distance = get_distance_f(g_fPaintersOrigin, origin);

        if(distance > 2)
          draw_line(g_fPaintersOrigin, origin);
      }
      else g_iPainting = false;
      g_iPainterCounter = false;
    }
  }
  else g_iPainting = false;

  return FMRES_IGNORED;
}

public show_paint_menu(id)
{
  if(!is_user_alive(id) || !simon_or_admin(id))
    return PLUGIN_HANDLED;

  static menu, option[64];
  menu = menu_create(g_szGameName, "show_paint_menu_handle");

  formatex(option, charsmax(option), "%L", id, "JAIL_EVENTEND", g_szGameName);
  menu_additem(menu, option, "0", 0);
  formatex(option, charsmax(option), "%L", id, "JAIL_GAME4_GIVE");
  menu_additem(menu, option, "1", 0);

  menu_display(id, menu);

  return PLUGIN_HANDLED;
}

public show_paint_menu_handle(id, menu, item)
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
  if(!pick)
    jail_game_byname(id, g_szGameName, 1);
  else
  {
    static name[32], data[3], menu;
    menu = menu_create(g_szGameName, "give_paint_handler");

    new num, i;
    static players[32];
    get_players(players, num, "a");

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

  return PLUGIN_HANDLED;
}

public give_paint_handler(id, menu, item)
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
  g_iThePainter = pick;
  static name[2][32];
  get_user_name(id, name[0], charsmax(name[]));
  get_user_name(pick, name[1], charsmax(name[]));
  client_print_color(0, print_team_default, "%s %L", JAIL_TAG, LANG_SERVER, "JAIL_GAME4_TAKE", name[0], name[1]);

  return PLUGIN_HANDLED;
}

start_paint(simon)
{
  g_iThePainter = simon;

  server_event(simon, g_szGameName, false);
  jail_set_globalinfo(GI_GAME, g_pMyNewGame);
  jail_set_globalinfo(GI_NOFREEBIES, true);
  my_registered_stuff(true);

  return PLUGIN_HANDLED;
}

end_paint(simon)
{
  g_iThePainter = false;
  server_event(simon, g_szGameName, true);
  jail_set_globalinfo(GI_GAME, false);
  jail_set_globalinfo(GI_NOFREEBIES, false);

  my_registered_stuff(false);
}

my_registered_stuff(val)
{
  if(val)
  {
    g_pPlayerPreThinkForward = register_forward(FM_PlayerPreThink, "Forward_PlayerPreThink_pre", 0);
  }
  else
  {
    unregister_forward(FM_PlayerPreThink, g_pPlayerPreThinkForward, 0);
  }
}

stock draw_line(Float:origin1[3], Float:origin2[3])
{
  message_begin(MSG_BROADCAST, SVC_TEMPENTITY);
  write_byte(TE_BEAMPOINTS);
  engfunc(EngFunc_WriteCoord, origin1[0]);
  engfunc(EngFunc_WriteCoord, origin1[1]);
  engfunc(EngFunc_WriteCoord, origin1[2]);
  engfunc(EngFunc_WriteCoord, origin2[0]);
  engfunc(EngFunc_WriteCoord, origin2[1]);
  engfunc(EngFunc_WriteCoord, origin2[2]);
  write_short(g_pSprite);
  write_byte(0);
  write_byte(10);
  write_byte(450); // life
  write_byte(50);
  write_byte(0);
  write_byte(random(255));
  write_byte(random(255));
  write_byte(random(255));
  write_byte(255);
  write_byte(0);
  message_end();
}

stock fm_get_aim_origin(index, Float:origin[3])
{
  static Float:start[3], Float:view_ofs[3];
  pev(index, pev_origin, start);
  pev(index, pev_view_ofs, view_ofs);
  xs_vec_add(start, view_ofs, start);

  static Float:dest[3];
  pev(index, pev_v_angle, dest);
  engfunc(EngFunc_MakeVectors, dest);
  global_get(glb_v_forward, dest);
  xs_vec_mul_scalar(dest, 9999.0, dest);
  xs_vec_add(start, dest, dest);
  engfunc(EngFunc_TraceLine, start, dest, 0, index, 0);
  get_tr2(0, TR_vecEndPos, origin);

  return 1;
}

stock move_toward_client(id, Float:origin[3])
{
  static Float:player_origin[3];
  pev(id, pev_origin, player_origin);
  origin[0] += (player_origin[0] > origin[0]) ? 1.0 : -1.0;
  origin[1] += (player_origin[1] > origin[1]) ? 1.0 : -1.0;
  origin[2] += (player_origin[2] > origin[2]) ? 1.0 : -1.0;
}

stock is_aiming_at_sky(id)
{
  static target, temp;
  get_user_aiming(id, target, temp);
  if(engfunc(EngFunc_PointContents,target) == CONTENTS_SKY)
    return true;

  return false;
}
