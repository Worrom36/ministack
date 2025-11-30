# ⚡ MINISTACK

A portable, self-contained PHP web stack.

## What's Included

| Component | Size | Description |
|-----------|------|-------------|
| **FrankenPHP** | ~48MB | Web server + PHP 8.4 in a single binary |
| ↳ SQLite | *(built-in)* | File-based database included in PHP |
| **MariaDB** | ~800MB | MySQL-compatible database *(optional)* |

## Quick Start

```bash
git clone https://github.com/YOUR_USERNAME/ministack.git
cd ministack/webserver
./install.sh
./start.sh
```

Open **http://localhost:8080**

## Installation Options

The installer asks if you want MariaDB:

```
Install MariaDB? [y/N]:
```

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

## Ports

| Service | Port |
|---------|------|
| Web | 8080 |
| MariaDB | 3307 |

No root required — uses unprivileged ports.

## Directory Structure

```
webserver/
├── frankenphp         # Web server + PHP (downloaded)
├── mariadb/           # Database (optional, downloaded)
├── htdocs/            # Your PHP files go here
│   └── index.php      # Test page
├── config/            # Generated configs
├── logs/              # Log files
├── install.sh
├── start.sh
└── stop.sh
```

## Requirements

- Linux x86_64 or ARM64
- `curl` or `wget`
- ~50MB disk space (without MariaDB)
- ~900MB disk space (with MariaDB)

## Connecting to the Database

### SQLite (default)
```php
$pdo = new PDO('sqlite:' . __DIR__ . '/data.db');
```

### MariaDB (if installed)
```php
$pdo = new PDO('mysql:host=127.0.0.1;port=3307', 'root', '');
```

CLI access:
```bash
./mariadb/bin/mysql -S ./mariadb/run/mariadb.sock -u root
```

## Portability

The entire stack is self-contained. To move it:

1. Stop the server: `./stop.sh`
2. Copy/move the `webserver/` folder anywhere
3. Start again: `./start.sh`

Configs are generated at runtime with correct paths.

## Tech Stack

- [FrankenPHP](https://frankenphp.dev/) — Modern PHP app server built on Caddy
  - [SQLite](https://sqlite.org/) — Embedded database (built into PHP)
- [MariaDB](https://mariadb.org/) — MySQL-compatible database
