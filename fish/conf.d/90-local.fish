# 90-local.fish - Source machine-specific overrides last (gitignored).
# Copy local.example.fish to local.fish and customise per machine.
if test -f "$__fish_config_dir/local.fish"
    source "$__fish_config_dir/local.fish"
end
