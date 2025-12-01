# ⚡ MINISTACK

A portable, self-contained PHP web stack, IRC chat server, and dynamic DNS updater.

## What's Installed

| Component | Size | Description |
|-----------|------|-------------|
| **FrankenPHP** | ~48MB | Web server + PHP 8.4 in a single binary |
| ↳ SQLite | *(built-in)* | File-based database included in PHP |
| **MariaDB** | ~800MB | MySQL-compatible database *(optional)* |
| **ngIRCd** | ~500KB | Lightweight IRC server *(optional)* |
| **Ergo** | ~15MB | Modern IRC server with WebSocket *(optional)* |
| **minidyn** | ~8KB | Dynamic DNS updater *(optional)* |

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