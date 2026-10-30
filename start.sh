#!/usr/bin/env bash

# Give permission to storage and bootstrap cache
chmod -R 775 storage bootstrap/cache

# Run database migrations and seeders for PostgreSQL
php artisan config:clear
php artisan migrate --force
php artisan db:seed --class=AdminUserSeeder --force

# Start Apache server
apache2-foreground
