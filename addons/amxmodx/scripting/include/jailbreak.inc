#if defined _jail_included
  #endinput
#endif
#define _jail_included

#include <jailbreak_const>

#if AMXX_VERSION_NUM >= 175
    #pragma reqlib jailbreak
    #if !defined AMXMODX_NOAUTOLOAD
        #pragma loadlib jailbreak
    #endif
#else
    #pragma library jailbreak
#endif

/**
 * Sets/gets players data.
 *
 * @param id					player index.
 * @param pd					enum PLAYERDATA.
 * @param value				new value.
 * @return						playerdata.
 */
native jail_get_playerdata(id, pd);
native jail_set_playerdata(id, pd, value);

/**
 * Sets/gets globals.
 *
 * @param gi					enum GLOBALINFO.
 * @param value				new value.
 * @return						globalinfo.
 */
native jail_get_globalinfo(gi);
native jail_set_globalinfo(gi, value);

/**
 * Sets/gets game mode.
 *
 * @param value				sets new game mode.
 * @return						game mode.
 */
native jail_get_gamemode();
native jail_set_gamemode(value);

/**
 * Sets/gets winner.
 *
 * @param value				sets new winner.
 * @return						winner.
 */
native jail_get_winner();
native jail_set_winner(value);

/**
 * Gets roundtime.
 *
 * @return						roundtime.
 */
native Float:jail_get_roundtime();

/**
 * Adds/updates day to Days menu and returns id.
 *
 * @param day					Day id.
 * @param dayname[]		Day name.
 * @param command[]		Day command.
 * @param available		Day available? (for conditioning 1/0)
 * @return						Day id.
 */
native jail_day_add(dayname[], command[], available);
native jail_day_update(day, dayname[], command[], available);
native jail_day_forceend(day);

/**
 * Starts day by it's id/name.
 *
 * @param id					Player id.
 * @param dayid				Day id to start.
 * @param dayname[]		Day name to start.
 * @param prepost			Pre/Post 0/1
 * @return						Day id.
 */
native jail_day_byid(id, dayid, prepost);
native jail_day_byname(id, dayname[], prepost);

/**
 * Gets days name.
 *
 * @param day					Day id.
 * @param dayname[]		Day name.
 * @return						dayname[]/dayid.
 */
native jail_day_getid(dayname[]);
native jail_day_getname(day, dayname[]);

/**
 * Adds/updates game to Games menu and returns id.
 *
 * @param game				Game id.
 * @param gamename[]	Game name.
 * @param command[]		Game command.
 * @param available		Game available? (for conditioning 1/0)
 * @return						Game id.
 */
native jail_game_add(gamename[], command[], available);
native jail_game_update(game, gamename[], command[], available);
native jail_game_forceend(game);

/**
 * Starts game by it's name/id.
 *
 * @param id					Player id.
 * @param game				Game id to start.
 * @param gamename[]	Game name to start.
 * @param prepost			Pre/Post 0/1
 * @return						Game id.
 */
native jail_game_byid(id, game, prepost);
native jail_game_byname(id, gamename[], prepost);

/**
 * Gets game name/id.
 *
 * @param game				Game id.
 * @param gamename[]	Game name.
 * @return						gamename[]/gameid.
 */
native jail_game_getid(gamename[]);
native jail_game_getname(game, gamename[]);

/**
 * Sets player crowbar status.
 *
 * @param id					Players id.
 * @param value				True/False
 * @return						value.
 */
native jail_player_crowbar(id, value);

/**
 * Sets player freeday status.
 *
 * @param id					Players id.
 * @param value				True/False
 * @param print				If value, then True/False
 * @return						True.
 */
native jail_player_freebie(id, value, print);

/**
 * Enables/disables hams for PD_HAMBLOCK playerdata.
 *
 * @param value				0/1 to disable/enable all ham blocks.
 * @return						true/false.
 */
native jail_ham_all(value);

/**
 * Enables/disables hams for PD_HAMBLOCK playerdata.
 *
 * @param ham[]				Array of values.
 * @return						true/false.
 */
native jail_ham_specific(ham[]);

/**
 * Opens/close cell doors.
 * @param id					Players id.
 * @param value				TS_CLOSED/TS_OPENED
 */
native jail_celldoors(id, value);

/**
 * Adds duel to Duel menu and returns id.
 *
 * @param duelname[]	Duel name.
 * @return						Duel id.
 */
native jail_duel_add(duelname[]);

/**
 * Adds duel to Duel menu and returns id.
 *
 * @return						Nothing.
 */
native jail_duel_lastrequest();

/**
 * Asks freebies to join day/game.
 *
 * @param event				Day/game id.
 * @param type				GI_DAY/GI_GAME.
 * @return						True/False.
 */
native jail_ask_freebie(event, type);

/**
 * Register achievement.
 *
 * @param name[]			Achievment name.
 * @param desc[]			Achievment description.
 * @param value				Achievment value.
 * @param needed			Achievment needed to complete.
 * @param max					Achievment maximum.
 * @return						True/False.
 */
native jail_achiev_register(name[], desc[], value, needed, max = 0);

/**
 * Register progress.
 *
 * @param id					User game id.
 * @param name[]			Achievment name.
 * @param progress		New progress value.
 * @return						True/False.
 */
native jail_achiev_get_progress(id, name[]);
native jail_achiev_set_progress(id, name[], progress);

/**
 * Register cvar to file.
 *
 * @param name[]			Cvar name.
 * @param string[]		Cvar value.
 * @param desc[]			Cvar description.
 * @return						true/false.
 */
native jail_register_cvar(name[], string[], desc[]);

/**
 * Called when game mode changes.
 *
 * @param mode				game mode.
 */
forward jail_gamemode(mode);

/**
 * Called when winner is set.
 *
 * @param winner			winner.
 */
forward jail_winner(winner);

/**
 * Called when day is started/ended.
 *
 * @param simon				Simons id.
 * @param day					Day id.
 * @param dayname[]		Day name.
 */
forward jail_day_start(simon, day, dayname[]);
forward jail_day_end(simon, day, dayname[]);

/**
 * Called when game is started/ended.
 *
 * @param simon				Simons id.
 * @param game				Game id.
 * @param gamename[]	Game name.
 */
forward jail_game_start(simon, game, gamename[]);
forward jail_game_end(simon, game, gamename[]);

/**
 * Called when game/day is called from chat.
 *
 * @param id					Player id.
 * @param command[]		Command name. ("fd")
 */
forward jail_day_command(id, command[]);
forward jail_game_command(id, command[]);

/**
 * Called when game is started/ended.
 *
 * @param simon				Simons id.
 * @param duel				Duel id.
 * @param AID					Duelist id.
 * @param BID					Duelist id.
 */
forward jail_duel_start(simon, duel, AID, BID);
forward jail_duel_end(simon, duel, AID, BID);

/**
 * Called when game is started/ended.
 *
 * @param id					Freebies id.
 * @param event				Day/game id.
 * @param type				GI_DAY/GI_GAME.
 */
forward jail_freebie_join(id, event, type);

/**
 * Called when achivements can be registered.
 */
forward jail_achivements_load();

/**
 * Called when achivements has been achieved.
 *
 * @param id					Player id.
 * @param name[]			Achievment name.
 * @param finished		Did player finish it? (true/false)
 * @param current			Current achieved count.
 * @param needed			Needed achievment count.
 */
forward jail_achivements_progress(id, name[], finished, current, needed);

#include <jailbreak_stocks>
