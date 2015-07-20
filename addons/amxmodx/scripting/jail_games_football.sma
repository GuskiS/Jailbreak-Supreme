#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <hamsandwich>
#include <cstrike>
#include <amx_settings_api>
#include <jailbreak>

#define MAX_NETS 2
#define TASK_NETS 1111

#if AMXX_VERSION_NUM < 183
#define Ham_CS_Player_ResetMaxSpeed Ham_Item_PreFrame
#endif

enum
{
    FIRST_POINT = 0,
    SECOND_POINT
}

enum _:PLAYER_INFO
{
  PI_BUILDINGSTAGE,
  PI_BUILDING
}

enum _:BALL_INFO
{
  BI_ENT,
  BI_OWNER,
  BI_GOAL
}

enum _:NET_INFO
{
  NI_COUNT,
  NI_ENT_A,
  NI_ENT_B
}

new const g_szBallSound[] = "suprjail/bounce.wav";
new const g_szBallModel[] = "models/suprjail/ball.mdl";
new const g_szBallName[] = "jailball_ent";
new const g_szNetName[] = "jailnet_ent";

new const g_szMainMenu[][] =
{
  "BALL_BALLMENU",
  "BALL_NETMENU"
};

new const g_szBallNetMenu[][] =
{
  "BALL_LOAD",
  "BALL_CREATE",
  "BALL_DELETE",
  "BALL_SAVE"
};

new const g_szBallStorage[] = "jailbreak_ball.ini";

new g_iPlayerInfo[33][PLAYER_INFO], Float:g_fPlayerNetOrigin[33][2][3];
new g_iBallInfo[BALL_INFO], Float:g_fBallSpawnOrigin[3], Float:g_fBallOwnerOrigin[3], Float:g_fBallLastTouch;
new g_iNetInfo[NET_INFO];

new g_szMapName[32];
new g_pTrailSprite;
new cvar_ball_speed, cvar_ball_velocity;
new HamHook:g_pHamHooks[4], g_pForwardEmitSound;

new g_pMyNewGame, g_szGameName[JAIL_MENUITEM];
new g_iUsingMenu;

public plugin_precache()
{
  g_pTrailSprite = precache_model("sprites/laserbeam.spr");
  precache_model(g_szBallModel);
  precache_sound(g_szBallSound);

  get_mapname(g_szMapName, charsmax(g_szMapName));
  strtolower(g_szMapName);
}

public plugin_init()
{
  register_plugin("[JAIL] Game: Football", JAIL_VERSION, JAIL_AUTHOR);

  cvar_ball_speed     = my_register_cvar("jail_ball_speed",     "230.0",  "Player movement speed with ball. (Default: 230.0)");
  cvar_ball_velocity  = my_register_cvar("jail_ball_velocity",  "600",    "Ball kick speed. (Default: 600)");

  DisableHamForward((g_pHamHooks[0] = RegisterHam(Ham_Touch, "info_target", "Ham_Touch_pre", 0)));
  DisableHamForward((g_pHamHooks[1] = RegisterHam(Ham_Think, "info_target", "Ham_Think_pre", 0)));
  DisableHamForward((g_pHamHooks[2] = RegisterHamPlayer(Ham_CS_Player_ResetMaxSpeed, "Ham_Player_ResetMaxSpeed_post", 1)));
  DisableHamForward((g_pHamHooks[3] = RegisterHamPlayer(Ham_ObjectCaps, "Ham_ObjectCaps_post", 1))); // using this instead of EmitSound to steal ball

  set_client_commands("ball", "main_menu_show");

  formatex(g_szGameName, charsmax(g_szGameName), "%L", LANG_PLAYER, "JAIL_GAME5");
  g_pMyNewGame = jail_game_add(g_szGameName, "football", 1);

  register_dictionary("jailbreak_ball.txt");

  new ret;
  amx_load_setting_int(g_szBallStorage, g_szMapName, "ball_exists", ret);
  if(ret)
  {
    new Float:origin[3];
    amx_load_setting_float(g_szBallStorage, g_szMapName, "ball[0]", origin[0]);
    amx_load_setting_float(g_szBallStorage, g_szMapName, "ball[1]", origin[1]);
    amx_load_setting_float(g_szBallStorage, g_szMapName, "ball[2]", origin[2]);
    remove_pushable(origin);
  }
}

public client_disconnected(id)
{
  if(task_exists(id+TASK_NETS))
    remove_task(id+TASK_NETS);
}

public jail_achivements_load()
{
  jail_achiev_register("JBA_SCOREGOALS", "JBA_SCOREGOALS_DESC", 5, 100, 0);
}

public jail_gamemode(mode)
{
  if(mode == GAME_ENDED)
    remove_all();
}

public jail_game_start(simon, game, gamename[])
{
  if(game == g_pMyNewGame)
    return start_football(simon);

  return PLUGIN_CONTINUE;
}

public jail_game_end(simon, game, gamename[])
{
  if(game == g_pMyNewGame)
    return end_football(simon);

  return PLUGIN_CONTINUE;
}

public main_menu_show(id)
{
  if(is_jail_admin(id))
  {
    if(game_active(id))
      return PLUGIN_CONTINUE;

    if(!g_iUsingMenu || g_iUsingMenu == id)
    {
      if(task_exists(TASK_NETS + id))
        remove_task(TASK_NETS + id);

      static menu, option[JAIL_MENUITEM];
      formatex(option, charsmax(option), "%L", id, "BALL_MAINMENU");
      menu = menu_create(option, "main_menu_handle");

      g_iUsingMenu = id;
      new data[3];
      for(new i = 0; i < sizeof(g_szMainMenu); i++)
      {
        formatex(option, charsmax(option), "%L", id, g_szMainMenu[i]);
        num_to_str(i, data, charsmax(data));
        menu_additem(menu, option, data, 0);
      }

      menu_display(id, menu);
    }
    else
    {
      static name[32];
      get_user_name(g_iUsingMenu, name, charsmax(name));
      client_print_color(id, print_team_default, "%s %L", JAIL_TAG, id, "BALL_USINGMENU", name);
    }
  }

  return PLUGIN_CONTINUE;
}

public main_menu_handle(id, menu, item)
{
  if(item == MENU_EXIT || !is_user_alive(id) || !is_jail_admin(id) || game_active(id))
  {
    menu_destroy(menu);
    if(!game_active())
      remove_all();
    g_iUsingMenu = false;
    return PLUGIN_HANDLED;
  }

  new access, callback, num[3];
  menu_item_getinfo(menu, item, access, num, charsmax(num), _, _, callback);
  menu_destroy(menu);

  new pick = str_to_num(num);
  switch(pick)
  {
    case 0: ball_menu_show(id);
    case 1: nets_menu_show(id);
  }

  return PLUGIN_HANDLED;
}

public ball_menu_show(id)
{
  if(game_active(id))
    return;

  static menu, option[JAIL_MENUITEM];
  formatex(option, charsmax(option), "%L", id, "BALL_BALLMENU");
  menu = menu_create(option, "ball_menu_handle");

  new data[3];
  for(new i = 0; i < sizeof(g_szBallNetMenu); i++)
  {
    formatex(option, charsmax(option), "%L %L", id, g_szBallNetMenu[i], id, "BALL_BALL");
    num_to_str(i, data, charsmax(data));
    menu_additem(menu, option, data, 0);
  }

  menu_display(id, menu);
}

public ball_menu_handle(id, menu, item)
{
  if(item == MENU_EXIT || !is_user_alive(id) || game_active(id))
  {
    menu_destroy(menu);
    if(!game_active())
    {
      remove_ball();
      main_menu_show(id);
    }
    return PLUGIN_HANDLED;
  }

  new access, callback, num[3];
  menu_item_getinfo(menu, item, access, num, charsmax(num), _, _, callback);
  menu_destroy(menu);

  new pick = str_to_num(num);
  switch(pick)
  {
    case 0: client_print_color(id, print_team_default, "%s %L", JAIL_TAG, id, load_ball(id) ? "BALL_SUCCEED" : "BALL_FAILED", id, "BALL_LOAD", id, "BALL_BALL");
    case 1: client_print_color(id, print_team_default, "%s %L", JAIL_TAG, id, ball_create(id) ? "BALL_SUCCEED" : "BALL_FAILED", id, "BALL_CREATE", id, "BALL_BALL");
    case 2: client_print_color(id, print_team_default, "%s %L", JAIL_TAG, id, remove_ball() ? "BALL_SUCCEED" : "BALL_FAILED", id, "BALL_DELETE", id, "BALL_BALL");
    case 3: client_print_color(id, print_team_default, "%s %L", JAIL_TAG, id, save_ball(id) ? "BALL_SUCCEED" : "BALL_FAILED", id, "BALL_SAVE", id, "BALL_BALL");
  }
  ball_menu_show(id);

  return PLUGIN_HANDLED;
}

public nets_menu_show(id)
{
  if(game_active(id))
    return;

  if(!task_exists(id+TASK_NETS))
    set_task(1.0, "net_showlines", TASK_NETS+id, _, _, "b");
    //net_showlines(TASK_NETS+id);

  static menu, option[JAIL_MENUITEM];
  formatex(option, charsmax(option), "%L", id, "BALL_NETMENU");
  menu = menu_create(option, "nets_menu_handle");

  new data[3];
  for(new i = 0; i < sizeof(g_szBallNetMenu); i++)
  {
    formatex(option, charsmax(option), "%L %L", id, g_szBallNetMenu[i], id, "BALL_NET");
    num_to_str(i, data, charsmax(data));
    menu_additem(menu, option, data, 0);
  }

  menu_display(id, menu);
}

public nets_menu_handle(id, menu, item)
{
  if(item == MENU_EXIT || !is_user_alive(id) || game_active(id))
  {
    if(task_exists(id+TASK_NETS))
      remove_task(id+TASK_NETS);

    menu_destroy(menu);
    if(!game_active())
    {
      remove_nets();
      main_menu_show(id);
    }
    return PLUGIN_HANDLED;
  }

  new access, callback, num[3];
  menu_item_getinfo(menu, item, access, num, charsmax(num), _, _, callback);
  menu_destroy(menu);

  new pick = str_to_num(num);
  switch(pick)
  {
    case 0: client_print_color(id, print_team_default, "%s %L", JAIL_TAG, id, load_nets(id) ? "BALL_SUCCEED" : "BALL_FAILED", id, "BALL_LOAD", id, "BALL_NET");
    case 1:
    {
      if(g_iNetInfo[NI_COUNT] < MAX_NETS)
      {
        my_emitsound_forward(true);
        g_iPlayerInfo[id][PI_BUILDING] = true;
        client_print_color(id, print_team_default, "%s %L", JAIL_TAG, id, "BALL_SETORIGIN1");
      }
      else
      {
        my_emitsound_forward(false);
        g_iPlayerInfo[id][PI_BUILDING] = false;
        client_print_color(id, print_team_default, "%s %L", JAIL_TAG, id, "BALL_MAXNETS", MAX_NETS);
      }
    }
    case 2:
    {
      new last = g_iNetInfo[NI_COUNT];
      new ent = g_iNetInfo[last];
      g_iNetInfo[last] = 0;

      if(is_valid_ent(ent))
      {
        remove_entity(ent);
        g_iNetInfo[NI_COUNT]--;
      }

      client_print_color(id, print_team_default, "%s %L", JAIL_TAG, id, ent ? "BALL_SUCCEED" : "BALL_FAILED", id, "BALL_DELETE", id, "BALL_NET");
    }
    case 3: client_print_color(id, print_team_default, "%s %L", JAIL_TAG, id, save_nets(id) ? "BALL_SUCCEED" : "BALL_FAILED", id, "BALL_SAVE", id, "BALL_NET");
  }
  if(task_exists(id+TASK_NETS))
    remove_task(id+TASK_NETS);
  nets_menu_show(id);

  return PLUGIN_HANDLED;
}

public Ham_Touch_pre(ent, id)
{
  if(!is_valid_ent(ent))
    return HAM_IGNORED;
  if(is_my_ent(ent, 1) && !id)
    return HAM_IGNORED;

  if(is_user_alive(id))
  {
    if(entity_get_int(ent, EV_INT_iuser1) == 0 && is_my_ent(ent, 0))
    {
      entity_set_int(ent, EV_INT_iuser1, id);
      entity_set_float(id, EV_FL_maxspeed, get_pcvar_float(cvar_ball_speed));
    }
  }
  else
  {
    static classname[32];
    entity_get_string(ent, EV_SZ_classname, classname, charsmax(classname));
    if(equal(g_szNetName, classname))
    {
      if(is_my_ent(id, 0) && (get_gametime() - g_fBallLastTouch) > 0.1)
      {
        ball_score();
        g_fBallLastTouch = get_gametime();
      }
    }
    else
    {
      static Float:velocity[3];
      entity_get_vector(ent, EV_VEC_velocity, velocity);

      if(vector_length(velocity) > 10.0)
      {
        velocity[0] *= 0.85;
        velocity[1] *= 0.85;
        velocity[2] *= 0.85;

        entity_set_vector(ent, EV_VEC_velocity, velocity);
        emit_sound(ent, CHAN_ITEM, g_szBallSound, 1.0, ATTN_NORM, 0, PITCH_NORM);
      }
    }
  }

  return HAM_HANDLED;
}

public Ham_Think_pre(ent)
{
  if(!is_valid_ent(ent) || !is_my_ent(ent))
    return HAM_IGNORED;

  static Float:vOrigin[3], Float:vBallVelocity[3];
  entity_set_float(ent, EV_FL_nextthink, halflife_time() + 0.05);
  entity_get_vector(ent, EV_VEC_origin, vOrigin);
  entity_get_vector(ent, EV_VEC_velocity, vBallVelocity);

  new solid = entity_get_int(ent, EV_INT_solid);
  new owner = entity_get_int(ent, EV_INT_iuser1);

  static Float:flGametime, Float:flLastThink;
  flGametime = get_gametime();

  if(flLastThink < flGametime)
  {
    if(vector_length(vBallVelocity) > 10.0)
    {
      ball_trail();
      flLastThink = flGametime + 3.0;
    }
  }

  if(owner > 0)
  {
    static Float:vOwnerOrigin[3];
    static const Float:velocity[3] = {1.0, 1.0, 0.0};
    entity_get_vector(owner, EV_VEC_origin, vOwnerOrigin);

    if(!is_user_alive(owner))
    {
      vOwnerOrigin[ 2 ] += 5.0;
      entity_set_int(ent, EV_INT_iuser1, 0);
      entity_set_origin(ent, vOwnerOrigin);
      entity_set_vector(ent, EV_VEC_velocity, velocity);
      return HAM_IGNORED;
    }

    if(solid != SOLID_NOT)
    {
      entity_set_int(ent, EV_INT_solid, SOLID_NOT);
      set_hudmessage(255, 20, 20, -1.0, 0.4, 1, 1.0, 1.5, 0.1, 0.1, 2);
      show_hudmessage(owner, "%L", owner, "BALL_GOTBALL");
    }

    static Float:angles[3], Float:origin[3];
    entity_get_vector(owner, EV_VEC_v_angle, angles);

    origin[0] = (floatcos(angles[1], degrees) * 55.0) + vOwnerOrigin[0];
    origin[1] = (floatsin(angles[1], degrees) * 55.0) + vOwnerOrigin[1];
    origin[2] = vOwnerOrigin[2];
    origin[2] -= (entity_get_int(owner, EV_INT_flags) & FL_DUCKING) ? 10 : 30;

    entity_set_vector(ent, EV_VEC_velocity, velocity);
    entity_set_origin(ent, origin);
  }
  else
  {
    if(solid != SOLID_BBOX)
      entity_set_int(ent, EV_INT_solid, SOLID_BBOX);

    static Float:flLastVerticalOrigin;
    if(vBallVelocity[2] == 0.0)
    {
      static iCounts;
      if(flLastVerticalOrigin > vOrigin[2])
      {
        iCounts++;
        if(iCounts > 10 && !g_iBallInfo[BI_GOAL])
        {
          iCounts = 0;
          ball_update(0);
        }
      }
      else
      {
        iCounts = 0;
        if(PointContents(vOrigin) != CONTENTS_EMPTY && !g_iBallInfo[BI_GOAL])
          ball_update(0);
      }
      flLastVerticalOrigin = vOrigin[2];
    }
  }

  return HAM_HANDLED;
}

public Ham_Player_ResetMaxSpeed_post(id)
{
  if(!is_user_alive(id) || !is_valid_ent(g_iBallInfo[BI_ENT]))
    return HAM_IGNORED;

  if(entity_get_int(g_iBallInfo[BI_ENT], EV_INT_iuser1) == id)
    cs_reset_user_maxspeed(id, get_pcvar_float(cvar_ball_speed));

  return HAM_HANDLED;
}

public Ham_ObjectCaps_post(id)
{
  if(is_user_alive(id) && is_valid_ent(g_iBallInfo[BI_ENT]))
  {
    new owner = entity_get_int(g_iBallInfo[BI_ENT], EV_INT_iuser1);
    if(owner == id)
    {
      ball_kick(id);
      g_iBallInfo[BI_OWNER] = owner;
      entity_get_vector(id, EV_VEC_origin, g_fBallOwnerOrigin);
    }
  }
}

public Forward_EmitSound_pre(id, channel, sample[])
{
  if(!is_user_connected(id))
    return FMRES_IGNORED;

  if(equal(sample, "common/wpn_denyselect.wav"))
  {
    if(g_iPlayerInfo[id][PI_BUILDING])
    {
      new Float:fOrigin[3], iOrigin[3];
      get_user_origin(id, iOrigin, 3);

      IVecFVec(iOrigin, fOrigin);
      if(g_iPlayerInfo[id][PI_BUILDINGSTAGE] == FIRST_POINT)
      {
        g_iPlayerInfo[id][PI_BUILDINGSTAGE] = SECOND_POINT;
        g_fPlayerNetOrigin[id][0] = fOrigin;
        client_print_color(id, print_team_default, "%s %L", JAIL_TAG, id, "BALL_SETORIGIN2");
      }
      else
      {
        my_emitsound_forward(false);
        g_iPlayerInfo[id][PI_BUILDINGSTAGE] = FIRST_POINT;
        g_iPlayerInfo[id][PI_BUILDING] = false;
        g_fPlayerNetOrigin[id][1] = fOrigin;

        net_create(g_fPlayerNetOrigin[id][0], fOrigin);
        client_print_color(id, print_team_default, "%s %L", JAIL_TAG, "BALL_SUCCEED", id, "BALL_CREATE", id, "BALL_NET");
      }
    }
  }

  return FMRES_IGNORED;
}

public load_all()
{
  if(load_ball(0) && load_nets(0))
    return PLUGIN_HANDLED;

  return PLUGIN_CONTINUE;
}

public load_ball(id)
{
  new ret;
  amx_load_setting_int(g_szBallStorage, g_szMapName, "ball_exists", ret);
  if(ret)
  {
    new Float:origin[3];
    amx_load_setting_float(g_szBallStorage, g_szMapName, "ball[0]", origin[0]);
    amx_load_setting_float(g_szBallStorage, g_szMapName, "ball[1]", origin[1]);
    amx_load_setting_float(g_szBallStorage, g_szMapName, "ball[2]", origin[2]);
    ball_create(0, origin);

    if(id)
    {
      static name[32];
      get_user_name(id, name, charsmax(name));
      log_amx("[JAIL] Admin %s loaded ball @ %s", name, g_szMapName);
      client_print_color(0, print_team_default, "%s Admin %s loaded ball!", JAIL_TAG, name);
    }

    return PLUGIN_HANDLED;
  }

  return PLUGIN_CONTINUE;
}

public load_nets(id)
{
  new ret, Float:R_point[2][3], Float:L_point[2][3];
  amx_load_setting_int(g_szBallStorage, g_szMapName, "nets_exists", ret);
  if(ret == MAX_NETS)
  {
    amx_load_setting_float(g_szBallStorage, g_szMapName, "L_point[0][0]", L_point[0][0]);
    amx_load_setting_float(g_szBallStorage, g_szMapName, "L_point[0][1]", L_point[0][1]);
    amx_load_setting_float(g_szBallStorage, g_szMapName, "L_point[0][2]", L_point[0][2]);
    amx_load_setting_float(g_szBallStorage, g_szMapName, "L_point[1][0]", L_point[1][0]);
    amx_load_setting_float(g_szBallStorage, g_szMapName, "L_point[1][1]", L_point[1][1]);
    amx_load_setting_float(g_szBallStorage, g_szMapName, "L_point[1][2]", L_point[1][2]);

    amx_load_setting_float(g_szBallStorage, g_szMapName, "R_point[0][0]", R_point[0][0]);
    amx_load_setting_float(g_szBallStorage, g_szMapName, "R_point[0][1]", R_point[0][1]);
    amx_load_setting_float(g_szBallStorage, g_szMapName, "R_point[0][2]", R_point[0][2]);
    amx_load_setting_float(g_szBallStorage, g_szMapName, "R_point[1][0]", R_point[1][0]);
    amx_load_setting_float(g_szBallStorage, g_szMapName, "R_point[1][1]", R_point[1][1]);
    amx_load_setting_float(g_szBallStorage, g_szMapName, "R_point[1][2]", R_point[1][2]);

    net_create(L_point[0], R_point[0]);
    net_create(L_point[1], R_point[1]);

    if(id)
    {
      static name[32];
      get_user_name(id, name, charsmax(name));
      log_amx("[JAIL] Admin %s loaded 2 nets @ %s", name, g_szMapName);
      client_print_color(0, print_team_default, "%s Admin %s loaded 2 nets!", JAIL_TAG, name);
    }

    return PLUGIN_HANDLED;
  }

  return PLUGIN_CONTINUE;
}

public save_ball(id)
{
  if(is_valid_ent(g_iBallInfo[BI_ENT]))
  {
    amx_save_setting_int(g_szBallStorage, g_szMapName, "ball_exists", 1);
    amx_save_setting_float(g_szBallStorage, g_szMapName, "ball[0]", g_fBallSpawnOrigin[0]);
    amx_save_setting_float(g_szBallStorage, g_szMapName, "ball[1]", g_fBallSpawnOrigin[1]);
    amx_save_setting_float(g_szBallStorage, g_szMapName, "ball[2]", g_fBallSpawnOrigin[2]);

    static name[32];
    get_user_name(id, name, charsmax(name));
    log_amx("[JAIL] Admin %s saved ball at these coordinates: %0.2f; %0.2f; %0.2f @ %s", name, g_fBallSpawnOrigin[0], g_fBallSpawnOrigin[1], g_fBallSpawnOrigin[2], g_szMapName);
    client_print_color(0, print_team_default, "%s Admin %s saved ball at these coordinates: %0.2f; %0.2f; %0.2f!", JAIL_TAG, name, g_fBallSpawnOrigin[0], g_fBallSpawnOrigin[1], g_fBallSpawnOrigin[2]);
    return PLUGIN_HANDLED;
  }

  return PLUGIN_CONTINUE;
}

public save_nets(id)
{
  static Float:R_point[2][3], Float:L_point[2][3];
  if(g_iNetInfo[NI_COUNT] == 2)
  {
    new nets[2], j;
    nets[0] = g_iNetInfo[NI_ENT_A];
    nets[1] = g_iNetInfo[NI_ENT_B];
    static Float:maxs[3], Float:origin[3];
    for(new i = 0; i < 2; i++)
    {
      entity_get_vector(nets[i], EV_VEC_origin, origin);
      entity_get_vector(nets[i], EV_VEC_maxs, maxs);

      for(j = 0; j < 3; j++)
      {
        L_point[i][j] = origin[j] + maxs[j];
        R_point[i][j] = origin[j] - maxs[j];
      }
    }
  }
  else return PLUGIN_CONTINUE;

  amx_save_setting_int(g_szBallStorage, g_szMapName, "nets_exists", 2);
  amx_save_setting_float(g_szBallStorage, g_szMapName, "L_point[0][0]", L_point[0][0]);
  amx_save_setting_float(g_szBallStorage, g_szMapName, "L_point[0][1]", L_point[0][1]);
  amx_save_setting_float(g_szBallStorage, g_szMapName, "L_point[0][2]", L_point[0][2]);
  amx_save_setting_float(g_szBallStorage, g_szMapName, "L_point[1][0]", L_point[1][0]);
  amx_save_setting_float(g_szBallStorage, g_szMapName, "L_point[1][1]", L_point[1][1]);
  amx_save_setting_float(g_szBallStorage, g_szMapName, "L_point[1][2]", L_point[1][2]);

  amx_save_setting_float(g_szBallStorage, g_szMapName, "R_point[0][0]", R_point[0][0]);
  amx_save_setting_float(g_szBallStorage, g_szMapName, "R_point[0][1]", R_point[0][1]);
  amx_save_setting_float(g_szBallStorage, g_szMapName, "R_point[0][2]", R_point[0][2]);
  amx_save_setting_float(g_szBallStorage, g_szMapName, "R_point[1][0]", R_point[1][0]);
  amx_save_setting_float(g_szBallStorage, g_szMapName, "R_point[1][1]", R_point[1][1]);
  amx_save_setting_float(g_szBallStorage, g_szMapName, "R_point[1][2]", R_point[1][2]);

  static name[32];
  get_user_name(id, name, charsmax(name));
  log_amx("[JAIL] Admin %s saved 2 nets @ %s", name, g_szMapName);
  client_print_color(0, print_team_default, "%s Admin %s saved 2 nets!", JAIL_TAG, name);

  return PLUGIN_HANDLED;
}

public remove_all()
{
  remove_ball();
  remove_nets();
}

remove_ball()
{
  if(g_iBallInfo[BI_ENT])
  {
    remove_entity_name(g_szBallName);
    g_iBallInfo[BI_ENT] = false;
    return 1;
  }

  return 0;
}

remove_nets()
{
  if(g_iNetInfo[NI_COUNT])
  {
    remove_entity_name(g_szNetName);
    g_iNetInfo[NI_ENT_A] = false;
    g_iNetInfo[NI_ENT_B] = false;
    g_iNetInfo[NI_COUNT] = false;
    return 1;
  }

  return 0;
}

public net_showlines(id)
{
  id -= TASK_NETS;
  if(!is_user_connected(id))
  {
    if(task_exists(TASK_NETS + id))
      remove_task(TASK_NETS + id);
    return;
  }

  new ent, i;
  static Float:fOrigin[3], Float:fMins[3], Float:fMaxs[3];
  static vMaxs[3], vMins[3];

  while((ent = find_ent_by_class(ent, g_szNetName)) > 0)
  {
    entity_get_vector(ent, EV_VEC_mins, fMins);
    entity_get_vector(ent, EV_VEC_maxs, fMaxs);
    entity_get_vector(ent, EV_VEC_origin, fOrigin);

    for(i = 0; i < 3; i++)
    {
      fMins[i] += fOrigin[i];
      fMaxs[i] += fOrigin[i];
    }

    FVecIVec(fMins, vMins);
    FVecIVec(fMaxs, vMaxs);

    draw_line(id, vMaxs[0], vMaxs[1], vMaxs[2], vMins[0], vMaxs[1], vMaxs[2]);
    draw_line(id, vMaxs[0], vMaxs[1], vMaxs[2], vMaxs[0], vMins[1], vMaxs[2]);
    draw_line(id, vMaxs[0], vMaxs[1], vMaxs[2], vMaxs[0], vMaxs[1], vMins[2]);
    draw_line(id, vMins[0], vMins[1], vMins[2], vMaxs[0], vMins[1], vMins[2]);
    draw_line(id, vMins[0], vMins[1], vMins[2], vMins[0], vMaxs[1], vMins[2]);
    draw_line(id, vMins[0], vMins[1], vMins[2], vMins[0], vMins[1], vMaxs[2]);
    draw_line(id, vMins[0], vMaxs[1], vMaxs[2], vMins[0], vMaxs[1], vMins[2]);
    draw_line(id, vMins[0], vMaxs[1], vMins[2], vMaxs[0], vMaxs[1], vMins[2]);
    draw_line(id, vMaxs[0], vMaxs[1], vMins[2], vMaxs[0], vMins[1], vMins[2]);
    draw_line(id, vMaxs[0], vMins[1], vMins[2], vMaxs[0], vMins[1], vMaxs[2]);
    draw_line(id, vMaxs[0], vMins[1], vMaxs[2], vMins[0], vMins[1], vMaxs[2]);
    draw_line(id, vMins[0], vMins[1], vMaxs[2], vMins[0], vMaxs[1], vMaxs[2]);
  }
}

ball_create(id, Float:vOrigin[3] = {0.0, 0.0, 0.0})
{
  if(!id && vOrigin[0] == 0.0 && vOrigin[1] == 0.0 && vOrigin[2] == 0.0)
    return 0;

  if(id && is_valid_ent(g_iBallInfo[BI_ENT]))
    remove_ball();

  new ent = create_entity("info_target");
  if(ent)
  {
    entity_set_string(ent, EV_SZ_classname, g_szBallName);
    entity_set_int(ent, EV_INT_solid, SOLID_BBOX);
    entity_set_int(ent, EV_INT_movetype, MOVETYPE_BOUNCE);
    entity_set_model(ent, g_szBallModel);
    entity_set_size(ent, Float:{-15.0, -15.0, 0.0}, Float:{ 15.0, 15.0, 12.0});

    entity_set_float(ent, EV_FL_framerate, 0.0);
    entity_set_int(ent, EV_INT_sequence, 0);
    entity_set_float(ent, EV_FL_nextthink, get_gametime() + 0.05);

    if(id > 0)
    {
      new iOrigin[3];
      get_user_origin(id, iOrigin, 3);
      IVecFVec(iOrigin, vOrigin);
      vOrigin[2] += 5.0;
      entity_set_origin(ent, vOrigin);
    }
    else entity_set_origin(ent, vOrigin);
    g_fBallSpawnOrigin = vOrigin;
    g_iBallInfo[BI_ENT] = ent;
    remove_pushable(vOrigin);

    return ent;
  }

  return -1;
}

ball_kick(id)
{
  cs_reset_user_maxspeed(id);
  static Float:vOrigin[3];
  entity_get_vector(g_iBallInfo[BI_ENT], EV_VEC_origin, vOrigin);

  if(PointContents(vOrigin) != CONTENTS_EMPTY)
    return PLUGIN_CONTINUE;

  new Float:vVelocity[3];
  velocity_by_aim(id, get_pcvar_num(cvar_ball_velocity), vVelocity);

  entity_set_int(g_iBallInfo[BI_ENT], EV_INT_solid, SOLID_BBOX);
  entity_set_size(g_iBallInfo[BI_ENT], Float:{-15.0, -15.0, 0.0}, Float:{15.0, 15.0, 12.0});
  entity_set_int(g_iBallInfo[BI_ENT], EV_INT_iuser1, 0);
  entity_set_vector(g_iBallInfo[BI_ENT], EV_VEC_velocity, vVelocity);

  return PLUGIN_HANDLED;
}

ball_score()
{
  static name[32], Float:fdistance, Float:origin[3];
  entity_get_vector(g_iBallInfo[BI_ENT], EV_VEC_origin, origin);

  get_user_name(g_iBallInfo[BI_OWNER], name, charsmax(name));
  fdistance = get_distance_f(origin, g_fBallOwnerOrigin);
  set_hudmessage(211, 211, 211, -1.0, 0.82, 0, 6.0, 6.0);

  if(g_iBallInfo[BI_OWNER] != 0)
    show_hudmessage(0, "%L", LANG_PLAYER, "BALL_SCORED", name, floatround(fdistance));

  jail_achiev_set_progress(g_iBallInfo[BI_OWNER], "JBA_SCOREGOALS", jail_achiev_get_progress(g_iBallInfo[BI_OWNER], "JBA_SCOREGOALS") + 1);
  g_iBallInfo[BI_GOAL] = true;
  ball_move(0);
  set_task(5.0, "ball_move", 1);
}

ball_update(id)
{
  if(!id || (is_user_alive(id) && simon_or_admin(id)))
  {
    if(is_valid_ent(g_iBallInfo[BI_ENT]))
      recreate_ball();
  }

  return PLUGIN_HANDLED;
}

public ball_move(where)
{
  if(!is_valid_ent(g_iBallInfo[BI_ENT]))
    return PLUGIN_CONTINUE;

  if(!where)
  {
    new Float:origin[3];
    for(new i = 0; i < 3; i++)
      origin[i] = -9999.9;
    entity_set_origin(g_iBallInfo[BI_ENT], origin);
  }
  else if(is_valid_ent(g_iBallInfo[BI_ENT]))
  {
    recreate_ball();
    g_iBallInfo[BI_GOAL] = false;
  }

  return PLUGIN_HANDLED;
}

ball_trail()
{
  message_begin(MSG_BROADCAST, SVC_TEMPENTITY);
  write_byte(TE_KILLBEAM);
  write_short(g_iBallInfo[BI_ENT]);
  message_end();

  message_begin(MSG_BROADCAST, SVC_TEMPENTITY);
  write_byte(TE_BEAMFOLLOW);
  write_short(g_iBallInfo[BI_ENT]);
  write_short(g_pTrailSprite);
  write_byte(10);
  write_byte(10);
  write_byte(0);
  write_byte(50);
  write_byte(255);
  write_byte(200);
  message_end();
}

net_create(Float:firstPoint[3], Float:lastPoint[3])
{
  if(g_iNetInfo[NI_COUNT] >= MAX_NETS)
    return;

  static Float:fCenter[3], Float:fSize[3];
  static Float:fMins[3], Float:fMaxs[3];

  for(new i = 0; i < 3; i++)
  {
    fCenter[i] = (firstPoint[i] + lastPoint[i]) / 2.0;
    fSize[i] = get_float_difference(firstPoint[i], lastPoint[i]);
    fMins[i] = fSize[i] / -2.0;
    fMaxs[i] = fSize[i] / 2.0;
  }
  //log_amx("origin %0.2f, %0.2f, %0.2f", fCenter[0], fCenter[1], fCenter[2]);
  //log_amx("fMins %0.2f, %0.2f, %0.2f", fMins[0], fMins[1], fMins[2]);
  //log_amx("fMaxs %0.2f, %0.2f, %0.2f", fMaxs[0], fMaxs[1], fMaxs[2]);
  //log_amx("");

  g_iNetInfo[NI_COUNT]++;
  new last = g_iNetInfo[NI_COUNT];

  if(is_valid_ent(g_iNetInfo[last]))
    remove_entity(g_iNetInfo[last]);

  new ent = create_entity("info_target");
  g_iNetInfo[last] = ent;

  if(ent)
  {
    DispatchSpawn(ent);
    entity_set_origin(ent, fCenter);
    entity_set_string(ent, EV_SZ_classname, g_szNetName);
    entity_set_int(ent, EV_INT_movetype, MOVETYPE_FLY);
    entity_set_int(ent, EV_INT_solid, SOLID_TRIGGER);
    entity_set_size(ent, fMins, fMaxs);
  }
}

start_football(simon)
{
  if(!load_all())
  {
    client_print_color(simon, print_team_default, "%s %L", JAIL_TAG, simon, "BALL_FAILEDSTART");
    return PLUGIN_CONTINUE;
  }

  my_ham_forwards(true);
  server_event(simon, g_szGameName, false);
  jail_set_globalinfo(GI_GAME, g_pMyNewGame);
  jail_set_globalinfo(GI_NOFREEBIES, true);

  return PLUGIN_HANDLED;
}

end_football(simon)
{
  new num, id;
  static players[32];
  get_players(players, num, "a");

  for(--num; num >= 0; num--)
  {
    id = players[num];
    cs_reset_user_maxspeed(id);
  }

  server_event(simon, g_szGameName, true);
  my_ham_forwards(false);
  jail_set_globalinfo(GI_GAME, false);
  jail_set_globalinfo(GI_NOFREEBIES, false);
  remove_all();

  return PLUGIN_HANDLED;
}

stock recreate_ball()
{
  entity_set_vector(g_iBallInfo[BI_ENT], EV_VEC_velocity, Float:{0.0, 0.0, 0.0});
  entity_set_origin(g_iBallInfo[BI_ENT], g_fBallSpawnOrigin);

  entity_set_int(g_iBallInfo[BI_ENT], EV_INT_movetype, MOVETYPE_BOUNCE);
  entity_set_size(g_iBallInfo[BI_ENT], Float:{-15.0, -15.0, 0.0}, Float:{15.0, 15.0, 12.0});
  entity_set_int(g_iBallInfo[BI_ENT], EV_INT_iuser1, 0);
}

stock draw_line(id, x1, y1, z1, x2, y2, z2)
{
  message_begin(id ? MSG_ONE_UNRELIABLE : MSG_BROADCAST, SVC_TEMPENTITY, _, id);
  write_byte(TE_BEAMPOINTS);
  write_coord(x1);
  write_coord(y1);
  write_coord(z1);
  write_coord(x2);
  write_coord(y2);
  write_coord(z2);
  write_short(g_pTrailSprite);
  write_byte(1);
  write_byte(1);
  write_byte(10);
  write_byte(5);
  write_byte(0);
  write_byte(255);
  write_byte(0);
  write_byte(0);
  write_byte(200);
  write_byte(0);
  message_end();
}

stock is_my_ent(ent, type = 0)
{
  static classname[32];
  entity_get_string(ent, EV_SZ_classname, classname, charsmax(classname));
  if(equal(type ? g_szNetName : g_szBallName, classname))
    return 1;

  return 0;
}

stock Float:get_float_difference(Float:num1, Float:num2)
{
  if(num1 > num2)
    return (num1-num2);
  else if(num2 > num1)
    return (num2-num1);

  return 0.0;
}

stock remove_pushable(const Float:origin[3])
{
  new push = -1;
  static classname[32];
  while((push = find_ent_in_sphere(push, origin, 50.0)) != 0)
  {
    entity_get_string(push, EV_SZ_classname, classname, charsmax(classname));
    if(equal(classname, "func_pushable"))
    {
      if(is_valid_ent(push))
        remove_entity(push);
      break;
    }
  }
}

stock my_ham_forwards(val)
{
  if(val)
  {
    for(new i = 0; i < sizeof(g_pHamHooks); i++)
      EnableHamForward(g_pHamHooks[i]);
  }
  else
  {
    for(new i = 0; i < sizeof(g_pHamHooks); i++)
      DisableHamForward(g_pHamHooks[i]);
  }
}

stock my_emitsound_forward(val)
{
  if(val)
    g_pForwardEmitSound = register_forward(FM_EmitSound, "Forward_EmitSound_pre", 0);
  else unregister_forward(FM_EmitSound, g_pForwardEmitSound, 0);
}

stock game_active(id = 0)
{
  if(jail_get_globalinfo(GI_GAME) == g_pMyNewGame)
  {
    if(id) client_print_color(id, print_team_default, "%s %L", JAIL_TAG, id, "JAIL_EVENTALREADY", g_szGameName, "games");
    return 1;
  }

  return 0;
}
