# Flutter App Configuration Fix

## 🚨 Current Issues

1. **Scraper URL is remote**: `http://50.116.44.162:4000` (should be local TRA crawler)
2. **Network access**: Your services are running but may need network binding

## ✅ Services Status

| Service | Port | Status | Network Access |
|---------|------|---------|---------------|
| Laravel Backend | 8001 | ✅ Running | ✅ Accessible at 192.168.0.60:8001 |
| TRA Crawler | 3000 | ✅ Running | ❓ Need to check network binding |
| Express Backend | 8000 | ✅ Running | ❓ Need to check network binding |

## 🔧 Required Changes

### 1. Update Flutter Configuration
File: `frontend/flutter_receipt_scanner/lib/main.dart`

**Change this:**
```dart
static const String scraperUrl = 'http://50.116.44.162:4000';
```

**To this:**
```dart
static const String scraperUrl = 'http://192.168.0.60:3000';
```

### 2. Make TRA Crawler Network Accessible

The TRA crawler is running on localhost:3000 but may not be accessible from network.

**Option A: Start with network binding**
```bash
cd server/node-tra-crawler
PORT=3000 node server.js --host=0.0.0.0
```

**Option B: Update server.js**
Edit `server/node-tra-crawler/server.js` line 27:
```javascript
// Change from:
app.listen(process.env.PORT || 3000, () => {
    console.log('server running');
})

// To:
app.listen(process.env.PORT || 3000, '0.0.0.0', () => {
    console.log('server running on all interfaces');
})
```

### 3. Verify Network Access

Test these URLs from your phone/device:
- Backend API: `http://192.168.0.60:8001/api`
- TRA Crawler: `http://192.168.0.60:3000`

## 🎯 Complete Local Configuration

After fixes, your Flutter app should use:

```dart
// Base API
static const String localBaseUrl = 'http://192.168.0.60:8001/api';

// TRA Scraper (local)
static const String scraperUrl = 'http://192.168.0.60:3000';

// Use local services
static const bool useLocalServer = true;
static const bool useDirectScraping = false; // Use your local scraper
```

## 🧪 Test Commands

```bash
# Test TRA crawler
curl http://192.168.0.60:3000

# Test Laravel API
curl http://192.168.0.60:8001/api/receipts

# Test from network (replace with your IP)
curl http://192.168.0.60:3000
curl http://192.168.0.60:8001
```