# WaveNotch

<p align="center">
  <strong>Turn your MacBook notch into something useful.</strong>
</p>

<p align="center">
  A native macOS dashboard for media controls, productivity tools, system information, and customizable widgets.
</p>

<p align="center">
  <a href="https://wavenotch.com">Website</a> ·
  <a href="https://github.com/dIwnsgml/WaveNotch">Source</a>
</p>

---

## About

WaveNotch is a native macOS application that transforms the area around the MacBook notch into an interactive dashboard.

Instead of treating the notch as unused screen space, WaveNotch turns it into a central place for media controls, productivity tools, system information, and customizable widgets.

The application is built primarily with **Swift and SwiftUI**.

## Features

### 🎵 Now Playing

Control currently playing media directly from the notch.

- Playback controls
- Track information
- Album artwork
- Queue management
- Spotify integration
- Apple Music / system media support

### 🎤 Synchronized Lyrics

View lyrics alongside currently playing music.

WaveNotch includes dedicated lyric management and search functionality for displaying synchronized song lyrics.

### 🧩 Customizable Widgets

WaveNotch includes a plugin-based widget system that allows different tools to be displayed inside the notch interface.

Current widgets and integrations include:

- 📁 File Tray
- 📶 Network Speed
- 💻 Hardware HUD
- ✅ Tasks
- 📸 Screen Capture
- 🐾 Notch Pets
- 📅 Calendar functionality
- 🎵 Media controls

### ⚙️ macOS Integration

WaveNotch integrates directly with macOS functionality, including:

- Global shortcuts
- Launch at login
- System notifications
- Bluetooth-connected device information
- Local weather support
- Custom URL schemes
- Background media monitoring

## Architecture

WaveNotch is organized into several main layers:

```text
Notch/
├── App/
├── Components/
├── Extensions/
├── Managers/
├── Models/
└── Views/
```

### Managers

Long-running application functionality is separated into dedicated managers.

Examples include:

```text
NowPlayingManager
SpotifyAuthManager
GoogleCalendarManager
PluginManager
HardwareHUDManager
SystemNotificationMonitor
DashboardManager
```

This separates system integrations and state management from the SwiftUI presentation layer.

### Views

The UI is built with SwiftUI and separated into feature-specific views and widgets, including:

```text
ContentView
PlayerTabView
PlaylistTabView
PluginStoreView
FileTrayWidget
NetworkSpeedWidget
HardwareHUDWidget
TasksWidget
ScreenCaptureWidget
NotchPetsWidget
```

## Tech Stack

- Swift
- SwiftUI
- macOS native APIs
- Xcode

Integrations include functionality around:

- Spotify
- Apple/system media
- Google Calendar
- Bluetooth devices
- macOS notifications
- Location-based weather

## Development

Clone the repository:

```bash
git clone https://github.com/dIwnsgml/WaveNotch.git
cd WaveNotch
```

Open:

```text
Notch.xcodeproj
```

in Xcode and run the macOS target.

Some integrations may require local credentials or permissions before they function.

## Privacy & Permissions

Certain optional WaveNotch features require macOS permissions.

Examples include:

- Location access for local weather
- Bluetooth access for connected-device battery information
- System permissions required by individual widgets

These capabilities are used only when their related functionality is enabled.

## Project Status

WaveNotch was actively developed from **April 2026 to August 2026**.

The repository is public as a showcase of the project's implementation and architecture.

## Author

**Jason (Junhee) Lee**

- Website: [leejason.dev](https://leejason.dev)
- LinkedIn: [jason-leee](https://linkedin.com/in/jason-leee)
- GitHub: [dIwnsgml](https://github.com/dIwnsgml)
