#!/bin/bash
# Script to set up a basic Nginx web server

# Update the system
echo "Updating system packages..."
sudo dnf update -y

# Install Nginx
echo "Installing Nginx..."
sudo dnf install nginx -y

# Start and enable Nginx
echo "Enabling and starting Nginx service..."
sudo systemctl enable --now nginx.service

# Configure firewall to allow HTTP traffic
echo "Configuring firewall..."
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --permanent --add-service=https
sudo firewall-cmd --reload

# Configure SELinux
echo "Configuring SELinux..."
sudo setsebool -P httpd_can_network_connect 1

# Note: Setting SELinux to permissive is generally not recommended for production
# Uncomment the following if you really need permissive mode
# sudo sed -i 's/^SELINUX=.*/SELINUX=permissive/' /etc/selinux/config
# sudo setenforce 0

# Remove the default Nginx configuration
sudo rm -f /etc/nginx/conf.d/default.conf

# Get public IP (fixed the typo by removing the 's')
PUBLIC_IP=$(curl -s ifconfig.me)
echo "Public IP: $PUBLIC_IP"

# Create a new Nginx configuration file
echo "Creating Nginx configuration..."
cat <<EOL | sudo tee /etc/nginx/conf.d/setup.conf
server {
    listen 80;
    server_name _;
    
    # Add security headers
    add_header X-Content-Type-Options nosniff;
    add_header X-Frame-Options SAMEORIGIN;
    add_header X-XSS-Protection "1; mode=block";
    
    location / {
        root /usr/share/nginx/html;
        index index.html;
        try_files \$uri \$uri/ /index.html;
    }
}
EOL

# Create the directory for the HTML file
sudo mkdir -p /usr/share/nginx/html

# Create the HTML file with functional form
echo "Creating web content..."
cat <<EOL | sudo tee /usr/share/nginx/html/index.html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Web Server</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            margin: 0;
            padding: 20px;
            line-height: 1.6;
            color: #333;
            max-width: 800px;
            margin: 0 auto;
        }
        h1 {
            color: #2c3e50;
            border-bottom: 1px solid #eee;
            padding-bottom: 10px;
        }
        .form-group {
            margin-bottom: 15px;
        }
        input[type="text"] {
            width: 300px;
            padding: 8px;
            margin-right: 10px;
            border: 1px solid #ddd;
            border-radius: 4px;
        }
        button {
            padding: 8px 15px;
            cursor: pointer;
            background-color: #3498db;
            color: white;
            border: none;
            border-radius: 4px;
        }
        button:hover {
            background-color: #2980b9;
        }
        #results {
            margin-top: 20px;
        }
        #results div {
            margin-top: 10px;
            padding: 10px;
            border: 1px solid #ddd;
            border-radius: 5px;
            background-color: #f9f9f9;
        }
        .server-info {
            margin-top: 30px;
            font-size: 0.9em;
            color: #7f8c8d;
        }
    </style>
</head>
<body>
    <h1>Welcome to Your Web Server</h1>
    <p>This is a basic web server running Nginx.</p>
    
    <div class="form-group">
        <input type="text" id="searchInput" placeholder="Enter search term...">
        <button onclick="performSearch()">Search</button>
    </div>
    
    <div id="results"></div>
    
    <div class="server-info">
        <p>Server Information:</p>
        <ul>
            <li>Server IP: <span id="serverIp"></span></li>
            <li>Nginx Version: <span id="nginxVersion"></span></li>
        </ul>
    </div>

    <script>
        // Simple function to demonstrate the search functionality
        function performSearch() {
            const searchTerm = document.getElementById('searchInput').value;
            if (!searchTerm) {
                alert('Please enter a search term');
                return;
            }
            
            const resultsDiv = document.getElementById('results');
            const resultItem = document.createElement('div');
            resultItem.textContent = 'You searched for: ' + searchTerm;
            resultsDiv.appendChild(resultItem);
            
            // Clear the input field
            document.getElementById('searchInput').value = '';
        }
        
        // Display server IP (you would need to set this server-side in a production environment)
        document.getElementById('serverIp').textContent = '$PUBLIC_IP';
        
        // This is just a placeholder - in a real environment you might want to generate this server-side
        document.getElementById('nginxVersion').textContent = 'Latest version';
    </script>
</body>
</html>
EOL

# Update the main Nginx configuration file
echo "Updating main Nginx configuration..."
cat <<EOL | sudo tee /etc/nginx/nginx.conf
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log notice;  # Changed from debug to notice for production
pid /run/nginx.pid;

# Load dynamic modules
include /usr/share/nginx/modules/*.conf;

events {
    worker_connections 1024;
}

http {
    log_format  main  '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                      '\$status \$body_bytes_sent "\$http_referer" '
                      '"\$http_user_agent" "\$http_x_forwarded_for" "\$proxy_host" "\$upstream_addr"';
    
    access_log  /var/log/nginx/access.log  main;
    
    sendfile            on;
    tcp_nopush          on;
    tcp_nodelay         on;
    keepalive_timeout   65;
    types_hash_max_size 2048;
    
    # Security settings
    server_tokens off;  # Don't show Nginx version
    
    include             /etc/nginx/mime.types;
    default_type        application/octet-stream;
    
    # Load modular configuration files
    include /etc/nginx/conf.d/*.conf;
}
EOL

# Restart Nginx to apply changes
echo "Restarting Nginx..."
sudo systemctl restart nginx

echo "Testing Nginx configuration..."
sudo nginx -t

echo "Deployment completed successfully!"
echo "Your web server is now accessible at http://$PUBLIC_IP"
