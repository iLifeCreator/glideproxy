#!/bin/bash

# Automated Installation Script для Enhanced Proxy v2.5-FINAL
# Оптимизированная установка для серверов 2 ядра / 4ГБ ОЗУ
# Автор: iLifeCreator
# Версия: 1.0

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
DOMAIN=${1:-"example.com"}
EMAIL=${2:-"admin@example.com"}
TARGET_DOMAIN=${3:-"app.example.com"}

echo -e "${BLUE}=== Enhanced Proxy v2.5-FINAL Automated Installation ===${NC}"
echo -e "${BLUE}Domain: ${DOMAIN}${NC}"
echo -e "${BLUE}Email: ${EMAIL}${NC}"
echo -e "${BLUE}Target: ${TARGET_DOMAIN}${NC}"
echo ""

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   echo -e "${RED}This script should not be run as root${NC}"
   exit 1
fi

# Function to log messages
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
    exit 1
}

warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

# Check system requirements
log "Checking system requirements..."

# Check available memory
TOTAL_MEM=$(free -m | awk 'NR==2{printf "%.0f", $2}')
if [ "$TOTAL_MEM" -lt 3000 ]; then
    warning "System has less than 3GB RAM ($TOTAL_MEM MB). This may affect performance."
fi

# Check CPU cores
CPU_CORES=$(nproc)
if [ "$CPU_CORES" -lt 2 ]; then
    warning "System has less than 2 CPU cores ($CPU_CORES). Performance may be limited."
fi

log "System specs: ${CPU_CORES} CPU cores, ${TOTAL_MEM}MB RAM"

# Update system packages
log "Updating system packages..."
sudo apt update && sudo apt upgrade -y

# Install required packages
log "Installing required packages..."
sudo apt install -y curl wget git nginx certbot python3-certbot-nginx htop build-essential

# Install Node.js 18.x
log "Installing Node.js 18.x..."
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs

# Verify installations
log "Verifying installations..."
node --version || error "Node.js installation failed"
npm --version || error "NPM installation failed"
nginx -v || error "Nginx installation failed"

# Install PM2 globally
log "Installing PM2 process manager..."
sudo npm install -g pm2

# Create project directory
PROJECT_DIR="/home/$(whoami)/enhanced-proxy-production"
log "Creating project directory: $PROJECT_DIR"
mkdir -p "$PROJECT_DIR"
cd "$PROJECT_DIR"

# Initialize Node.js project
log "Setting up Node.js project..."
cat > package.json << EOF
{
  "name": "enhanced-proxy-production",
  "version": "2.5.0",
  "description": "Enhanced Simple Proxy Server v2.5-FINAL - Production Optimized",
  "main": "src/enhanced-simple-proxy-final.js",
  "scripts": {
    "start": "node src/enhanced-simple-proxy-final.js",
    "pm2": "pm2 start ecosystem.single.config.js --env production",
    "pm2:stop": "pm2 stop enhanced-proxy-single",
    "pm2:restart": "pm2 restart enhanced-proxy-single",
    "pm2:logs": "pm2 logs enhanced-proxy-single --nostream",
    "pm2:status": "pm2 status"
  },
  "dependencies": {
    "express": "^4.18.2",
    "http-proxy-middleware": "^2.0.6",
    "lru-cache": "^10.0.0",
    "pino": "^8.15.0",
    "pino-pretty": "^10.2.0",
    "dotenv": "^16.3.1"
  },
  "engines": {
    "node": ">=18.0.0"
  },
  "author": "iLifeCreator",
  "license": "MIT"
}
EOF

# Install dependencies
log "Installing Node.js dependencies..."
npm install

# Create directory structure
log "Creating directory structure..."
mkdir -p src logs config

# Create environment configuration
log "Creating environment configuration..."
cat > .env.production << EOF
NODE_ENV=production
PORT=3000
TARGET_DOMAIN=${TARGET_DOMAIN}
PROXY_DOMAIN=${DOMAIN}
TARGET_PROTOCOL=https

# Performance settings optimized for 2-core/4GB server
MAX_SOCKETS=500
MAX_FREE_SOCKETS=50
REQUEST_TIMEOUT=15000

# Caching settings - optimized for single process
CACHE_MAX_SIZE=1000
STATIC_CACHE_AGE=86400
CACHE_MAX_AGE=7200

# Monitoring
ENABLE_METRICS=true
LOG_LEVEL=info
LOG_REQUESTS=false

# Thread pool optimization
UV_THREADPOOL_SIZE=8
EOF

# Download the optimized proxy files from the repository
log "Downloading Enhanced Proxy v2.5-FINAL files..."

# Note: In real deployment, these would be copied from the repository
# For now, we'll create placeholder files that reference the repository

cat > src/enhanced-simple-proxy-final.js << 'EOF'
// This is a placeholder - in production, copy the actual file from:
// https://github.com/iLifeCreator/glideproxy/blob/production-optimized-final/optimized-proxy/src/enhanced-simple-proxy-final.js

console.error('ERROR: Please copy the actual enhanced-simple-proxy-final.js file from the repository');
console.error('Repository: https://github.com/iLifeCreator/glideproxy');
console.error('Branch: production-optimized-final');
console.error('File: optimized-proxy/src/enhanced-simple-proxy-final.js');
process.exit(1);
EOF

# Create PM2 ecosystem configuration
log "Creating PM2 ecosystem configuration..."
cat > ecosystem.single.config.js << EOF
/**
 * PM2 Single Instance Configuration для автоматической установки
 * Оптимизированная конфигурация для максимальной эффективности памяти
 */

module.exports = {
  apps: [{
    name: 'enhanced-proxy-single',
    script: './src/enhanced-simple-proxy-final.js',
    
    // Единственный инстанс для экономии памяти
    instances: 1,
    exec_mode: 'fork',
    
    // Автоматический перезапуск
    autorestart: true,
    watch: false,
    
    // Ограичения памяти (консервативно для 4ГБ ОЗУ)
    max_memory_restart: '2000M',
    
    // Production переменные окружения
    env_production: {
      NODE_ENV: 'production',
      PORT: 3000,
      TARGET_DOMAIN: '${TARGET_DOMAIN}',
      PROXY_DOMAIN: '${DOMAIN}',
      TARGET_PROTOCOL: 'https',
      
      WORKERS: 1,
      LOG_LEVEL: 'info',
      ENABLE_METRICS: 'true',
      UV_THREADPOOL_SIZE: 8,
      
      CACHE_MAX_SIZE: 1000,
      STATIC_CACHE_AGE: 86400,
      CACHE_MAX_AGE: 7200,
      
      MAX_SOCKETS: 500,
      MAX_FREE_SOCKETS: 50,
      REQUEST_TIMEOUT: 15000,
      
      LOG_REQUESTS: 'false'
    },
    
    // Логирование
    log_file: './logs/enhanced-single.log',
    out_file: './logs/enhanced-single-out.log',
    error_file: './logs/enhanced-single-error.log',
    log_date_format: 'YYYY-MM-DD HH:mm:ss Z',
    merge_logs: true,
    
    listen_timeout: 3000,
    kill_timeout: 5000,
    
    node_args: [
      '--max-old-space-size=1800',
      '--optimize-for-size'
    ],
    
    monitoring: false,
    wait_ready: true,
    
    restart_delay: 1000,
    exp_backoff_restart_delay: 100,
    max_restarts: 5,
    min_uptime: '60s'
  }]
};
EOF

# Create nginx configuration
log "Creating nginx configuration..."
sudo tee /etc/nginx/sites-available/${DOMAIN}.conf > /dev/null << EOF
server {
    listen 80;
    server_name ${DOMAIN};
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name ${DOMAIN};
    
    # SSL will be configured by certbot
    
    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
        
        proxy_connect_timeout 15s;
        proxy_send_timeout 15s;
        proxy_read_timeout 15s;
        
        proxy_buffering on;
        proxy_buffer_size 16k;
        proxy_buffers 8 16k;
        proxy_busy_buffers_size 32k;
    }
    
    location /health {
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_connect_timeout 5s;
        proxy_send_timeout 5s;
        proxy_read_timeout 5s;
        add_header X-Health-Check "nginx-direct";
    }
    
    access_log /var/log/nginx/${DOMAIN}.access.log;
    error_log /var/log/nginx/${DOMAIN}.error.log;
    client_max_body_size 100M;
}
EOF

# Enable nginx site
log "Enabling nginx site..."
sudo ln -sf /etc/nginx/sites-available/${DOMAIN}.conf /etc/nginx/sites-enabled/
sudo nginx -t || error "Nginx configuration test failed"

# Obtain SSL certificate
log "Obtaining SSL certificate from Let's Encrypt..."
sudo certbot --nginx -d ${DOMAIN} --email ${EMAIL} --agree-tos --non-interactive --redirect

# Reload nginx
log "Reloading nginx..."
sudo systemctl reload nginx

# Create management scripts
log "Creating management scripts..."

cat > start.sh << 'EOF'
#!/bin/bash
echo "Starting Enhanced Proxy v2.5-FINAL..."
pm2 start ecosystem.single.config.js --env production
pm2 save
sudo pm2 startup systemd -u $(whoami) --hp $(pwd)
EOF

cat > stop.sh << 'EOF'
#!/bin/bash
echo "Stopping Enhanced Proxy..."
pm2 stop enhanced-proxy-single
EOF

cat > status.sh << 'EOF'
#!/bin/bash
echo "=== PM2 Status ==="
pm2 status
echo ""
echo "=== Health Check ==="
curl -s http://localhost:3000/health | jq . || echo "Health check failed"
EOF

cat > logs.sh << 'EOF'
#!/bin/bash
pm2 logs enhanced-proxy-single --nostream --lines 50
EOF

chmod +x *.sh

log "Installation completed successfully!"
echo ""
echo -e "${GREEN}=== Next Steps ===${NC}"
echo -e "${YELLOW}1. Copy the actual enhanced-simple-proxy-final.js file from the repository${NC}"
echo -e "${YELLOW}2. Run: ./start.sh to start the proxy${NC}"
echo -e "${YELLOW}3. Run: ./status.sh to check status${NC}"
echo -e "${YELLOW}4. Check logs with: ./logs.sh${NC}"
echo ""
echo -e "${GREEN}Repository: https://github.com/iLifeCreator/glideproxy${NC}"
echo -e "${GREEN}Branch: production-optimized-final${NC}"
echo -e "${GREEN}Health Check: https://${DOMAIN}/health${NC}"
echo ""
echo -e "${BLUE}Enhanced Proxy v2.5-FINAL installation completed!${NC}"
EOF