# watchtower-observer-web-scraper

A [watchtower-server](https://github.com/Desvelao/watchtower-server)
standalone worker image with the `watchtower_observer_web_scraper` plugin
(static-HTML product scraping) baked in, ready to run with no local Lua
toolchain - see `src/README.md` for the plugin itself.

## Requirements

- Docker
- An `observable_types` row already created on your `watchtower-server`
  deployment (the default config uses `"product"`), with an
  `observation_schema` declaring whatever fields your sites extract (e.g.
  `price`/`discount`/`available`/`url`)

## Usage

- **Configuration** - [docs/config.md](./docs/config.md)
- **Production** (Docker/Docker Compose) - [prod/README.md](./prod/README.md)
- **Development** (editing the plugin) - [dev/README.md](./dev/README.md)
