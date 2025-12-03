#!/bin/sh
set -e

echo "Starting entrypoint script..."

# Ensure dependencies are installed (first boot or fresh container)
if [ ! -d vendor ]; then
    echo "vendor directory missing. Installing PHP dependencies..."
    composer install --no-dev --optimize-autoloader --no-interaction
fi

# Check if .env file exists
if [ ! -f .env ]; then
    echo "ERROR: .env file not found!"
    exit 1
fi

# Print .env file location for verification
echo "Verifying .env file location..."
pwd
ls -la .env
echo "The .env file is located at: $(pwd)/.env"

# Generate app key if not set
if ! grep -q "APP_KEY=" .env || grep -q "APP_KEY=$" .env; then
    echo "Generating application key..."
    php artisan key:generate --force
fi

# Create symlink for storage
echo "Creating storage symlink..."
php artisan storage:link --force

# Clear and rebuild cache
echo "Clearing and rebuilding cache..."
php artisan config:clear
php artisan cache:clear
php artisan route:clear
php artisan view:clear

# Fix PSR-4 case mismatches that can occur on case-insensitive dev machines
if [ -d app/actions ]; then
  echo "Fixing PSR-4 mismatch: renaming app/actions -> app/Actions"
  mv app/actions app/ActionsTmp && mv app/ActionsTmp app/Actions
fi

# Rebuild autoloader to ensure all classes are properly loaded
echo "Rebuilding autoloader..."
composer dump-autoload --optimize --classmap-authoritative

# Re-optimize after autoloader rebuild
echo "Re-optimizing application..."
php artisan config:cache
php artisan route:cache
php artisan view:cache

# Verify permissions
echo "Verifying permissions..."
chmod -R 775 storage bootstrap/cache
chown -R www-data:www-data storage bootstrap/cache

# Display environment info (without secrets)
echo "Environment information:"
php artisan --version
php -v

echo "Entrypoint script completed successfully."

# Execute the command passed to docker run
exec "$@"
