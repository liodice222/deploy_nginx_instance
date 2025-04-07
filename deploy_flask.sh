#!/bin/bash
# Script to set up Flask with Nginx as a reverse proxy

echo "Setting up Flask application with Nginx..."

# Install Python and Flask dependencies
echo "Installing Python and Flask dependencies..."
sudo dnf install python3 python3-pip -y
sudo pip3 install flask gunicorn

# Create directory for the Flask app
echo "Creating directory for Flask app..."
sudo mkdir -p /opt/myapp

# Create the Flask application file
echo "Creating Flask application (app.py)..."
cat <<EOL | sudo tee /opt/myapp/app.py
from flask import Flask, jsonify, request
import random
import time

# Initialize the Flask application
app = Flask(__name__)

# Define a simple route for the homepage
@app.route('/')
def index():
    return "Welcome to the Flask App!"

@app.route('/metrics')
def metrics():
    # Generate random metrics
    cpu = random.uniform(0, 100)
    memory = random.uniform(0, 100)
    return jsonify({
        "cpu_usage": cpu,
        "memory_usage": memory
    })

# Define a route that returns JSON data
@app.route('/api/data', methods=['GET'])
def get_data():
    sample_data = {
        'message': "Hello from Flask!",
        'version': '1.0'
    }
    return jsonify(sample_data)

# Define a route to accept POST data
@app.route('/api/echo', methods=['POST'])
def echo():
    data = request.get_json()
    if data is None:
        return jsonify({'error': 'No JSON payload provided.'}), 400
    return jsonify({'you_sent': data})

# Run the application if executed directly
if __name__ == '__main__':
    # Setting debug=True for development allows automatic reloads on code changes.
    app.run(host='0.0.0.0', port=5000, debug=True)
EOL

# Create systemd service file for the Flask app
echo "Creating systemd service for Flask app..."
cat <<EOL | sudo tee /etc/systemd/system/flask-app.service
[Unit]
Description=Flask Application
After=network.target

[Service]
User=nginx
WorkingDirectory=/opt/myapp
ExecStart=/usr/local/bin/gunicorn --workers 3 --bind 127.0.0.1:5000 app:app
Restart=always

[Install]
WantedBy=multi-user.target
EOL

# Modify Nginx configuration to act as a reverse proxy
echo "Configuring Nginx as a reverse proxy for Flask..."
cat <<EOL | sudo tee /etc/nginx/conf.d/setup.conf
server {
    listen 80;
    server_name _;
    
    # Add security headers
    add_header X-Content-Type-Options nosniff;
    add_header X-Frame-Options SAMEORIGIN;
    add_header X-XSS-Protection "1; mode=block";
    
    # For static files (if you have any)
    location /static/ {
        alias /opt/myapp/static/;
    }
    
    # Forward all requests to the Flask app
    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOL

# Set proper permissions
echo "Setting permissions for Flask app..."
sudo chown -R nginx:nginx /opt/myapp
sudo chmod -R 755 /opt/myapp

# Start and enable the Flask service
echo "Starting and enabling Flask service..."
sudo systemctl daemon-reload
sudo systemctl start flask-app
sudo systemctl enable flask-app

# Restart Nginx
echo "Restarting Nginx to apply changes..."
sudo systemctl restart nginx

# Test the Flask app
echo "Testing Flask application setup..."
echo "Flask app status:"
sudo systemctl status flask-app
echo "Nginx status:"
sudo systemctl status nginx
echo "Checking connection to Flask app:"
curl -s http://127.0.0.1:5000/metrics

echo "Setup complete! Your Flask app should now be accessible through Nginx."
echo "Try these endpoints:"
echo "  - / - Main page"
echo "  - /metrics - Random CPU and memory metrics"
echo "  - /api/data - Sample JSON data"
echo "  - POST to /api/echo - Echoes back your JSON payload"
