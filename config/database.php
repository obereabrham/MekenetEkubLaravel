<?php

$pgsqlUrl = env('DB_URL', env('DATABASE_URL'));
$pgsqlUrlHost = is_string($pgsqlUrl) ? parse_url($pgsqlUrl, PHP_URL_HOST) : null;
$pgsqlHost = $pgsqlUrlHost ?: env('DB_HOST', '127.0.0.1');
$pgsqlUsesPooler = is_string($pgsqlHost) && str_contains($pgsqlHost, '-pooler.');
$pgsqlDirectHost = $pgsqlUsesPooler ? preg_replace('/-pooler(?=\.)/', '', $pgsqlHost) : null;

return [
    'default' => env('DB_CONNECTION', 'mysql'),
    'connections' => [
        'mysql' => [
            'driver' => 'mysql', 'url' => env('DB_URL'), 'host' => env('DB_HOST', '127.0.0.1'),
            'port' => env('DB_PORT', '3306'), 'database' => env('DB_DATABASE', 'mekenet_ekub'),
            'username' => env('DB_USERNAME', 'root'), 'password' => env('DB_PASSWORD', ''),
            'unix_socket' => env('DB_SOCKET', ''), 'charset' => 'utf8mb4', 'collation' => 'utf8mb4_unicode_ci',
            'prefix' => '', 'prefix_indexes' => true, 'strict' => true,
            'engine' => null, 'options' => extension_loaded('pdo_mysql') ? array_filter([PDO::ATTR_TIMEOUT => env('DB_TIMEOUT', 5)]) : [],
        ],
        'pgsql' => [
            'driver' => 'pgsql',
            // Render/Neon commonly provide DATABASE_URL; DB_URL remains supported too.
            'url' => $pgsqlUrl,
            'host' => env('DB_HOST', '127.0.0.1'),
            'port' => env('DB_PORT', '5432'),
            'database' => env('DB_DATABASE', 'mekenet_ekub'),
            'username' => env('DB_USERNAME', 'postgres'),
            'password' => env('DB_PASSWORD', ''),
            'charset' => 'utf8',
            'prefix' => '',
            'prefix_indexes' => true,
            'search_path' => env('DB_SCHEMA', 'public'),
            'sslmode' => env('DB_SSLMODE', 'prefer'),
            'pooled' => env('DB_POOLED', $pgsqlUsesPooler),
            'direct' => $pgsqlDirectHost ? [
                'host' => env('DB_DIRECT_HOST', $pgsqlDirectHost),
            ] : [],
            'options' => extension_loaded('pdo_pgsql') ? array_filter([PDO::ATTR_TIMEOUT => env('DB_TIMEOUT', 5)]) : [],
        ],
    ],
    'migrations' => ['table' => 'migrations', 'update_date_on_publish' => true],
    'redis' => ['client' => env('REDIS_CLIENT', 'phpredis'), 'options' => ['cluster' => env('REDIS_CLUSTER', 'redis'), 'prefix' => env('REDIS_PREFIX', 'mekenet_database_')]],
];
