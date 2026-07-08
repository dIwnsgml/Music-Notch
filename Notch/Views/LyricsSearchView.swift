import SwiftUI

struct LyricsSearchView: View {
    @ObservedObject var nowPlaying: NowPlayingManager

    @State private var titleQuery: String
    @State private var artistQuery: String
    @State private var selectedSource: LyricsSourceFilter = .all
    @State private var results: [LyricsSearchResult] = []
    @State private var selectedResult: LyricsSearchResult?
    @State private var isSearching = false
    @State private var errorMessage: String?
    @State private var appliedResultID: UUID?
    @State private var activeSearchID = UUID()

    init(nowPlaying: NowPlayingManager) {
        self.nowPlaying = nowPlaying
        let query = nowPlaying.currentLyricsSearchQuery()
        _titleQuery = State(initialValue: query.title)
        _artistQuery = State(initialValue: query.artist)
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()
                .opacity(0.35)

            searchControls
                .padding(18)

            HStack(alignment: .top, spacing: 0) {
                resultsColumn
                    .frame(minWidth: 300, idealWidth: 340, maxWidth: 390)

                Divider()
                    .opacity(0.35)

                previewColumn
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 680, minHeight: 500)
        .background(Color(nsColor: .windowBackgroundColor))
        .task {
            await search()
        }
        .onChange(of: selectedSource) { _, _ in
            Task { await search() }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.accentColor.opacity(0.16))
                    .frame(width: 42, height: 42)

                Image(systemName: "music.mic")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.accentColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("Lyrics Search")
                    .font(.system(size: 17, weight: .bold))
                Text("Find a better version, choose a source, then save it for this song.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button {
                nowPlaying.markNoLyricsForCurrentSong()
                LyricsSearchWindowManager.shared.close()
            } label: {
                Label("No Lyrics", systemImage: "eye.slash.fill")
                    .font(.system(size: 12, weight: .bold))
            }
            .buttonStyle(.bordered)
            .help("Do not search automatically for this song until you search again.")
        }
        .padding(18)
    }

    private var searchControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Title")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                    TextField("Song title", text: $titleQuery)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text("Artist")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                    TextField("Artist", text: $artistQuery)
                        .textFieldStyle(.roundedBorder)
                }
            }

            HStack(spacing: 10) {
                Picker("Source", selection: $selectedSource) {
                    ForEach(LyricsSourceFilter.allCases) { filter in
                        Text(filter.title).tag(filter)
                    }
                }
                .pickerStyle(.segmented)

                Button {
                    Task { await search() }
                } label: {
                    Label(isSearching ? "Searching" : "Search", systemImage: "magnifyingglass")
                        .font(.system(size: 12, weight: .bold))
                }
                .buttonStyle(.borderedProminent)
                .disabled(isSearching || titleQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private var resultsColumn: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("\(results.count) result\(results.count == 1 ? "" : "s")")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.secondary)

                Spacer()

                if isSearching {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 14)

            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 80)
            } else if results.isEmpty && !isSearching {
                emptyResults
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(results) { result in
                            resultRow(result)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 16)
                }
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color.black.opacity(0.025))
    }

    private var emptyResults: some View {
        VStack(spacing: 10) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 28, weight: .semibold))
                .foregroundColor(.secondary.opacity(0.75))
            Text("No lyrics found")
                .font(.system(size: 13, weight: .bold))
            Text("Try a shorter title, remove remix tags, or switch sources.")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 28)
    }

    private func resultRow(_ result: LyricsSearchResult) -> some View {
        let isSelected = selectedResult?.id == result.id

        return Button {
            selectedResult = result
        } label: {
            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 8) {
                    sourceBadge(result.source)

                    Text(result.isSynced ? "Synced" : "Plain")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)

                    Spacer()

                    Text("\(result.lines.count) lines")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(result.title)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    Text(result.artist.isEmpty ? "Unknown artist" : result.artist)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                if let preview = result.lines.first?.text {
                    Text(preview)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? Color.accentColor.opacity(0.16) : Color.white.opacity(0.06))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isSelected ? Color.accentColor.opacity(0.55) : Color.white.opacity(0.08), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var previewColumn: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let selectedResult {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 8) {
                            sourceBadge(selectedResult.source)
                            Text(selectedResult.isSynced ? "Timestamped lyrics" : "Plain lyrics")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.secondary)
                        }

                        Text(selectedResult.title)
                            .font(.system(size: 18, weight: .bold))
                            .lineLimit(1)

                        Text(selectedResult.artist.isEmpty ? "Unknown artist" : selectedResult.artist)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)
                            .lineLimit(1)

                        if let album = selectedResult.album, !album.isEmpty {
                            Text(album)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 8) {
                        Text("\(Int(selectedResult.score * 100))% match")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)

                        Button {
                            nowPlaying.applyLyricsSearchResult(selectedResult)
                            appliedResultID = selectedResult.id
                        } label: {
                            Label(appliedResultID == selectedResult.id ? "Using" : "Use Lyrics", systemImage: "checkmark.circle.fill")
                                .font(.system(size: 12, weight: .bold))
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }

                Divider()
                    .opacity(0.35)

                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(selectedResult.lines.enumerated()), id: \.offset) { _, line in
                            HStack(alignment: .firstTextBaseline, spacing: 10) {
                                if selectedResult.isSynced {
                                    Text(formatLyricTime(line.time))
                                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                        .foregroundColor(.secondary)
                                        .frame(width: 46, alignment: .leading)
                                }

                                Text(line.text)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.primary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                    .padding(.bottom, 18)
                }
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "text.quote")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundColor(.secondary.opacity(0.75))
                    Text(isSearching ? "Searching lyrics..." : "Select a result")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(18)
    }

    private func search() async {
        let title = titleQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let artist = artistQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }

        let searchID = UUID()
        activeSearchID = searchID
        isSearching = true
        errorMessage = nil
        selectedResult = nil
        appliedResultID = nil
        results = []

        let primarySources: Set<LyricsSearchSource> = selectedSource == .all ? [.cache, .lrclib, .kugou] : selectedSource.sources
        let primaryResults = await nowPlaying.searchLyricsResults(title: title, artist: artist, sources: primarySources)
        guard activeSearchID == searchID else { return }

        results = primaryResults
        selectedResult = primaryResults.first

        if selectedSource == .all {
            let secondaryResults = await nowPlaying.searchLyricsResults(title: title, artist: artist, sources: [.lyricsOVH, .netease])
            guard activeSearchID == searchID else { return }

            results = mergedResults(primaryResults + secondaryResults)
            if selectedResult == nil {
                selectedResult = results.first
            }
        }

        isSearching = false
        errorMessage = results.isEmpty ? "No results from \(selectedSource.title)." : nil
    }

    private func mergedResults(_ incoming: [LyricsSearchResult]) -> [LyricsSearchResult] {
        var seen = Set<String>()
        var merged: [LyricsSearchResult] = []

        for result in incoming.sorted(by: { $0.score > $1.score }) {
            let preview = result.lines.prefix(8).map(\.text).joined(separator: "|").lowercased()
            let key = [
                result.source.rawValue,
                result.title.lowercased(),
                result.artist.lowercased(),
                preview
            ].joined(separator: "::")

            if seen.insert(key).inserted {
                merged.append(result)
            }
        }

        return merged
    }

    private func sourceBadge(_ source: LyricsSearchSource) -> some View {
        Text(source.rawValue)
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(sourceColor(source))
            .padding(.horizontal, 7)
            .frame(height: 20)
            .background(sourceColor(source).opacity(0.13))
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    private func sourceColor(_ source: LyricsSearchSource) -> Color {
        switch source {
        case .cache: return .blue
        case .lrclib: return .green
        case .kugou: return .orange
        case .lyricsOVH: return .purple
        case .netease: return .red
        }
    }

    private func formatLyricTime(_ seconds: Double) -> String {
        let safe = max(0, seconds)
        let minute = Int(safe) / 60
        let second = Int(safe) % 60
        return String(format: "%d:%02d", minute, second)
    }
}

private enum LyricsSourceFilter: String, CaseIterable, Hashable, Identifiable {
    case all
    case cache
    case lrclib
    case kugou
    case lyricsOVH
    case netease

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "All"
        case .cache: return "Cached"
        case .lrclib: return "LRCLIB"
        case .kugou: return "KuGou"
        case .lyricsOVH: return "Lyrics.ovh"
        case .netease: return "Netease"
        }
    }

    var sources: Set<LyricsSearchSource> {
        switch self {
        case .all:
            return Set(LyricsSearchSource.allCases)
        case .cache:
            return [.cache]
        case .lrclib:
            return [.lrclib]
        case .kugou:
            return [.kugou]
        case .lyricsOVH:
            return [.lyricsOVH]
        case .netease:
            return [.netease]
        }
    }
}
