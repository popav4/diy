# CLAUDE.md

This file provides guidance to Claude Code when working with this repository.

## Build Commands

```bash
# Build release version
./BuildRelease.sh

# Or directly with xcodebuild
xcodebuild -project DiskInventoryY.xcodeproj -scheme DiskInventoryY -configuration Release

# Build debug version
xcodebuild -project DiskInventoryY.xcodeproj -scheme DiskInventoryY -configuration Debug
```

No test suite exists.

## Architecture Overview

Disk Inventory Y is a macOS SwiftUI application that visualizes disk space usage using treemaps. Pure Swift codebase with async/await concurrency.

### Core Components

- **App/DiskInventoryYApp.swift** - App entry point, single-window application
- **App/AppState.swift** - Observable state management, orchestrates scanning

### Models

- **Models/FileNode.swift** - Tree structure representing scanned filesystem. Stores URL, name, size, children. Supports recursive size calculation and sorting.

### Services

- **Services/FileScanner.swift** - Actor-based async filesystem scanner. Uses `withThrowingTaskGroup` for parallel directory traversal. Supports cancellation via Swift's structured concurrency.

### Views

- **Views/ContentView.swift** - Main view composing sidebar, treemap, and toolbar
- **Views/TreemapView.swift** - Canvas-based treemap visualization using squarified algorithm
- **Views/SidebarView.swift** - File browser outline view
- **Views/ToolbarView.swift** - Scan controls and preferences

### Utilities

- **Utilities/FileSizeFormatter.swift** - Human-readable file size formatting

## Key Patterns

- **SwiftUI + Observable** - `@Observable` macro for reactive state
- **Actor isolation** - FileScanner actor for thread-safe scanning
- **Structured concurrency** - Parallel child scanning with task groups
- **Sendable conformance** - Thread-safe progress reporting

## macOS Considerations

- Minimum deployment: macOS 14.0+
- Apple Silicon + Intel (Universal)
- Requires Full Disk Access for scanning protected directories
- App Sandbox enabled with file read permissions

## License

GPL v3
