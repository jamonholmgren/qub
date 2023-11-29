#!/bin/bash

# Qub CLI
# By @jamonholmgren & @knewter

VERSION="0.0.1"

echo "Qub -- QBasic Website Generator"

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
    echo "  init [name] [template]  Create a new project"
    # echo "  build [name]            Build a project"
    # echo "  serve [name]            Serve a project"
    echo "  help                    Show help"
    echo ""
    echo "Options:"
    echo "  -h, --help              Show help"
    echo "  -v, --version           Show version number"
    echo ""
    echo "Examples:"
    echo "  qub init my-project"
    # echo "  qub build my-project"
    # echo "  qub serve my-project"
    echo ""
    exit 0
fi
