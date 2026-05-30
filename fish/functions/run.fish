function run --description 'Run a script with the detected package manager'
    if test (count $argv) -lt 1
        echo "Usage: run <script>"
        echo "Example: run dev"
        return 1
    end
    if test -f yarn.lock
        echo "📦 Using Yarn"
        yarn $argv
    else if test -f pnpm-lock.yaml
        echo "📦 Using pnpm"
        pnpm $argv
    else if test -f package-lock.json; or test -f package.json
        echo "📦 Using npm"
        npm run $argv
    else
        echo "❌ No package.json found"
        return 1
    end
end
