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

No root required — uses unprivileged ports.

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