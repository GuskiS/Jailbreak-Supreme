#include <amxmodx>
#include <hamsandwich>
#include <cstrike>
#include <sqlx>
#include <jailbreak>

#pragma defclasslib sqlite sqlite
new Handle:g_pSqlTuple;
new g_szUserIP[33][20];
new g_szUserName[33][40];
new g_iUserBlocked[33];
new cvar_block_ct;

public plugin_init()
{
  register_plugin("[JAIL] Block CT", JAIL_VERSION, JAIL_AUTHOR);

  cvar_block_ct = register_cvar("jail_block_ct", "2"/*, "AntiRetry 0/1/2 off/MySQL/Sqlite. (Default: 2)"*/);
  set_client_commands("block", "cmd_show_block");
  RegisterHamPlayer(Ham_Spawn, "Ham_Spawn_pre", 0);
}

public Ham_Spawn_pre(id)
{
  if(is_user_connected(id) && g_iUserBlocked[id] && cs_get_user_team(id) == CS_TEAM_CT)
  {
    client_print_color(id, print_team_default, "%s %L", JAIL_TAG, id, "JAIL_YOUHAVEBEENBLOCKED");
    cs_set_user_team(id, CS_TEAM_T);
  }
}

public cmd_show_block(id)
{
  if(is_user_connected(id) && is_jail_admin(id))
  {
    static option[64], data[3];
    formatex(option, charsmax(option), "%L", id, "JAIL_MENUMENU");
    new menu = menu_create(option, "show_block_handle");

    new num, i;
    static players[32];
    get_players(players, num);

    for(--num; num >= 0; num--)
    {
      i = players[num];
      get_user_name(i, option, charsmax(option));
      format(option, charsmax(option), "%L %s", id, g_iUserBlocked[i] ? "JAIL_UNBLOCK_CT" : "JAIL_BLOCK_CT", option);
      num_to_str(i, data, charsmax(data));
      menu_additem(menu, option, data, 0);
    }

    menu_display(id, menu);
  }
}

public show_block_handle(id, menu, item)
{
  if(item == MENU_EXIT || !is_user_connected(id) || !is_jail_admin(id))
  {
    menu_destroy(menu);
    return PLUGIN_HANDLED;
  }

  new access, callback, num[3];
  menu_item_getinfo(menu, item, access, num, charsmax(num), _, _, callback);
  menu_destroy(menu);

  new user_id = str_to_num(num);
  if(g_iUserBlocked[user_id])
  {
    client_print_color(0, print_team_default, "%s %L", JAIL_TAG, LANG_SERVER, "JAIL_UNBLOCKED", g_szUserName[id], g_szUserName[user_id]);
    DB_BlocksRemove(user_id);
  }
  else
  {
    client_print_color(0, print_team_default, "%s %L", JAIL_TAG, LANG_SERVER, "JAIL_BLOCKED", g_szUserName[id], g_szUserName[user_id]);
    DB_BlocksSave(id, user_id);
  }

  return PLUGIN_HANDLED;
}

public plugin_cfg()
  set_task(0.1, "DB_Init");

public plugin_end()
{
  if(g_pSqlTuple)
    SQL_FreeHandle(g_pSqlTuple);
}

public client_putinserver(id)
{
  g_szUserIP[id][0] = EOS;
  g_szUserName[id][0] = EOS;
  g_iUserBlocked[id] = false;
  if(is_user_bot(id))
    return;

  get_user_ip(id, g_szUserIP[id], charsmax(g_szUserIP[]), 1);
  get_user_name(id, g_szUserName[id], charsmax(g_szUserName[]));
  escape_mysql(g_szUserName[id], charsmax(g_szUserName[]));
  DB_BlocksLoad(id);
}

public DB_Init()
{
  new cvar = get_pcvar_num(cvar_block_ct);
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
    g_pSqlTuple = SQL_MakeDbTuple("localhost", "root", "", "jailbreak_supreme");

  }
  else set_fail_state("[JAIL] CVAR set wrongly, plugin turning off!");

  new error[128];
  new code, Handle:connection = SQL_Connect(g_pSqlTuple, code, error, charsmax(error));
  if(connection == Empty_Handle)
    set_fail_state(error);

  new Handle:queries;
  if(cvar == 1)
  {
    queries = SQL_PrepareQuery(connection,
      "CREATE TABLE IF NOT EXISTS jail_block_ct(\
        id int unsigned NOT NULL AUTO_INCREMENT, \
        ip varchar(20) NOT NULL default '', \
        name varchar(40) NOT NULL default '', \
        by_admin varchar(40) NOT NULL default '', \
        blocked_at int(20) NOT NULL default '', \
        PRIMARY KEY (id)\
      );"
    );
  }
  else if(cvar == 2)
  {
    queries = SQL_PrepareQuery(connection,
      "CREATE TABLE IF NOT EXISTS jail_block_ct(\
        id INTEGER PRIMARY KEY, \
        ip CHAR(20) UNIQUE NOT NULL DEFAULT '', \
        name CHAR(40) NOT NULL DEFAULT '', \
        by_admin CHAR(40) NOT NULL DEFAULT '', \
        blocked_at INTEGER NOT NULL DEFAULT '' \
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

public DB_BlocksLoad(id)
{
  SQL_QueryMeWithHandle(id, "DB_BlocksLoad_handle", "SELECT * FROM `jail_block_ct` WHERE ip = ^"%s^" OR name = ^"%s^";",
    g_szUserIP[id], g_szUserName[id]);
}

public DB_BlocksSave(admin_id, id)
{
  SQL_QueryMeWithHandle(id, "DB_BlocksLoad_handle",
    "INSERT INTO `jail_block_ct` (`ip`, `name`, `by_admin`, `blocked_at`) VALUES (^"%s^", ^"%s^", ^"%s^", '%d'); \
    SELECT * FROM `jail_block_ct` WHERE ip = ^"%s^" OR name = ^"%s^";",
    g_szUserIP[id], g_szUserName[id], g_szUserName[admin_id], get_systime(0), g_szUserIP[id], g_szUserName[id]);
}

public DB_BlocksRemove(id)
{
  SQL_QueryMeWithHandle(id, "DB_BlocksLoad_handle", "DELETE FROM `jail_block_ct` WHERE ip = ^"%s^" OR name = ^"%s^";",
    g_szUserIP[id], g_szUserName[id]);
}

public DB_BlocksLoad_handle(fail_state, Handle:query, error[], error_code, data[], datasize)
{
  if(SQL_IsError(fail_state, error_code, error))
  {
    SQL_FreeHandle(query);
    return PLUGIN_HANDLED;
  }

  new id = data[0];
  if(!is_user_connected(id))
  {
    SQL_FreeHandle(query);
    return PLUGIN_HANDLED;
  }

  if(SQL_NumResults(query) > 0)
    g_iUserBlocked[id] = true;
  else g_iUserBlocked[id] = false;

  SQL_FreeHandle(query);
  return PLUGIN_HANDLED;
}

stock SQL_QueryMeWithHandle(id, handle[], query[], any:...)
{
  static message[300];
  vformat(message, charsmax(message), query, 4);
  new array[1];
  array[0] = id;

  SQL_ThreadQuery(g_pSqlTuple, handle, message, array, sizeof(array));
}
