-- Pinned third-party LuaRocks dependency for this repo's own Docker images
-- (docker/images/dev/Dockerfile, docker/images/prod/Dockerfile) - installed
-- with `luarocks-5.1 install --only-deps <this file>`, same "pinned deps,
-- no-op build" shape watchtower-server's own
-- docker/rockspecs/watchtower-worker-deps-1.0-1.rockspec uses for its base
-- worker image. This is a separate package (build = {type = "none"}) purely
-- so `--only-deps` installs exactly the version pinned below and nothing
-- else - `xml` (webscraper's own transitive dependency) is installed
-- separately first, from docker/rockspecs/xml-1.1.3-1.rockspec, since it
-- needs a patched build recipe rather than a plain version pin.
package = "watchtower-observer-web-scraper-deps"
version = "1.0-1"

source = {
  url = "git+https://github.com/Desvelao/watchtower-monitor-html-static-lua",
}

description = {
  summary = "Pinned LuaRocks dependency (webscraper) for this repo's own Docker images.",
  homepage = "https://github.com/Desvelao/watchtower-monitor-html-static-lua",
  license = "MIT",
}

dependencies = {
  "lua >= 5.1, < 5.4",
  -- Must match src/watchtower-observer-web-scraper-0.1.0-1.rockspec's own
  -- dependency pin. Needs `xml` (see docker/rockspecs/xml-1.1.3-1.rockspec)
  -- already installed first - see that file's own header comment.
  "webscraper == 0.2.0-1",
}

build = {
  type = "none",
}
