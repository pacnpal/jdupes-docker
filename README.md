# jdupes-docker

A minimal Docker image for [jdupes](https://codeberg.org/jbruchon/jdupes) — a fast duplicate-file finder and remover — built on Alpine Linux.

[![Build and Push Docker Image](https://github.com/pacnpal/jdupes-docker/actions/workflows/build.yml/badge.svg)](https://github.com/pacnpal/jdupes-docker/actions/workflows/build.yml)
[![GHCR Package](https://img.shields.io/badge/ghcr.io-pacnpal%2Fjdupes--docker-blue?logo=github)](https://github.com/pacnpal/jdupes-docker/pkgs/container/jdupes-docker)

---

## Usage

The container's entrypoint is `jdupes`, so you can pass flags and paths directly after the image name. Mount the directory you want to scan to `/data` inside the container.

### Basic scan (dry run — list duplicates only)

```bash
docker run --rm -v /path/to/files:/data ghcr.io/pacnpal/jdupes-docker -r /data
```

### Delete duplicates (auto-keep first, delete the rest)

```bash
docker run --rm -v /path/to/files:/data ghcr.io/pacnpal/jdupes-docker -r -d -N /data
```

### Scan a specific subdirectory

```bash
docker run --rm -v /path/to/files:/data ghcr.io/pacnpal/jdupes-docker -r /data/photos
```

### Use with Docker Compose

```yaml
services:
  jdupes:
    image: ghcr.io/pacnpal/jdupes-docker:latest
    command: ["-r", "-d", "-N", "/data"]
    volumes:
      - /path/to/files:/data
```

---

## Common flags

| Flag | Description |
|------|-------------|
| `-r` | Recurse into subdirectories |
| `-d` | Delete duplicate files (keeps the first copy in each set) |
| `-N` | No-prompt mode — don't ask for confirmation when deleting |
| `-S` | Show file sizes in the output |
| `-L` | Create hard links instead of deleting duplicates |

---

## Permissions

When mounting host directories, the container runs as `root` by default. If you need to preserve a specific user context (e.g. to avoid deleting files as root), you can use Docker's `--user` flag:

```bash
docker run --rm --user "$(id -u):$(id -g)" -v /path/to/files:/data ghcr.io/pacnpal/jdupes-docker -r /data
```

Note that deletion (`-d`) requires write permission on the mounted volume. Running without `--user` (i.e. as root) is the simplest way to ensure delete operations succeed on most NAS or volume mounts.

---

## Image details

- **Base image:** `alpine:latest`
- **Platforms:** `linux/amd64`, `linux/arm64` (suitable for Synology NAS, Raspberry Pi, etc.)
- **Package:** installed via `apk add jdupes` from Alpine's official repositories
- **Official jdupes project:** <https://codeberg.org/jbruchon/jdupes>
