bash#!/bin/bash
sudo apt update
sudo apt install -y haproxy apache2-utils

# HAProxy config optimized for maximum speed
sudo tee /etc/haproxy/haproxy.cfg > /dev/null << 'EOF'
global
   daemon
   maxconn 4096
   nbproc 1
   cpu-map 1 0
   tune.bufsize 32768
   tune.maxrewrite 2048
   tune.http.maxhdr 200

defaults
   mode http
   timeout connect 1s
   timeout client 30s
   timeout server 30s
   option http-keep-alive
   option splice-auto
   option tcp-nodelay
   no option log-health-checks

frontend http_proxy
   bind *:3128
   acl auth http_auth(users)
   http-request auth if !auth
   default_backend api_backend

backend api_backend
   mode http
   balance roundrobin
   option httpchk GET /
   server dynamic 127.0.0.1:80 disabled

listen stats
   bind *:8080
   stats enable
   stats uri /stats
EOF

# Kernel optimizations for speed
sudo tee -a /etc/sysctl.conf > /dev/null << 'EOF'
net.core.somaxconn = 65535
net.ipv4.tcp_congestion_control = bbr
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.ipv4.tcp_rmem = 4096 87380 134217728
net.ipv4.tcp_wmem = 4096 65536 134217728
EOF

sudo sysctl -p

# Create auth
read -p "Username: " user
read -s -p "Password: " pass
echo ""
echo "$user:$(openssl passwd -1 $pass)" | sudo tee /etc/haproxy/users

# Firewall
sudo ufw allow 3128
sudo ufw allow 8080
sudo ufw --force enable

sudo systemctl restart haproxy
sudo systemctl enable haproxy

echo "✅ Ultra-fast HAProxy running on $(curl -s ifconfig.me):3128"
echo "📊 Stats: http://$(curl -s ifconfig.me):8080/stats"
