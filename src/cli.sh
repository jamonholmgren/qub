#!/bin/bash

# Qub CLI
# By @jamonholmgren & @knewter
main() {
    VERSION="0.1.0"

    # What OS are we running on?

    OS=$(uname -s)

    # Colors

    BLUE='\033[0;34m'
    YELLOW='\033[1;33m'
    RED='\033[0;31m'
    DKGRAY='\033[1;30m'
    CYAN='\033[0;36m'
    GREEN='\033[0;32m'
    END='\033[0m' # End Color

    function replace_in_file {
        local filename=$1
        local variable_name=$2
        local replace_with=$3
        local os_type=$(uname -s)

        if [[ $os_type == "Darwin" ]]; then
            sed -i '' "s/\$${variable_name}/${replace_with}/g" "$filename"
        elif [[ $os_type == "Linux" ]]; then
            sed -i "s/\$${variable_name}/${replace_with}/g" "$filename"
        fi
    }

    # Print header

    echo ""
    echo -e "${BLUE}Qub -- QBasic Website Generator${END}"
    echo ""

    # Print version and exit

    if [[ $1 == "-v" || $1 == "--version" ]]; then
        echo "${VERSION}"
        return 0
    fi

    # Help command if provided -h or --help

    if [[ $1 == "-h" || $1 == "--help" ]]; then
        echo "Usage: qub [command] [options]"
        echo ""
        echo "Commands:"
        echo "  create          Create a new Qub QB64 web project"
        echo "  setup-server    Set up remote server for deployment (coming soon)"
        echo ""
        echo "Options:"
        echo "  -h, --help      Show help"
        echo "  -v, --version   Show version number"
        echo ""
        echo "Examples:"
        echo "  qub create"
        echo ""
        return 0
    fi

    # Create command

    if [[ $1 == "create" ]]; then
        echo "Creating new Qub QB64 website project..."
        echo ""

        # If $DOMAIN isn't set, ask for it
        if [[ -z $DOMAIN ]]; then
            echo -e "${YELLOW}What domain will this be hosted on?${END} ${DKGRAY}(e.g. jamon.dev)${END}"
            read DOMAIN
        fi

        # If $DOMAIN is still empty, exit
        if [[ -z $DOMAIN ]]; then
            echo ""
            echo -e "${RED}Domain name cannot be empty.${END}"
            echo ""
            return 1
        fi

        # Check for anything but numbers, letters, dashes, and periods
        if [[ $DOMAIN =~ [^a-zA-Z0-9\.\-] ]]; then
            echo ""
            echo -e "${RED}Domain name can only contain numbers, letters, dashes, and periods.${END}"
            echo ""
            return 1
        fi

        # Check if the folder exists (DOMAIN)
        if [[ -d $DOMAIN ]]; then
            echo ""
            echo -e "${RED}Folder already exists.${END}"
            echo ""
            return 1
        fi

        # Make the folders
        mkdir $DOMAIN
        mkdir $DOMAIN/bin
        mkdir -p $DOMAIN/web/pages
        mkdir -p $DOMAIN/web/static

        GITHUB_TEMPLATE="https://raw.githubusercontent.com/jamonholmgren/qub/main/template"

        echo ""
        echo -e "${GREEN}Creating project...${END}"
        echo ""

        # Copy files from Github
        curl -s $GITHUB_TEMPLATE/README.md > $DOMAIN/README.md
        replace_in_file "$DOMAIN/README.md" "DOMAIN" "$DOMAIN"
        echo -e "${GREEN}✓${END} README.md"
        curl -s $GITHUB_TEMPLATE/app.bas > $DOMAIN/app.bas
        echo -e "${GREEN}✓${END} app.bas"
        curl -s $GITHUB_TEMPLATE/.gitignore > $DOMAIN/.gitignore
        echo -e "${GREEN}✓${END} .gitignore"
        curl -s $GITHUB_TEMPLATE/bin/install_qb64 > $DOMAIN/bin/install_qb64
        echo -e "${GREEN}✓${END} bin/install_qb64"
        curl -s $GITHUB_TEMPLATE/bin/build > $DOMAIN/bin/build
        echo -e "${GREEN}✓${END} bin/build"
        curl -s $GITHUB_TEMPLATE/web/pages/home.html > $DOMAIN/web/pages/home.html
        replace_in_file "$DOMAIN/web/pages/home.html" "DOMAIN" "$DOMAIN"
        echo -e "${GREEN}✓${END} web/pages/home.html"
        curl -s $GITHUB_TEMPLATE/web/pages/contact.html > $DOMAIN/web/pages/contact.html
        echo -e "${GREEN}✓${END} web/pages/contact.html"
        curl -s $GITHUB_TEMPLATE/web/pages/404.html > $DOMAIN/web/pages/404.html
        echo -e "${GREEN}✓${END} web/pages/404.html"
        curl -s $GITHUB_TEMPLATE/web/static/scripts.js > $DOMAIN/web/static/scripts.js
        echo -e "${GREEN}✓${END} web/static/scripts.js"
        curl -s $GITHUB_TEMPLATE/web/static/styles.css > $DOMAIN/web/static/styles.css
        echo -e "${GREEN}✓${END} web/static/styles.css"
        curl -s $GITHUB_TEMPLATE/web/footer.html > $DOMAIN/web/footer.html
        replace_in_file "$DOMAIN/web/footer.html" "DOMAIN" "$DOMAIN"
        echo -e "${GREEN}✓${END} web/footer.html"
        curl -s $GITHUB_TEMPLATE/web/header.html > $DOMAIN/web/header.html
        echo -e "${GREEN}✓${END} web/header.html"
        curl -s $GITHUB_TEMPLATE/web/head.html > $DOMAIN/web/head.html
        echo -e "${GREEN}✓${END} web/head.html"
        
        # Make the binary files executable
        chmod +x $DOMAIN/bin/*

        # Ask if the user wants to install QB64

        echo ""
        echo -e "${YELLOW}Do you want to install QB64?${END} ${DKGRAY}(y/n)${END}"
        read INSTALL_QB64

        if [[ $INSTALL_QB64 == "y" ]]; then
            echo ""
            echo -e "${YELLOW}Installing QB64...${END}"
            echo ""
            pushd $DOMAIN
            ./bin/install_qb64
            popd
        fi

        echo ""
        echo -e "${GREEN}New QB64 website project created!${END}"
        echo ""
        echo -e "${YELLOW}Next steps:${END}"
        echo ""
        echo -e "  ${CYAN}cd ${DOMAIN}${END}"
        if [[ $INSTALL_QB64 != "y" ]]; then
            echo -e "  ${CYAN}./bin/install_qb64${END}"
        fi
        echo -e "  ${CYAN}./bin/build${END}"
        echo -e "  ${CYAN}./app${END}"
        echo ""
        echo -e "${YELLOW}Support Qub development:${END}"
        echo ""
        echo -e "  ${CYAN}Star the repo: ${DKGRAY}https://github.com/jamonholmgren/qub${END}"
        echo -e "  ${CYAN}Tell me what you're making: ${DKGRAY}https://twitter.com/jamonholmgren${END}"
        echo ""

        return 0
    fi
}

main "$@"
