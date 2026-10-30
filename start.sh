#!/usr/bin/env bash
# Run database migrations automatically
php artisan migrate --force

# Start Apache server
apache2-foreground
