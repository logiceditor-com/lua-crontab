package = "lua-crontab"
version = "scm-1"
source = {
   url = "git://github.com/logiceditor-com/lua-crontab.git",
   branch = "master"
}
description = {
   summary = "stores crons, determines next occurrence of cron",
   homepage = "http://github.com/logiceditor-com/lua-crontab",
   license = "MIT/X11",
   maintainer = "LogicEditor Team <team@logiceditor.com>"
}
dependencies = {
   "lua-nucleo >= 1.1.0",
}
build = {
   type = "none",
   install = {
      lua = {
         ["crontab.code.profile"] = "crontab/code/profile.lua";
         ["lua-crontab"] = "crontab/crontab.lua";
      }
   }
}
