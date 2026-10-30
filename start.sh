#!/usr/bin/env bash

# Give full permission to storage and cache
chmod -R 775 storage bootstrap/cache
chown -R www-data:www-data storage bootstrap/cache

# Clear config and run migrations for PostgreSQL
php artisan config:clear
php artisan migrate --force
php artisan db:seed --class=AdminUserSeeder --force

# Start Apache server
apache2-foreground
