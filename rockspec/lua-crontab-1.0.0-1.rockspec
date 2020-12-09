package = "lua-crontab"
version = "1.0.0-1"
source = {
   url = "" -- TODO
}
description = {
   summary = "The Crontab",
   homepage = "http://logiceditor.com",
   license = "MIT/X11",
   maintainer = "LogicEditor Team <team@logiceditor.com>"
}
dependencies = {
   "lua-nucleo >= 1.1.0",
}
build = {
   type = "builtin",
   modules = {
      ["lua-crontab"] = "crontab/crontab.lua";
   }
}
