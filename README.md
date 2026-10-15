![GitHub Release](https://img.shields.io/github/v/release/dariogriffo/kitty-debian)
![GitHub Release Date](https://img.shields.io/github/release-date/dariogriffo/kitty-debian)

<img src="kitty.png" alt="kitty" width="96" align="right">

# kitty for Debian and Ubuntu

This repository contains build scripts that produce **unofficial** Debian and
Ubuntu packages (`.deb`) of the latest [kitty](https://github.com/kovidgoyal/kitty)
release, the fast, feature-rich, GPU based terminal emulator by Kovid Goyal,
hosted at [deb.griffo.io](https://deb.griffo.io).

The packages repackage the **official upstream prebuilt bundle**
(`kitty-<version>-x86_64.txz` / `kitty-<version>-arm64.txz`). Nothing is rebuilt
from source: you get exactly the bits upstream's installer gives you, with its
own Python runtime and libraries, but managed by apt and updated the day a
release ships upstream.

Supported suites: Debian **bookworm, trixie, forky, sid** and Ubuntu **jammy,
noble, questing, resolute**. Architectures: **amd64 and arm64**, the two
upstream publishes bundles for (there is no i386, armhf or riscv64 build).

## Packages

Same four-way split and same names as Debian's own packages, so an existing
Debian or Ubuntu kitty install upgrades in place.

| Package | Arch | Contents |
| --- | --- | --- |
| `kitty` | amd64, arm64 | The upstream bundle under `/opt/kitty`, `/usr/bin/kitty` and `/usr/bin/kitten` symlinks, desktop entry, icons, man pages, fish/zsh completions. Registers the `x-terminal-emulator` alternative. |
| `kitty-terminfo` | all | `/usr/share/terminfo/x/xterm-kitty`. Install this alone on servers you ssh into. |
| `kitty-shell-integration` | all | `/usr/lib/kitty/shell-integration` (bash, fish, zsh, ssh kitten bootstrap), for remote systems. |
| `kitty-doc` | all | The HTML documentation under `/usr/share/doc/kitty/html`. Recommended by `kitty`. |

`apt install kitty` pulls in `kitty-terminfo` and `kitty-shell-integration`.

### What the `kitty` package depends on

The bundle brings its own Python, OpenSSL, harfbuzz, freetype, cairo, wayland
and xkbcommon libraries. The only things it needs from the system are the
display-server client libraries every desktop already has: libx11, libxcb,
libxcursor, libdbus, libfontconfig, libgl and libegl, plus glibc 2.35 or newer.
`libcanberra0` (terminal bell) and `libstartup-notification0` are Recommends.

## Install / Update

### The Debian way (apt)

```sh
sudo install -d -m 0755 /etc/apt/keyrings
curl -fsSL https://deb.griffo.io/EA0F721D231FDD3A0A17B9AC7808B4DD62C41256.asc | sudo gpg --dearmor --yes -o /etc/apt/keyrings/deb.griffo.io.gpg
echo "deb [signed-by=/etc/apt/keyrings/deb.griffo.io.gpg] https://deb.griffo.io/apt $(lsb_release -sc 2>/dev/null) main" | sudo tee /etc/apt/sources.list.d/deb.griffo.io.list
sudo apt update
sudo apt install kitty
```

To make sure apt keeps preferring this repository over the distribution's own
kitty packages, pin it:

```sh
sudo tee /etc/apt/preferences.d/deb.griffo.io-kitty > /dev/null << 'EOT'
Package: kitty kitty-terminfo kitty-shell-integration kitty-doc
Pin: origin deb.griffo.io
Pin-Priority: 1001
EOT
```

### Manual installation

1. Download the `.deb` files for your suite and architecture from the
   [Releases](https://github.com/dariogriffo/kitty-debian/releases) page
   (`kitty-terminfo`, `kitty-shell-integration` and `kitty`, optionally
   `kitty-doc`).
2. Install them:

```sh
sudo apt install ./kitty-terminfo_*.deb ./kitty-shell-integration_*.deb ./kitty_*.deb
```

## Updating

Re-run any install method above; the packages are upgraded in place. Do **not**
use `kitten update-self`: it downloads a new kitten binary over the packaged
`/opt/kitty/bin/kitten` behind apt's back. If you did, `sudo apt reinstall kitty`
restores it.

## Notes

- **Shell completions.** fish and zsh completions for `kitty`, `kitten` and
  `clone-in-kitty` are installed system-wide. bash has no static completion
  file: kitty's shell integration enables it, or run
  `source <(kitten __complete__ setup bash)`.
- **Opening files and URLs with kitty.** Like Debian, `kitty-open.desktop` is
  shipped only as an example (`/usr/share/doc/kitty/examples/`) because it
  registers kitty as a handler for text, images, directories and ssh URLs.
  Copy it to `~/.local/share/applications/` to opt in.
- **Sample configuration.** `/usr/share/doc/kitty/examples/kitty.conf`.
- **Input methods.** Start kitty with `GLFW_IM_MODULE=ibus kitty` to type
  through ibus or fcitx5.

## Building locally

Requires Docker (binary packages) and `dpkg-dev`/`devscripts` (source packages):

```sh
./build_debian.sh 0.49.2 1 all   # -> ./out/*.deb        (Debian suites)
./build_ubuntu.sh 0.49.2 1 all   # -> ./out/*_ubu.deb    (Ubuntu suites)
./build_src.sh    0.49.2 1       # -> *.dsc / *.orig.tar.gz / *.debian.tar.xz
```

The arm64 packages are assembled on an amd64 machine: the bundle is only
unpacked and copied, never executed, so no emulation is needed.

## How releases work

A scheduled workflow (`check-upstream.yml`) compares the latest upstream kitty
release against the latest release published here and, when they differ,
dispatches `release.yml`, which validates the upstream licence (GPL-3.0), builds
all packages for every suite and both architectures, and publishes a GitHub
Release tagged `<version>+<build>`.

## Disclaimer

- This is an unofficial community packaging project. For kitty itself, see
  [kovidgoyal/kitty](https://github.com/kovidgoyal/kitty) and
  [sw.kovidgoyal.net/kitty](https://sw.kovidgoyal.net/kitty/).
- This repo is not for kitty bug reports, only for the Debian packaging.
- Inspired by the packaging approach of
  [neovim-debian](https://github.com/dariogriffo/neovim-debian).
