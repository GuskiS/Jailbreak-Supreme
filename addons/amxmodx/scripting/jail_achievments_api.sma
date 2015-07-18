#include <amxmodx>
#include <sqlx>
#include <jailbreak>

#pragma defclasslib sqlite sqlite

enum _:DB_ACHIEV
{
  ACHIEVMENT_ID,
  ACHIEVMENT_STATUS,
  ACHIEVMENT_NEEDED_COUNT,
  ACHIEVMENT_MAX_COUNT,
  ACHIEVMENT_NAME[32],
  ACHIEVMENT_DESCRIPTION[128]
}

enum _:DB_ACHIEV_PLAYERS
{
  PLAYER_ID,
  PLAYER_PLAY_TIME,
  PLAYER_FIRST_JOIN,
  PLAYER_LAST_JOIN,
  PLAYER_CONNECTS,
  PLAYER_NICK_NAME[40]
}

enum _:DB_ACHIEV_PROGRESS
{
  PROGRESS_ID,
  PROGRESS_ACHIEVMENT_ID,
  PROGRESS_PLAYER_ID,
  PROGRESS_CURRENT_COUNT,
  PROGRESS_FIRST_AT,
  PROGRESS_LAST_AT,
  PROGRESS_FINISHED_AT
}
#define ACHIEVMENT_COUNT 20
new g_szPlayerName[33][40], cvar_achievments;
new Handle:g_pSqlTuple;
new g_szAchievments[ACHIEVMENT_COUNT][DB_ACHIEV];
new g_szPlayers[32][DB_ACHIEV_PLAYERS];
new g_szProgress[32][ACHIEVMENT_COUNT][DB_ACHIEV_PROGRESS];

public plugin_init()
{
  register_plugin("[JAIL] Achievments API", JAIL_VERSION, JAIL_AUTHOR);
  cvar_achievments = register_cvar("jail_achievments", "2"/*, "Stats 0/1/2 off/MySQL/Sqlite. (Default: 2)"*/);
  // set_client_commands("achiev", "");
  // RegisterHamPlayer(Ham_Killed, "Ham_Killed_post", 1);
}

public plugin_cfg()
  set_task(0.1, "delayed_plugin_cfg");

public delayed_plugin_cfg()
{
  MySQL_Init();
  DB_AchievmentsLoad();
}

// public plugin_natives()
// {
//   register_library("jailbreak");
//   register_native("jail_achiev_register", "_achiev_register");
//   register_native("jail_achiev_get_value", "_achiev_get_value");
//   register_native("jail_achiev_set_value", "_achiev_set_value");
// }

public plugin_end()
{
  if(g_pSqlTuple)
    SQL_FreeHandle(g_pSqlTuple);
}

public client_putinserver(id)
{
  g_szPlayerName[id][0] = EOS;
  if(is_user_bot(id))
    return;

  get_user_name(id, g_szPlayerName[id], charsmax(g_szPlayerName[]));
  escape_mysql(g_szPlayerName[id], charsmax(g_szPlayerName[]));
  DB_PlayerLoad(id);
}

public client_disconnect(id)
{
  g_szPlayerName[id][0] = EOS;
}

public client_infochanged(id)
{
  if(!is_user_connected(id))
    return;

  static newname[40], oldname[32];
  get_user_name(id, oldname, charsmax(oldname));
  get_user_info(id, "name", newname, charsmax(newname));

  if(!equali(newname, oldname))
  {
    g_szPlayerName[id] = newname;
    escape_mysql(g_szPlayerName[id], charsmax(g_szPlayerName[]));
    DB_PlayerLoad(id);
  }
}

public MySQL_Init()
{
  new cvar = get_pcvar_num(cvar_achievments);
  if(cvar == 1)
  {
    new host[64], user[33], pass[32], db[32];
    get_cvar_string("amx_sql_host", host, charsmax(host));
    get_cvar_string("amx_sql_user", user, charsmax(user));
    get_cvar_string("amx_sql_pass", pass, charsmax(pass));
    get_cvar_string("amx_sql_db", db, charsmax(db));
    g_pSqlTuple = SQL_MakeDbTuple(host, user, pass, db);
  }
  else if(cvar == 2)
  {
    SQL_SetAffinity("sqlite");
    g_pSqlTuple = SQL_MakeDbTuple("localhost", "root", "", "jail_achievments");

  }
  else set_fail_state("[JailBreak] CVAR set wrongly, plugin turning off!");

  new error[128];
  new error_code, Handle:connection = SQL_Connect(g_pSqlTuple, error_code, error, charsmax(error));
  if(connection == Empty_Handle)
    set_fail_state(error);

  new Handle:queries;
  if(cvar == 1)
  {
    queries = SQL_PrepareQuery(connection,
      "CREATE TABLE IF NOT EXISTS jail_achievments(\
        `id` int unsigned NOT NULL AUTO_INCREMENT, \
        `status` int(1) NOT NULL DEFAULT '1', \
        `name` varchar(32) UNIQUE NOT NULL default '', \
        `description` varchar(128) UNIQUE NOT NULL default '', \
        `needed_count` int(10) NOT NULL DEFAULT '0', \
        `max_count` int(10) NOT NULL DEFAULT '0', \
        `value` int(10) NOT NULL DEFAULT '0', \
        `icon` varchar(64) NOT NULL DEFAULT 'default', \
        PRIMARY KEY (`id`)\
      ); \
      CREATE TABLE IF NOT EXISTS jail_achievments_players(\
        `id` int unsigned NOT NULL AUTO_INCREMENT, \
        `nick_name` varchar(40) UNIQUE NOT NULL default '', \
        `play_time` int(10) NOT NULL DEFAULT '0', \
        `first_join` int(20) NOT NULL DEFAULT '0', \
        `last_join` int(20) NOT NULL DEFAULT '0', \
        `connects` int(6) NOT NULL DEFAULT '0', \
        PRIMARY KEY (`id`)\
      ); \
      CREATE TABLE IF NOT EXISTS jail_achievments_progress(\
        `id` int unsigned NOT NULL AUTO_INCREMENT, \
        `achievment_id` int unsigned NOT NULL, \
        `player_id` int unsigned NOT NULL, \
        `current_count` int(10) NOT NULL, \
        `first_at` int(20) NOT NULL DEFAULT '0', \
        `last_at` int(20) NOT NULL DEFAULT '0', \
        `finished_at` int(20) NOT NULL DEFAULT '0', \
        PRIMARY KEY (`id`)\
      );"
    );
  }
  else if(cvar == 2)
  {
    queries = SQL_PrepareQuery(connection,
      "CREATE TABLE IF NOT EXISTS jail_achievments(\
        `id` INTEGER PRIMARY KEY, \
        `status` INTEGER NOT NULL DEFAULT '1', \
        `name` CHAR(32) UNIQUE NOT NULL DEFAULT '', \
        `description` CHAR(128) UNIQUE NOT NULL DEFAULT '', \
        `needed_count` INTEGER NOT NULL DEFAULT '0', \
        `max_count` INTEGER NOT NULL DEFAULT '0', \
        `value` INTEGER NOT NULL DEFAULT '0', \
        `icon` CHAR(64) NOT NULL DEFAULT 'default' \
      ); \
      CREATE TABLE IF NOT EXISTS jail_achievments_players(\
        `id` INTEGER PRIMARY KEY, \
        `nick_name` CHAR(40) UNIQUE NOT NULL DEFAULT '', \
        `play_time` INTEGER NOT NULL DEFAULT '0', \
        `first_join` INTEGER NOT NULL DEFAULT '0', \
        `last_join` INTEGER NOT NULL DEFAULT '0', \
        `connects` INTEGER NOT NULL DEFAULT '0' \
      ); \
      CREATE TABLE IF NOT EXISTS jail_achievments_progress(\
        `id` INTEGER PRIMARY KEY, \
        `achievment_id` INTEGER NOT NULL, \
        `player_id` INTEGER NOT NULL, \
        `current_count` INTEGER NOT NULL, \
        `first_at` INTEGER NOT NULL DEFAULT '0', \
        `last_at` INTEGER NOT NULL DEFAULT '0', \
        `finished_at` INTEGER NOT NULL DEFAULT '0' \
      );"
    );
  }

  if(!SQL_Execute(queries))
  {
    SQL_QueryError(queries, error, charsmax(error));
    set_fail_state(error);
  }

  SQL_FreeHandle(queries);
  SQL_FreeHandle(connection);
}

public DB_AchievmentsLoad()
{
  SQL_ThreadQuery(g_pSqlTuple, "DB_AchievmentsLoad_handle", "SELECT * FROM `jail_achievments`");
}

public DB_AchievmentsLoad_handle(fail_state, Handle:query, error[], error_code, data[], datasize)
{
  if(SQL_IsError(fail_state, error_code, error))
    return PLUGIN_HANDLED;

  new results = SQL_NumResults(query);
  if(results > 0)
  {
    new achiev_id = SQL_FieldNameToNum(query, "id");
    new status = SQL_FieldNameToNum(query, "status");
    new name = SQL_FieldNameToNum(query, "name");
    new description = SQL_FieldNameToNum(query, "description");
    new needed_count = SQL_FieldNameToNum(query, "needed_count");
    new max_count = SQL_FieldNameToNum(query, "max_count");

    for(new i = 0; i < results; i++)
    {
      g_szAchievments[i][ACHIEVMENT_ID] = SQL_ReadResult(query, achiev_id);
      g_szAchievments[i][ACHIEVMENT_STATUS] = SQL_ReadResult(query, status);
      g_szAchievments[i][ACHIEVMENT_NEEDED_COUNT] = SQL_ReadResult(query, needed_count);
      g_szAchievments[i][ACHIEVMENT_MAX_COUNT] = SQL_ReadResult(query, max_count);
      SQL_ReadResult(query, name, g_szAchievments[i][ACHIEVMENT_NAME], charsmax(g_szAchievments[][ACHIEVMENT_NAME]));
      SQL_ReadResult(query, description, g_szAchievments[i][ACHIEVMENT_DESCRIPTION], charsmax(g_szAchievments[][ACHIEVMENT_DESCRIPTION]));

      SQL_NextRow(query);
    }
  }

  SQL_FreeHandle(query);
  return PLUGIN_HANDLED;
}

public DB_PlayerLoad(id)
{
  new query[128], user_id[1];
  user_id[0] = id;

  formatex(query, charsmax(query), "SELECT * FROM `jail_achievments_players` WHERE `nick_name` = '%s'", g_szPlayerName[id]);
  SQL_ThreadQuery(g_pSqlTuple, "DB_PlayerLoad_handle", query, user_id, sizeof(user_id));
}

public DB_PlayerLoad_handle(fail_state, Handle:query, error[], error_code, data[], datasize)
{
  if(SQL_IsError(fail_state, error_code, error))
    return PLUGIN_HANDLED;

  new id = data[0];
  if(!is_user_connected(id))
    return PLUGIN_HANDLED;

  new sys_time = get_systime(0), results = SQL_NumResults(query);
  if(!results)
  {
    SQL_QueryMe("INSERT INTO `jail_achievments_players` (`nick_name`, `first_join`, `last_join`, `connects`) \
      VALUES (^"%s^", '%d', '%d', '1')",	g_szPlayerName[id], sys_time, sys_time);

    SQL_FreeHandle(query);
    return PLUGIN_HANDLED;
  }
  else if(results > 0)
  {
    new player_id = SQL_FieldNameToNum(query, "id");
    new nick_name = SQL_FieldNameToNum(query, "nick_name");
    new play_time = SQL_FieldNameToNum(query, "play_time");
    new first_join = SQL_FieldNameToNum(query, "first_join");
    new last_join = SQL_FieldNameToNum(query, "last_join");
    new connects = SQL_FieldNameToNum(query, "connects");

    g_szPlayers[id][PLAYER_ID] = SQL_ReadResult(query, player_id);
    g_szPlayers[id][PLAYER_PLAY_TIME] = SQL_ReadResult(query, play_time);
    g_szPlayers[id][PLAYER_FIRST_JOIN] = SQL_ReadResult(query, first_join);
    g_szPlayers[id][PLAYER_LAST_JOIN] = SQL_ReadResult(query, last_join);
    g_szPlayers[id][PLAYER_CONNECTS] = SQL_ReadResult(query, connects);
    SQL_ReadResult(query, nick_name, g_szPlayers[id][PLAYER_NICK_NAME], charsmax(g_szPlayers[][PLAYER_NICK_NAME]));
  }

  SQL_QueryMe("UPDATE `jail_achievments_players` SET `last_join` = '%d', `connects` = `connects`+1 WHERE `id` = '%d'",
    sys_time, g_szPlayers[id][PLAYER_ID]);

  SQL_FreeHandle(query);
  return PLUGIN_HANDLED;
}

public DB_ProgressLoad(id)
{
  new query[128], user_id[1];
  user_id[0] = id;

  formatex(query, charsmax(query), "SELECT * FROM `jail_achievments_progress` WHERE `player_id` = '%d'", g_szPlayers[id][PLAYER_ID]);
  SQL_ThreadQuery(g_pSqlTuple, "DB_ProgressLoad_handle", query, user_id, sizeof(user_id));
}

public DB_ProgressLoad_handle(fail_state, Handle:query, error[], error_code, data[], datasize)
{
  if(SQL_IsError(fail_state, error_code, error))
    return PLUGIN_HANDLED;

  new id = data[0];
  if(!is_user_connected(id))
    return PLUGIN_HANDLED;

  new results = SQL_NumResults(query);
  if(results > 0)
  {
    new achiev;
    new achievment_id = SQL_FieldNameToNum(query, "achievment_id");
    for(new j, i = 0; i < results; i++)
    {
      achiev = SQL_ReadResult(query, achievment_id);
      for(j = 0; j < DB_ACHIEV_PROGRESS; j++)
        g_szProgress[id][achiev][j] = SQL_ReadResult(query, j);

      SQL_NextRow(query);
    }
  }

  SQL_FreeHandle(query);
  return PLUGIN_HANDLED;
}

public DB_Empty_handle(fail_state, Handle:query, error[], error_code, data[], datasize)
{
  SQL_IsError(fail_state, error_code, error);
}

stock SQL_QueryMe(query[], any:...)
{
  static message[256];
  vformat(message, charsmax(message), query, 2);

  SQL_ThreadQuery(g_pSqlTuple, "DB_Empty_handle", message);
}

stock SQL_IsError(fail_state, error_code, error[])
{
  if(fail_state == TQUERY_CONNECT_FAILED)
  {
    log_amx("[JailBreak] Could not connect to SQL database: %s", error);
    return true;
  }
  else if(fail_state == TQUERY_QUERY_FAILED)
  {
    log_amx("[JailBreak] Query failed: %s", error);
    return true;
  }
  else if(error_code)
  {
    log_amx("[JailBreak] Error on query: %s", error);
    return true;
  }

  return false;
}
