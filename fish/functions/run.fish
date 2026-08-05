function run --description 'Run a script with the detected package manager'
    if test (count $argv) -lt 1
        echo "Usage: run <script>"
        echo "Example: run dev"
        return 1
    end
    # bun is checked first: it writes bun.lockb (<1.2) or bun.lock (1.2+), but bun
    # projects frequently still carry a package-lock.json from before the switch, which
    # would otherwise fall through to npm below.
    if test -f bun.lockb; or test -f bun.lock
        echo "📦 Using Bun"
        bun run $argv
    else if test -f yarn.lock
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
