-- Patched build recipe for the `xml` rock (webscraper's own dependency) -
-- upstream's own published rockspec doesn't build cleanly under luarocks
-- 3.x, and its `source` has no `tag`, so a plain `luarocks install xml
-- 1.1.3-1` would clone the repo's default branch rather than the REL-1.1.3
-- release this pins to. See docker/images/{dev,prod}/Dockerfile: they clone
-- REL-1.1.3 manually, overwrite the checkout's own rockspec with this file,
-- then install from that local path - this file is never installed
-- directly from a rocks server.
--
-- Originally lived in watchtower-server's own
-- server/plugins/observer_configs/xml.rockspec (removed there once this
-- plugin - webscraper's only consumer - moved to this repo); copied here
-- verbatim.
package = "xml"
version = "1.1.3-1"
source = {
  url = 'git://github.com/lubyk/xml',
  dir = 'xml',
}
description = {
  summary = "Very fast xml parser based on RapidXML",
  detailed = [[
    This module is part of the Lubyk project.

    Main features are:
     - Fast and easy to use
     - Complete documentation
     - Based on proven code (RapidXML)
     - Full test coverage

    Read the documentation at http://doc.lubyk.org/xml.html.
  ]],
  homepage = "http://doc.lubyk.org/xml.html",
  license = "MIT"
}

dependencies = {
  "lua >= 5.1, < 5.4",
  "lub >= 1.0.3, < 2",
}
build = {
  type = 'builtin',
  modules = {
    -- Plain Lua files
    ['xml'            ] = 'xml/init.lua',
    ['xml.Parser'     ] = 'xml/Parser.lua',
    -- C module
    ['xml.core'       ] = {
      sources = {
        'src/Parser.cpp',
        'src/bind/dub/dub.cpp',
        'src/bind/xml_Parser.cpp',
        'src/bind/xml_core.cpp',
      },
      incdirs   = {'include', 'src/bind', 'src/vendor'},
    },
  },
  platforms = {
    freebsd = {
      modules = {
        ['xml.core'] = {
          sources = {
          },
          libraries = {'c++'},
        },
      },
    },
    linux = {
      modules = {
        ['xml.core'] = {
          sources = {
          },
          libraries = {'stdc++'},
        },
      },
    },
    macosx = {
      modules = {
        ['xml.core'] = {
          sources = {
          },
          libraries = {'stdc++'},
        },
      },
    },
  },
}
