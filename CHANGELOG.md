# Changelog

All notable changes to GlideProxy will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2024-06-26 - ИСПРАВЛЕННАЯ ВЕРСИЯ

### 🔧 Critical Fixes
- **nginx Configuration**: Fixed double escape symbols (\\$ → \$) causing syntax errors
- **Port Conflicts**: Added port usage detection with netstat before installation
- **Project Conflicts**: Added existing project detection with cleanup option
- **Script Creation**: Ensured all management scripts are created reliably

### ✨ New Features
- **create_nginx_config()**: New function with proper escape handling using << 'EOF'
- **create_management_scripts()**: Dedicated function for management script creation
- **Project Validation**: Pre-installation checks for conflicts and dependencies

### 🛠 Improvements
- Added `net-tools` package for netstat command
- Enhanced error handling and user feedback
- Better validation of installation parameters
- Improved documentation and troubleshooting guides

### 🐛 Bug Fixes
- Fixed nginx configuration syntax errors
- Fixed SSL certificate acquisition issues
- Fixed PM2 process management conflicts
- Fixed management script creation interruptions

### 📦 Dependencies
- Added: net-tools (for netstat command)

### 🔄 Migration
- Fully backward compatible with v1.0 installations
- Can be used to update existing configurations
- No breaking changes to existing deployments

## [1.1.0] - 2024-12-28

### Fixed
- Fixed nginx configuration escaping issues (\\$ -> \$)
- Added project existence check with cleanup option
- Added port conflict detection and warnings
- Improved script creation with proper functions
- Better error handling and validation

### Improved
- Multiple proxy instances support on same server
- Enhanced installer reliability and robustness
- Better user feedback and warnings

## [1.0.0] - 2024-12-28

### Added
- Initial release of GlideProxy Universal Reverse Proxy Installer
- Automatic Node.js 18.x installation and configuration
- PM2 process manager with memory limits and auto-restart
- nginx SSL termination with Let's Encrypt certificates
- Advanced URL rewriting for HTML/CSS/JavaScript content
- Comprehensive health monitoring with periodic target checks
- Winston logging with daily rotation
- Production-ready security configuration (HSTS, rate limiting, security headers)
- UFW firewall automatic configuration
- Interactive and automated installation modes
- One-liner installation support
- Management scripts (status, restart, logs, SSL renewal)
- Comprehensive documentation and usage examples

### Features
- **Automatic SSL**: Let's Encrypt certificates with auto-renewal
- **Security**: TLS 1.2/1.3, HSTS headers, rate limiting, attack pattern blocking
- **Monitoring**: Health checks, comprehensive logging, PM2 monitoring
- **URL Rewriting**: Advanced content transformation for HTML/CSS/JS
- **Management**: Ready-to-use scripts for common operations
- **Flexibility**: Configurable parameters for different use cases

### Supported Systems
- Ubuntu 18.04+ (recommended 20.04+)
- Debian 10+
- CentOS 8+ (requires adaptation)

### Minimum Requirements
- RAM: 512MB (recommended 1GB+)
- Disk: 2GB free space
- Network: Internet access for package installation
- Ports: 22 (SSH), 80 (HTTP), 443 (HTTPS) 