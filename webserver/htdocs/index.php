<?php
$dbStatus = false;
$dbError = '';
try {
    $pdo = new PDO('mysql:host=127.0.0.1;port=3307', 'root', '');
    $dbStatus = true;
    $dbVersion = $pdo->query('SELECT VERSION()')->fetchColumn();
} catch (Exception $e) {
    $dbError = $e->getMessage();
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
    </div>
</body>
</html>
