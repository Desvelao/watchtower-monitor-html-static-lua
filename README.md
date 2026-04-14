# Description

Watchtower monitor worker.

# Requirements

- Lua 5.1
- Luarocks

Install from .rockspec:

```console
cd src
luarocks install --only-deps watchtower-monitor-html-static-lua-*.rockspec
```

# Pipeline configuration

Refer to [pipeline configuration](./docs/config.md).

# Production

## Docker run

1. Copy the `prod/data/config.json.example` to `config.json` and edit it:
```console
cp prod/data/config.json.example config.json
```

Edit the `config.json` file with the desired configuration.

2. Run the container:
```console
docker run --rm -it \
  -v $(pwd)/config.json:/watchtower-monitor-html.json \
  ghcr.io/desvelao/watchtower-monitor-html-static-lua:0.0.1
```

If using an output proccesor such as `file-ndjson`, mount the volume with:

```console
docker run --rm -it \
  -v $(pwd)/config.json:/watchtower-monitor-html.json \
  -v $(pwd)/monitoring.json:/data/monitoring.json \
  ghcr.io/desvelao/watchtower-monitor-html-static-lua:0.0.1
```

## Docker compose

Refer to [production](./prod/README.md).

## Usage with crontab (Docker deployment)

Add the following task:

```
* * * * * /usr/local/bin/docker-compose -f <PATH_TO_DOCKER_COMPOSE_FILE> up >> <PATH_TO_SCRAPER>/scraper.log
```

Example:
Run cron task to 12:00 of each day:

```
0 12 * * * /usr/local/bin/docker-compose -f /home/pi/docker_compose/price_scraper/docker-compose.yml up >> /home/pi/docker_compose/price_scraper/scraper.log
```

# Development

Refer to [development](./dev/README.md).
