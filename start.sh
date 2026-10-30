#!/usr/bin/env bash

# Give full permission to storage and cache
chmod -R 775 storage bootstrap/cache
chown -R www-data:www-data storage bootstrap/cache

# Clear all previous caches so new environment variables can take effect
php artisan config:clear
php artisan cache:clear
php artisan route:clear

# Run database migrations and seeders
php artisan migrate --force
php artisan db:seed --class=AdminUserSeeder --force

# Start Apache server
apache2-foreground
