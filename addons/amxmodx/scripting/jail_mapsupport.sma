#include <amxmodx>
#include <hamsandwich>
#include <fakemeta>
#include <engine>
#include <jailbreak>

new const g_iToggleStates[][] =
{
  {0, 2, 3, 1},
  {2, 0, 1, 3},
  {1, 3, 0, 2},
  {3, 1, 2, 0}
};

new g_iJBMap, cvar_shoot_buttons;
new Array:g_aDoors, g_iButtons[5];
new Trie:g_tMultiManagers;
new g_pForwardSpawn, g_iMapFix, g_szMapName[32], g_iNukeEnts[2];

enum _:MAPNAMES
{
  JAIL_GUETTA = 1,
  JAIL_NUKE,
  JAIL_MIDDAY,
  JAIL_LATEST,
  JAIL_ATNAS,
  JAIL_MINECRAFT
}

public plugin_precache()
{
  if(is_jailmap())
  {
    g_tMultiManagers = TrieCreate();
    g_iJBMap = true;

    get_mapname(g_szMapName, charsmax(g_szMapName));
    strtolower(g_szMapName);

    if(equal(g_szMapName, "jail_guetta", 11))
    {
      g_iMapFix = JAIL_GUETTA;
      g_pForwardSpawn	= register_forward(FM_Spawn, "Forward_Spawn_post", 1);
    }
    else if(equal(g_szMapName, "jail_nuke", 9))
    {
      g_iMapFix = JAIL_NUKE;
      g_pForwardSpawn	= register_forward(FM_Spawn, "Forward_Spawn_post", 1);
    }
    else if(equal(g_szMapName, "jail_midday", 11))
      g_iMapFix = JAIL_MIDDAY;
    else if(equal(g_szMapName, "jail_latest"))
      g_iMapFix = JAIL_LATEST;
    else if(equal(g_szMapName, "jail_atnas", 10))
      g_iMapFix = JAIL_ATNAS;
    else if(equal(g_szMapName, "jail_minecraft", 14))
    {
      g_iMapFix = JAIL_MINECRAFT;
      create_wall_block(Float:{-1901.50, 265.50, 335.00}, Float:{-80.50, -15.50, -48.00}, Float:{80.50, 15.50, 48.0});
    }
  }
}

public plugin_init()
{
  register_plugin("[JAIL] Map support", JAIL_VERSION, JAIL_AUTHOR);

  if(g_iJBMap)
  {
    g_aDoors = ArrayCreate();
    setup_buttons();

    cvar_shoot_buttons = register_cvar("jail_shoot_buttons", "1");
    set_client_commands("open", "jail_cmd_open");
    set_client_commands("close", "jail_cmd_close");
    RegisterHam(Ham_TraceAttack, "func_button", "Ham_TraceAttack_pre", 0);
    RegisterHam(Ham_Use, "func_button", "Ham_Use_pre", 0);
    //register_clcmd("say /c", "my_cmd");
  }
}

public jail_achivement_load()
{
    jail_achiev_register("Open doors", "You must open doors", 10, 1, 1);
}

public plugin_natives()
{
  register_library("jailbreak");
  register_native("jail_celldoors", "_celldoors");
}

//public my_cmd(id)
//{
//	new origin[3], Float:fOrigin[3];
//	get_user_origin(id, origin, 3);
//	IVecFVec(origin, fOrigin);
//	log_amx("%0.2f, %0.2f, %0.2f", fOrigin[0], fOrigin[1], fOrigin[2]);
//}

public Forward_Spawn_post(ent)
{
  if(is_valid_ent(ent))
  {
    switch(g_iMapFix)
    {
      case JAIL_GUETTA:
      {
        new myent = find_ent_in_sphere(-1, Float:{741.00, 74.00, 160.00}, 5.0);
        if(myent)
        {
          remove_entity(myent);
          unregister_forward(FM_Spawn, g_pForwardSpawn, 1);
        }
      }
      case JAIL_NUKE:
      {
        new myent = find_ent_in_sphere(-1, Float:{-404.00, -782.00, -415.00}, 5.0);
        if(myent)
        {
          g_iNukeEnts[0] = myent;
          unregister_forward(FM_Spawn, g_pForwardSpawn, 1);
          create_wall_block(Float:{-222.0, -329.0, -303.5}, Float:{-32.0, -40.0, -111.5}, Float:{32.0, 40.0, 111.5});
        }
      }
    }
  }
}

public pfn_keyvalue(ent)
{
  if(!g_iJBMap || !is_valid_ent(ent))
    return PLUGIN_CONTINUE;

  static classname[32], keyname[32], value[32];
  copy_keyvalue(classname, charsmax(classname), keyname, charsmax(keyname), value, charsmax(value));
  if(!equal(classname, "multi_manager"))
    return PLUGIN_CONTINUE;

  TrieSetCell(g_tMultiManagers, keyname, ent);
  return PLUGIN_CONTINUE;
}

public Ham_Use_pre(ent, id, idactivator, type, Float:value)
{
  if(type == 2 && value == 1.0)
  {
    if(!task_exists(id))
    {
      if(fix_nuke_doors(id, ent))
        return HAM_HANDLED;

      if(in_button(ent))
      {
        jail_achiev_set_progress(id, "Open doors", jail_achiev_get_progress(id, "Open doors") + 1);
        set_task(0.1, "jail_doors", id);
        return HAM_HANDLED;
      }
    }
  }

  return HAM_IGNORED;
}

public Ham_TraceAttack_pre(button, id)
{
  if(is_valid_ent(button) && get_pcvar_num(cvar_shoot_buttons) && !jail_get_globalinfo(GI_BLOCKDOORS))
  {
    if(!task_exists(id))
    {
      if(fix_nuke_doors(id, button))
        return HAM_HANDLED;

      if(in_button(button))
      {
        set_task(0.5, "jail_doors", id);
        return HAM_HANDLED;
      }
    }

    on_button(id, button);
    return HAM_HANDLED;
  }

  return HAM_IGNORED;
}

public fix_nuke_doors(id, ent)
{
  if(id && g_iMapFix == JAIL_NUKE && g_iNukeEnts[1] == ent)
  {
    new door = g_iNukeEnts[0];
    if(get_door_state(door) == TS_OPENED)
      toggle_doors(door, TS_CLOSING);
    else if(get_door_state(door) == TS_CLOSED)
      ExecuteHamB(Ham_Use, door, id, 0, 1, 1.0);
    return 1;
  }

  return 0;
}

public jail_cmd_open(id)
{
  if(simon_or_admin(id) && get_cell_state() == TS_CLOSED)
    jail_doors(id);
}

public jail_cmd_close(id)
{
  if(simon_or_admin(id))
  {
    if(g_iMapFix == JAIL_NUKE)
    {
      if(get_door_state(g_iNukeEnts[0]) == TS_OPENED)
        toggle_doors(g_iNukeEnts[0], TS_CLOSING);
    }
    if(get_cell_state() == TS_OPENED)
      jail_doors(id);
  }
}

public jail_doors(id)
{
  if(jail_get_gamemode() == GAME_ENDED)
    return;

  new door, newstate;
  for(new i = 0; i < ArraySize(g_aDoors); i++)
  {
    door = ArrayGetCell(g_aDoors, i);
    if(door)
    {
      if(get_door_state(door) == TS_OPENED)
      {
        toggle_doors(door, TS_CLOSING);
        newstate = TS_CLOSED;
      }
      else if(get_door_state(door) == TS_CLOSED)
      {
        newstate = TS_OPENED;
        if(g_iMapFix == JAIL_ATNAS)
          entity_set_int(door, EV_INT_solid, SOLID_NOT);

        ExecuteHamB(Ham_Use, door, id, 0, 1, 1.0);
      }
    }
  }

  static name[32];
  get_user_name(id, name, charsmax(name));
  if(newstate == TS_OPENED)
    client_print_color(0, print_team_default, "%s %L", JAIL_TAG, LANG_SERVER, "JAIL_OPENEDCELLS", id ? name : "Server");
  else if(newstate == TS_CLOSED)
    client_print_color(0, print_team_default, "%s %L", JAIL_TAG, LANG_SERVER, "JAIL_CLOSEDCELLS", id ? name : "Server");
}

public on_button(id, button)
{
  if(entity_get_int(button, EV_INT_spawnflags) >= SF_BUTTON_TOUCH_ONLY)
    fake_touch(button, id);
  else ExecuteHamB(Ham_Use, button, id, 0, 2, 1.0);
  entity_set_float(button, EV_FL_frame, 0.0);
}

public setup_buttons()
{
  static info[32];
  new ent[3], Float:origin[3], pos;
  while((ent[0] = find_ent_by_class(ent[0], "info_player_deathmatch")))
  {
    entity_get_vector(ent[0], EV_VEC_origin, origin);
    while((ent[1] = find_ent_in_sphere(ent[1], origin, 200.0)))
    {
      if(!is_valid_ent(ent[1]))
        continue;

      entity_get_string(ent[1], EV_SZ_classname, info, charsmax(info));
      if(!equal(info, "func_door") && !equal(info, "func_door_rotating"))
        continue;

      entity_get_string(ent[1], EV_SZ_targetname, info, charsmax(info));
      if(!info[0])
        continue;

      if(!in_array(g_aDoors, ent[1]))
      {
        if(ent[1] != g_iNukeEnts[0])
          ArrayPushCell(g_aDoors, ent[1]);
        DispatchKeyValue(ent[1], "wait", -1);

        //log_amx("SPAWNFLAGS %d", entity_get_int(ent[1], EV_INT_spawnflags));
        if(g_iMapFix == JAIL_ATNAS)
          entity_set_int(ent[1], EV_INT_spawnflags, 128);
        else entity_set_int(ent[1], EV_INT_spawnflags, 0);

        if(g_iMapFix == JAIL_MIDDAY || g_iMapFix == JAIL_LATEST || g_iMapFix == JAIL_ATNAS || g_iMapFix == JAIL_NUKE)
          entity_set_float(ent[1], EV_FL_speed, 200.0);
      }

      if(TrieKeyExists(g_tMultiManagers, info))
      {
        TrieGetCell(g_tMultiManagers, info, ent[2]);
        entity_get_string(ent[2], EV_SZ_targetname, info, charsmax(info));
        if(!info[0])
          continue;
        ent[2] = find_ent_by_target(0, info);
      }
      else ent[2] = find_ent_by_target(0, info);

      if(!in_button(ent[2]) && pos < sizeof(g_iButtons))
      {
        if(g_iMapFix == JAIL_NUKE && ent[1] == g_iNukeEnts[0])
          g_iNukeEnts[1] = ent[2];
        g_iButtons[pos] = ent[2];
        pos++;
      }
    }
  }
}

stock in_array(Array:array, item)
{
  for(new i = 0; i < ArraySize(array); i++)
  {
    if(ArrayGetCell(g_aDoors, i) == item)
      return 1;
  }

  return 0;
}

stock in_button(ent)
{
  for(new i = 0; i < sizeof(g_iButtons); i++)
    if(g_iButtons[i] == ent)
      return 1;

  return 0;
}

stock get_cell_state()
{
  new doorstate = -1, door;
  for(new i = 0; i < ArraySize(g_aDoors); i++)
  {
    door = ArrayGetCell(g_aDoors, i);
    if(door) doorstate = get_door_state(door);
  }

  return doorstate;
}

stock get_door_state(door)
  return ExecuteHam(Ham_GetToggleState, door);

stock toggle_doors(ent, newstate)
{
  new endstate = g_iToggleStates[get_door_state(ent)][newstate];

  for(new i = 1; i <= endstate; i++)
    call_think(ent);

  if(g_iMapFix == JAIL_ATNAS)
    entity_set_int(ent, EV_INT_solid, SOLID_BSP);

  return newstate;
}

stock create_wall_block(const Float:origin[3], const Float:mins[3], const Float:maxs[3])
{
  new ent = create_entity("info_target");
  if(ent)
  {
    entity_set_string(ent, EV_SZ_classname, "wall_block_ent");
    static model[64];
    formatex(model, charsmax(model), "models/player/%s/%s.mdl", JAIL_T_MODEL, JAIL_T_MODEL);
    entity_set_model(ent, model);
    entity_set_size(ent, mins, maxs);

    entity_set_int(ent, EV_INT_solid, SOLID_BBOX);
    entity_set_int(ent, EV_INT_movetype, MOVETYPE_NONE);
    entity_set_origin(ent, origin);

    return ent;
  }

  return 0;
}

public _celldoors(plugin, params)
{
  if(params != 2)
    return -1;
  new id = get_param(1);
  new val = get_param(2);

  if(get_cell_state() != val)
    jail_doors(id);

  return 1;
}
