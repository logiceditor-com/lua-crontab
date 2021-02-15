--------------------------------------------------------------------------------
-- config.lua: list-exports configuration
-- This file is a part of lua-crontab library
-- Copyright (c) lua-crontab authors (see file `COPYRIGHT` for the license)
--------------------------------------------------------------------------------
-- Note that PROJECT_PATH is defined in the environment
--------------------------------------------------------------------------------

common =
{
  PROJECT_PATH = PROJECT_PATH;

  exports =
  {
    exports_dir = PROJECT_PATH .. "/crontab/code/";
    profiles_dir = PROJECT_PATH .. "/crontab/code/";

    sources =
    {
      {
        sources_dir = PROJECT_PATH;
        root_dir_only = "crontab/";
        lib_name = "lua-crontab";
        profile_filename = "profile.lua";
        out_filename = "exports.lua";
        file_header = [[
-- This file is a part of lua-crontab library
-- See file `COPYRIGHT` for the license and copyright information
]]
      };
    };
  };
}

--------------------------------------------------------------------------------

list_exports =
{
  action =
  {
    name = "help";
    param =
    {
      -- No parameters
    };
  };
};
