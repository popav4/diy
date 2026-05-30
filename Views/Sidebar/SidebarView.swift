//
//  SidebarView.swift
//  DiskInventoryY
//
//  Sidebar showing file kind statistics
//

import SwiftUI

struct SidebarView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        List(selection: $appState.selectedKind) {
            if let root = appState.rootNode {
                Section("Summary") {
                    LabeledContent("Total Size") {
                        Text(FileSizeFormatter.string(from: root.size))
                            .monospacedDigit()
                    }

                    LabeledContent("File Types") {
                        Text("\(appState.kindStatistics.count)")
                            .monospacedDigit()
                    }

                    let totalFiles = appState.kindStatistics.reduce(0) { $0 + $1.count }
                    LabeledContent("Files") {
                        Text("\(totalFiles)")
                            .monospacedDigit()
                    }
                }
            }

            if !appState.kindStatistics.isEmpty {
                Section("File Types") {
                    ForEach(appState.kindStatistics) { stat in
                        FileKindRow(
                            statistic: stat,
                            displayName: appState.displayKindName(for: stat.kindName)
                        )
                            .tag(stat.kindName)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("File Types")
    }
}

struct FileKindRow: View {
    let statistic: FileKindStatistic
    let displayName: String

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statistic.color)
                .frame(width: 12, height: 12)

            VStack(alignment: .leading, spacing: 2) {
                Text(titleLine)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text("\(statistic.formattedCount) files")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(sourceLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text(statistic.formattedSize)
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    private var sourceLabel: String {
        switch statistic.kindSource {
        case .macOS:
            return "macOS"
        case .external:
            return "External"
        case .special:
            return "Merged"
        }
    }

    private var titleLine: String {
        guard let ext = statistic.extensionDisplay, !ext.isEmpty else {
            return displayName
        }
        if ext == "various" {
            return displayName
        }
        return "\(displayName) (.\(ext))"
    }
}

#Preview {
    SidebarView()
        .environmentObject(AppState())
        .frame(width: 250, height: 400)
}
