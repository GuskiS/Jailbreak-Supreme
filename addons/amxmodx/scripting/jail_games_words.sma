#include <amxmodx>
#include <cstrike>
#include <jailbreak>
#include <timer_controller>

#define TASK_WORDS 1111

new g_pMyNewGame, cvar_words_time, g_szGamesWord[32];
new g_szGameName[JAIL_MENUITEM], g_iTimeOnClock;

public plugin_init()
{
  register_plugin("[JAIL] Words game", JAIL_VERSION, JAIL_AUTHOR);

  cvar_words_time = register_cvar("jail_words_time", "15");
  register_clcmd("jail_my_word", "pick_the_word");

  register_clcmd("say", "hook_say");

  formatex(g_szGameName, charsmax(g_szGameName), "%L", LANG_PLAYER, "JAIL_GAME2");
  g_pMyNewGame = jail_game_add(g_szGameName, "words", 1);
}

public jail_game_start(simon, game, gamename[])
{
  if(game == g_pMyNewGame)
  {
    word_game_on(simon);
    return PLUGIN_HANDLED;
  }

  return PLUGIN_CONTINUE;
}

public jail_game_end(simon, game, gamename[])
{
  if(game == g_pMyNewGame)
  {
    word_game_off(simon);
    return PLUGIN_HANDLED;
  }

  return PLUGIN_CONTINUE;
}

public word_game_on(id)
{
  server_event(id, g_szGameName, 0);
  jail_set_globalinfo(GI_GAME, g_pMyNewGame);
  jail_set_globalinfo(GI_NOFREEBIES, true);
  client_cmd(id, "messagemode jail_my_word");

  return PLUGIN_HANDLED;
}

public word_game_off(id)
{
  if(task_exists(TASK_WORDS))
    remove_task(TASK_WORDS);

  server_event(id == TASK_WORDS ? 0 : id, g_szGameName, 1);
  jail_set_globalinfo(GI_GAME, false);
  jail_set_globalinfo(GI_NOFREEBIES, false);
  g_szGamesWord[0] = '^0';
  RoundTimerSet(0, g_iTimeOnClock);
}

public pick_the_word(id)
{
  if(game_equal(g_pMyNewGame) && equal(g_szGamesWord, ""))
  {
    read_argv(1, g_szGamesWord, charsmax(g_szGamesWord));
    trim(g_szGamesWord);
    if(equal(g_szGamesWord, ""))
    {
      ColorChat(id, NORMAL, "%s %L", JAIL_TAG, LANG_SERVER, "JAIL_GAME2_ERROR");
      client_cmd(id, "messagemode jail_my_word");
      return PLUGIN_HANDLED;
    }

    g_iTimeOnClock = RoundTimerGet()-floatround(jail_get_roundtime());
    RoundTimerSet(0, get_pcvar_num(cvar_words_time));
    set_task(get_pcvar_float(cvar_words_time), "word_game_off", TASK_WORDS);
  }

  return PLUGIN_HANDLED;
}

public hook_say(id)
{
  if(game_equal(g_pMyNewGame) && cs_get_user_team(id) == CS_TEAM_T && is_user_alive(id) && !equal(g_szGamesWord, ""))
  {
    static words[192];
    read_args(words, charsmax(words));
    remove_quotes(words);

    if(equali(words, g_szGamesWord))
    {
      static name[32];
      get_user_name(id, name, charsmax(name));
      ColorChat(0, NORMAL, "%s %L", JAIL_TAG, LANG_SERVER, "JAIL_GAME2_WON", name, g_szGameName, words);
      word_game_off(id);
    }
    words[0] = '^0';
  }
}
