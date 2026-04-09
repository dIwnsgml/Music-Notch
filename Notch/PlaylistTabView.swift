import SwiftUI

struct PlaylistTabView: View {
    @ObservedObject var nowPlaying: NowPlayingManager
    
    var body: some View {
        VStack(spacing: 0) {
            if nowPlaying.playlist.isEmpty {
                VStack {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 24))
                        .foregroundColor(.gray.opacity(0.6))
                        .padding(.bottom, 4)
                    Text("No upcoming tracks found")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(nowPlaying.playlist) { track in
                            Button(action: {
                                nowPlaying.playTrack(track)
                            }) {
                                HStack(spacing: 12) {
                                    Group {
                                        if let urlString = track.imageURL, let url = URL(string: urlString), urlString != "NO_IMAGE", !urlString.isEmpty {
                                            AsyncImage(url: url) { image in
                                                image.resizable().aspectRatio(contentMode: .fill)
                                            } placeholder: {
                                                Rectangle().fill(nowPlaying.artworkDominantColor.opacity(0.3))
                                            }
                                        } else {
                                            ZStack {
                                                Rectangle().fill(nowPlaying.artworkDominantColor.opacity(0.3))
                                                Image(systemName: "music.note")
                                                    .font(.system(size: 10, weight: .bold))
                                                    .foregroundColor(.white.opacity(0.8))
                                            }
                                        }
                                    }
                                    .frame(width: 32, height: 32)
                                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        let isCurrent = nowPlaying.currentSong.contains(track.title)
                                        Text(track.title)
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(isCurrent ? nowPlaying.artworkDominantColor : .white)
                                            .lineLimit(1)
                                        Text(track.artist)
                                            .font(.system(size: 10, weight: .medium))
                                            .foregroundColor(isCurrent ? nowPlaying.artworkDominantColor.opacity(0.8) : .gray)
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                }
                                .padding(.horizontal, 20)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 12)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
