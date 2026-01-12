# ClockerBar

A macOS menu bar app for BambooHR time tracking. Clock in/out with a single click.

## Features

- **Menu bar integration** - Lives in your menu bar, always accessible
- **Smart reminders** - Icon changes if you forget to clock in (after 8AM) or out (after 6PM)
- **Secure storage** - Credentials stored in macOS Keychain
- **Quick setup** - 3-step wizard with employee auto-discovery

## Menu Bar Icons

| Icon | Meaning |
|------|---------|
| `clock` | Clocked out |
| `clock.fill` | Clocked in |
| `clock.badge.questionmark` | Past 8AM, not clocked in |
| `clock.badge.questionmark.fill` | Past 6PM, still clocked in |

## Requirements

- macOS 13.0+
- Xcode (for building)
- BambooHR API key

## Installation

```bash
make run
```

On first launch, the setup wizard will guide you through:
1. Enter your BambooHR API key
2. Enter your company domain (e.g., `acme` from `acme.bamboohr.com`)
3. Select your name from the employee directory

## Build Commands

```bash
make build  # Build app
make run    # Build and launch
make clean  # Clean build artifacts
```

## Getting Your API Key

1. Log in to BambooHR
2. Go to Account → API Keys
3. Generate a new key

## License

MIT
