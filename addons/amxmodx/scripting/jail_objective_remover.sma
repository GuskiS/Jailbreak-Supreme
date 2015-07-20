#include <amxmodx>
#include <engine>
#include <jailbreak_const>

new g_iBuyZone;

new const g_szObjectives[][] =
{
  "func_bomb_target",
  "info_bomb_target",
  "info_vip_start",
  "func_vip_safetyzone",
  "func_escapezone",
  "hostage_entity",
  "monster_scientist",
  "func_hostage_rescue",
  //"trigger_camera",
  "info_hostage_rescue",
  "func_buyzone"
};

public plugin_precache()
{
  g_iBuyZone = create_entity("func_buyzone");
  entity_set_size(g_iBuyZone, Float:{-8191.0, -8191.0, -8191.0}, Float:{-8190.0, -8190.0, -8190.0});
  DispatchSpawn(g_iBuyZone);
}

public plugin_init()
{
  register_plugin("[JAIL] Objective remover", JAIL_VERSION, JAIL_AUTHOR);
}

public pfn_spawn(ent)
{
  if(!is_valid_ent(ent))
    return PLUGIN_CONTINUE;

  static classname[32], i;
  entity_get_string(ent, EV_SZ_classname, classname, charsmax(classname));
  if(g_iBuyZone == ent && equal(classname, "func_buyzone"))
    return PLUGIN_CONTINUE;

  for(i = 0; i < sizeof(g_szObjectives); i++)
  {
    if(equal(classname, g_szObjectives[i]))
    {
      remove_entity(ent);
      return PLUGIN_HANDLED;
    }
  }

  return PLUGIN_CONTINUE;
}
