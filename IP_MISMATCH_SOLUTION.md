# 🔧 IP Mismatch Solution

## 🚨 Issue Identified

- **Flutter App Detects**: `192.168.0.236` (mobile network)
- **Services Running On**: `192.168.0.60` (WiFi network)
- **Result**: Connection refused errors

## 📱 Quick Fixes

### Option 1: Force Flutter to Use Correct IP
Update your Flutter app's IP detection by adding the correct IP to the priority list.

In `lib/main.dart`, update the `commonLocalIPs` array:

```dart
static const List<String> commonLocalIPs = [
  '192.168.0.60',   // YOUR ACTUAL WIFI IP (put this first)
  '192.168.0.236',  // Detected IP (secondary)
  '192.168.1.1',    
  '192.168.0.1',    
  '10.0.0.1',       
  '172.16.0.1',     
  '127.0.0.1',      
];
```

### Option 2: Use the Service Status Script
Run our service checker to see current status:

```bash
./check-services.sh
```

### Option 3: Manual Network Selection
If you're using mobile hotspot or different networks:

1. **Check your device's network**: Make sure your phone/device is on the same WiFi as your computer
2. **Disable mobile data**: Turn off mobile data on your test device
3. **Connect to same WiFi**: Ensure both computer and device are on the same WiFi network

## 🛠️ Network Troubleshooting

### Check Multiple IPs
Test these URLs in your browser or with curl:

```bash
# Test all possible IPs
curl http://192.168.0.60:8001/api/receipts
curl http://192.168.0.236:8001/api/receipts
curl http://192.168.1.1:8001/api/receipts
```

### Check Network Interface
```bash
# See all network interfaces
ifconfig -a

# Check what's listening on ports
lsof -i :8001
lsof -i :3000
```

## 🎯 Recommended Solution

**Immediate Fix**: Update Flutter configuration to prioritize the working IP:

1. Open `frontend/flutter_receipt_scanner/lib/main.dart`
2. Find the `commonLocalIPs` array (around line 40)
3. Move `'192.168.0.60'` to the first position
4. Restart your Flutter app

**Long-term Fix**: The dynamic IP detection will eventually find the working IP, but this ensures it tries the correct one first.

## 📋 Alternative: Static IP Configuration  

If dynamic detection keeps failing, temporarily use static IPs:

```dart
class ApiConfig {
  // Temporarily disable auto-detection
  static const bool autoDetectLocalIP = false;
  
  // Use working IP directly
  static const List<String> commonLocalIPs = [
    '192.168.0.60',  // Your confirmed working IP
  ];
}
```

## ✅ Expected Result

After fixing the IP priority, your Flutter app should show:

```
I/flutter: 📡 Detected local IP: 192.168.0.60
I/flutter: Attempting API call to: http://192.168.0.60:8001/api/receipts?page=1
I/flutter: API Response: Success
```

Your services are running and accessible - it's just an IP detection/priority issue! 🎯