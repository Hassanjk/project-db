<?php
declare(strict_types=1);
?>
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>PHP FPM Demo</title>
  <style>
    body { font-family: Arial, sans-serif; margin: 2rem; line-height: 1.5; }
    code { background: #f2f2f2; padding: 0.1rem 0.3rem; border-radius: 4px; }
    .box { border: 1px solid #ddd; border-radius: 8px; padding: 1rem; max-width: 800px; }
  </style>
</head>
<body>
  <div class="box">
    <h1>PHP-FPM + Nginx Demo</h1>
    <p>This page is served by <code>nginx-php-demo</code> and executed by <code>php-fpm-demo</code>.</p>
    <p>Target database host for class demo: <code>mariadb-demo:3306</code>.</p>
    <ul>
      <li>phpMyAdmin: <code>http://127.0.0.1:8082</code></li>
      <li>Nginx/PHP page: <code>http://127.0.0.1:8081</code></li>
      <li>MariaDB exposed port: <code>3306</code></li>
      <li>PHP-FPM exposed port: <code>9000</code></li>
    </ul>
    <p>PHP version: <code><?php echo PHP_VERSION; ?></code></p>
  </div>
</body>
</html>
