#!/bin/bash

echo "Starting TRA Crawler Service..."
echo "================================"
echo "Service will run on: http://localhost:3000"
echo "================================"
echo ""
echo "Available endpoints:"
echo "  GET / - Health check"
echo "  GET /receipt/:code/:time - Verify TRA receipt"
echo ""
echo "Example:"
echo "  http://localhost:3000/receipt/123456789/120530"
echo "  (where 120530 = 12:05:30)"
echo ""
echo "Press Ctrl+C to stop the server"
echo "================================"

# Set PORT to 3000 for local development
export PORT=3000

# Start the server
npm start