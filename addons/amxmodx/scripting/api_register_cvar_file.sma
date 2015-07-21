#include <amxmodx>
new Trie:g_tCvarsToFile, g_iTrieSize;
new cvar_file_name, g_szFileName[32];

public plugin_init()
{
  register_plugin("JailBreak Supreme", "1.0.0", "GuskiS");
  register_cvar("api_register_cvar_file", "1.0.0", FCVAR_SERVER|FCVAR_EXTDLL|FCVAR_SPONLY);

  cvar_file_name = register_cvar("api_rcf_file_name", "");
}

public plugin_natives()
{
  register_library("api_register_cvar_file");
  register_native("api_write_cvar_to_file",	"_write_cvar_to_file");
}

public plugin_cfg()
{
  TrieDestroy(g_tCvarsToFile);
  if(strlen(g_szFileName) > 5)
    auto_exec_config(g_szFileName, true);
}

public _write_cvar_to_file(plugin, params)
{
  if(params != 3)
    return 0;

  static name[48], string[16], pluginname[48], description[128];
  get_string(1, name, charsmax(name));
  get_string(2, string, charsmax(string));
  get_string(3, description, charsmax(description));
  get_plugin(plugin, pluginname, charsmax(pluginname));

  return write_cvar_to_file(name, string, description, pluginname);
}

stock write_cvar_to_file(name[], string[], description[], plug[])
{
  if(strlen(g_szFileName) < 5)
  {
    get_pcvar_string(cvar_file_name, g_szFileName, charsmax(g_szFileName));
    if(strlen(g_szFileName) < 5)
      return 0;
  }

  static path[96];
  if(!path[0])
  {
    get_localinfo("amxx_configsdir", path, charsmax(path));
    format(path, charsmax(path), "%s/%s", path, g_szFileName);
  }

  if(!g_tCvarsToFile)
    g_tCvarsToFile = TrieCreate();

  new file;
  if(!file_exists(path))
  {
    file = fopen(path, "wt");
    if(!file)
      return 0;
    fclose(file);
  }

  file = fopen(path, "rt");
  if(!file)
    return 0;

  if(!g_iTrieSize)
  {
    new newline[48];
    static line[128];
    while(!feof(file))
    {
      fgets(file, line, charsmax(line));
      if(line[0] == ';' || !line[0])
        continue;

      parse(line, newline, charsmax(newline));
      remove_quotes(newline);
      #if AMXX_VERSION_NUM >= 183
        TrieSetCell(g_tCvarsToFile, newline, 1, false);
      #else
        TrieSetCell(g_tCvarsToFile, newline, 1);
      #endif
      g_iTrieSize++;
    }
  }
  fclose(file);
  file = fopen(path, "at");

  if(!TrieKeyExists(g_tCvarsToFile, name))
  {
    fprintf(file, "%-32s %-8s // %-32s // %s^n", name, string, plug, description);
    #if AMXX_VERSION_NUM >= 183
      TrieSetCell(g_tCvarsToFile, name, 1, false);
    #else
      TrieSetCell(g_tCvarsToFile, name, 1);
    #endif
    g_iTrieSize++;
  }

  fclose(file);
  return 1;
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
