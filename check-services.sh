#!/bin/bash

echo "🔍 TRA Scanner App - Service Status Check"
echo "=========================================="
echo ""

# Check TRA Crawler Service (Port 3000)
echo "1. TRA Crawler Service (Port 3000):"
if lsof -i :3000 >/dev/null 2>&1; then
    echo "   ✅ RUNNING"
    curl -s http://localhost:3000 >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "   ✅ Health check: PASSED"
        echo "   📍 URL: http://localhost:3000"
    else
        echo "   ❌ Health check: FAILED"
    fi
else
    echo "   ❌ NOT RUNNING"
    echo "   💡 Start with: cd server/node-tra-crawler && npm start"
fi
echo ""

# Check Laravel Backend (Port 8000)
echo "2. Laravel Backend (Port 8000):"
if lsof -i :8000 >/dev/null 2>&1; then
    echo "   ✅ RUNNING"
    curl -s http://localhost:8000 >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "   ✅ Health check: PASSED"
        echo "   📍 URL: http://localhost:8000"
    else
        echo "   ❌ Health check: FAILED"
    fi
else
    echo "   ❌ NOT RUNNING"
    echo "   💡 Start with: cd back-end && php artisan serve"
fi
echo ""

# Check Express Backend (Alternative port)
echo "3. Express Backend (Port 8001):"
if lsof -i :8001 >/dev/null 2>&1; then
    echo "   ✅ RUNNING"
    curl -s http://localhost:8001 >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "   ✅ Health check: PASSED"
        echo "   📍 URL: http://localhost:8001"
    else
        echo "   ❌ Health check: FAILED"
    fi
else
    echo "   ❌ NOT RUNNING"
    echo "   💡 Start with: cd backend && npm start"
fi
echo ""

# Summary
echo "📋 Summary:"
RUNNING_COUNT=0
if lsof -i :3000 >/dev/null 2>&1; then ((RUNNING_COUNT++)); fi
if lsof -i :8000 >/dev/null 2>&1; then ((RUNNING_COUNT++)); fi
if lsof -i :8001 >/dev/null 2>&1; then ((RUNNING_COUNT++)); fi

echo "   Services running: $RUNNING_COUNT/3"
echo ""

if [ $RUNNING_COUNT -eq 3 ]; then
    echo "🎉 All services are running!"
elif [ $RUNNING_COUNT -gt 0 ]; then
    echo "⚠️  Some services are running. Check individual status above."
else
    echo "❌ No services are running."
fi

echo ""
echo "📱 For Flutter app development:"
echo "   - Use TRA Crawler: http://localhost:3000"
echo "   - Use Laravel API: http://localhost:8000/api"
echo "=========================================="