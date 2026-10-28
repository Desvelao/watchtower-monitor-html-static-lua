# Dev image: same base as docker/images/prod/Dockerfile, with the same
# xml/webscraper install baked in (see that file's own comments for why),
# but without src/ or the default config baked in - dev/docker-compose.yml
# bind-mounts ../src over /worker_plugins/watchtower_observer_web_scraper
# for live editing instead of COPYing it here.
FROM ghcr.io/desvelao/watchtower-worker:0.1.0-alpha2

USER root

COPY docker/rockspecs/xml-1.1.3-1.rockspec /tmp/xml-1.1.3-1.rockspec
RUN git clone --branch REL-1.1.3 --depth 1 https://github.com/lubyk/xml /tmp/xml_lua \
    && cp /tmp/xml-1.1.3-1.rockspec /tmp/xml_lua/xml-1.1.3-1.rockspec \
    && luarocks-5.1 install /tmp/xml_lua/xml-1.1.3-1.rockspec \
    && rm -rf /tmp/xml_lua /tmp/xml-1.1.3-1.rockspec

COPY docker/rockspecs/watchtower-observer-web-scraper-deps-1.0-1.rockspec /tmp/watchtower-observer-web-scraper-deps-1.0-1.rockspec
RUN luarocks-5.1 install --only-deps /tmp/watchtower-observer-web-scraper-deps-1.0-1.rockspec \
    && rm -f /tmp/watchtower-observer-web-scraper-deps-1.0-1.rockspec

USER watchtower
