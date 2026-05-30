//
//  SettingsView.swift
//  DiskInventoryY
//
//  Application settings/preferences
//

import SwiftUI
import AppKit

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsTab()
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            TreeMapSettingsTab()
                .tabItem {
                    Label("TreeMap", systemImage: "square.grid.2x2")
                }

            LogsSettingsTab()
                .tabItem {
                    Label("Logs", systemImage: "doc.text.magnifyingglass")
                }

            AboutTab()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 480, height: 700)
    }
}

struct GeneralSettingsTab: View {
    @AppStorage("showPhysicalSize") private var showPhysicalSize = true
    @AppStorage("showPackageContents") private var showPackageContents = false
    @AppStorage("ignoreCreatorCodes") private var ignoreCreatorCodes = true
    @AppStorage("useExternalFileKinds") private var useExternalFileKinds = true
    @AppStorage("collapseUnknownFileTypes") private var collapseUnknownFileTypes = true
    @AppStorage("showFreeSpace") private var showFreeSpace = true
    @AppStorage("showOtherSpace") private var showOtherSpace = true
    @AppStorage("useParallelScanning") private var useParallelScanning = true

    var body: some View {
        ScrollView {
            Form {
                Section("File Sizes") {
                    Toggle("Show physical file size (disk space used)", isOn: $showPhysicalSize)
                        .help("Recommended: ON. Matches real disk usage in macOS Disk Utility. If OFF, values switch to logical file sizes and may not match actual space used on APFS volumes.")

                    Text(showPhysicalSize
                         ? "Recommended mode: values match actual disk usage."
                         : "Logical-size mode is enabled: totals can diverge from actual used space in Disk Utility, especially on APFS.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Packages & Bundles") {
                    Toggle("Show package contents", isOn: $showPackageContents)
                        .help("Display contents of application bundles and packages")

                    Toggle("Ignore creator codes when determining file type", isOn: $ignoreCreatorCodes)
                        .help("Use file extension instead of legacy creator codes")

                    Toggle("Use extended file type catalog for unknown types", isOn: $useExternalFileKinds)
                        .help("When macOS cannot determine a known type, use bundled external catalog names for file extensions")

                    Text("Applied on next scan/refresh.")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)

                    Toggle("Collapse unknown file types into one group", isOn: $collapseUnknownFileTypes)
                        .help("Display only known file types and merge unknown ones into a single entry and color")
                }

                Section("Volume Display") {
                    Toggle("Show free space", isOn: $showFreeSpace)
                        .help("Display free space on the volume in the treemap")

                    Toggle("Show other space", isOn: $showOtherSpace)
                        .help("Display space used by other files on the volume")
                }

                Section("Scanning") {
                    Toggle("Parallel scanning", isOn: $useParallelScanning)
                        .help("Scan directories in parallel for faster results. Disable for sequential scanning if you experience issues.")
                }
            }
            .formStyle(.grouped)
            .padding()
        }
    }
}

struct TreeMapSettingsTab: View {
    @AppStorage("cushionShading") private var cushionShading = true
    @AppStorage("showLabels") private var showLabels = true
    @AppStorage("minRectSize") private var minRectSize = 3.0

    var body: some View {
        Form {
            Section("Appearance") {
                Toggle("Cushion shading", isOn: $cushionShading)
                    .help("Apply gradient shading for a 3D cushion effect")

                Toggle("Show file name labels", isOn: $showLabels)
                    .help("Display file names on treemap rectangles")
            }

            Section("Performance") {
                Slider(value: $minRectSize, in: 1...10, step: 1) {
                    Text("Minimum rectangle size")
                } minimumValueLabel: {
                    Text("1")
                } maximumValueLabel: {
                    Text("10")
                }
                .help("Minimum size in pixels for treemap rectangles")

                Text("Smaller values show more detail but may be slower")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

struct AboutTab: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.pie.fill")
                .font(.system(size: 64))
                .foregroundStyle(.blue)

            Text("Disk Inventory Y")
                .font(.title)
                .fontWeight(.bold)

            Text("Version 2.0")
                .foregroundStyle(.secondary)

            Text("A disk usage visualization tool using treemaps")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Divider()

            Text("Original author: Tjark Derlien")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Text("Swift rewrite - 2024")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Text("Fork and ongoing development - 2026: Alexander Popov")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Link("GPL v3 License", destination: URL(string: "https://www.gnu.org/licenses/gpl-3.0.html")!)
                .font(.caption)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct LogsSettingsTab: View {
    @AppStorage(AppLogger.loggingEnabledKey)
    private var isLoggingEnabled = true

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Enable logging", isOn: $isLoggingEnabled)

            Text("Current log file")
                .font(.headline)

            Text(AppLogger.shared.logFileURL.path)
                .font(.system(size: 12, weight: .regular, design: .monospaced))
                .lineLimit(3)
                .textSelection(.enabled)

            HStack(spacing: 12) {
                Button("Open Log") {
                    NSWorkspace.shared.open(AppLogger.shared.logFileURL)
                }
                .disabled(!isLoggingEnabled)

                Button("Open Log Folder") {
                    NSWorkspace.shared.open(AppLogger.shared.logFileURL.deletingLastPathComponent())
                }
                .disabled(!isLoggingEnabled)

                Button("Clear Log") {
                    AppLogger.shared.clearLog()
                }
                .disabled(!isLoggingEnabled)
            }

            Spacer()
        }
        .padding()
    }
}

#Preview {
    SettingsView()
}
