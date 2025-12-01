<?php
// MariaDB status
$dbStatus = false;
$dbError = '';
try {
    $pdo = new PDO('mysql:host=127.0.0.1;port=3307', 'mini', 'stack');
    $dbStatus = true;
    $dbVersion = $pdo->query('SELECT VERSION()')->fetchColumn();
} catch (Exception $e) {
    $dbError = $e->getMessage();
}

// IRC status
$ircStatus = false;
$ircError = 'Not running';
$fp = @fsockopen('127.0.0.1', 6667, $errno, $errstr, 1);
if ($fp) {
    $ircStatus = true;
    fclose($fp);
}

// DDNS status
$ddnsStatus = false;
$ddnsInfo = 'Not running';
$ddnsPidFile = __DIR__ . '/../../minidyn/data/minidyn.pid';
$ddnsConfig = __DIR__ . '/../../minidyn/config';
if (file_exists($ddnsPidFile)) {
    $pid = trim(file_get_contents($ddnsPidFile));
    if (file_exists("/proc/$pid")) {
        $ddnsStatus = true;
        if (file_exists($ddnsConfig)) {
            $config = parse_ini_file($ddnsConfig);
            $host = $config['DDNS_HOST'] ?? '';
            $interval = $config['INTERVAL'] ?? '';
            $ddnsInfo = $host . ($interval ? " (every {$interval}m)" : '');
        } else {
            $ddnsInfo = 'Running';
        }
    }
}
?>
<!DOCTYPE html>
<html>
<head>
    <title>MINISTACK</title>
    <style>
        body { font-family: system-ui; background: #1a1a2e; color: #eee; padding: 2rem; }
        .container { max-width: 500px; margin: 0 auto; }
        h1 { color: #00d9ff; }
        .status { padding: 1rem; border-radius: 8px; margin: 1rem 0; }
        .ok { background: #1e4620; border: 1px solid #4caf50; }
        .err { background: #4a1c1c; border: 1px solid #f44336; }
    </style>
</head>
<body>
    <div class="container">
        <h1>⚡ MINISTACK</h1>
        <div class="status ok">
            ✓ FrankenPHP: <?= phpversion() ?>
        </div>
        <div class="status <?= $dbStatus ? 'ok' : 'err' ?>">
            <?= $dbStatus ? "✓ MariaDB: $dbVersion" : "✗ MariaDB: $dbError" ?>
        </div>
        <div class="status <?= $ircStatus ? 'ok' : 'err' ?>">
            <?= $ircStatus ? "✓ IRC: Port 6667" : "✗ IRC: $ircError" ?>
        </div>
        <div class="status <?= $ddnsStatus ? 'ok' : 'err' ?>">
            <?= $ddnsStatus ? "✓ DDNS: $ddnsInfo" : "✗ DDNS: $ddnsInfo" ?>
        </div>
    </div>
</body>
</html>
