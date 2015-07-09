#include <amxmodx>
#include <amxmisc>
#include <engine>
#include <cstrike>
#include <hamsandwich>
#include <fakemeta>
#include <jailbreak>

new cvar_talk_mode;
new g_iCanTalk[33];

public plugin_init()
{
  register_plugin("[JAIL] Voice", JAIL_VERSION, JAIL_AUTHOR);
  RegisterHamPlayer(Ham_Killed, "Ham_Killed_post", 1);
  register_forward(FM_Voice_SetClientListening, "Forward_SetClientListening");

  cvar_talk_mode = register_cvar("jail_talk_mode", "3");//0-simon only, 1-simon+ct, 2-simon+admin, 3-simon+ct+admin, 4-all

  register_clcmd("+simonvoice", "cmd_voiceon");
  register_clcmd("-simonvoice", "cmd_voiceoff");
}

public Ham_Killed_post(victim, killer, shouldgib)
{
  if(!is_user_connected(victim))
    return HAM_IGNORED;

  g_iCanTalk[victim] = false;
  return HAM_HANDLED;
}

public Forward_SetClientListening(receiver, sender, bool:listen)
{
  if(!is_user_connected(receiver) || !is_user_connected(sender) || sender == receiver)
    return FMRES_IGNORED;

  if(get_speak(sender) == SPEAK_MUTED)
  {
    engfunc(EngFunc_SetClientListening, receiver, sender, false);
    return FMRES_SUPERCEDE;
  }

  listen = false;
  if(is_user_alive(sender))
  {
    listen = bool:can_talk(sender);
  }
  else
  {
    if(is_user_alive(receiver))
      listen = false;
    else listen = true;
  }

  engfunc(EngFunc_SetClientListening, receiver, sender, listen);
  return FMRES_SUPERCEDE;
}

public cmd_voiceon(id)
{
  new simon = jail_get_globalinfo(GI_SIMON);
  if(id == simon || can_talk(id) || cs_get_user_team(id) == CS_TEAM_CT)
  {
    client_cmd(id, "+voicerecord");
    g_iCanTalk[id] = true;
  }

  return PLUGIN_HANDLED;
}

public cmd_voiceoff(id)
{
  client_cmd(id, "-voicerecord");
  g_iCanTalk[id] = false;

  return PLUGIN_HANDLED;
}

can_talk(sender)
{
  new bool:value = false;
  if(jail_get_playerdata(sender, PD_TALK))
    value = true;
  else
  {
    switch(get_pcvar_num(cvar_talk_mode))
    {
      case 0:
      {
        if(g_iCanTalk[sender])
          value = true;
      }
      case 1:
      {
        if(g_iCanTalk[sender] || cs_get_user_team(sender) == CS_TEAM_CT)
          value = true;
      }
      case 2:
      {
        if(g_iCanTalk[sender] || is_user_admin(sender))
          value = true;
      }
      case 3:
      {
        if(g_iCanTalk[sender] || is_user_admin(sender) || cs_get_user_team(sender) == CS_TEAM_CT)
          value = true;
      }
      default: value = true;
    }
  }

  return value;
}
