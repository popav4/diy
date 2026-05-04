# Disk Inventory Y

Disk Inventory Y is a macOS disk usage visualizer. It scans a selected folder or volume and renders the result as a treemap, making large files and directories easy to spot.

This project is a modern SwiftUI rewrite inspired by Disk Inventory X.

## Upstream

This repository is a fork of [`diskinv/diy`](https://github.com/diskinv/diy).

## Features

- Native macOS SwiftUI application.
- Treemap visualization rendered with SwiftUI `Canvas`.
- Async filesystem scanning with parallel directory traversal.
- Sidebar with file tree navigation and file kind statistics.
- Zoom in, zoom out, refresh, and folder selection commands.
- Optional display of free space, other space, package contents, and physical file size.

## Requirements

- macOS 14.0 or later.
- Xcode with the macOS SDK.

Scanning protected locations may require granting the app Full Disk Access in macOS System Settings.

## Build

Use the repository shell scripts instead of invoking `xcodebuild` directly. They keep build behavior consistent and write the latest build log to `.tmp/log/build/`.

Debug build:

```bash
./BuildDebug.sh
```

Debug app output:

```text
build/Build/Products/Debug/Disk Inventory Y.app
```

Release build:

```bash
./BuildRelease.sh
```

Release app output:

```text
build/Build/Products/Release/Disk Inventory Y.app
```

## Project Structure

- `App/` - application entry point and global app state.
- `Models/` - filesystem tree and file kind statistics.
- `Services/` - async filesystem scanner.
- `Views/` - SwiftUI views for the sidebar, file list, settings, and treemap.
- `Utilities/` - file size formatting and file kind color assignment.

## License

GPL v3. See the source headers and project metadata for copyright details.
