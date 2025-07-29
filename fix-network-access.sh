#!/bin/bash

echo "🔧 Fixing Network Access for TRA Scanner Services"
echo "=================================================="

# Kill existing services
echo "1. Stopping existing services..."
pkill -f "php artisan serve"
pkill -f "node server.js"
sleep 2

# Get current IP
CURRENT_IP=$(ifconfig | grep "inet " | grep -v "127.0.0.1" | head -1 | awk '{print $2}')
echo "2. Detected IP: $CURRENT_IP"

# Start services with network binding
echo "3. Starting services with network access..."

# Start Laravel backend with network binding
echo "   Starting Laravel backend on 0.0.0.0:8001..."
cd "/Volumes/DopestGeek Recovery/uchafu/tra_scanner_app/back-end"
nohup php artisan serve --host=0.0.0.0 --port=8001 > ../laravel.log 2>&1 &
LARAVEL_PID=$!

# Start TRA crawler with network binding  
echo "   Starting TRA crawler on 0.0.0.0:3000..."
cd "/Volumes/DopestGeek Recovery/uchafu/tra_scanner_app/server/node-tra-crawler"

# Update server.js to bind to all interfaces
if ! grep -q "0.0.0.0" server.js; then
    echo "   Updating TRA crawler for network access..."
    sed -i '' 's/app.listen(process.env.PORT || 3000,/app.listen(process.env.PORT || 3000, "0.0.0.0",/g' server.js
fi

nohup node server.js > ../tra-crawler.log 2>&1 &
CRAWLER_PID=$!

# Wait for services to start
echo "4. Waiting for services to start..."
sleep 3

# Test connectivity
echo "5. Testing connectivity..."
echo "   Laravel Backend (Port 8001):"
if curl -s "http://$CURRENT_IP:8001" >/dev/null 2>&1; then
    echo "   ✅ Accessible at http://$CURRENT_IP:8001"
else
    echo "   ❌ Not accessible"
fi

echo "   TRA Crawler (Port 3000):"
if curl -s "http://$CURRENT_IP:3000" >/dev/null 2>&1; then
    echo "   ✅ Accessible at http://$CURRENT_IP:3000"
else
    echo "   ❌ Not accessible"
fi

echo ""
echo "🎯 Service Status:"
echo "   Laravel PID: $LARAVEL_PID"
echo "   Crawler PID: $CRAWLER_PID"
echo ""
echo "📱 For Flutter app, your services should be accessible at:"
echo "   Backend: http://$CURRENT_IP:8001/api"
echo "   Scraper: http://$CURRENT_IP:3000"
echo ""
echo "📋 If Flutter still detects a different IP, try these URLs manually:"
echo "   http://192.168.0.60:8001/api"
echo "   http://192.168.0.236:8001/api (if on different network)"
echo ""
echo "✅ Setup complete! Services are now network-accessible."