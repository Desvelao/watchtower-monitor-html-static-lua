# Build local image

```console
docker build -f Dockerfile -D -t watchtower-monitor-html-static-lua:<TAG> --progress=plain --no-cache ../../..
```

where:
- `<TAG>`: is the tag version
