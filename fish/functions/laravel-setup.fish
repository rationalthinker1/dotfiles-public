function laravel-setup --description 'Fresh Laravel project setup'
    composer install
    cp .env.example .env
    php artisan key:generate
    php artisan migrate
    php artisan db:seed
    echo "✓ Laravel project setup complete!"
end
