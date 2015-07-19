#include <amxmodx>
#include <hamsandwich>
#include <jailbreak>

public plugin_init()
{
  register_plugin("[JAIL] Basic achievments", JAIL_VERSION, JAIL_AUTHOR);

  register_event("DeathMsg", "Event_DeathMsg", "a");
}

public jail_achivements_load()
{
  jail_achiev_register("JBA_CONNECTSERVER", "JBA_CONNECTSERVER_DESC", 1, 200, 0);
  jail_achiev_register("JBA_SUICIDES", "JBA_SUICIDES_DESC", 2, 200, 0);
  jail_achiev_register("JBA_KILLS_GRENADE", "JBA_KILLS_GRENADE_DESC", 2, 200, 0);
  jail_achiev_register("JBA_KILLS_KNIFE", "JBA_KILLS_KNIFE_DESC", 2, 200, 0);
  jail_achiev_register("JBA_KILLS_HEADSHOT", "JBA_KILLS_HEADSHOT_DESC", 2, 200, 0);
  jail_achiev_register("JBA_ROUND_SURVIVED", "JBA_ROUND_SURVIVED_DESC", 3, 500, 0);
  jail_achiev_register("JBA_ROUND_STARTED", "JBA_ROUND_STARTED_DESC", 2, 1000, 0);
}

public jail_gamemode(mode)
{
  if(mode == GAME_ENDED || mode == GAME_STARTED)
  {
    new num, id;
    static players[32];
    get_players(players, num, "a");

    for(--num; num >= 0; num--)
    {
      id = players[num];
      if(mode == GAME_ENDED)
        jail_achiev_set_progress(id, "JBA_ROUND_SURVIVED", jail_achiev_get_progress(id, "JBA_ROUND_SURVIVED") + 1);
      else jail_achiev_set_progress(id, "JBA_ROUND_STARTED", jail_achiev_get_progress(id, "JBA_ROUND_STARTED") + 1);
    }
  }
}

public client_putinserver(id)
{
  if(is_user_bot(id))
    return;

  if(!task_exists(id))
    set_task(1.0, "putinserver", id);
}

public putinserver(id)
{
  jail_achiev_set_progress(id, "JBA_CONNECTSERVER", jail_achiev_get_progress(id, "JBA_CONNECTSERVER") + 1);
}

public Event_DeathMsg()
{
  new killer = read_data(1);
  new victim = read_data(2);
  static weapon[16];
  read_data(4, weapon, charsmax(weapon));

  if(equali(weapon, "worldspawn"))
    jail_achiev_set_progress(victim, "JBA_SUICIDES", jail_achiev_get_progress(victim, "JBA_SUICIDES") + 1);

  if(equali(weapon, "grenade"))
    jail_achiev_set_progress(killer, "JBA_KILLS_GRENADE", jail_achiev_get_progress(killer, "JBA_KILLS_GRENADE") + 1);

  if(equali(weapon, "knife"))
    jail_achiev_set_progress(killer, "JBA_KILLS_KNIFE", jail_achiev_get_progress(killer, "JBA_KILLS_KNIFE") + 1);

  if(read_data(2))
    jail_achiev_set_progress(killer, "JBA_KILLS_HEADSHOT", jail_achiev_get_progress(killer, "JBA_KILLS_HEADSHOT") + 1);
}
