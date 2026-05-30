function laravel-fresh --description 'Fresh migrate + seed + clear caches'
    echo "🔄 Dropping database..."
    pa migrate:fresh
    echo "🌱 Seeding database..."
    pa db:seed
    echo "🗑️  Clearing caches..."
    pa optimize:clear
    echo "✓ Laravel reset complete!"
end
