#!/bin/bash

INSTALL_DIR="/opt"
if [ -z "$APP_NAME" ]; then
    APP_NAME="LynxAPI"
fi
APP_DIR="$INSTALL_DIR/$APP_NAME"
DATA_DIR="/var/lib/$APP_NAME"
COMPOSE_FILE="$APP_DIR/docker-compose.yml"


colorized_echo() {
    local color=$1
    local text=$2

    case $color in
        "red")
        printf "\e[91m${text}\e[0m\n";;
        "green")
        printf "\e[92m${text}\e[0m\n";;
        "yellow")
        printf "\e[93m${text}\e[0m\n";;
        "blue")
        printf "\e[94m${text}\e[0m\n";;
        "magenta")
        printf "\e[95m${text}\e[0m\n";;
        "cyan")
        printf "\e[96m${text}\e[0m\n";;
        *)
            echo "${text}"
        ;;
    esac
}

check_running_as_root() {
    if [ "$(id -u)" != "0" ]; then
        colorized_echo red "This command must be run as root."
        exit 1
    fi
}

detect_os() {
    # Detect the operating system
    if [ -f /etc/lsb-release ]; then
        OS=$(lsb_release -si)
        elif [ -f /etc/os-release ]; then
        OS=$(awk -F= '/^NAME/{print $2}' /etc/os-release | tr -d '"')
        elif [ -f /etc/redhat-release ]; then
        OS=$(cat /etc/redhat-release | awk '{print $1}')
        elif [ -f /etc/arch-release ]; then
        OS="Arch"
    else
        colorized_echo red "Unsupported operating system"
        exit 1
    fi
}

detect_and_update_package_manager() {
    colorized_echo blue "Updating package manager"
    if [[ "$OS" == "Ubuntu"* ]] || [[ "$OS" == "Debian"* ]]; then
        PKG_MANAGER="apt-get"
        $PKG_MANAGER update
        elif [[ "$OS" == "CentOS"* ]]; then
        PKG_MANAGER="yum"
        $PKG_MANAGER update -y
        $PKG_MANAGER epel-release -y
        elif [ "$OS" == "Fedora"* ]; then
        PKG_MANAGER="dnf"
        $PKG_MANAGER update
        elif [ "$OS" == "Arch" ]; then
        PKG_MANAGER="pacman"
        $PKG_MANAGER -Sy
    else
        colorized_echo red "Unsupported operating system"
        exit 1
    fi
}

detect_compose() {
    # Check if docker compose command exists
    if docker compose >/dev/null 2>&1; then
        COMPOSE='docker compose'
        elif docker-compose >/dev/null 2>&1; then
        COMPOSE='docker-compose'
    else
        colorized_echo red "docker compose not found"
        exit 1
    fi
}

install_package () {
    if [ -z $PKG_MANAGER ]; then
        detect_and_update_package_manager
    fi

    PACKAGE=$1
    colorized_echo blue "Installing $PACKAGE"
    if [[ "$OS" == "Ubuntu"* ]] || [[ "$OS" == "Debian"* ]]; then
        $PKG_MANAGER -y install "$PACKAGE"
        elif [[ "$OS" == "CentOS"* ]]; then
        $PKG_MANAGER install -y "$PACKAGE"
        elif [ "$OS" == "Fedora"* ]; then
        $PKG_MANAGER install -y "$PACKAGE"
        elif [ "$OS" == "Arch" ]; then
        $PKG_MANAGER -S --noconfirm "$PACKAGE"
    else
        colorized_echo red "Unsupported operating system"
        exit 1
    fi
}

install_docker() {
    # Install Docker and Docker Compose using the official installation script
    colorized_echo blue "Installing Docker"
    curl -fsSL https://get.docker.com | sh
    colorized_echo green "Docker installed successfully"
}

generate_api_secret_key() {
    # Generate a random API secret key using OpenSSL
    local api_key=$(openssl rand -hex 32)
    echo "$api_key"
}

replace_api_secret_key() {
    local api_key=$(generate_api_secret_key)
    # Replace the placeholder in the .env file with the generated API secret key
    sed -i "s/your_secret_key_here/$api_key/" "$APP_DIR/.env"
    colorized_echo green "API secret key set in $APP_DIR/.env"
}

install_LynxAPI() {
    # Fetch releases
    FILES_URL_PREFIX="https://raw.githubusercontent.com/shojaei-mohammad/LynxAPI/main"

    mkdir -p "$DATA_DIR"
    mkdir -p "$APP_DIR"

    local api_key=$(generate_api_secret_key)

    colorized_echo blue "Fetching compose file"
    curl -sL "$FILES_URL_PREFIX/docker-compose.yml" -o "$COMPOSE_FILE"
    colorized_echo green "Compose file saved in $COMPOSE_FILE"

    colorized_echo blue "Fetching .env file"
    curl -sL "$FILES_URL_PREFIX/.env.sample" -o "$APP_DIR/.env"
    colorized_echo green ".env file fetched"

    # Update database connection string if needed
    sed -i 's/^# \(SQLALCHEMY_DATABASE_URL = .*\)$/\1/' "$APP_DIR/.env"
    sed -i "s~\(SQLALCHEMY_DATABASE_URL = \).*~\1\"sqlite:///$DATA_DIR/db.sqlite3\"~" "$APP_DIR/.env"
    colorized_echo green "Database connection string set in $APP_DIR/.env"
    sed -i "s/your_secret_key_here/$api_key/" "$APP_DIR/.env"
    colorized_echo green "API secret key set in $APP_DIR/.env"

    colorized_echo green "LynxAPI's files downloaded and configured successfully"
}
