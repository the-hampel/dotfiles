#!/bin/bash
set -e

# Initialize the variables
TEST=false
MODE=std
OTHER_ARGS=()

# Process command-line options
while [[ $# -gt 0 ]]; do
    case "$1" in
        --all)
            MODE=all
            shift # move to next argument
            ;;
        --gam)
            MODE=gam
            shift # move to next argument
            ;;
        --ncl)
            MODE=ncl
            shift # move to next argument
            ;;
        --test)
            TEST=true
            shift # move to next argument
            ;;
        *)
           OTHER_ARGS+=("$1")
           shift
           ;;
    esac
done

time make DEPS=1 -j$NCORE $MODE

if [ $TEST = true ]; then
    make test
fi
