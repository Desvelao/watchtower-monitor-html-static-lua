# Development

## Setup

1. Copy the example worker config and edit it:
```console
cp worker_config/worker_config.example.lua worker_config/worker_config.lua
```

## Start

```console
docker compose up -d
```

## Enter the container

```console
docker compose exec worker sh
```

## Run the worker

The container's entrypoint is overridden to stay idle (`tail -f /dev/null`)
so you can run the worker manually while iterating on `../src`:

```console
docker compose exec worker lua /app/main.lua --once
```

Drop `--once` to run it as a persistent loop instead (see
watchtower-server's `docs/dev/worker-configuration.md` for every run mode).
Edits to `../src` take effect on the next run - no restart needed, since it's
bind-mounted straight onto the image's `/worker_plugins/watchtower_observer_web_scraper`.

## Stop

```console
docker compose stop
```

## Destroy

```console
docker compose down -v
```

## Format code

```console
stylua src
```
(`stylua` isn't in this base image - install it locally, or run it via the
`stylua/stylua` Docker image against `../src`.)
