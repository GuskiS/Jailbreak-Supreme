#if defined _api_register_cvar_file_included
  #endinput
#endif
#define _api_register_cvar_file_included

#if AMXX_VERSION_NUM >= 175
  #pragma reqlib api_register_cvar_file
  #if !defined AMXMODX_NOAUTOLOAD
    #pragma loadlib api_register_cvar_file
  #endif
#else
  #pragma library api_register_cvar_file
#endif

/**
 * Write cvar information to file.
 *
 * @param name[]				CVAR name.
 * @param string[]			CVAR value as string.
 * @param desc[]				CVAR description.
 * @return						  true/false.
 */
native api_write_cvar_to_file(name[], string[], desc[]);

// Stock to write and register CVAR.
stock register_cvar_file(name[], string[], desc[], flags = 0, Float:fvalue = 0.0)
{
  api_write_cvar_to_file(name, string, desc);
  return register_cvar(name, string, flags, fvalue);
}
