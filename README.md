# ⚡ MINISTACK

A portable, self-contained PHP web stack, IRC chat server, dynamic DNS updater, and blog CMS.

## What's Installed

| Component | Size | Description |
|-----------|------|-------------|
| **FrankenPHP** | ~48MB | Web server + PHP 8.4 in a single binary |
| ↳ SQLite | *(built-in)* | File-based database included in PHP |
| **MariaDB** | ~800MB | MySQL-compatible database *(optional)* |
| **ngIRCd** | ~500KB | Lightweight IRC server *(optional)* |
| **Ergo** | ~15MB | Modern IRC server with WebSocket *(optional)* |
| **minidyn** | ~8KB | Dynamic DNS updater *(optional)* |
| **NucleusCMS** | ~1MB + ~30MB skins | Classic PHP blog CMS v3.8dev *(optional)* |

## Quick Start

```bash
./install.sh
./start.sh
```

Open **http://localhost:8080**

## Installation Options

| Choice | Result | Size |
|--------|--------|------|
| **N** (default) | FrankenPHP + SQLite | ~48MB |
| **Y** | FrankenPHP + MariaDB | ~877MB |

SQLite is built into PHP — perfect for blogs, small apps, and prototypes.

## Commands

```bash
./install.sh    # Download binaries
./start.sh      # Start web server (+ database if installed)
./stop.sh       # Stop everything
```

## Ports & Credentials

| Service | Port | User | Password |
|---------|------|------|----------|
| Web | 8080 | — | — |
| MariaDB | 3307 | `mini` | `stack` |
| IRC | 6667 | `mini` | `stack` |
| WebSocket | 6668 | — | — |

No root required — uses unprivileged ports.  
*WebSocket port only available with Ergo IRC server.*

## Directory Structure

```
webserver/
├── frankenphp/        # Web server + PHP (downloaded)
├── mariadb/           # Database (optional, downloaded)
├── htdocs/            # Your PHP files go here
│   └── index.php      # Test page
├── config/            # Generated configs
├── logs/              # Log files
├── install.sh
├── start.sh
└── stop.sh

chatserver/
├── bin/               # IRC server binary (ngIRCd or Ergo)
├── etc/               # Configuration files
├── data/              # Ergo database (if using Ergo)
├── logs/              # Log files
├── install.sh         # Choose ngIRCd or Ergo
├── start.sh
└── stop.sh

minidyn/
├── data/              # IP cache and logs
├── install.sh         # Configure DDNS provider
├── update.sh          # Manual IP update
├── start.sh           # Start background updater
└── stop.sh

nucleuscms/
├── install.sh            # Download, deploy, and configure NucleusCMS
├── fetch-skin-bundle.sh  # Rebuild skin bundle from Wayback (maintainer)
├── dependencies.txt      # Version and download info
└── included/             # Internal assets (used by install.sh)
    ├── finish-install.sh
    ├── import-skins.php
    ├── skins-bundle.zip
    └── skins-manifest.json
```

## Requirements

- Linux x86_64 or ARM64

## Connecting to the Database

### SQLite (default)
```php
$pdo = new PDO('sqlite:' . __DIR__ . '/data.db');
```

### MariaDB (if installed)
```php
$pdo = new PDO('mysql:host=127.0.0.1;port=3307', 'mini', 'stack');
```

CLI access:
```bash
./mariadb/bin/mysql -S ./mariadb/run/mariadb.sock -u mini -pstack
```

## Connecting to IRC

**Install** (choose ngIRCd or Ergo):
```bash
cd chatserver && ./install.sh
```

| Server | Lightweight | WebSocket |
|--------|-------------|-----------|
| ngIRCd | ✅ ~500KB | ❌ No |
| Ergo | ~15MB | ✅ Yes |

**Connect** with any IRC client (mIRC, HexChat, irssi, etc.):

| Setting | Value |
|---------|-------|
| Server | `localhost` (or your host IP) |
| Port | `6667` |
| WebSocket | `ws://host:6668` *(Ergo only)* |

Once connected:
```
/join #general
/oper mini stack
```

## Dynamic DNS

For remote access with a dynamic IP:

```bash
cd minidyn
./install.sh    # Configure your DDNS provider
./start.sh      # Start background updater
```

Supported providers: No-IP, DuckDNS, Dynu, FreeDNS

## NucleusCMS Blog

NucleusCMS v3.8dev from GitHub.

Fully automated install (no browser wizard needed):

```bash
cd nucleuscms
./install.sh    # deploy + configure with MINISTACK defaults
```

Defaults: admin `mini`/`stack`, database `nucleus`, blog at `/nucleus/`, default skin **grey**.

The installer includes `included/skins-bundle.zip` (~185 of 191 community skins from the historical Nucleus skins site). All skins are deployed and imported into the database automatically. Use `--no-skin-bundle` for a minimal install (core skins only).

Options:

```bash
./install.sh --admin-pass mypass --blog-name "My Blog"
./install.sh --no-skin-bundle     # skip bundled skin library
./install.sh --skip-wizard        # deploy files only
./install.sh --wizard-only        # run wizard on existing deploy
./install.sh --repatch-only       # re-patch + redeploy/import skins
./fetch-skin-bundle.sh            # rebuild skins-bundle.zip (maintainer)
```

| What | Value |
|------|-------|
| Blog | http://localhost:8080/nucleus/ |
| Admin | http://localhost:8080/nucleus/nucleus/ |
| Login | `mini` / `stack` |
| Database | `nucleus` @ `127.0.0.1:3307` (user `mini`, password `stack`) |

No start/stop scripts — NucleusCMS is served by FrankenPHP alongside your other htdocs content.
