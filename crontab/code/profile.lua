--------------------------------------------------------------------------------
--- Lua-crontab exports profile
-- @module lua-crontab.code.profile
-- This file is a part of lua-crontab library
-- @copyright lua-crontab authors (see file `COPYRIGHT` for the license)
--------------------------------------------------------------------------------

local PROFILE = { }

--------------------------------------------------------------------------------

PROFILE.skip = setmetatable({ }, {
  __index = function(t, k)
    -- Excluding files outside of crontab/ and inside crontab/code
    local v = (not k:match("^crontab/")) or k:match("^crontab/code/")
    t[k] = v
    return v
  end;
})

--------------------------------------------------------------------------------

return PROFILE
