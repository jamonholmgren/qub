#!/bin/bash

# Qub CLI

main() {
    VERSION="0.1.0"

    # Colors

    BLUE='\033[1;34m'
    YELLOW='\033[1;33m'
    RED='\033[1;31m'
    DKGRAY='\033[0;30m'
    CYAN='\033[1;36m'
    GREEN='\033[1;32m'
    END='\033[0m' # End Color

    GITHUB_TEMPLATE="https://raw.githubusercontent.com/jamonholmgren/qub/main/template"

    function replace_in_file {
        local filename=$1
        local variable_name=$2
        local replace_with=$3
        local os_type
        os_type=$(uname -s)

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

    # Create command

    if [[ $1 == "create" ]]; then
        echo "Creating new Qub QB64 website project..."
        echo ""

        # If $DOMAIN isn't set, ask for it
        if [[ -z $DOMAIN ]]; then
            echo -e "${YELLOW}What domain will this be hosted on?${END} ${DKGRAY}(e.g. jamon.dev)${END}"
            read -r DOMAIN
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
        mkdir "${DOMAIN}"
        mkdir "${DOMAIN}/bin"
        mkdir -p "${DOMAIN}/qub"
        mkdir -p "${DOMAIN}/web/pages"
        mkdir -p "${DOMAIN}/web/static"

        echo ""
        echo -e "${GREEN}Creating project...${END}"
        echo ""

        # Copy files from Github
        curl -s $GITHUB_TEMPLATE/README.md > "${DOMAIN}/README.md"
        replace_in_file "$DOMAIN/README.md" "DOMAIN" "$DOMAIN"
        echo -e "${GREEN}✓${END} README.md"
        curl -s $GITHUB_TEMPLATE/qub/server.bas > "${DOMAIN}/qub/server.bas"
        echo -e "${GREEN}✓${END} qub/server.bas"
        curl -s $GITHUB_TEMPLATE/qub/qub.conf > "${DOMAIN}/qub/qub.conf"
        echo -e "${GREEN}✓${END} qub/qub.conf"
        curl -s $GITHUB_TEMPLATE/.gitignore > "${DOMAIN}/.gitignore"
        echo -e "${GREEN}✓${END} .gitignore"
        curl -s $GITHUB_TEMPLATE/bin/install_qb64 > "${DOMAIN}/bin/install_qb64"
        echo -e "${GREEN}✓${END} bin/install_qb64"
        curl -s $GITHUB_TEMPLATE/bin/build > "${DOMAIN}/bin/build"
        echo -e "${GREEN}✓${END} bin/build"
        curl -s $GITHUB_TEMPLATE/web/pages/home.html > "${DOMAIN}/web/pages/home.html"
        replace_in_file "$DOMAIN/web/pages/home.html" "DOMAIN" "$DOMAIN"
        echo -e "${GREEN}✓${END} web/pages/home.html"
        curl -s $GITHUB_TEMPLATE/web/pages/contact.html > "${DOMAIN}/web/pages/contact.html"
        echo -e "${GREEN}✓${END} web/pages/contact.html"
        curl -s $GITHUB_TEMPLATE/web/pages/404.html > "${DOMAIN}/web/pages/404.html"
        echo -e "${GREEN}✓${END} web/pages/404.html"
        curl -s $GITHUB_TEMPLATE/web/static/scripts.js > "${DOMAIN}/web/static/scripts.js"
        echo -e "${GREEN}✓${END} web/static/scripts.js"
        curl -s $GITHUB_TEMPLATE/web/static/styles.css > "${DOMAIN}/web/static/styles.css"
        echo -e "${GREEN}✓${END} web/static/styles.css"
        curl -s $GITHUB_TEMPLATE/web/layout.html > "${DOMAIN}/web/layout.html"
        replace_in_file "$DOMAIN/web/layout.html" "DOMAIN" "$DOMAIN"
        echo -e "${GREEN}✓${END} web/layout.html"
        
        # Make the binary files executable
        chmod +x "${DOMAIN}/bin/*"

        # Ask if the user wants to install QB64

        echo ""
        echo -e "${YELLOW}Do you want to install QB64?${END} ${DKGRAY}(y/n)${END}"
        read -r INSTALL_QB64

        if [[ $INSTALL_QB64 == "y" ]]; then
            echo ""
            echo -e "${YELLOW}Installing QB64...${END}"
            echo ""
            pushd "${DOMAIN}" || return 1
            ./bin/install_qb64
            popd || return 1
        fi

        echo ""
        echo -e "${GREEN}New QB64 website project created!${END}"
        echo ""
        echo -e "${YELLOW}Next steps:${END}"
        echo ""
        echo -e "  cd ${DOMAIN}"
        if [[ $INSTALL_QB64 != "y" ]]; then
            echo -e "  ./bin/install_qb64"
        fi
        echo -e "  ./bin/build"
        echo -e "  ./server"
        echo ""
        echo -e "${YELLOW}Support Qub development:${END}"
        echo ""
        echo -e "  ${CYAN}Star the repo: ${DKGRAY}https://github.com/jamonholmgren/qub${END}"
        echo -e "  ${CYAN}Tell me what you're making: ${DKGRAY}https://twitter.com/jamonholmgren${END}"
        echo ""

        return 0
    fi

    # qub update

    if [[ $1 == "update" ]]; then
        echo ""
        echo "Updating Qub-powered QB64 website project..."
        echo ""

        # If we don't have a server.bas file, exit

        if [[ ! -f qub/server.bas ]]; then
            echo ""
            echo -e "${RED}qub/server.bas file not found.${END} Are you in the right folder?"
            echo ""
            return 1
        fi

        # If we aren't in a git repo, exit (unless --force is passed)

        if [[ ! -d .git && ($2 != "--force" && $3 != "--force") ]]; then
            echo ""
            echo -e "${RED}Not in a git repo ... we don't want to lose your work.${END} To force update, pass --force."
            echo ""
            return 1
        fi

        # If we are in a git repo, but the working tree is dirty, exit (unless --force is passed)

        if [[ -d .git && $(git status --porcelain) && ($2 != "--force" && $3 != "--force") ]]; then
            echo ""
            echo -e "${RED}Git working tree is dirty ... you should commit your work first.${END} To force update, pass --force."
            echo ""
            return 1
        fi

        # Download the latest server.bas from the template

        curl -s $GITHUB_TEMPLATE/qub/server.bas > qub/server.bas
        echo -e "${GREEN}✓${END} qub/server.bas updated to latest"
        echo ""

        return 0
    fi

    # Otherwise, print help

    # Help command if provided -h or --help

    echo -e "${CYAN}Usage:${END} qub [command|option]"
    echo -e ""
    echo -e "${CYAN}Commands:${END}"
    echo -e "  create          Create a new Qub QB64 web project"
    echo -e "  update          Update an existing Qub QB64 web project to the latest Qub version"
    echo -e ""
    echo -e "${CYAN}Options:${END}"
    echo -e "  -h, --help      Show help"
    echo -e "  -v, --version   Show version number"
    echo -e ""
    echo -e "${CYAN}Examples:${END}"
    echo -e "  qub --help"
    echo -e "  qub -v"
    echo -e "  qub create"
    echo -e "  qub update"
    echo -e ""
    echo -e "If you need more help, please visit:"
    echo -e "  ${DKGRAY}https://github.com/jamonholmgren/qub${END}"
    echo -e ""
    return 0
}

main "$@"
