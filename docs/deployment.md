# SavingPlus Deployment Guide

## Local Development (Docker Compose)

### Prerequisites
- Docker & Docker Compose
- Node.js 18+ (for frontend development)
- Go 1.22+ (for backend development without Docker)

### Quick Start
```bash
# Start PostgreSQL + Redis + API
docker-compose up -d

# The API will be available at:
# Customer API: http://localhost:8080
# Admin API:    http://localhost:8081

# Run migrations (already applied via docker-entrypoint-initdb.d)
# To re-run: docker exec -i savingplus-postgres-1 psql -U savingplus -d savingplus < backend/migrations/000001_init.up.sql

# Seed test data
# docker exec -i savingplus-postgres-1 psql -U savingplus -d savingplus < scripts/seed.sql
```

### Frontend Development
```bash
# Customer app
cd frontend/customer-app
npm install
npm run dev   # http://localhost:3000

# Admin app
cd frontend/admin-app
npm install
npm run dev   # http://localhost:3001
```

### Backend Development (without Docker)
```bash
cd backend
cp .env.example .env
# Edit .env with your local PostgreSQL and Redis settings
go run ./cmd/api/
```

## Production Deployment (Single VM)

### 1. Server Setup
```bash
# Ubuntu 22.04 recommended
sudo apt update && sudo apt upgrade -y
sudo apt install -y docker.io docker-compose nginx certbot python3-certbot-nginx

# Enable Docker
sudo systemctl enable docker
sudo usermod -aG docker $USER
```

### 2. SSL Certificate
```bash
sudo certbot --nginx -d api.savingplus.co.tz -d admin.savingplus.co.tz -d app.savingplus.co.tz
```

### 3. Nginx Configuration
```nginx
# /etc/nginx/sites-available/savingplus

# Customer API
server {
    listen 443 ssl http2;
    server_name api.savingplus.co.tz;

    ssl_certificate /etc/letsencrypt/live/api.savingplus.co.tz/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/api.savingplus.co.tz/privkey.pem;
    ssl_protocols TLSv1.3;

    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}

# Admin API
server {
    listen 443 ssl http2;
    server_name admin.savingplus.co.tz;

    ssl_certificate /etc/letsencrypt/live/admin.savingplus.co.tz/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/admin.savingplus.co.tz/privkey.pem;
    ssl_protocols TLSv1.3;

    # Optional: IP whitelist for admin
    # allow 196.x.x.x;
    # deny all;

    location / {
        proxy_pass http://127.0.0.1:8081;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}

# Customer Web App
server {
    listen 443 ssl http2;
    server_name app.savingplus.co.tz;

    ssl_certificate /etc/letsencrypt/live/app.savingplus.co.tz/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/app.savingplus.co.tz/privkey.pem;
    ssl_protocols TLSv1.3;

    root /var/www/savingplus/customer-app/dist;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }

    location /api {
        proxy_pass http://127.0.0.1:8080;
    }
}
```

### 4. Deploy
```bash
# Clone repo
git clone <repo-url> /opt/savingplus
cd /opt/savingplus

# Create production .env
cp backend/.env.example backend/.env
# Edit with production values (strong secrets, real API keys, etc.)

# Build and start
docker-compose -f docker-compose.yml up -d

# Build frontend
cd frontend/customer-app && npm ci && npm run build
sudo cp -r dist /var/www/savingplus/customer-app/

cd ../admin-app && npm ci && npm run build
sudo cp -r dist /var/www/savingplus/admin-app/

# Restart nginx
sudo systemctl restart nginx
```

### 5. Security Checklist
- [ ] Change all default secrets in .env
- [ ] Use strong JWT_SECRET (64+ random chars)
- [ ] Use unique ENCRYPTION_KEY (32 random bytes, hex-encoded)
- [ ] Enable TLS 1.3 only
- [ ] Set up firewall (allow 80, 443 only)
- [ ] Enable PostgreSQL SSL
- [ ] Set Redis password
- [ ] IP whitelist admin panel
- [ ] Configure log rotation
- [ ] Set up monitoring (Prometheus + Grafana recommended)
- [ ] Set up automated backups for PostgreSQL
- [ ] Enable MFA for all admin users
