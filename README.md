# FocusTrace

FocusTrace is a transparent, local-first personal screen-time tracker built with Flutter.

The MVP supports:

- Android usage summaries through Android Usage Access and `UsageStatsManager`
- Windows active-window tracking while the app is open
- Local SQLite storage for usage sessions and settings
- A dashboard for today's tracked usage

FocusTrace does not implement hidden monitoring, keylogging, screenshots, clipboard reading, browser history reading, or content monitoring.

## Platforms

- Android: reads today's app usage after the user grants Usage Access.
- Windows: tracks the active desktop window only while FocusTrace is open and tracking is manually started.

iOS, macOS, and Linux are not part of the MVP, but the architecture keeps platform data sources isolated so they can be added later.

## Android Usage Access

Android protects app-usage data behind the Usage Access settings screen. FocusTrace checks whether this access is granted and shows a permission card when it is missing.

The app declares:

```xml
<uses-permission android:name="android.permission.PACKAGE_USAGE_STATS" tools:ignore="ProtectedPermissions" />
```

FocusTrace opens the system Usage Access settings when you press **Open Usage Access Settings**. After granting access, return to the app and refresh.

## Windows Tracking

Windows tracking is manual and session-based:

1. Open FocusTrace.
2. Press **Start Tracking**.
3. FocusTrace periodically reads the foreground window title and process name.
4. Press **Stop Tracking** to end the current session.

Tracking stops when the app is closed. Background startup and tray tracking are not implemented in the MVP.

## Run

Install dependencies:

```sh
flutter pub get
```

Run on Android:

```sh
flutter run -d android
```

Run on Windows:

```sh
flutter run -d windows
```

## Tests

```sh
flutter test
```

## Privacy

All usage data is stored locally in SQLite on the device. FocusTrace does not send tracked data to a server and does not include sync in the MVP. Clearing local data removes stored usage sessions and settings from the local database.

## Roadmap

- macOS support using `NSWorkspace.frontmostApplication`
- iOS support using Screen Time APIs where possible
- App categories
- Charts
- Weekly and monthly reports
- Local export to CSV
- Optional encrypted sync later
