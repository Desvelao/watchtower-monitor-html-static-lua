# Development

## Setup

1. Copy the `data/config.json.example` to `data/config.json` and edit it:
```console
cp data/config.json.example data/config.json
```

## Build/start

```console
docker compose up -d
```
This will start the development environment in detached mode.

## Enter to the container

```console
docker compose exec dev sh
```

## Stop

```console
docker compose stop
```

## Destroy

```console
docker compose down -v
```

## Run the script

```
lua script.lua
```

## Format code

```
cd /app
/usr/local/bin/stylua .
```
