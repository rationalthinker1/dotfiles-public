# 🧠 nginx Cheat Sheet

## 🔍 Service Control

```bash
sudo systemctl start nginx                      # Start nginx
sudo systemctl stop nginx                       # Stop nginx
sudo systemctl restart nginx                    # Restart (drops connections)
sudo systemctl reload nginx                     # Reload config (graceful, no downtime)
sudo systemctl status nginx                     # Check status
sudo systemctl enable nginx                     # Enable on boot
sudo systemctl disable nginx                    # Disable on boot
```

## 🔧 Config Testing and Management

```bash
sudo nginx -t                                   # Test config syntax (always run before reload)
sudo nginx -T                                   # Test and dump full resolved config
sudo nginx -s reload                            # Reload config (alternative to systemctl)
sudo nginx -s stop                              # Fast shutdown
sudo nginx -s quit                              # Graceful shutdown (finish requests)
nginx -v                                        # Show version
nginx -V                                        # Show version + compile options + modules
```

## 📁 Key Paths

```bash
# Config:
/etc/nginx/nginx.conf                           # Main config
/etc/nginx/sites-available/                     # Site configs (available)
/etc/nginx/sites-enabled/                       # Active symlinks
/etc/nginx/conf.d/                              # Additional config includes
/etc/nginx/snippets/                            # Reusable config snippets

# Logs:
/var/log/nginx/access.log                       # Access log (all requests)
/var/log/nginx/error.log                        # Error log
# Per-site logs often at /var/log/nginx/{site}_access.log

# Other:
/var/www/html/                                  # Default document root
/etc/nginx/mime.types                           # MIME type mappings
/run/nginx.pid                                  # PID file
```

## 🌐 Site Management (sites-available pattern)

```bash
# Enable a site:
sudo ln -s /etc/nginx/sites-available/mysite /etc/nginx/sites-enabled/

# Disable a site:
sudo rm /etc/nginx/sites-enabled/mysite

# Create new site config:
sudo vim /etc/nginx/sites-available/mysite

# Always test + reload after changes:
sudo nginx -t && sudo systemctl reload nginx
```

## 📋 Common Config Blocks

```bash
# Basic static site:
# server {
#     listen 80;
#     server_name example.com www.example.com;
#     root /var/www/example;
#     index index.html;
#     location / {
#         try_files $uri $uri/ =404;
#     }
# }

# PHP (FastCGI) proxy:
# location ~ \.php$ {
#     fastcgi_pass unix:/run/php/php8.2-fpm.sock;
#     fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
#     include fastcgi_params;
# }

# Reverse proxy to app server:
# location / {
#     proxy_pass http://127.0.0.1:3000;
#     proxy_set_header Host $host;
#     proxy_set_header X-Real-IP $remote_addr;
#     proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
#     proxy_set_header X-Forwarded-Proto $scheme;
# }

# WebSocket proxy:
# location /ws {
#     proxy_pass http://127.0.0.1:3000;
#     proxy_http_version 1.1;
#     proxy_set_header Upgrade $http_upgrade;
#     proxy_set_header Connection "upgrade";
# }

# SSL / HTTPS:
# server {
#     listen 443 ssl http2;
#     server_name example.com;
#     ssl_certificate /etc/letsencrypt/live/example.com/fullchain.pem;
#     ssl_certificate_key /etc/letsencrypt/live/example.com/privkey.pem;
#     ssl_protocols TLSv1.2 TLSv1.3;
# }

# HTTP → HTTPS redirect:
# server {
#     listen 80;
#     server_name example.com;
#     return 301 https://$host$request_uri;
# }

# Rate limiting:
# limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;
# location /api/ {
#     limit_req zone=api burst=20 nodelay;
# }
```

## 📊 Log Analysis

```bash
# Real-time access log
sudo tail -f /var/log/nginx/access.log

# Real-time error log
sudo tail -f /var/log/nginx/error.log

# Top 20 IPs by request count
sudo awk '{print $1}' /var/log/nginx/access.log | sort | uniq -c | sort -rn | head -20

# Top requested URLs
sudo awk '{print $7}' /var/log/nginx/access.log | sort | uniq -c | sort -rn | head -20

# Count requests by HTTP status code
sudo awk '{print $9}' /var/log/nginx/access.log | sort | uniq -c | sort -rn

# Find 5xx errors
sudo grep " 50[0-9] " /var/log/nginx/access.log | tail -20

# Requests per minute (last hour)
sudo awk -v d="$(date -d '1 hour ago' '+%d/%b/%Y:%H')" '$4 ~ d {print substr($4,14,5)}' /var/log/nginx/access.log | sort | uniq -c
```

## 🔗 Common Combos

```bash
# Quick test: edit config → test → reload
sudo vim /etc/nginx/sites-available/mysite && sudo nginx -t && sudo systemctl reload nginx

# Tail both logs simultaneously
sudo tail -f /var/log/nginx/{access,error}.log

# Check which sites are enabled
ls -la /etc/nginx/sites-enabled/

# Find all server_name directives across configs
grep -r "server_name" /etc/nginx/sites-enabled/

# Check which process is using port 80
sudo lsof -i :80

# Generate self-signed cert for testing
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/ssl/private/test.key -out /etc/ssl/certs/test.crt

# Check SSL certificate expiry
echo | openssl s_client -servername example.com -connect example.com:443 2>/dev/null | openssl x509 -noout -dates
```

## ⚠️ Gotchas

```bash
# Always nginx -t before reload — a bad config will crash nginx on restart
# sites-enabled should contain SYMLINKS, not copies — edit the files in sites-available
# Missing semicolons in config cause cryptic "unexpected }" errors
# try_files with proxy_pass: use try_files $uri @backend, not try_files $uri proxy_pass
# worker_connections * worker_processes = max concurrent connections
# Logs can grow huge — configure logrotate or use access_log off for static assets
# On Ubuntu: default site is /etc/nginx/sites-enabled/default — remove it for production
```

