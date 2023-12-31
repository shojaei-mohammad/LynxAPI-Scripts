#!/bin/bash

# Define variables
REPO_URL="https://github.com/shojaei-mohammad/LynxAPI.git"
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )" # Gets the directory where the script is located
MAIN_DIR="$SCRIPT_DIR/LynxAPI"
SOURC_DIR="$MAIN_DIR/code"
ENV_FILE="$SOURC_DIR/.env"
ENV_SAMPLE_FILE="$SOURC_DIR/.env.sample"
NETWORK_CONFIG_SCRIPT="$SOURC_DIR/app/scripts/network-config.sh"
DATABASE_DIR="$SOURC_DIR/data"
DATABASE_FILE="rbac_db.db"
DATABASE_URL="sqlite:///$DATABASE_DIR/$DATABASE_FILE"
CREATE_USER_SCRIPT="$SOURC_DIR/app/db/create_user.py"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Helper function for colored echo
colored_echo() {
    echo -e "${GREEN}$1${NC}"
}

# Function to install Python 3.10 or later
install_python() {
    colored_echo "Installing Python 3.10 or later..."
    sudo apt-get update
    sudo apt-get install -y software-properties-common
    sudo add-apt-repository ppa:deadsnakes/ppa -y
    sudo apt-get update
    sudo apt-get install -y python3.10
}

# Check the installed Python version
installed_python_version=$(python3 -c "import sys; print('.'.join(map(str, sys.version_info[:2])))")

# Check if Python 3.10 or later is installed
if [ "$(printf '%s\n' "3.10" "$installed_python_version" | sort -V | head -n1)" != "3.10" ]; then
    install_python
else
    colored_echo "Python $installed_python_version is installed."
fi

# Check if pip is installed, if not, install it
if ! command -v pip3 &> /dev/null; then
    colored_echo "pip is not installed. Installing pip..."
    sudo apt-get install -y python3-pip
else
    colored_echo "pip is already installed."
fi

# Check if venv is installed, if not, install it
if ! command -v virtualenv &> /dev/null; then
    colored_echo "venv is not installed. Installing venv..."
    sudo pip3 install virtualenv
else
    colored_echo "venv is already installed."
fi

# Step 1: Clone the FastAPI app repository
colored_echo "Cloning the repository..."
git clone $REPO_URL "$SOURC_DIR"

# Step 2: Create a virtual environment in the main directory
colored_echo "Creating a virtual environment..."
virtualenv -p python3.10 "$MAIN_DIR"/venv

# Activate the virtual environment
source "$MAIN_DIR"/venv/bin/activate

# shellcheck disable=SC2164
cd "$SOURC_DIR"

# Step 3: Install the requirements in the virtual environment
colored_echo "Installing requirements in the virtual environment..."
pip install -r ./requirements.txt

# Step 4: Initialize the database directory
colored_echo "Creating the database directory..."
mkdir -p "$DATABASE_DIR"

# Step 5: Generate a secure API secret (using openssl for generating a secure random string)
colored_echo "Generating a secure API secret..."
API_SECRET_VALUE=$(openssl rand -hex 32)

# Step 6: Replace the API secret in the .env file, update paths, and read Uvicorn settings
colored_echo "Configuring environment variables..."
cp "$ENV_SAMPLE_FILE" "$ENV_FILE"

sed -i "s|API_SECRET_KEY=your_secret_key_here|API_SECRET_KEY=$API_SECRET_VALUE|" "$ENV_FILE"
sed -i "s|SCRIPTS_PATH=/path/to/app/scripts/network-config.sh|SCRIPTS_PATH=$NETWORK_CONFIG_SCRIPT|" "$ENV_FILE"
sed -i "s|SQLALCHEMY_DATABASE_URL=\"sqlite:////path/to/code/data/db.sqlite3\"|SQLALCHEMY_DATABASE_URL=\"$DATABASE_URL\"|" "$ENV_FILE"

# Read Uvicorn settings from .env
UVICORN_HOST=$(grep UVICORN_HOST "$ENV_FILE" | cut -d '=' -f2)
UVICORN_PORT=$(grep UVICORN_PORT "$ENV_FILE" | cut -d '=' -f2)

# Step 7: Run session.py to initialize the database
colored_echo "Initializing the database..."
export PYTHONPATH="${PYTHONPATH}:$SOURC_DIR"
python3 app/db/session.py

# Step 8: Create an API user
colored_echo "Creating an API user..."
python3 "$CREATE_USER_SCRIPT"

# Step 9: Run the FastAPI app using Uvicorn with settings from the .env file
colored_echo "Starting the FastAPI app using Uvicorn..."
nohup uvicorn app.main:app --host "$UVICORN_HOST" --port "$UVICORN_PORT" &

# Provide user feedback
colored_echo "FastAPI app installation is complete and running on http://$UVICORN_HOST:$UVICORN_PORT"

# End of script
