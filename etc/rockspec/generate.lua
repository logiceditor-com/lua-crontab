--------------------------------------------------------------------------------
-- rockspec/generate.lua: lua-crontab dumb rockspec generator
-- This file is a part of lua-crontab library
-- Copyright (c) lua-crontab authors (see file `COPYRIGHT` for the license)
--------------------------------------------------------------------------------

pcall(require, 'luarocks.require') -- Ignoring errors

local lfs = require 'lfs'

-- From lua-aplicado.
local function find_all_files(path, regexp, dest, mode)
  dest = dest or {}
  mode = mode or false

  assert(mode ~= "directory")

  for filename in lfs.dir(path) do
    if filename ~= "." and filename ~= ".." then
      local filepath = path .. "/" .. filename
      local attr = lfs.attributes(filepath)
      if attr.mode == "directory" then
        find_all_files(filepath, regexp, dest)
      elseif not mode or attr.mode == mode then
        if filename:find(regexp) then
          dest[#dest + 1] = filepath
        end
      end
    end
  end

  return dest
end

local files = find_all_files("crontab", "^.*%.lua$")
table.sort(files)

local version = select(1, ...) or "scm-1"
local branch = select(2, ...) or "master"

io.stdout:write([[
package = "lua-crontab"
version = "]] .. version .. [["
source = {
   url = "git://github.com/logiceditor-com/lua-crontab.git",
   branch = "]] .. branch .. [["
}
description = {
   summary = "stores crons, determines next occurrence of cron",
   homepage = "http://github.com/logiceditor-com/lua-crontab",
   license = "MIT/X11"
}
dependencies = {
   "lua-nucleo >= 1.1.0",
}
build = {
   type = "none",
   install = {
      lua = {
]])

for i = 1, #files do
  local name = files[i]
  io.stdout:write([[
         []] .. (
          ("%q"):format(
              name:gsub("/", "."):gsub("\\", "."):gsub("%.lua$", "")
            )
        ) .. [[] = ]] .. (("%q"):format(name)) .. [[;
]])
end

io.stdout:write([[
      }
   }
}
]])
io.stdout:flush()
