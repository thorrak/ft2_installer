#!/usr/bin/env bash
#
# Fermentrack 2 Installer Script
#
# This script automates the installation of Fermentrack 2, including:
# - OS compatibility checking
# - Prerequisites installation
# - GitHub CLI setup and authentication
# - Docker installation
# - Node.js installation
# - Repository cloning/updating
# - Environment configuration
# - UI building
# - Docker container building and startup
#
# Usage: ./install.sh [OPTIONS]
# Run with --help for more information.
#

set -e  # Exit immediately on error

###############################################################################
# Color Output Helper Functions
###############################################################################

# Print informational message in blue
info() {
    printf '\033[0;34m[INFO]\033[0m %s\n' "$1"
}

# Print success message in green
success() {
    printf '\033[0;32m[SUCCESS]\033[0m %s\n' "$1"
}

# Print warning message in yellow
warning() {
    printf '\033[0;33m[WARNING]\033[0m %s\n' "$1"
}

# Print error message in red and exit
error() {
    printf '\033[0;31m[ERROR]\033[0m %s\n' "$1" >&2
    exit 1
}

###############################################################################
# Global Variables with Defaults
###############################################################################

INSTALL_DIR="$HOME/fermentrack_2"
MULTI_TENANT=false
NO_START=false
UNATTENDED=true
PORT=80
NO_PORT_CHECK=false

###############################################################################
# Help Function
###############################################################################

show_help() {
    cat << EOF
Fermentrack 2 Installer

Usage: $(basename "$0") [OPTIONS]

Options:
    --install-dir PATH    Set the installation directory
                          (default: \$HOME/fermentrack_2)
    --port PORT           Set the port to check/use (default: 80)
    --multi-tenant        Enable multi-tenant mode
    --no-start            Install but do not start the services
    --no-port-check       Skip the port availability check
    --interactive         Run in interactive mode (with prompts)
    --unattended          Run in unattended mode (default, no prompts)
    --help                Show this help message and exit

Examples:
    $(basename "$0")
        Install with default settings

    $(basename "$0") --install-dir /opt/fermentrack
        Install to a custom directory

    $(basename "$0") --multi-tenant --interactive
        Install in multi-tenant mode with prompts

EOF
}

###############################################################################
# Argument Parsing
###############################################################################

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --install-dir)
                if [[ -z "$2" || "$2" == --* ]]; then
                    error "--install-dir requires a PATH argument"
                fi
                INSTALL_DIR="$2"
                shift 2
                ;;
            --port)
                if [[ -z "$2" || "$2" == --* ]]; then
                    error "--port requires a PORT argument"
                fi
                PORT="$2"
                shift 2
                ;;
            --multi-tenant)
                MULTI_TENANT=true
                shift
                ;;
            --no-start)
                NO_START=true
                shift
                ;;
            --no-port-check)
                NO_PORT_CHECK=true
                shift
                ;;
            --interactive)
                UNATTENDED=false
                shift
                ;;
            --unattended)
                UNATTENDED=true
                shift
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                error "Unknown option: $1. Use --help for usage information."
                ;;
        esac
    done
}

###############################################################################
# Phase Functions (Stubs)
###############################################################################

# Check operating system compatibility
check_os() {
    info "Checking operating system compatibility..."

    # Initialize global variable
    OS_ID="unknown"

    # Check if we're on Linux
    if [[ "$(uname -s)" != "Linux" ]]; then
        error "This installer only supports Linux operating systems."
    fi

    # Check if /etc/os-release exists
    if [[ ! -f /etc/os-release ]]; then
        error "Cannot detect OS: /etc/os-release not found. This installer requires a Debian-based Linux distribution."
    fi

    # Read OS information
    # shellcheck source=/dev/null
    source /etc/os-release
    OS_ID="${ID:-unknown}"

    case "$OS_ID" in
        debian|raspbian)
            success "Running on ${PRETTY_NAME:-$OS_ID}"
            ;;
        ubuntu)
            warning "Running on ${PRETTY_NAME:-Ubuntu}, which is not a tested distribution."
            warning "The installer may work, but is designed for Debian/Raspbian."
            if [[ "$UNATTENDED" != true ]]; then
                read -r -p "Do you want to continue anyway? [y/N] " response
                case "$response" in
                    [yY][eE][sS]|[yY])
                        info "Continuing with installation on $OS_ID..."
                        ;;
                    *)
                        error "Installation cancelled by user."
                        ;;
                esac
            else
                warning "Unattended mode: continuing with installation on $OS_ID..."
            fi
            ;;
        *)
            warning "Running on ${PRETTY_NAME:-$OS_ID}, which is not a tested distribution."
            warning "The installer is designed for Debian/Raspbian."
            if [[ "$UNATTENDED" != true ]]; then
                read -r -p "Do you want to continue anyway? [y/N] " response
                case "$response" in
                    [yY][eE][sS]|[yY])
                        info "Continuing with installation on $OS_ID..."
                        ;;
                    *)
                        error "Installation cancelled by user."
                        ;;
                esac
            else
                warning "Unattended mode: continuing with installation on $OS_ID..."
            fi
            ;;
    esac

    # Check that apt-get is available
    if ! command -v apt-get &> /dev/null; then
        error "apt-get is not available. This installer requires a Debian-based distribution with apt."
    fi

    success "Operating system check passed."
}

# Check if the target port is available
check_port() {
    if [[ "$NO_PORT_CHECK" == true ]]; then
        info "Skipping port check (--no-port-check flag provided)"
        return 0
    fi

    info "Checking if port $PORT is available..."

    # Try to fetch from localhost on the specified port
    local response
    local curl_exit_code

    response=$(curl -s --connect-timeout 5 "http://localhost:$PORT" 2>/dev/null) || curl_exit_code=$?

    # If curl failed with connection refused (exit code 7), port is free
    if [[ ${curl_exit_code:-0} -eq 7 ]]; then
        success "Port $PORT is available."
        return 0
    fi

    # If curl succeeded or got a different error, something is listening
    if [[ ${curl_exit_code:-0} -eq 0 ]]; then
        # Check if the response contains "Fermentrack 2"
        if echo "$response" | grep -q "Fermentrack 2"; then
            warning "Port $PORT is in use by an existing Fermentrack 2 installation."
            warning "This appears to be an upgrade. The existing installation will be updated."
            return 0
        else
            error "Port $PORT is already in use by another application. Please stop the application using this port or use --port to specify a different port. You can also use --no-port-check to skip this check."
        fi
    else
        # Curl failed with a different error (timeout, etc.) - something might be there
        warning "Port $PORT appears to be in use but not responding to HTTP requests."
        warning "This could be a non-HTTP service or a slow-starting application."
        if [[ "$UNATTENDED" != true ]]; then
            read -r -p "Do you want to continue anyway? [y/N] " response
            case "$response" in
                [yY][eE][sS]|[yY])
                    info "Continuing with installation..."
                    ;;
                *)
                    error "Installation cancelled by user."
                    ;;
            esac
        else
            warning "Unattended mode: continuing with installation..."
        fi
    fi
}

# Install system prerequisites
install_prerequisites() {
    info "Installing prerequisites..."

    # Define required packages
    local required_packages=(git curl build-essential)
    local packages_to_install=()

    # Check each package
    for package in "${required_packages[@]}"; do
        if dpkg -s "$package" &> /dev/null; then
            info "Package '$package' is already installed."
        elif command -v "$package" &> /dev/null; then
            # Fallback: check if the command exists (for packages that might be installed differently)
            info "Command '$package' is available."
        else
            info "Package '$package' needs to be installed."
            packages_to_install+=("$package")
        fi
    done

    # Install missing packages if any
    if [[ ${#packages_to_install[@]} -gt 0 ]]; then
        info "Installing missing packages: ${packages_to_install[*]}"

        info "Updating package lists..."
        if ! sudo apt-get update; then
            error "Failed to update package lists. Please check your internet connection and try again."
        fi

        info "Installing packages..."
        if ! sudo apt-get install -y "${packages_to_install[@]}"; then
            error "Failed to install packages. Please check the errors above and try again."
        fi

        success "Successfully installed: ${packages_to_install[*]}"
    else
        info "All prerequisite packages are already installed."
    fi

    success "Prerequisites installation completed."
}

# Install GitHub CLI and authenticate
install_gh_and_auth() {
    info "Setting up GitHub CLI and authentication..."

    # Part 1: Install GitHub CLI if not present
    if command -v gh &> /dev/null; then
        info "GitHub CLI is already installed"
    else
        info "Installing GitHub CLI..."
        sudo mkdir -p -m 755 /etc/apt/keyrings
        wget -qO- https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null
        sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
        sudo apt-get update
        sudo apt-get install gh -y
        success "GitHub CLI installed successfully"
    fi

    # Part 2: Authenticate if needed
    if gh auth status &> /dev/null; then
        info "GitHub CLI is already authenticated"
    else
        info "GitHub CLI authentication required..."
        if [[ "$UNATTENDED" == true ]]; then
            error "GitHub authentication is required but running in unattended mode. Please authenticate manually with 'gh auth login' before running in unattended mode."
        fi
        info "Starting interactive GitHub authentication..."
        gh auth login
        success "GitHub authentication completed"
    fi

    # Set up git credential helper to use gh authentication
    info "Configuring git to use GitHub CLI credentials..."
    gh auth setup-git
    success "Git credential helper configured"

    # Validate repository access
    info "Validating access to Fermentrack repository..."
    if ! gh repo view thorrak/fermentrack_2 --json name &> /dev/null; then
        error "Unable to access the thorrak/fermentrack_2 repository. Please ensure you have access to this repository and that your GitHub authentication is correct. You may need to request access or check your organization membership."
    fi
    success "Repository access validated"
}

# Install Docker
install_docker() {
    info "Setting up Docker..."

    # Part 1: Install Docker if not present
    if ! command -v docker &> /dev/null; then
        info "Installing Docker..."
        curl -fsSL https://get.docker.com | sh

        # Verify installation succeeded
        if ! command -v docker &> /dev/null; then
            error "Docker installation failed. Please install Docker manually and re-run this script."
        fi
        success "Docker installed successfully."
    else
        success "Docker is already installed."
    fi

    # Part 2: Handle docker group membership
    local user_in_group=false
    local docker_works=false

    # Check if user is in docker group
    if id -nG "$USER" | grep -qw docker; then
        user_in_group=true
    fi

    # Check if docker commands work without sudo
    if docker ps >/dev/null 2>&1; then
        docker_works=true
    fi

    # Scenario 1: User in group AND docker ps works - success, proceed
    if [[ "$user_in_group" == true && "$docker_works" == true ]]; then
        success "Docker is properly configured and ready to use."
        return 0
    fi

    # Scenario 2: User NOT in group - add to group, then exit with logout message
    if [[ "$user_in_group" == false ]]; then
        info "Adding user '$USER' to the docker group..."
        sudo usermod -aG docker "$USER"

        cat << 'EOF'

╔════════════════════════════════════════════════════════════════╗
║  ACTION REQUIRED: You need to log out and log back in          ║
║  for Docker group membership to take effect.                   ║
║                                                                ║
║  After logging back in, re-run this installer.                 ║
╚════════════════════════════════════════════════════════════════╝

EOF
        exit 0
    fi

    # Scenario 3: User in group BUT docker ps fails - they haven't logged out/in yet
    if [[ "$user_in_group" == true && "$docker_works" == false ]]; then
        cat << 'EOF'

╔════════════════════════════════════════════════════════════════╗
║  ACTION REQUIRED: You need to log out and log back in          ║
║  for Docker group membership to take effect.                   ║
║                                                                ║
║  After logging back in, re-run this installer.                 ║
╚════════════════════════════════════════════════════════════════╝

EOF
        exit 0
    fi
}

# Install Node.js
install_nodejs() {
    info "Checking Node.js installation..."

    if command -v node &> /dev/null; then
        # Node.js is installed, check version
        local node_version
        node_version=$(node --version)
        # Extract major version number (e.g., v20.10.0 -> 20)
        local major_version
        major_version=$(echo "$node_version" | sed 's/^v//' | cut -d'.' -f1)

        if [[ "$major_version" -lt 18 ]]; then
            warning "Node.js $node_version is installed but is outdated (major version $major_version < 18)."
            warning "It is recommended to upgrade to Node.js 18 or later."
            warning "Continuing with the current version..."
        else
            success "Node.js $node_version is installed and meets the minimum requirement (>= 18)."
        fi
    else
        # Node.js is not installed, install it
        info "Node.js is not installed. Installing Node.js 20 LTS via NodeSource..."

        # Run the NodeSource setup script
        info "Adding NodeSource repository..."
        curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -

        # Install Node.js
        info "Installing Node.js package..."
        sudo apt-get install -y nodejs

        # Verify installation
        if command -v node &> /dev/null && command -v npm &> /dev/null; then
            local installed_node_version
            local installed_npm_version
            installed_node_version=$(node --version)
            installed_npm_version=$(npm --version)
            success "Node.js $installed_node_version installed successfully."
            success "npm $installed_npm_version installed successfully."
        else
            error "Node.js installation failed. Please install Node.js manually."
        fi
    fi
}

# Helper function to initialize/update submodules with SSH->HTTPS fallback
init_submodules() {
    local repo_dir="$1"

    cd "$repo_dir"

    # First attempt: try submodule update as-is
    if git submodule update --init --recursive 2>/dev/null; then
        return 0
    fi

    # If that failed, rewrite SSH URLs to HTTPS in .gitmodules and retry
    info "Submodule fetch failed, converting SSH URLs to HTTPS..."
    if [[ -f .gitmodules ]]; then
        sed -i 's|git@github.com:|https://github.com/|g' .gitmodules
        git submodule sync
    fi

    if ! git submodule update --init --recursive; then
        error "Failed to update submodules even with HTTPS fallback."
    fi

    return 0
}

# Clone or update the Fermentrack repository
clone_or_update_repo() {
    # Scenario 1: Directory doesn't exist (fresh install)
    if [[ ! -d "$INSTALL_DIR" ]]; then
        info "Cloning Fermentrack 2 repository..."

        if ! gh repo clone thorrak/fermentrack_2 "$INSTALL_DIR"; then
            error "Failed to clone the Fermentrack 2 repository."
        fi

        info "Initializing submodules..."
        init_submodules "$INSTALL_DIR"

        # Verify the ui/ submodule is populated
        if [[ ! -f "$INSTALL_DIR/ui/package.json" ]]; then
            error "Submodule initialization failed: ui/package.json not found. The ui/ submodule may not have been cloned properly."
        fi

        success "Successfully cloned Fermentrack 2 repository."
        return 0
    fi

    # Directory exists - check if it's a git repository
    if [[ ! -d "$INSTALL_DIR/.git" ]]; then
        # Scenario 3: Directory exists but is NOT a git repo
        error "Directory $INSTALL_DIR exists but is not a git repository. Please remove it or choose a different install directory."
    fi

    # It's a git repo - check if it's the correct one
    local remote_url
    remote_url=$(git -C "$INSTALL_DIR" remote get-url origin 2>/dev/null || echo "")

    if [[ "$remote_url" != *"fermentrack_2"* ]]; then
        # Scenario 4: Directory exists but is a different repo
        error "Directory $INSTALL_DIR contains a different git repository. Please remove it or choose a different install directory."
    fi

    # Scenario 2: Directory exists and is the correct repo
    info "Updating existing Fermentrack 2 installation..."

    cd "$INSTALL_DIR"

    if ! git fetch; then
        error "Failed to fetch updates from the remote repository."
    fi

    if ! git pull; then
        error "Failed to pull updates from the remote repository."
    fi

    info "Updating submodules..."
    init_submodules "$INSTALL_DIR"

    # Verify ui/ submodule is populated
    if [[ ! -f "$INSTALL_DIR/ui/package.json" ]]; then
        error "Submodule verification failed: ui/package.json not found. The ui/ submodule may not have been updated properly."
    fi

    success "Successfully updated Fermentrack 2 repository."
}

# Configure environment settings
configure_environment() {
    info "Configuring environment..."

    # Define paths
    local PRODUCTION_DIR="$INSTALL_DIR/.envs/.production"
    local SAMPLE_DIR="$INSTALL_DIR/.envs/.production_sample"

    # Check if .production already exists (idempotent - preserve existing secrets)
    if [[ -d "$PRODUCTION_DIR" ]]; then
        info "Existing configuration found, preserving your settings..."
        return 0
    fi

    # Fresh setup - create production environment from sample
    info "Creating production environment configuration..."

    # Verify sample directory exists
    if [[ ! -d "$SAMPLE_DIR" ]]; then
        error "Sample configuration directory not found: $SAMPLE_DIR"
    fi

    # Copy sample directory to production
    cp -r "$SAMPLE_DIR" "$PRODUCTION_DIR"

    # Generate Django secret key
    local DJANGO_SECRET
    DJANGO_SECRET=$(openssl rand -base64 48)

    # Update .django file with generated secret
    sed -i "s/^DJANGO_SECRET_KEY=.*/DJANGO_SECRET_KEY=$DJANGO_SECRET/" "$PRODUCTION_DIR/.django"

    # Generate Fernet key for django-encrypted-fields (URL-safe base64-encoded 32 bytes)
    local FERNET_KEY
    FERNET_KEY=$(openssl rand -base64 32 | tr '+/' '-_' | tr -d '\n')

    # Uncomment and set DJANGO_ENCRYPTED_FIELDS_SALT_KEY
    sed -i "s/^# DJANGO_ENCRYPTED_FIELDS_SALT_KEY=$/DJANGO_ENCRYPTED_FIELDS_SALT_KEY=$FERNET_KEY/" "$PRODUCTION_DIR/.django"

    # Configure PostgreSQL credentials
    local POSTGRES_PASS
    POSTGRES_PASS=$(openssl rand -base64 32)

    # Update .postgres file with credentials
    sed -i "s/^POSTGRES_USER=.*/POSTGRES_USER=fermentrack/" "$PRODUCTION_DIR/.postgres"
    sed -i "s/^POSTGRES_PASSWORD=.*/POSTGRES_PASSWORD=$POSTGRES_PASS/" "$PRODUCTION_DIR/.postgres"

    # Handle multi-tenant mode
    if [[ "$MULTI_TENANT" == true ]]; then
        # Check if FERMENTRACK_MULTI_TENANT_MODE already exists in .django
        if ! grep -q "^FERMENTRACK_MULTI_TENANT_MODE=" "$PRODUCTION_DIR/.django"; then
            echo "FERMENTRACK_MULTI_TENANT_MODE=True" >> "$PRODUCTION_DIR/.django"
        fi
    fi

    success "Environment configuration complete"
}

# Build the UI components
build_ui() {
    info "Building Fermentrack 2 UI..."

    cd "$INSTALL_DIR/ui"

    info "Installing npm dependencies..."
    if ! npm install; then
        error "Failed to install npm dependencies. Please ensure Node.js and npm are properly installed. You can check with 'node --version' and 'npm --version'."
    fi

    info "Building UI application..."
    if ! npm run build; then
        error "Failed to build UI. Please check the build output above for errors. Common issues include missing dependencies or TypeScript errors."
    fi

    success "UI build complete"
}

# Build and start Docker containers
build_and_start_docker() {
    info "Building Docker containers..."

    cd "$INSTALL_DIR"

    if ! docker compose -f production.yml build; then
        error "Failed to build Docker containers. Please ensure Docker is properly installed and running. You can check with 'docker --version' and 'docker compose version'."
    fi

    success "Docker build complete"

    if [[ "$NO_START" == true ]]; then
        info "Skipping service start (--no-start flag provided)"
        return 0
    fi

    info "Starting Fermentrack 2 services..."

    if ! docker compose -f production.yml up -d; then
        error "Failed to start Docker containers. Please check the Docker logs for more information."
    fi

    success "Services started"
}

###############################################################################
# Main Function
###############################################################################

main() {
    # Parse command line arguments
    parse_arguments "$@"

    # Display welcome banner
    cat << 'EOF'

███████╗███████╗██████╗ ███╗   ███╗███████╗███╗   ██╗████████╗██████╗  █████╗  ██████╗██╗  ██╗██████╗
██╔════╝██╔════╝██╔══██╗████╗ ████║██╔════╝████╗  ██║╚══██╔══╝██╔══██╗██╔══██╗██╔════╝██║ ██╔╝╚════██╗
█████╗  █████╗  ██████╔╝██╔████╔██║█████╗  ██╔██╗ ██║   ██║   ██████╔╝███████║██║     █████╔╝  █████╔╝
██╔══╝  ██╔══╝  ██╔══██╗██║╚██╔╝██║██╔══╝  ██║╚██╗██║   ██║   ██╔══██╗██╔══██║██║     ██╔═██╗ ██╔═══╝
██║     ███████╗██║  ██║██║ ╚═╝ ██║███████╗██║ ╚████║   ██║   ██║  ██║██║  ██║╚██████╗██║  ██╗███████╗
╚═╝     ╚══════╝╚═╝  ╚═╝╚═╝     ╚═╝╚══════╝╚═╝  ╚═══╝   ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝╚══════╝

                              Fermentrack 2 Installer

EOF

    info "Starting Fermentrack 2 installation..."
    info "Installation directory: $INSTALL_DIR"
    info "Port: $PORT"
    info "Multi-tenant mode: $MULTI_TENANT"
    info "No-start mode: $NO_START"
    info "No-port-check mode: $NO_PORT_CHECK"
    info "Unattended mode: $UNATTENDED"
    echo ""

    # Execute each installation phase in order
    check_os
    echo ""

    check_port
    echo ""

    install_prerequisites
    echo ""

    install_gh_and_auth
    echo ""

    install_docker
    echo ""

    install_nodejs
    echo ""

    clone_or_update_repo
    echo ""

    configure_environment
    echo ""

    build_ui
    echo ""

    build_and_start_docker
    echo ""

    # Display final success message
    success "=============================================="
    success "Fermentrack 2 installation completed!"
    success "=============================================="
    echo ""
    info "Installation directory: $INSTALL_DIR"
    echo ""

    if [[ "$NO_START" == true ]]; then
        info "Services were not started (--no-start flag was used)"
        info "To start services, run:"
        echo "    cd $INSTALL_DIR && docker compose -f production.yml up -d"
    else
        info "Services are now running!"
        info "Access Fermentrack at: http://localhost"
        info "(If accessing from another device, use your server's IP address)"
    fi

    echo ""
    info "Useful commands:"
    echo "    View logs:        cd $INSTALL_DIR && docker compose -f production.yml logs -f"
    echo "    Stop services:    cd $INSTALL_DIR && docker compose -f production.yml down"
    echo "    Restart:          cd $INSTALL_DIR && docker compose -f production.yml restart"
    echo ""
    success "Thank you for installing Fermentrack 2!"
}

###############################################################################
# Script Entry Point
###############################################################################

main "$@"
