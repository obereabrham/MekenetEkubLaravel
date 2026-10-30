FROM php:8.3-apache

# Enable Apache Rewrite Module for Laravel URLs
RUN a2enmod rewrite

# Install necessary system dependencies and PostgreSQL libraries
RUN apt-get update && apt-get install -y \
    libpq-dev \
    libpng-dev \
    libonig-dev \
    libxml2-dev \
    zip \
    unzip \
    git \
    curl

# Install PHP extensions including PostgreSQL (pgsql and pdo_pgsql)
RUN docker-php-ext-install pdo_pgsql pgsql pdo_mysql mbstring exif pcntl bcmath gd

# Get latest Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Set working directory
WORKDIR /var/www/html

# Copy project files
COPY . /var/www/html

# Install composer dependencies
RUN composer install --no-dev --optimize-autoloader

# Set permissions for storage and bootstrap cache
RUN chown -R www-data:www-data /var/www/html/storage /var/www/html/bootstrap/cache

# Clear and cache routes and configurations during build/start
RUN php artisan config:clear && php artisan route:clear

# Configure Apache document root to point to Laravel's public directory
RUN sed -i -e 's!/var/www/html!/var/www/html/public!g' /etc/apache2/sites-available/000-default.conf

# Allow .htaccess overrides so Laravel routing works properly (Fixes 404 errors)
RUN echo '<Directory /var/www/html/public>\n\
    Options Indexes FollowSymLinks\n\
    AllowOverride All\n\
    Require all granted\n\
</Directory>' >> /etc/apache2/apache2.conf

EXPOSE 80

# Start Apache in the foreground and clear cache on start/build if needed
CMD ["apache2-foreground"]
