#if defined _jail_stocks_included
  #endinput
#endif
#define _jail_stocks_included

stock is_jailmap()
{
  static mapname[32];
  get_mapname(mapname, charsmax(mapname));

  if(equali(mapname, "jail_", 5) || equali(mapname, "jb_", 3) || equali(mapname, "jailbreak_", 10))
    return 1;

  return 0;
}

stock auto_exec_config(const szName[], bool:bAutoCreate=true)
{
  new szFileName[32];
  new iLen = copy(szFileName, charsmax(szFileName), szName);
  if(iLen <= 4 || !equal(szFileName[iLen-4], ".cfg"))
    add(szFileName, charsmax(szFileName), ".cfg");

  new szConfigPath[96];
  get_localinfo("amxx_configsdir", szConfigPath, charsmax(szConfigPath));
  format(szConfigPath, charsmax(szConfigPath), "%s/%s", szConfigPath, szFileName);

  if(file_exists(szConfigPath))
  {
    server_cmd("exec %s", szConfigPath);
    server_exec();
    return 1;
  }
  else if(bAutoCreate)
  {
    new fp = fopen(szConfigPath, "wt");
    if(!fp)
      return -1;
    new szPluginFileName[96], szPluginName[64], szAuthor[32], szVersion[32], szStatus[2];
    new iPlugin = get_plugin(-1,
          szPluginFileName, charsmax(szPluginFileName),
          szPluginName, charsmax(szPluginName),
          szVersion, charsmax(szVersion),
          szAuthor, charsmax(szAuthor),
          szStatus, charsmax(szStatus));

    fprintf(fp, "; ^"%s^" onfiguration file^n", szPluginName);
    fprintf(fp, "; Author : ^"%s^"^n", szAuthor);
    fprintf(fp, "; Version : ^"%s^"^n", szVersion);
    fprintf(fp, "; File : ^"%s^"^n", szPluginFileName);

    new iMax;
    iMax = get_plugins_cvarsnum();
    new iTempId, iPcvar, szCvarName[256], szCvarValue[128], i;
    for(i = 0; i<iMax; i++)
    {
      get_plugins_cvar(i, szCvarName, charsmax(szCvarName), _, iTempId, iPcvar);
      if(iTempId == iPlugin)
      {
        get_pcvar_string(iPcvar, szCvarValue, charsmax(szCvarValue));
        fprintf(fp, "%s ^"%s^"^n", szCvarName, szCvarValue);
      }
    }

    fclose(fp);
  }
  return 0;
}

stock strip_weapons(id)
{
  if(!is_user_alive(id))
    return;

  static const PRIMARY_WEAPONS_BIT_SUM = (1<<CSW_SCOUT)|(1<<CSW_XM1014)|(1<<CSW_MAC10)|(1<<CSW_AUG)|(1<<CSW_UMP45)|(1<<CSW_SG550)|(1<<CSW_GALIL)|(1<<CSW_FAMAS)|
    (1<<CSW_AWP)|(1<<CSW_MP5NAVY)|(1<<CSW_M249)|(1<<CSW_M3)|(1<<CSW_M4A1)|(1<<CSW_TMP)|(1<<CSW_G3SG1)|(1<<CSW_SG552)|(1<<CSW_AK47)|(1<<CSW_P90);
  static const SECONDARY_WEAPONS_BIT_SUM = (1<<CSW_P228)|(1<<CSW_ELITE)|(1<<CSW_FIVESEVEN)|(1<<CSW_USP)|(1<<CSW_GLOCK18)|(1<<CSW_DEAGLE);
  static const GRENADES_WEAPONS_BIT_SUM = (1<<CSW_HEGRENADE)|(1<<CSW_FLASHBANG)|(1<<CSW_SMOKEGRENADE)|(1<<CSW_C4);
  new weapons[32], num_weapons, index, weaponid;
  get_user_weapons(id, weapons, num_weapons);

  static wname[32];
  for (index = 0; index < num_weapons; index++)
  {
    weaponid = weapons[index];

    if(((1<<weaponid) & PRIMARY_WEAPONS_BIT_SUM) || ((1<<weaponid) & SECONDARY_WEAPONS_BIT_SUM) || ((1<<weaponid) & GRENADES_WEAPONS_BIT_SUM))
    {
      get_weaponname(weaponid, wname, charsmax(wname));

      ham_strip_weapon(id, wname);
      cs_set_user_bpammo(id, weaponid, 0);
    }
  }

  set_pdata_float(id, 116, 0.0); // m_fHasPrimary
  remove_user_shield(id);
}

stock ham_strip_weapon(index, const weapon[])
{
  if(!is_user_alive(index))
    return false;

  new weaponid = get_weaponid(weapon);
  if(!weaponid)
    return false;

  new weapon_ent = fm_find_ent_by_owner(-1, weapon, index);
  if (!weapon_ent)
    return false;

  new current_weapon_ent = fm_cs_get_current_weapon_ent(index);
  new current_weapon = pev_valid(current_weapon_ent) ? cs_get_weapon_id(current_weapon_ent) : -1;
  if(current_weapon == weaponid)
    ExecuteHamB(Ham_Weapon_RetireWeapon, weapon_ent);

  if (!ExecuteHamB(Ham_RemovePlayerItem, index, weapon_ent))
    return false;

  user_has_weapon(index, weaponid, 0);
  ExecuteHamB(Ham_Item_Kill, weapon_ent);
  remove_user_shield(index);
  //set_pev(index, pev_weapons, pev(index, pev_weapons) & ~(1<<weaponid));

  return true;
}

stock ham_give_weapon(id, weapon[], val = 0)
{
  if(!is_user_alive(id))
    return false;

  if(!equal(weapon, "weapon_",7)) return 0;

  new wEnt = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, weapon));
  if(!pev_valid(wEnt)) return 0;

  set_pev(wEnt, pev_spawnflags, SF_NORESPAWN);
  dllfunc(DLLFunc_Spawn, wEnt);

  if(!ExecuteHamB(Ham_AddPlayerItem, id, wEnt))
  {
    if(pev_valid(wEnt)) set_pev(wEnt, pev_flags, pev(wEnt, pev_flags) | FL_KILLME);
    return 0;
  }

  ExecuteHamB(Ham_Item_AttachToPlayer, wEnt, id);
  if(val && !is_user_bot(id))
    //ExecuteHamB(Ham_Item_Deploy, fm_find_ent_by_owner(-1, weapon, id));
    show_weapon(id, weapon);

  return wEnt;
}

stock show_weapon(id, weapon[])
{
  static msg;
  if(!msg)
    msg = get_user_msgid("CurWeapon");

  new weaponid = get_weaponid(weapon);
  if(user_has_weapon(id, weaponid))
    ExecuteHamB(Ham_Item_Deploy, fm_find_ent_by_owner(-1, weapon, id));

  engclient_cmd(id, weapon);

  emessage_begin(MSG_ONE_UNRELIABLE, msg, _, id);
  ewrite_byte(1);
  ewrite_byte(weaponid);
  ewrite_byte(-1);
  emessage_end();
}

stock fm_find_ent_by_owner(entity, const classname[], owner)
{
  while ((entity = engfunc(EngFunc_FindEntityByString, entity, "classname", classname)) && pev(entity, pev_owner) != owner) { /* keep looping */ }
  return entity;
}

stock fm_find_ent_by_class(entity, const classname[])
  return engfunc(EngFunc_FindEntityByString, entity, "classname", classname);

stock fm_cs_get_current_weapon_ent(id)
{
  if(pev_valid(id) != 2)
    return -1;

  return get_pdata_cbase(id, 373);
}

stock can_admin_do()
{
  if(get_pcvar_num(get_cvar_pointer("jail_admin_access")))
    return 1;

  return 0;
}

stock simon_or_admin(id)
{
  if(jail_get_gamemode() != GAME_STARTED)
  {
    ColorChat(id, NORMAL, "%s %L", JAIL_TAG, id, "JAIL_GAMENOTSTARTED");
    return 0;
  }

  new simon = jail_get_playerdata(id, PD_SIMON), admin = (can_admin_do() && is_jail_admin(id));
  if(simon)// || jail_get_globalinfo(GI_FREEPASS) == id)
    return 1;
  else if(admin)
  {
    static command[32];
    read_argv(0, command, charsmax(command));
    if(equal(command, "say") || equal(command, "say_team"))
      read_argv(1, command, charsmax(command));

    if(!equal(command, "menuselect"))
    {
      static name[2][32], simon;
      get_user_name(id, name[0], charsmax(name[]));
      get_user_name(simon = jail_get_globalinfo(GI_SIMON), name[1], charsmax(name[]));
      log_amx("[JAIL] Admin %s used %s command, simon was %s", name[0], command, simon ? name[1] : "none");
    }
    return 1;
  }
  else
  {
    if(can_admin_do())
      ColorChat(id, NORMAL, "%s %L", JAIL_TAG, id, "JAIL_SIMON_ADMIN");
    else ColorChat(id, NORMAL, "%s %L", JAIL_TAG, id, "JAIL_SIMON_MUSTBE");
  }

  return 0;
}

stock is_jail_admin(id)
{
  if(get_user_flags(id) & JAIL_ADMIN_ACCESS)
    return 1;

  return 0;
}

stock in_progress_current(type, value)
{
  return jail_get_globalinfo(type) == value;
}

stock in_progress(id, value)
{
  new event = jail_get_globalinfo(value);
  if(event)
  {
    if(id)
    {
      static name[JAIL_MENUITEM];
      if(value == GI_DAY)
        jail_day_getname(event, name);
      else jail_game_getname(event, name);

      ColorChat(id, NORMAL, "%s %L", JAIL_TAG, id, "JAIL_EVENTALREADY", name, value == GI_DAY ? "days" : "games");
    }
    return 1;
  }

  return 0;
}

stock server_event(id, event[], val)
{
  static name[32];
  get_user_name(id, name, charsmax(name));
  ColorChat(0, NORMAL, "%s %L", JAIL_TAG, LANG_SERVER, val ? "JAIL_EVENTOFF" : "JAIL_EVENTON", event, id ? name : "server");
  log_amx("[JAIL] %L", LANG_SERVER, val ? "JAIL_EVENTOFF" : "JAIL_EVENTON", event, id ? name : "server");
}

stock CsTeams:get_reverse_state()
{
  if(jail_get_globalinfo(GI_REVERSE))
    return CS_TEAM_T;

  return CS_TEAM_CT;
}

stock set_client_commands(cmd[], func[])
{
  //log_amx("%s", cmd);
  static msg[32];
  formatex(msg, charsmax(msg), "say /%s", cmd);
  register_clcmd(msg, func);
  formatex(msg, charsmax(msg), "say_team /%s", cmd);
  register_clcmd(msg, func);
  formatex(msg, charsmax(msg), "jail_%s", cmd);
  register_clcmd(msg, func);
}

stock remove_user_shield(id)
{
#if AMXX_VERSION_NUM >= 183
    if(get_pdata_bool(id, 2043))								//m_bHasShield
    {
        set_pdata_bool(id, 2043, false);						//m_bHasShield
        set_pdata_int(id, 116, 0);								// m_fHasPrimary
        set_pdata_bool(id, 2042, false);						// m_bUsesShield
        set_pev(id, pev_gamestate, 1);
        new iHideHUD = get_pdata_int(id, 361);					// m_iHideHUD
        if(iHideHUD & (1<<7))
            set_pdata_int(id, 361, iHideHUD & ~(1<<7));	// m_iHideHUD

        return 1;
    }
#endif
    return -id;
}

stock set_player_glow(id, val, r=0, g=0, b=0, amount=0)
{
  if(val)
    set_user_rendering(id, kRenderFxGlowShell, r, g, b, kRenderNormal, amount);
  else set_user_rendering(id);
}

stock cs_reset_user_maxspeed(id, Float:val = 0.0)
{
  static Float:maxspeed;
  if(!val)
  {
    switch(get_user_weapon(id))
    {
      case CSW_SG550, CSW_AWP, CSW_G3SG1: maxspeed = 210.0;
      case CSW_M249: maxspeed = 220.0;
      case CSW_AK47: maxspeed = 221.0;
      case CSW_M3, CSW_M4A1: maxspeed = 230.0;
      case CSW_SG552: maxspeed = 235.0;
      case CSW_XM1014, CSW_AUG, CSW_GALIL, CSW_FAMAS: maxspeed = 240.0;
      case CSW_P90: maxspeed = 245.0;
      case CSW_SCOUT: maxspeed = 260.0;
      default: maxspeed = 250.0;
    }
  }
  else maxspeed = val;

  #if defined _fun_included
  set_user_maxspeed(id, maxspeed);
  #else
    #if defined _engine_included
    entity_set_float(id, EV_FL_maxspeed, maxspeed);
    #else
    set_pev(id, pev_maxspeed, maxspeed);
    #endif
  #endif
}

stock move_grenade()
{
  new ent = -1;
  #if defined _engine_included
  while((ent = find_ent_by_class(ent, "grenade")))
    entity_set_origin(ent, Float:{-8191.0, -8191.0, -8191.0});
  #else
  while((ent = fm_find_ent_by_class(ent, "grenade")))
    engfunc(EngFunc_SetOrigin, ent, Float:{-8191.0, -8191.0, -8191.0});
  #endif

  return 1;
}

stock show_player_menu(id, pick, status, handle[])
{
  static name[32], data[3], newmenu;
  formatex(name, charsmax(name), "%L", id, "JAIL_MENUMENU");
  newmenu = menu_create(name, handle);
  static players[32];
  new inum, i;
  get_players(players, inum, status, pick ? "TERRORIST" : "CT");

  for(--inum; inum >= 0; inum--)
  {
    i = players[inum];
    if(jail_get_playerdata(i, PD_FREEDAY)) continue;
    get_user_name(i, name, charsmax(name));
    num_to_str(i, data, charsmax(data));
    menu_additem(newmenu, name, data, 0);
  }

  menu_display(id, newmenu);
}
