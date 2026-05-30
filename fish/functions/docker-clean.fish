function docker-clean --description 'Prune ALL docker data (with confirmation)'
    read -P "Prune ALL Docker data (images, containers, volumes)? (y/n): " confirm
    if test "$confirm" != y
        echo "Cancelled"
        return 1
    end
    echo "🗑️  Cleaning Docker system..."
    docker system prune -af --volumes
    echo "✓ Docker cleanup complete"
end
