#!/usr/bin/env bash

set -eou pipefail

# Function to display help
show_help() {
    echo "Usage: $0 --margin=<max_risk> --profit=<profit_percent> --loss=<stop_loss_percent> --leverage=<leverage> --margin-limit=<limit>"
    echo
    echo "Arguments:"
    echo "  --margin         Maximum amount willing to risk per trade"
    echo "  --profit        Expected profit percentage"
    echo "  --loss          Stop loss percentage"
    echo "  --leverage      Trading leverage"
    echo "  --margin-limit  Maximum margin limit"
}

# Initialize variables with default empty values
max_risk=""
profit_percent=""
stop_loss_percent=""
leverage=""
limit=""

# Parse named arguments
for arg in "$@"; do
    case $arg in
        --margin=*)
        max_risk="${arg#*=}"
        ;;
        --profit=*)
        profit_percent="${arg#*=}"
        ;;
        --loss=*)
        stop_loss_percent="${arg#*=}"
        ;;
        --leverage=*)
        leverage="${arg#*=}"
        ;;
        --margin-limit=*)
        limit="${arg#*=}"
        ;;
        --help)
        show_help
        exit 0
        ;;
        *)
        echo "Error: Unknown argument: $arg"
        show_help
        exit 1
        ;;
    esac
done

# Check if all required arguments are provided
if [ -z "$max_risk" ] || [ -z "$profit_percent" ] || [ -z "$stop_loss_percent" ] || [ -z "$leverage" ] || [ -z "$limit" ]; then
    echo "Error: Missing required arguments"
    show_help
    exit 1
fi

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

# Initial position size calculation
position_size=$(echo "scale=16; ($max_risk * 100) / ($stop_loss_percent + 2 * 0.04)" | bc)
margin_required=$(echo "scale=16; $position_size / $leverage" | bc)

# Check margin limit and adjust if needed
if (( $(echo "$margin_required > $limit" | bc -l) )); then
    position_size=$(echo "scale=16; $limit * $leverage" | bc)
    margin_required=$limit
    echo "Warning: Position size adjusted due to margin limit ($limit)"
fi

# Calculate final values
total_fees=$(echo "scale=2; 2 * 0.04 * $position_size/100" | bc)
position_loss=$(echo "scale=2; $position_size * $stop_loss_percent/100" | bc)
actual_risk=$(echo "scale=2; $total_fees + $position_loss" | bc)
expected_profit=$(echo "scale=2; ($position_size * $profit_percent/100) - $total_fees" | bc)

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
printf "║ Expected Profit:      \033[32m%-8.2f\033[0m  ║\n" $expected_profit
printf "╚═════════════════════════════════╝\n"

exit 0
