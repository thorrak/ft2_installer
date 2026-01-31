# Fermentrack 2 Installer

Automated installation script for [Fermentrack 2](https://github.com/thorrak/fermentrack_2).

## Quick Start

```bash
curl -fsSL https://install_ft2.fermentrack.com | bash
```

Or clone and run locally:

```bash
git clone https://github.com/thorrak/ft2_installer.git
cd ft2_installer
./install.sh
```

## Requirements

- **Operating System:** Debian or Raspberry Pi OS (other Debian-based distros may work)
- **Architecture:** x86_64 or ARM (Raspberry Pi)
- **Permissions:** sudo access required
- **GitHub Access:** Access to the private `fermentrack_2` and `fermentrack_ui` repositories (temporary requirement)

## What Gets Installed

The installer will set up:

- **Git, curl, build-essential** - Basic build tools
- **GitHub CLI (gh)** - For repository access
- **Docker** - Container runtime
- **Node.js 20 LTS** - For building the UI
- **Fermentrack 2** - The application itself

## Command-Line Options

| Option               | Description                                                  |
|----------------------|--------------------------------------------------------------|
| `--install-dir PATH` | Installation directory (default: `~/fermentrack_2`)          |
| `--port PORT`        | Port to check for availability (default: `80`)               |
| `--multi-tenant`     | Enable multi-tenant mode                                     |
| `--no-start`         | Build but don't start services                               |
| `--no-port-check`    | Skip the port availability check                             |
| `--unattended`       | Non-interactive mode (requires pre-authenticated GitHub CLI) |
| `--help`             | Show help message                                            |

### Examples

```bash
# Install with defaults
./install.sh

# Install to custom directory
./install.sh --install-dir /opt/fermentrack

# Install with multi-tenant mode enabled
./install.sh --multi-tenant

# Build only, don't start services
./install.sh --no-start
```

## Installation Process

The installer performs these steps:

1. **OS Check** - Verifies compatible Linux distribution
2. **Port Check** - Verifies target port is available (detects existing Fermentrack 2 installations)
3. **Prerequisites** - Installs git, curl, build-essential
4. **GitHub CLI** - Installs and authenticates gh
5. **Docker** - Installs Docker and configures user permissions
6. **Node.js** - Installs Node.js 20 LTS via NodeSource
7. **Repository** - Clones or updates Fermentrack 2
8. **Configuration** - Creates environment files with generated secrets
9. **UI Build** - Builds the frontend application
10. **Docker Build** - Builds the application containers
11. **Start** - Launches Fermentrack 2

## First Run Notes

On the first run, you may need to **log out and back in** after Docker is installed. This is required for Docker group membership to take effect. Simply re-run the installer after logging back in.

## Idempotency

The installer is safe to run multiple times:

- Already-installed packages are skipped
- Existing configuration files are preserved
- Repository updates are pulled automatically
- Docker images are rebuilt with layer caching

## Post-Installation

After installation completes, Fermentrack 2 will be accessible at:

- **Local:** http://localhost
- **Remote:** http://YOUR_SERVER_IP

### Useful Commands

```bash
# View logs
cd ~/fermentrack_2 && docker compose -f production.yml logs -f

# Stop services
cd ~/fermentrack_2 && docker compose -f production.yml down

# Restart services
cd ~/fermentrack_2 && docker compose -f production.yml restart

# Update Fermentrack 2
./install.sh  # Just re-run the installer
```

## Troubleshooting

### Port 80 is already in use

If another application is using port 80, you have several options:

```bash
# Check what's using the port
sudo lsof -i :80

# Use a different port (note: you'll also need to configure Docker to use this port)
./install.sh --port 8080

# Skip the port check entirely
./install.sh --no-port-check
```

### "Permission denied" when running Docker

Log out and back in to apply Docker group membership, then re-run the installer.

### GitHub authentication fails

Run `gh auth login` manually and follow the prompts, then re-run the installer.

### UI build fails

Ensure Node.js is properly installed:
```bash
node --version  # Should be v18 or higher
npm --version
```

### Docker build fails

Check Docker is running:
```bash
docker --version
docker compose version
docker ps
```

## License

See the [Fermentrack 2 repository](https://github.com/thorrak/fermentrack_2) for license information.
