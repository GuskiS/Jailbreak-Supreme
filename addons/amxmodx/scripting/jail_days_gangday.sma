#include <amxmodx>
#include <cstrike>
#include <fakemeta>
#include <hamsandwich>
#include <fun>
#include <jailbreak>

new g_pMyNewDay, g_szDayName[JAIL_MENUITEM], g_iPlayerGang[33];
new HamHook:g_HamTraceAttack, HamHook:g_HamKilled, g_pMsgScreenFade;

public plugin_init()
{
  register_plugin("[JAIL] Gang day", JAIL_VERSION, JAIL_AUTHOR);

  DisableHamForward((g_HamTraceAttack = RegisterHamPlayer(Ham_TraceAttack, "Ham_TraceAttack_pre", 0)));
  DisableHamForward((g_HamKilled = RegisterHamPlayer(Ham_Killed, "Ham_Killed_post", 1)));

  formatex(g_szDayName, charsmax(g_szDayName), "%L", LANG_PLAYER, "JAIL_DAY6");
  g_pMyNewDay = jail_day_add(g_szDayName, "gang", 1);
  g_pMsgScreenFade = get_user_msgid("ScreenFade");
}

public jail_freebie_join(id, event, type)
{
  if(type == GI_DAY && event == g_pMyNewDay)
  {
    set_player_attributes(id);
    set_player_glowing(id);
    return PLUGIN_HANDLED;
  }

  return PLUGIN_CONTINUE;
}

public jail_day_start(simon, day, dayname[])
{
  if(day == g_pMyNewDay)
  {
    start_gangday(simon);
    return PLUGIN_HANDLED;
  }

  return PLUGIN_CONTINUE;
}

public jail_day_end(simon, day, dayname[])
{
  if(day == g_pMyNewDay)
  {
    end_gangday(simon);
    return PLUGIN_HANDLED;
  }

  return PLUGIN_CONTINUE;
}

public Ham_Killed_post(victim, killer, shouldgib)
{
  if(!is_user_connected(victim))
    return HAM_IGNORED;

  if(g_iPlayerGang[victim])
    reset_user(victim);
  if(!team_count(1) || !team_count(2))
    end_gangday(0);

  return HAM_IGNORED;
}

public Ham_TraceAttack_pre(victim, attacker, Float:damage, Float:direction[3], tracehandle, damagebits)
{
  if(is_user_connected(victim) && is_user_connected(attacker))
  {
    if(g_iPlayerGang[victim] == g_iPlayerGang[attacker] && cs_get_user_team(victim) == cs_get_user_team(attacker))
      return HAM_SUPERCEDE;
  }

  return HAM_IGNORED;
}

start_gangday(simon)
{
  new num, id;
  static players[32];
  get_players(players, num, "ae", "TERRORIST");

  if(num < 4)
  {
    client_print_color(id, print_team_default, "%s %L", JAIL_TAG, id, "JAIL_DAY6_EXTRA1", id, "JAIL_DAY6");
    return;
  }

  for(--num; num >= 0; num--)
  {
    id = players[num];
    if(jail_get_playerdata(id, PD_FREEDAY)) continue;
    set_player_attributes(id);
  }

  team_normalize();
  get_players(players, num, "ae", "TERRORIST");
  for(--num; num >= 0; num--)
  {
    id = players[num];
    if(jail_get_playerdata(id, PD_FREEDAY)) continue;
    set_player_glowing(id);
  }

  server_event(simon, g_szDayName, false);
  jail_set_globalinfo(GI_BLOCKDOORS, true);
  my_ham_hooks(true);
  jail_celldoors(simon, TS_OPENED);

  set_cvar_num("mp_friendlyfire", 1);
  jail_ham_all(true);
  jail_set_globalinfo(GI_DAY, g_pMyNewDay);
}

public set_player_attributes(id)
{
  jail_player_crowbar(id, false);
  jail_set_playerdata(id, PD_HAMBLOCK, true);

  strip_weapons(id);
  set_user_health(id, 100);
  ham_give_weapon(id, "weapon_mac10", 1);
  cs_set_user_bpammo(id, CSW_MAC10, 100);
  g_iPlayerGang[id] = random_num(1, 2);
}

public set_player_glowing(id)
{
  if(g_iPlayerGang[id] == 1)
  {
    make_screenfade(id, 255, 0, 0, SF_FADE_IN + SF_FADE_ONLYONE);
    set_player_glow(id, 1, 255, 0, 0, 30);
  }
  else
  {
    make_screenfade(id, 0, 255, 0, SF_FADE_IN + SF_FADE_ONLYONE);
    set_player_glow(id, 1, 0, 255, 0, 30);
  }
}

end_gangday(simon)
{
  new num, id;
  static players[32];
  get_players(players, num, "ae", "TERRORIST");

  for(--num; num >= 0; num--)
  {
    id = players[num];
    reset_user(id);
    ExecuteHamB(Ham_CS_RoundRespawn, id);
  }

  jail_celldoors(simon, TS_CLOSED);
  set_cvar_num("mp_friendlyfire", 0);
  server_event(simon, g_szDayName, true);
  jail_set_globalinfo(GI_BLOCKDOORS, false);
  jail_ham_all(false);
  jail_set_globalinfo(GI_DAY, false);
  my_ham_hooks(false);
}

reset_user(id)
{
  jail_set_playerdata(id, PD_HAMBLOCK, false);
  strip_weapons(id);
  if(g_iPlayerGang[id] == 1)
    make_screenfade(id, 255, 0, 0, 0);
  else if(g_iPlayerGang[id] == 2)
    make_screenfade(id, 0, 255, 0, 0);

  g_iPlayerGang[id] = false;
  set_player_glow(id, 0);
}

my_ham_hooks(val)
{
  if(val)
  {
    EnableHamForward(g_HamTraceAttack);
    EnableHamForward(g_HamKilled);
  }
  else
  {
    DisableHamForward(g_HamTraceAttack);
    DisableHamForward(g_HamKilled);
  }
}

team_count(team)
{
  new num, id, count;
  static players[32];
  get_players(players, num, "ae", "TERRORIST");

  for(--num; num >= 0; num--)
  {
    id = players[num];
    if(g_iPlayerGang[id] == team)
      count++;
  }

  return count;
}

team_normalize()
{
  new num, id;
  static players[32];
  get_players(players, num, "ae", "TERRORIST");

  new count[3];
  count[1] = team_count(1);
  count[2] = team_count(2);

  get_players(players, num, "ae", "TERRORIST");
  while(abs(count[1] - count[2]) > 1)
  {
    id = players[random(num)];
    if(count[1] > count[2])
    {
      if(g_iPlayerGang[id] == 1)
      {
        g_iPlayerGang[id] = 2;
        count[1]--;
        count[2]++;
      }
    }
    else
    {
      if(g_iPlayerGang[id] == 2)
      {
        g_iPlayerGang[id] = 1;
        count[1]++;
        count[2]--;
      }
    }
  }
}

make_screenfade(id, r, g, b, type)
{
  message_begin(MSG_ONE_UNRELIABLE, g_pMsgScreenFade, _, id);
  write_short(10000); //duration
  write_short(0); //hold
  write_short(type); //flags (SF_FADE_IN + SF_FADE_ONLYONE) (SF_FADEOUT)
  write_byte(r); //r
  write_byte(g); //g
  write_byte(b); //b
  write_byte(50); //a
  message_end();
}
