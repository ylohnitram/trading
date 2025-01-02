#!/usr/bin/env bash

set -eou pipefail

# Function to display help
show_help() {
    echo "Usage: $0 <max_risk> <profit_percent> <stop_loss_percent> <leverage> <limit>"
    echo
    echo "Arguments:"
    echo "  max_risk          Maximum amount willing to risk per trade"
    echo "  profit_percent    Expected profit percentage"
    echo "  stop_loss_percent Stop loss percentage"
    echo "  leverage          Trading leverage"
    echo "  limit            Maximum margin limit"
}

# Check arguments
if [ $# -ne 5 ]; then
    echo "Error: Incorrect number of arguments"
    show_help
    exit 1
fi

# Assign arguments
readonly max_risk=$1
readonly profit_percent=$2
readonly stop_loss_percent=$3
readonly leverage=$4
readonly limit=$5

# Validate numeric input
if ! [[ $max_risk =~ ^[0-9]+(\.[0-9]+)?$ ]] || \
   ! [[ $profit_percent =~ ^[0-9]+(\.[0-9]+)?$ ]] || \
   ! [[ $stop_loss_percent =~ ^[0-9]+(\.[0-9]+)?$ ]] || \
   ! [[ $leverage =~ ^[0-9]+(\.[0-9]+)?$ ]] || \
   ! [[ $limit =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
    echo "Error: All arguments must be numbers"
    show_help
    exit 1
fi

# Calculate position size and required margin
position_size=$(echo "scale=16; $max_risk / ($stop_loss_percent/100)" | bc)
margin_required=$(echo "scale=16; $position_size / $leverage" | bc)

# Check margin limit and adjust if needed
if (( $(echo "$margin_required > $limit" | bc -l) )); then
    position_size=$(echo "scale=16; $limit * $leverage" | bc)
    margin_required=$limit
    actual_risk=$(echo "scale=16; $position_size * $stop_loss_percent/100" | bc)
    echo "Warning: Position size adjusted due to margin limit ($limit)"
else
    actual_risk=$max_risk
fi

# Calculate fees and profit
total_fees=$(echo "scale=2; 2 * 0.04 * $position_size/100" | bc)
expected_profit=$(echo "scale=2; $position_size * $profit_percent/100" | bc)
profit_amount=$(echo "scale=2; $expected_profit - $total_fees" | bc)

printf "╔═════════════════════════════════╗\n"
printf "║       TRADE CALCULATIONS        ║\n"
printf "╠═════════════════════════════════╣\n"
printf "║ Maximum Risk:         \033[31m%-8.2f\033[0m  ║\n" $actual_risk
printf "║ Expected Profit %%:    %-7.2f%%  ║\n" $profit_percent
printf "║ Stop Loss %%:          %-7.2f%%  ║\n" $stop_loss_percent
printf "║ Leverage:             %-8.2f  ║\n" $leverage
printf "╠═════════════════════════════════╣\n"
printf "║ Position Size:        %-8.2f ║\n" $position_size
printf "║ Margin Required:      \033[33m%-8.2f\033[0m  ║\n" $margin_required
printf "║ Total Fees:           %-8.2f  ║\n" $total_fees
printf "║ Expected Profit:      \033[32m%-8.2f\033[0m  ║\n" $profit_amount
printf "╚═════════════════════════════════╝\n"

exit 0
