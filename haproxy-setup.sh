#!/bin/bash
sudo apt update
sudo apt install -y haproxy apache2-utils

# Simple, working HAProxy config for maximum speed
sudo tee /etc/haproxy/haproxy.cfg > /dev/null << 'EOF'
global
   daemon
   maxconn 4096
   tune.bufsize 32768

defaults
   mode http
   timeout connect 5s
   timeout client 50s
   timeout server 50s
   option http-keep-alive

frontend http_proxy
   bind *:3128
   acl auth http_auth(users)
   http-request auth if !auth
   default_backend api_servers

backend api_servers
   mode http
   balance roundrobin
   option forwardfor
   http-request set-header X-Forwarded-Proto https if { ssl_fc }
   http-request set-header X-Forwarded-Proto http if !{ ssl_fc }
   server dynamic 0.0.0.0:80 disabled

frontend stats
   bind *:8080
   stats enable
   stats uri /stats
EOF

# Kernel optimizations
echo 'net.core.somaxconn = 65535' | sudo tee -a /etc/sysctl.conf
echo 'net.ipv4.tcp_congestion_control = bbr' | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

# Create auth
read -p "Enter username: " username
read -s -p "Enter password: " password
echo ""
echo "$username:$(openssl passwd -1 $password)" | sudo tee /etc/haproxy/users

# Firewall
sudo ufw allow 3128
sudo ufw allow 8080
sudo ufw --force enable

# Start HAProxy
sudo systemctl restart haproxy
sudo systemctl enable haproxy

echo "✅ HAProxy running on $(curl -s ifconfig.me):3128"
echo "Username: $username"
echo "Test: curl -x $(curl -s ifconfig.me):3128 --proxy-user $username:password https://httpbin.org/ip"
