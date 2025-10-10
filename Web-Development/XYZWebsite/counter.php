<?php
declare(strict_types=1);

header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store, no-cache, must-revalidate');
header('Pragma: no-cache');

function respond(int $total): void {
    echo json_encode(['total' => $total], JSON_UNESCAPED_UNICODE);
    exit;
}

$file = __DIR__ . '/counter.txt';
$ua = strtolower($_SERVER['HTTP_USER_AGENT'] ?? '');
$bots = ['bot', 'spider', 'crawl', 'slurp', 'bing', 'yandex', 'duckduck', 'baiduspider', 'semrush', 'ahrefs', 'facebookexternalhit'];

foreach ($bots as $bot) {
    if ($bot !== '' && strpos($ua, $bot) !== false) {
        $current = (int)@file_get_contents($file);
        respond($current);
    }
}

if (!file_exists($file)) {
    file_put_contents($file, '0');
}

$fp = fopen($file, 'c+');
if ($fp === false) {
    $current = (int)@file_get_contents($file);
    respond($current);
}

if (flock($fp, LOCK_EX)) {
    $contents = stream_get_contents($fp);
    $count = (int)trim($contents);
    $count++;
    ftruncate($fp, 0);
    rewind($fp);
    fwrite($fp, (string)$count);
    fflush($fp);
    flock($fp, LOCK_UN);
    fclose($fp);
    respond($count);
}

$current = (int)@file_get_contents($file);
respond($current);
