# AGENTS.md - ClockerBar

> **Status**: Active macOS menu bar app.
> **Purpose**: Time tracking menu bar app that integrates with BambooHR clock in/out.

## Key Files
- `bamboohr-spec.yaml` - OpenAPI 3.1.0 spec for BambooHR Time Tracking API
- `ClockerBar/` - Swift Package Manager project

### Swift Sources (`ClockerBar/Sources/ClockerBar/`)
| File | Purpose |
|------|---------|
| `main.swift` | App entry point |
| `AppDelegate.swift` | App lifecycle, Edit menu for copy/paste |
| `BambooHRClient.swift` | BambooHR API client (timesheet, clock in/out, employee directory) |
| `ClockerService.swift` | Business logic layer |
| `KeychainManager.swift` | Secure credential storage in macOS Keychain |
| `StatusBarController.swift` | Menu bar UI with SF Symbol icons |
| `SetupWindowController.swift` | Multi-step setup wizard |

### App Bundle
- `ClockerBar/ClockerBar.app/` - App bundle with `Info.plist` (LSUIElement=true for menu bar only)

---

## Build / Run Commands

```bash
cd ClockerBar

# Build
xcodebuild -scheme ClockerBar -destination 'platform=macOS' build

# Copy binary to app bundle
cp ~/Library/Developer/Xcode/DerivedData/ClockerBar-*/Build/Products/Debug/ClockerBar ClockerBar.app/Contents/MacOS/

# Run
open ClockerBar.app
```

---

## Features

### Menu Bar Icons (SF Symbols)
| Icon | State |
|------|-------|
| `clock` | Clocked out |
| `clock.fill` | Clocked in |
| `clock.badge.questionmark` | Past 8AM, not clocked in (reminder) |
| `clock.badge.questionmark.fill` | Past 6PM, still clocked in (reminder) |

### Dropdown Menu
- Status display (Clocked In / Clocked Out)
- Time since clock-in
- Today's total hours
- Toggle / Refresh / Settings / Quit actions

### Setup Wizard (3 steps)
1. Enter API Key
2. Enter Company Domain
3. Select employee from auto-loaded directory

Credentials stored securely in macOS Keychain.

---

## Code Style

### Swift
- Swift 5, macOS 13.0+
- Swift Package Manager
- AppKit for UI (no SwiftUI)

### Patterns
- Async/await for API calls
- MainActor for UI updates
- Delegate pattern for communication between controllers

### Naming Conventions
| Element | Convention | Example |
|---------|------------|---------|
| Files | PascalCase | `BambooHRClient.swift` |
| Types/Classes | PascalCase | `StatusBarController` |
| Functions/Variables | camelCase | `loadEmployees()` |
| Constants | camelCase | `refreshInterval` |

---

## BambooHR API

### Authentication
Basic Auth: API key as username, `x` as password.

### Key Endpoints
| Endpoint | Method | Description |
|----------|--------|-------------|
| `/employees/directory` | GET | Get employee list |
| `/time_tracking/timesheet_entries` | GET | Get entries for date range |
| `/time_tracking/employees/{id}/clock_in` | POST | Clock in |
| `/time_tracking/employees/{id}/clock_out` | POST | Clock out |

### Clock Status Detection
Employee is "clocked in" when timesheet entry has:
- `type === "clock"`
- `start !== null`
- `end === null`

---

## Agent Instructions

### Do
- Use Swift async/await for API calls
- Use MainActor.run for UI updates from async contexts
- Store credentials in Keychain, never in files
- Handle all API error cases

### Don't
- Commit API keys or secrets
- Use force unwrapping (`!`) except for IBOutlets
- Block the main thread with synchronous network calls

---

*Updated: January 2026*
