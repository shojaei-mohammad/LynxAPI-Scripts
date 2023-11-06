#!/bin/bash

# Define variables
REPO_URL="https://github.com/your-username/your-repo.git" # Replace with your repository URL
MAIN_DIR="LynxAPI" # Directory name for the cloned repository
ENV_FILE="$MAIN_DIR/.env"
ENV_SAMPLE_FILE="$MAIN_DIR/.env.sample"
NETWORK_CONFIG_SCRIPT="$MAIN_DIR/app/scripts/network-config.sh"
DATABASE_DIR="$MAIN_DIR/data"
DATABASE_FILE="rbac_db.db"
DATABASE_URL="sqlite:///$DATABASE_DIR/$DATABASE_FILE"
CREATE_USER_SCRIPT="$MAIN_DIR/app/utils/create_user.py"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Helper function for colored echo
colored_echo() {
    echo -e "${GREEN}$1${NC}"
}

# Step 1: Clone the FastAPI app repository
colored_echo "Cloning the repository..."
git clone $REPO_URL $MAIN_DIR
cd $MAIN_DIR

# Step 2: Install the requirements (Assuming you have Python & pip installed)
colored_echo "Installing requirements..."
pip install -r requirements.txt

# Step 3: Initialize the database directory
colored_echo "Creating the database directory..."
mkdir -p $DATABASE_DIR

# Step 4: Run session.py to initialize the database
colored_echo "Initializing the database..."
python app/db/session.py

# Step 5: Generate a secure API secret (using openssl for generating a secure random string)
colored_echo "Generating a secure API secret..."
API_SECRET_VALUE=$(openssl rand -hex 32)

# Step 6: Replace the API secret in the .env file, update paths, and read Uvicorn settings
colored_echo "Configuring environment variables..."
cp $ENV_SAMPLE_FILE $ENV_FILE

sed -i "s|API_SECRET_KEY=your_secret_key_here|API_SECRET_KEY=$API_SECRET_VALUE|" $ENV_FILE
sed -i "s|SCRIPTS_PATH=/path/to/app/scripts/network-config.sh|SCRIPTS_PATH=$NETWORK_CONFIG_SCRIPT|" $ENV_FILE
sed -i "s|SQLALCHEMY_DATABASE_URL=\"sqlite:///path/to/db.sqlite3\"|SQLALCHEMY_DATABASE_URL=\"$DATABASE_URL\"|" $ENV_FILE

# Read Uvicorn settings from .env
UVICORN_HOST=$(grep UVICORN_HOST $ENV_FILE | cut -d '=' -f2)
UVICORN_PORT=$(grep UVICORN_PORT $ENV_FILE | cut -d '=' -f2)

# Step 7: Create an API user
colored_echo "Creating an API user..."
python $CREATE_USER_SCRIPT

# Step 8: Run the FastAPI app using Uvicorn with settings from the .env file
colored_echo "Starting the FastAPI app using Uvicorn..."
nohup uvicorn app.main:app --host "$UVICORN_HOST" --port "$UVICORN_PORT" &

# Provide user feedback
colored_echo "FastAPI app installation is complete and running on http://$UVICORN_HOST:$UVICORN_PORT"

# End of script
