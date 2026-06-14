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
                    SettingsToggleRow(
                        title: "Show physical file size (disk space used)",
                        detail: showPhysicalSize
                            ? "Recommended mode: values match actual disk usage."
                            : "Logical-size mode is enabled: totals can diverge from actual used space in Disk Utility, especially on APFS.",
                        isOn: $showPhysicalSize
                    )
                    .help("Recommended: ON. Matches real disk usage in macOS Disk Utility. If OFF, values switch to logical file sizes and may not match actual space used on APFS volumes.")
                }

                Section("Packages & Bundles") {
                    SettingsToggleRow("Show package contents", isOn: $showPackageContents)
                        .help("Display contents of application bundles and packages")

                    SettingsToggleRow("Ignore creator codes when determining file type", isOn: $ignoreCreatorCodes)
                        .help("Use file extension instead of legacy creator codes")

                    SettingsToggleRow("Use extended file type catalog for unknown types", isOn: $useExternalFileKinds)
                        .help("When macOS cannot determine a known type, use bundled external catalog names for file extensions")

                    SettingsToggleRow("Collapse unknown file types into one group", isOn: $collapseUnknownFileTypes)
                        .help("Display only known file types and merge unknown ones into a single entry and color")
                }

                Section("Volume Display") {
                    SettingsToggleRow("Show free space", isOn: $showFreeSpace)
                        .help("Display free space on the volume in the treemap")

                    SettingsToggleRow("Show other space", isOn: $showOtherSpace)
                        .help("Display space used by other files on the volume")
                }

                Section("Scanning") {
                    SettingsToggleRow("Parallel scanning", isOn: $useParallelScanning)
                        .help("Scan directories in parallel for faster results. Disable for sequential scanning if you experience issues.")
                }
            }
            .formStyle(.grouped)
            .padding()
        }
    }
}

private struct SettingsValueRow<Content: View>: View {
    let title: String
    let detail: String?
    @ViewBuilder let content: Content

    init(_ title: String, detail: String? = nil, @ViewBuilder content: () -> Content = { EmptyView() }) {
        self.title = title
        self.detail = detail
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                if let detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
            }

            content
        }
    }
}

private struct SettingsToggleRow: View {
    let title: String
    let detail: String?
    @Binding var isOn: Bool

    init(_ title: String, detail: String? = nil, isOn: Binding<Bool>) {
        self.title = title
        self.detail = detail
        self._isOn = isOn
    }

    init(title: String, detail: String? = nil, isOn: Binding<Bool>) {
        self.title = title
        self.detail = detail
        self._isOn = isOn
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                if let detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 16)

            Toggle(title, isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
        }
    }
}

private struct SettingsSectionHeader: View {
    let title: String
    let detail: String?

    init(_ title: String, detail: String? = nil) {
        self.title = title
        self.detail = detail
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
            if let detail {
                Text(detail)
                    .font(.caption)
                    .fontWeight(.regular)
                    .foregroundStyle(.secondary)
                    .textCase(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct TreeMapSettingsTab: View {
    @AppStorage("cushionShading") private var cushionShading = true
    @AppStorage("showLabels") private var showLabels = true
    @AppStorage("minRectSize") private var minRectSize = 3.0

    var body: some View {
        ScrollView {
            Form {
                Section("Appearance") {
                    SettingsToggleRow("Cushion shading", isOn: $cushionShading)
                    .help("Apply gradient shading for a 3D cushion effect")

                    SettingsToggleRow("Show file name labels", isOn: $showLabels)
                        .help("Display file names on treemap rectangles")
                }

                Section("Performance") {
                    SettingsValueRow(
                        "Minimum rectangle size",
                        detail: "Smaller values show more detail but may be slower"
                    ) {
                        HStack {
                            Slider(value: $minRectSize, in: 1...10, step: 1) {
                                Text("Minimum rectangle size")
                            } minimumValueLabel: {
                                Text("1")
                            } maximumValueLabel: {
                                Text("10")
                            }
                            .labelsHidden()

                            Text("\(Int(minRectSize)) px")
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                                .frame(width: 42, alignment: .trailing)
                        }
                    }
                    .help("Minimum size in pixels for treemap rectangles")
                }
            }
            .formStyle(.grouped)
            .padding()
        }
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
    @AppStorage(AppLogger.treeMapLayoutDiagnosticsEnabledKey)
    private var isTreeMapLayoutDiagnosticsEnabled = false

    var body: some View {
        ScrollView {
            Form {
                Section("Logging") {
                    SettingsToggleRow("Enable logging", isOn: $isLoggingEnabled)

                    SettingsValueRow("Current log file", detail: AppLogger.shared.logFileURL.path) {
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
                    }
                }

                Section {
                    SettingsToggleRow("TreeMap layout diagnostics", isOn: $isTreeMapLayoutDiagnosticsEnabled)
                        .help("Temporary diagnostics can produce large logs and reduce performance. Keep them disabled unless you are actively investigating a specific issue.")
                        .disabled(!isLoggingEnabled)
                } header: {
                    SettingsSectionHeader(
                        "Temporary diagnostics",
                        detail: "Enable only while investigating a specific issue. These diagnostics can produce large logs and reduce performance."
                    )
                }
            }
            .formStyle(.grouped)
            .padding()
        }
    }
}

#Preview {
    SettingsView()
}
