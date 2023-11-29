#!/bin/bash

# Qub CLI
# By @jamonholmgren & @knewter

VERSION="0.0.1"

# colors
RED='\033[0;31m'
BLUE='\033[0;34m'
END='\033[0m' # End Color

# Print header

echo ""
echo -e "${BLUE}Qub -- QBasic Website Generator${END}"
echo ""

# Print version and exit

if [[ $1 == "-v" || $1 == "--version" ]]; then
    echo "${VERSION}"
    exit 0
fi

# Help command if provided -h or --help

if [[ $1 == "-h" || $1 == "--help" ]]; then
    echo "Usage: qub [command] [options]"
    echo ""
    echo "Commands:"
    echo "  create          Create a new Qub QB64 web project (coming soon)"
    echo "  setup-server    Set up remote server for deployment (coming soon)"
    echo ""
    echo "Options:"
    echo "  -h, --help      Show help"
    echo "  -v, --version   Show version number"
    echo ""
    echo "Examples:"
    echo "  qub create"
    echo ""
    exit 0
fi

# Create command

if [[ $1 == "create" ]]; then
    echo "Creating new Qub project..."
    echo ""
    echo "Coming soon!"
    echo ""
    exit 0
fi
