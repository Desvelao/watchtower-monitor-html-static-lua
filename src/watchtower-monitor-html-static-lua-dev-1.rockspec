package = "watchtower-monitor-html-static-lua"
version = "dev-1"
source = {
   url = "*** please add URL for source tarball, zip or repository here ***"
}
description = {
   detailed = [[
Scrap the products prices
]],
   homepage = "*** please enter a project homepage ***",
   license = "MIT"
}
dependencies = {
   "lua >= 5.1, < 5.2",
   "lua-requests == 1.2",
   "lua-csv == 1.1",
   "htmlparser == 0.3.9",
   "dkjson == 2.8-1",
   "busted == 2.2.0",
   "luastash == 0.2.0-1",
   "webscraper == 0.1.0",
}
build = {
   type = "builtin",
   modules = {
      script = "script.lua"
   }
}

