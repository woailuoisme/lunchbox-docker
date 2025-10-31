# Docker Installation Script

This script provides a cross-platform solution for installing Docker and Docker Compose using Alibaba Cloud mirrors. It supports both Ubuntu and CentOS-based systems.

## Features

- ✅ **Cross-platform support**: Ubuntu, CentOS, RHEL, Rocky Linux, AlmaLinux
- ✅ **Smart detection**: Checks if Docker and Docker Compose are already installed
- ✅ **Aliyun mirrors**: Uses Alibaba Cloud mirrors for faster downloads in China
- ✅ **Automatic configuration**: Sets up Docker daemon with optimized settings
- ✅ **User permissions**: Automatically adds current user to docker group

## Usage

### Basic Usage

```bash
# Make the script executable
chmod +x install-docker-simple.sh

# Run the script (requires sudo)
sudo ./install-docker-simple.sh
```

### What the Script Does

1. **Checks system requirements**
   - Verifies root privileges
   - Detects operating system
   - Checks if Docker/Docker Compose are already installed

2. **Installs Docker (if needed)**
   - Updates package repositories
   - Installs dependencies
   - Adds Docker repository using Aliyun mirrors
   - Installs Docker CE and related packages

3. **Installs Docker Compose (if needed)**
   - Installs Docker Compose plugin (V2)
   - Uses `docker compose` command (space, not dash)

4. **Configures Docker**
   - Starts and enables Docker service
   - Configures Aliyun registry mirrors for faster image pulling
   - Sets up logging and storage drivers

5. **Sets up user permissions**
   - Adds current user to docker group
   - Provides instructions for group changes to take effect

## Supported Systems

- **Ubuntu**: 18.04, 20.04, 22.04, 24.04
- **CentOS**: 7, 8, Stream
- **RHEL**: 7, 8, 9
- **Rocky Linux**: 8, 9
- **AlmaLinux**: 8, 9

## Behavior

- **If both Docker and Docker Compose are installed**: Script exits with success message
- **If only Docker Compose is missing**: Installs only Docker Compose plugin
- **If neither are installed**: Performs full installation

## Post-Installation

After installation, you may need to:

```bash
# Apply group changes without logging out
newgrp docker

# Or log out and log back in
```

## Verification

Verify the installation:

```bash
# Check Docker version
docker --version

# Check Docker Compose version
docker compose version

# Test Docker functionality
docker run hello-world
```

## Usage Examples

```bash
# Start services in background
docker compose up -d

# Stop services
docker compose down

# View service logs
docker compose logs [service-name]

# List running containers
docker ps

# Build images
docker compose build
```

## Registry Mirrors

The script configures Docker to use the following registry mirrors for faster image downloads in China:

- `https://registry.cn-hangzhou.aliyuncs.com` (Aliyun)
- `https://docker.mirrors.ustc.edu.cn` (USTC)
- `https://hub-mirror.c.163.com` (Netease)

## Troubleshooting

### Permission Denied

If you get permission errors:

```bash
# Add your user to docker group
sudo usermod -aG docker $USER

# Apply changes
newgrp docker
```

### Service Not Starting

If Docker service fails to start:

```bash
# Check service status
systemctl status docker

# Start service manually
sudo systemctl start docker

# Enable on boot
sudo systemctl enable docker
```

### Network Issues

If you have network connectivity issues:

```bash
# Check if Aliyun mirrors are accessible
curl -I http://mirrors.cloud.aliyuncs.com

# Try alternative mirrors
# Edit /etc/docker/daemon.json to modify registry mirrors
```

## File Structure

```
lunchbox/scripts/
├── install-docker-simple.sh  # Main installation script
└── README.md                 # This documentation
```

## Notes

- This script uses Docker Compose V2 (plugin) which uses `docker compose` command
- Traditional `docker-compose` (with dash) is not installed
- The script is idempotent - safe to run multiple times
- All installations use Alibaba Cloud mirrors for better performance in China

## License

This script is provided as-is for educational and deployment purposes.