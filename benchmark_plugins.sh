#!/usr/bin/env bash
# ==============================================================================
# ZSH Plugin Benchmark Script
# ==============================================================================
# Measures the startup time impact of each zinit plugin by starting with all
# plugins disabled and enabling them one at a time.

set -uo pipefail

ZSHRC_PATH="/home/raza/.dotfiles/zsh/.zshrc"
BACKUP_PATH="${ZSHRC_PATH}.backup.$(date +%s)"
ITERATIONS=${1:-2}  # Default to 2 iterations
RESULTS_FILE="plugin_benchmark_results.csv"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Create backup
echo -e "${YELLOW}Creating backup: ${BACKUP_PATH}${NC}"
cp "${ZSHRC_PATH}" "${BACKUP_PATH}"

# Function to measure average startup time
measure_time() {
    local total=0
    local result
    local tmpfile=$(mktemp)

    for ((i=1; i<=ITERATIONS; i++)); do
        /usr/bin/time -f "%e" zsh -i -c exit 2>"$tmpfile" >/dev/null
        result=$(tail -n 1 "$tmpfile" | grep -oE '[0-9]+\.[0-9]+' | head -n 1)
        if [[ -z "$result" ]]; then
            result="0.0"
        fi
        total=$(awk -v t="$total" -v r="$result" 'BEGIN {print t + r}')
    done

    rm -f "$tmpfile"
    awk -v t="$total" -v iters="$ITERATIONS" 'BEGIN {printf "%.3f", t / iters}'
}

# Function to restore original zshrc
restore_zshrc() {
    cp "${BACKUP_PATH}" "${ZSHRC_PATH}"
}

# Function to comment out all plugins
comment_all_plugins() {
    # Comment out all zi/zinit lines and their configuration parameters
    sed -i '/^zi ice\|^zi light\|^zi snippet\|^zinit ice\|^zinit light\|^zinit snippet\|^  atclone\|^  atpull\|^  atload/s/^/# BENCHMARK: /' "${ZSHRC_PATH}"
}

# Function to uncomment a specific plugin
uncomment_plugin() {
    local start_line=$1
    local end_line=$2

    # Remove BENCHMARK comment from specific lines
    sed -i "${start_line},${end_line}s/^# BENCHMARK: //" "${ZSHRC_PATH}"
}

# Trap to ensure we always restore on exit
trap restore_zshrc EXIT

echo -e "${BLUE}=== ZSH Plugin Benchmark ===${NC}"
echo -e "${YELLOW}Iterations per test: ${ITERATIONS}${NC}"
echo -e "${YELLOW}Testing 44 plugins...${NC}"
echo ""

# First, comment out all plugins and measure baseline
echo -e "${YELLOW}Commenting out all plugins...${NC}"
comment_all_plugins
echo -e "${YELLOW}Measuring baseline (no plugins)...${NC}"
baseline=$(measure_time)

if [[ -z "$baseline" || "$baseline" == "0.000" ]]; then
    echo -e "${RED}Error: Failed to measure baseline time${NC}"
    exit 1
fi

echo -e "${GREEN}Baseline (no plugins): ${baseline}s${NC}"

# Estimate total time
estimated_time=$(awk -v iters="$ITERATIONS" -v base="$baseline" 'BEGIN {printf "%.0f", (44 * iters * base / 60)}')
echo -e "${YELLOW}Estimated time to complete: ~${estimated_time} minutes${NC}"
echo ""

# Initialize results file
echo "Plugin,Line Range,Time (s),Impact (s),Impact (%)" > "${RESULTS_FILE}"

# Define plugin blocks (line start, line end, plugin name)
plugins=(
    "482:483:powerlevel10k"
    "493:494:zsh-syntax-highlighting"
    "512:517:fzf"
    "522:523:fzf-tab"
    "527:528:fzf-tab-source"
    "533:534:zsh-autosuggestions"
    "538:539:zsh-completions"
    "544:545:zsh-you-should-use"
    "550:551:jq-zsh-plugin"
    "555:556:zsh-fancy-completions"
    "565:568:zoxide"
    "573:574:bd"
    "578:579:rename"
    "584:585:eza"
    "590:591:erdtree"
    "593:594:dua-cli"
    "599:600:zshmarks"
    "610:611:ripgrep"
    "617:618:bat"
    "623:624:fd"
    "629:630:sd"
    "635:636:jq"
    "641:642:up"
    "647:648:qsv"
    "650:651:yazi"
    "658:659:gh-cli"
    "664:666:atuin"
    "669:670:bottom"
    "673:675:tokei"
    "678:679:hyperfine"
    "682:683:dust"
    "687:688:delta"
    "691:692:duf"
    "695:696:doggo"
    "699:700:lazygit"
    "703:704:lazydocker"
    "707:708:procs"
    "719:720:forgit"
    "725:726:git-open"
    "732:733:git-extras"
    "742:743:zsh-artisan"
    "755:755:omz-sudo"
    "756:756:omz-copyfile"
    "757:757:omz-dirhistory"
)

total_plugins=${#plugins[@]}
current=0

for plugin_def in "${plugins[@]}"; do
    ((current++))

    # Parse plugin definition
    start_line=$(echo "$plugin_def" | cut -d':' -f1)
    end_line=$(echo "$plugin_def" | cut -d':' -f2)
    plugin_name=$(echo "$plugin_def" | cut -d':' -f3)

    echo -e "${YELLOW}[${current}/${total_plugins}] Testing ${plugin_name} (lines ${start_line}-${end_line})...${NC}"

    # Start fresh with all plugins commented out
    restore_zshrc
    comment_all_plugins

    # Uncomment just this plugin
    uncomment_plugin "$start_line" "$end_line"

    # Measure time with this plugin enabled
    plugin_time=$(measure_time)

    # Calculate impact (positive = plugin adds time)
    diff=$(awk -v plugin="$plugin_time" -v base="$baseline" 'BEGIN {printf "%.3f", plugin - base}')
    impact=$(awk -v base="$baseline" -v d="$diff" 'BEGIN {if (base > 0) printf "%.2f", (d / base) * 100; else print 0}')

    # Save to CSV
    echo "${plugin_name},${start_line}-${end_line},${plugin_time},${diff},${impact}" >> "${RESULTS_FILE}"

    # Color code: Red if adds significant time, yellow if moderate, green if minimal
    if awk -v d="$diff" 'BEGIN {exit !(d > 0.1)}'; then
        color=$RED
    elif awk -v d="$diff" 'BEGIN {exit !(d > 0.05)}'; then
        color=$YELLOW
    else
        color=$GREEN
    fi

    echo -e "  ${color}Plugin time: ${plugin_time}s (adds ${diff}s / ${impact}%)${NC}"
    echo ""
done

# Restore original
restore_zshrc

echo -e "${GREEN}=== Benchmark Complete ===${NC}"
echo ""
echo -e "${YELLOW}Top 10 slowest plugins:${NC}"
tail -n +2 "${RESULTS_FILE}" | sort -t',' -k4 -rn | head -10 | while IFS=',' read -r name lines time diff impact; do
    printf "  %-30s %8s  (%6s%%)\n" "$name" "${diff}s" "$impact"
done
echo ""
echo -e "Full results: ${BLUE}${RESULTS_FILE}${NC}"
echo -e "Backup: ${BLUE}${BACKUP_PATH}${NC}"
