#!/bin/bash

# Stop script immediately if any command fails
set -e

# ==========================================
# CONFIGURATION
# ==========================================
PROJECT_DIR="/Users/jasonlee/Coding/App/Notch"
RELEASES_DIR="$PROJECT_DIR/Releases"
WEBSITE_PUBLIC_DIR="/Users/jasonlee/Coding/Web/Wave-Notch-Website/public"
SPARKLE_BIN="/Users/jasonlee/Downloads/Sparkle-2.9.1/bin/generate_appcast"
MASTER_BACKGROUND="$RELEASES_DIR/background.png"
EXPORT_PLIST="$PROJECT_DIR/ExportOptions.plist"
NOTARY_PROFILE="WaveNotchNotary" # ⚡️ Your secure keychain profile

echo "🚀 Starting 100% Automated WaveNotch Release Pipeline..."

# 1. Ask for version number
read -p "Enter the new visible version (e.g., 2.3): " VERSION_NUM
RELEASE_FOLDER_NAME="WaveNotch_Release_$VERSION_NUM"
RELEASE_FOLDER_PATH="$RELEASES_DIR/$RELEASE_FOLDER_NAME"
DMG_NAME="${RELEASE_FOLDER_NAME}.dmg"
DMG_PATH="$RELEASES_DIR/$DMG_NAME"
ARCHIVE_PATH="$RELEASES_DIR/WaveNotch.xcarchive"

if [ ! -f "$EXPORT_PLIST" ]; then
    echo "❌ Error: ExportOptions.plist not found at $EXPORT_PLIST!"
    exit 1
fi

# 2. Increment Build and Update Version
cd "$PROJECT_DIR"
echo "📈 Updating Xcode version to $VERSION_NUM and incrementing build number..."
agvtool new-marketing-version "$VERSION_NUM"
agvtool next-version -all

# 3. Create Release Folder
mkdir -p "$RELEASE_FOLDER_PATH"

# 4. Xcode Build & Archive
echo "🏗️ Archiving WaveNotch..."
rm -rf "$ARCHIVE_PATH" 
xcodebuild -project Notch.xcodeproj -scheme Notch -configuration Release -archivePath "$ARCHIVE_PATH" archive 

# 5. Xcode Export
echo "📦 Exporting .app bundle using your Developer ID..."
xcodebuild -exportArchive -archivePath "$ARCHIVE_PATH" -exportOptionsPlist "$EXPORT_PLIST" -exportPath "$RELEASE_FOLDER_PATH" 

if [ ! -d "$RELEASE_FOLDER_PATH/WaveNotch.app" ]; then
    echo "❌ Error: WaveNotch.app failed to export!"
    exit 1
fi

# 6. Copy background.png
echo "🖼️  Copying DMG background..."
cp "$MASTER_BACKGROUND" "$RELEASE_FOLDER_PATH/"

# 7. Create the DMG
echo "💿 Packaging DMG..."
cd "$RELEASE_FOLDER_PATH"
create-dmg \
  --volname "WaveNotch" \
  --window-pos 200 120 \
  --window-size 600 400 \
  --icon-size 120 \
  --icon "WaveNotch.app" 150 170 \
  --hide-extension "WaveNotch.app" \
  --app-drop-link 450 170 \
  --background "background.png" \
  "$DMG_NAME" \
  "WaveNotch.app/"

# 8. Move DMG outside the folder
echo "🚚 Moving DMG to root Releases folder..."
mv "$DMG_NAME" "$RELEASES_DIR/"
cd "$RELEASES_DIR"

# ⚡️ 9. NOTARIZE THE DMG (NEW)
echo "🛡️ Uploading to Apple for Malware Scan (This takes 1-5 minutes)..."
xcrun notarytool submit "$DMG_NAME" --keychain-profile "$NOTARY_PROFILE" --wait

# ⚡️ 10. STAPLE THE TICKET (NEW)
echo "📎 Stapling Notarization Ticket to DMG..."
xcrun stapler staple "$DMG_NAME"

# 11. Generate Sparkle Appcast
echo "✨ Generating Sparkle Appcast..."
"$SPARKLE_BIN" "$RELEASES_DIR"

# 12. Patch the URL in appcast.xml
echo "🔗 Patching appcast.xml URLs to point to /releases/..."
sed -i '' 's|https://wavenotch.com/WaveNotch_Release_|https://wavenotch.com/releases/WaveNotch_Release_|g' "$RELEASES_DIR/appcast.xml"

# 13. Deploy to Website Directory
echo "🌐 Deploying to Website..."
mkdir -p "$WEBSITE_PUBLIC_DIR/releases"
cp "$RELEASES_DIR/appcast.xml" "$WEBSITE_PUBLIC_DIR/appcast.xml"
cp "$DMG_PATH" "$WEBSITE_PUBLIC_DIR/releases/"

# 14. Cleanup temporary files
rm -rf "$ARCHIVE_PATH"

echo ""
echo "🎉 SUCCESS! WaveNotch $VERSION_NUM is built, notarized by Apple, and deployed without warnings!"
