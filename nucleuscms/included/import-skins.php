#!/usr/bin/env php
<?php
/**
 * MINISTACK: import Nucleus skins from skins/<name>/skinbackup.xml
 *
 * Usage:
 *   import-skins.php <htdocs/nucleus-path> <skin-name> [...]
 *   import-skins.php <htdocs/nucleus-path> --all [--exclude=atom,rss2.0,rsd]
 */

if (PHP_SAPI !== 'cli' && ! getenv('NUCLEUS_IMPORT_SKINS')) {
    exit('CLI only');
}

$deployRoot = $argv[1] ?? '';
$args       = array_slice($argv, 2);

if ($deployRoot === '' || $args === []) {
    fwrite(STDERR, "Usage: import-skins.php <htdocs/nucleus-path> <skin-name> [...]\n");
    fwrite(STDERR, "       import-skins.php <htdocs/nucleus-path> --all [--exclude=a,b]\n");
    exit(1);
}

$importAll = false;
$exclude   = [];
$skinNames = [];

foreach ($args as $arg) {
    if ($arg === '--all') {
        $importAll = true;
        continue;
    }
    if (str_starts_with($arg, '--exclude=')) {
        $exclude = array_filter(array_map('trim', explode(',', substr($arg, 10))));
        continue;
    }
    $skinNames[] = $arg;
}

// Minimal request context so config.php / globalfunctions.php do not exit on CLI
$_SERVER['REQUEST_URI']          = '/';
$_SERVER['REQUEST_METHOD']       = 'GET';
$_SERVER['HTTP_HOST']            = 'localhost';
$_SERVER['HTTP_ACCEPT_LANGUAGE'] = 'en-US';
$_SERVER['REMOTE_ADDR']          = '127.0.0.1';
if ( ! defined('NC_MTN_MODE')) {
    define('NC_MTN_MODE', 'upgrade');
}

$config = rtrim($deployRoot, '/') . '/config.php';
if ( ! is_file($config)) {
    fwrite(STDERR, "config.php not found: $config\n");
    exit(1);
}

require $config;
require_once $DIR_LIBS . 'skinie.php';

if ($importAll) {
    $skinNames = [];
    foreach (glob($DIR_SKINS . '*', GLOB_ONLYDIR) ?: [] as $dir) {
        $name = basename($dir);
        if (in_array($name, $exclude, true)) {
            continue;
        }
        if (is_file($dir . '/skinbackup.xml') || is_file($dir . '/skindata.xml')) {
            $skinNames[] = $name;
        }
    }
    sort($skinNames);
}

if ($skinNames === []) {
    fwrite(STDERR, "No skins to import\n");
    exit(1);
}

$imported = [];
$errors   = [];

foreach ($skinNames as $name) {
    $name = basename(str_replace(['\\', '/'], '', $name));
    $file = $DIR_SKINS . $name . '/skinbackup.xml';

    if ( ! is_file($file)) {
        $alt = $DIR_SKINS . $name . '/skindata.xml';
        $file = is_file($alt) ? $alt : $file;
    }

    if ( ! is_file($file)) {
        $errors[] = "missing skin file for '$name'";
        continue;
    }

    $importer = new SKINIMPORT();
    $error    = $importer->readFile($file);
    if ($error) {
        $errors[] = "$name: read failed ($error)";
        continue;
    }

    $error = $importer->writeToDatabase(0);
    if ($error) {
        if ($error === _SKINIE_NAME_CLASHES_DETECTED) {
            $imported[] = "$name (already present)";
            continue;
        }
        $errors[] = "$name: import failed ($error)";
        continue;
    }

    $imported[] = $name;
}

foreach ($imported as $line) {
    echo "imported: $line\n";
}

if ($errors !== []) {
    foreach ($errors as $error) {
        fwrite(STDERR, "error: $error\n");
    }
    exit(1);
}

exit(0);
