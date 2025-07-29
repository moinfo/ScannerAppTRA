#!/bin/bash

echo "Setting up Laravel Backend..."

# Navigate to Laravel backend directory
cd back-end

# Install PHP dependencies
echo "Installing PHP dependencies..."
composer install

# Copy environment file
if [ ! -f .env ]; then
    echo "Creating .env file..."
    cp .env.example .env
fi

# Generate application key
php artisan key:generate

# Set up database (update these values in .env)
echo "Please update the following in your .env file:"
echo "DB_CONNECTION=mysql"
echo "DB_HOST=127.0.0.1"
echo "DB_PORT=3306"
echo "DB_DATABASE=tra_scanner"
echo "DB_USERNAME=root"
echo "DB_PASSWORD=your_password"
echo ""
echo "Press Enter when you've updated .env file..."
read

# Create database if it doesn't exist
echo "Creating database..."
mysql -u root -p -e "CREATE DATABASE IF NOT EXISTS tra_scanner;"

# Run migrations
echo "Running database migrations..."
php artisan migrate

# Seed database
echo "Seeding database..."
php artisan db:seed

# Create storage link
php artisan storage:link

# Clear caches
php artisan cache:clear
php artisan config:clear
php artisan route:clear

echo "Laravel backend setup complete!"
echo "You can start the server with: php artisan serve"