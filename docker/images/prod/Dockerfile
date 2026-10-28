# Ships the watchtower_observer_web_scraper plugin baked into the published
# watchtower-server standalone worker image - see
# https://github.com/Desvelao/watchtower-server/blob/main/docker/images/prod/worker/Dockerfile
# for what that base image already provides: Lua 5.1 + LuaRocks,
# `lua-cjson`, `luasec`, `luasocket`, `pling`, watchtower-server's own
# `shared/` (including watchtower_worker_core, this plugin's own runtime
# dependency) baked in at /shared, and LUA_PATH already covering both
# /shared and /worker_plugins. It does NOT include `webscraper`/`xml` - this
# plugin is their only consumer, so installing them is this image's own
# responsibility (see below).
FROM ghcr.io/desvelao/watchtower-worker:0.1.0-alpha2

# The base image already dropped to its own unprivileged `watchtower` user;
# RUN (unlike COPY) executes as whatever USER is currently active, so
# installing anything with luarocks-5.1 below needs root back temporarily.
USER root

# xml (webscraper's own dependency) doesn't build cleanly under luarocks 3.x
# from its own published rockspec, and that rockspec's `source` has no
# `tag`, so installing it directly would clone the repo's default branch
# rather than this pinned release - clone REL-1.1.3 manually, drop in the
# patched rockspec, then install from that local checkout. Same recipe
# watchtower-server used before this plugin (webscraper's only consumer)
# moved to this repo - see docker/rockspecs/xml-1.1.3-1.rockspec's own
# header. No `apk add` needed for git/build tools - the base image already
# retains them (gcc/build-base/git/zlib-dev, confirmed not stripped by its
# own `apk del .build-deps`).
COPY docker/rockspecs/xml-1.1.3-1.rockspec /tmp/xml-1.1.3-1.rockspec
RUN git clone --branch REL-1.1.3 --depth 1 https://github.com/lubyk/xml /tmp/xml_lua \
    && cp /tmp/xml-1.1.3-1.rockspec /tmp/xml_lua/xml-1.1.3-1.rockspec \
    && luarocks-5.1 install /tmp/xml_lua/xml-1.1.3-1.rockspec \
    && rm -rf /tmp/xml_lua /tmp/xml-1.1.3-1.rockspec

# Pinned webscraper version - see
# docker/rockspecs/watchtower-observer-web-scraper-deps-1.0-1.rockspec.
COPY docker/rockspecs/watchtower-observer-web-scraper-deps-1.0-1.rockspec /tmp/watchtower-observer-web-scraper-deps-1.0-1.rockspec
RUN luarocks-5.1 install --only-deps /tmp/watchtower-observer-web-scraper-deps-1.0-1.rockspec \
    && rm -f /tmp/watchtower-observer-web-scraper-deps-1.0-1.rockspec

# src/ is this plugin's own package root (module paths resolve as
# watchtower_observer_web_scraper.*) - copied onto the base image's
# /worker_plugins mount point, the same directory a bind mount would use for
# local iteration (see dev/docker-compose.yml), just baked in instead.
COPY --chown=watchtower:watchtower src/ /worker_plugins/watchtower_observer_web_scraper/

# A runnable-out-of-the-box default WORKER_CONFIG_FILE (enables this plugin,
# one "web_scraper" observer entry) - override by mounting your own file over
# this path, or by pointing WORKER_CONFIG_FILE at a different mounted path;
# both are the base image's own, unmodified mechanisms.
COPY --chown=watchtower:watchtower docker/images/prod/worker_config.default.lua /app/worker_config.default.lua

ENV WORKER_CONFIG_FILE=/app/worker_config.default.lua

# Drop back to the base image's own unprivileged user for runtime.
USER watchtower

# WORKDIR/ENTRYPOINT are inherited unchanged from the base image.
