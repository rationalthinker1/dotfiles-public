function cc --description 'Stage all and commit with the Claude /commit skill'
    echo "📋 Files to be committed:"
    git status --short
    echo ""
    echo "📝 Last commit:"
    git log -1 --oneline --color=always
    echo ""
    git add -A; and claude -p '/commit'; and echo ""; and echo "✅ New commit:"; and git log -1 --color=always
end
