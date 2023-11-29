#!/bin/bash

# Qub CLI
# By @jamonholmgren & @knewter

VERSION="0.0.1"

# What OS are we running on?

OS=$(uname -s)

# Colors

BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
GRAY='\033[0;37m'
DKGRAY='\033[1;30m'
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
    echo "Creating new Qub QB64 website project..."
    echo ""
    echo -e "${YELLOW}What domain will this be hosted on?${END} ${DKGRAY}(e.g. jamon.dev)${END}"
    read DOMAIN

    # Check for any whitespace in the domain name
    if [[ $DOMAIN =~ [[:space:]] ]]; then
        echo ""
        echo -e "${RED}Domain name cannot contain whitespace.${END}"
        echo ""
        exit 1
    fi

    # Check if the folder exists (DOMAIN)
    if [[ -d $DOMAIN ]]; then
        echo ""
        echo -e "${RED}Folder already exists.${END}"
        echo ""
        exit 1
    fi

    # Make the folder
    mkdir $DOMAIN
    mkdir $DOMAIN/bin

    GITHUB_TEMPLATE="https://raw.githubusercontent.com/jamonholmgren/qub/main/template"

    # Copy files from Github
    curl -s $GITHUB_TEMPLATE/README.md > $DOMAIN/README.md
    curl -s $GITHUB_TEMPLATE/app.bas > $DOMAIN/app.bas
    curl -s $GITHUB_TEMPLATE/bin/install_qb64 > $DOMAIN/bin/install_qb64
    
    # Make the binary files executable
    chmod +x $DOMAIN/bin/*

    # Replace the domain name in the README

    if [[ $OS == "Darwin" ]]; then
      sed -i '' "s/\$DOMAIN/$DOMAIN/g" $DOMAIN/README.md
    elif [[ $OS == "Linux" ]]; then
      sed -i "s/\$DOMAIN/$DOMAIN/g" $DOMAIN/README.md
    fi

    exit 0
fi
