#include <amxmodx>
#include <sqlx>
#include <jailbreak>

#pragma defclasslib sqlite sqlite

enum _:DB_ACHIEV
{
  ACHIEVMENT_ID,
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

new g_szPlayerName[33][40], cvar_achievments;
new Handle:g_pSqlTuple;

public plugin_init()
{
  register_plugin("[JAIL] Achievments API", JAIL_VERSION, JAIL_AUTHOR);
  cvar_achievments = my_register_cvar("jail_achievments", "2"/*, "Stats 0/1/2 off/MySQL/Sqlite. (Default: 2)"*/);
  set_client_commands("achiev", "");
  RegisterHamPlayer(Ham_Killed, "Ham_Killed_post", 1);
}

public plugin_cfg()
  set_task(0.1, "delayed_plugin_cfg");

public delayed_plugin_cfg()
{
  MySQL_Init();
}

public plugin_natives()
{
  register_library("jailbreak");
  register_native("jail_achiev_register", "_achiev_register");
  register_native("jail_achiev_get_value", "_achiev_get_value");
  register_native("jail_achiev_set_value", "_achiev_set_value");
}

public plugin_end()
{
  if(g_pSqlTuple)
    SQL_FreeHandle(g_pSqlTuple);
}

public client_putinserver(id)
{
  reset_client(id);
  g_szPlayerName[id][0] = EOS;
  if(is_user_bot(id))
    return;

  get_user_name(id, g_szPlayerName[id], charsmax(g_szPlayerName[]));
  escape_mysql(g_szPlayerName[id], charsmax(g_szPlayerName[]));
  MySQL_Load(id);
}

public client_disconnect(id)
{
  MySQL_Save(id);
  reset_client(id);
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
    reset_client(id);
    g_szPlayerName[id] = newname;
    escape_mysql(g_szPlayerName[id], charsmax(g_szPlayerName[]));
    MySQL_Load(id);
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
  new code, Handle:connection = SQL_Connect(g_pSqlTuple, code, error, charsmax(error));
  if(connection == Empty_Handle)
    set_fail_state(error);

  new Handle:queries;
  if(cvar == 1)
  {
    queries = SQL_PrepareQuery(connection,
      "CREATE TABLE IF NOT EXISTS jail_achievments(\
        `id` int unsigned NOT NULL AUTO_INCREMENT, \
        `name` varchar(32) UNIQUE NOT NULL default '', \
        `description` varchar(128) UNIQUE NOT NULL default '', \
        `needed_count` int(10) NOT NULL DEFAULT '0', \
        `max_count` int(10) NOT NULL DEFAULT '0', \
        `icon` varchar(64) NOT NULL DEFAULT 'default', \
        PRIMARY KEY (`id`)\
      ), \
      CREATE TABLE IF NOT EXISTS jail_achievments_players(\
        `id` int unsigned NOT NULL AUTO_INCREMENT, \
        `nick_name` varchar(40) UNIQUE NOT NULL default '', \
        `play_time` int(10) NOT NULL, \
        `first_join` int(20) NOT NULL DEFAULT '0', \
        `last_join` int(20) NOT NULL DEFAULT '0', \
        `connects` int(6) NOT NULL DEFAULT '0', \
        PRIMARY KEY (`id`)\
      ), \
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
        `name` CHAR(32) UNIQUE NOT NULL DEFAULT '', \
        `description` CHAR(128) UNIQUE NOT NULL DEFAULT '', \
        `needed_count` INTEGER NOT NULL DEFAULT '0', \
        `max_count` INTEGER NOT NULL DEFAULT '0', \
        `icon` CHAR(64) NOT NULL DEFAULT 'default' \
      ), \
      CREATE TABLE IF NOT EXISTS jail_achievments_players(\
        `id` INTEGER PRIMARY KEY, \
        `nick_name` CHAR(40) UNIQUE NOT NULL DEFAULT '', \
        `play_time` INTEGER NOT NULL, \
        `first_join` INTEGER NOT NULL DEFAULT '0', \
        `last_join` INTEGER NOT NULL DEFAULT '0', \
        `connects` INTEGER NOT NULL DEFAULT '0' \
      ), \
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
