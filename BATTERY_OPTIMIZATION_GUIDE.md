# Battery Optimization Guide for LPU Live

To ensure your WebSocket connection stays active even when your phone is locked, you need to disable battery optimization for the LPU Live app.

## Why This Is Needed

When your phone is locked, Android/iOS often restricts network access for apps to save battery. This causes the "No address associated with hostname" error you're experiencing. By disabling battery optimization, the app can maintain its WebSocket connection even when the phone is locked.

## How to Disable Battery Optimization

### Android Devices:

#### Method 1: Through Settings
1. Open **Settings** on your Android device
2. Go to **Battery** or **Battery & Performance**
3. Tap **Battery Optimization** or **Battery Saver**
4. Find **LPU Live** in the list
5. Tap on **LPU Live**
6. Select **Don't optimize** or **Not optimized**
7. Tap **Done** or **Save**

#### Method 2: Through App Settings
1. Open **Settings** on your Android device
2. Go to **Apps** or **Application Manager**
3. Find and tap **LPU Live**
4. Tap **Battery** or **Battery Usage**
5. Select **Don't optimize** or **Not optimized**

#### Method 3: Through Developer Options (Advanced)
1. Enable **Developer Options** (tap Build Number 7 times in About Phone)
2. Go to **Developer Options**
3. Find **Background App Limits** or **Background Process Limit**
4. Set to **No background processes** or **Standard limit**

### iOS Devices:

#### Method 1: Through Settings
1. Open **Settings** on your iPhone/iPad
2. Go to **Battery**
3. Tap **Battery Health**
4. Turn off **Low Power Mode** (if enabled)

#### Method 2: Through App Settings
1. Open **Settings** on your iPhone/iPad
2. Go to **General** > **Background App Refresh**
3. Find **LPU Live** in the list
4. Enable **Background App Refresh** for LPU Live

## Additional Settings

### Android Additional Settings:

1. **Auto-start Management:**
   - Go to **Settings** > **Apps** > **LPU Live**
   - Enable **Auto-start** or **Allow auto-start**

2. **Data Usage:**
   - Go to **Settings** > **Data Usage**
   - Find **LPU Live** and ensure it has **Unrestricted data access**

3. **Doze Mode (Android 6+):**
   - Go to **Settings** > **Battery** > **Battery Optimization**
   - Add **LPU Live** to **Not optimized** list

### iOS Additional Settings:

1. **Background App Refresh:**
   - Go to **Settings** > **General** > **Background App Refresh**
   - Enable for **LPU Live**

2. **Low Data Mode:**
   - Go to **Settings** > **Cellular** > **Cellular Data Options**
   - Turn off **Low Data Mode**

## Verification

After making these changes:

1. **Test the Connection:**
   - Open LPU Live app
   - Connect to WebSocket
   - Lock your phone
   - Wait 5-10 minutes
   - Unlock and check if connection is still active

2. **Check Logs:**
   - Look for these log messages:
   ```
   ✅ [BackgroundWebSocket] Connected successfully
   📡 [BackgroundWebSocket] Connectivity check passed
   🔌 [ForegroundService] Foreground service started successfully
   ```

## Troubleshooting

### If Connection Still Drops:

1. **Check Network Settings:**
   - Ensure WiFi/Mobile data is stable
   - Try switching between WiFi and Mobile data

2. **Restart the App:**
   - Force close LPU Live
   - Reopen and reconnect

3. **Check Device-Specific Settings:**
   - Some manufacturers (Samsung, Xiaomi, etc.) have additional battery optimization settings
   - Look for **MIUI Optimization**, **Samsung Battery Optimization**, etc.

4. **Update the App:**
   - Ensure you're using the latest version of LPU Live

### Common Issues:

- **"No address associated with hostname"** - Battery optimization is still enabled
- **Connection drops after 5 minutes** - Doze mode is still active
- **No notifications** - Background app refresh is disabled

## Benefits After Setup:

✅ **Persistent Connection** - WebSocket stays connected when phone is locked
✅ **Real-time Notifications** - Get notified of new messages immediately
✅ **Better User Experience** - No need to reconnect when unlocking phone
✅ **Reliable Messaging** - Messages are delivered instantly

## Important Notes:

- Disabling battery optimization may slightly increase battery usage
- The app will show a persistent notification when maintaining connection
- This is normal behavior for apps that need to stay connected
- You can always re-enable battery optimization if needed

## Support

If you continue to experience connection issues after following this guide, please contact support with:
- Your device model and Android/iOS version
- Screenshots of your battery optimization settings
- Log files from the app (if available)
