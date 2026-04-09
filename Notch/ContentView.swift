import SwiftUI

enum AppTab {
    case player
    case playlist
}

struct ContentView: View {
    @State private var isExpanded = false
    @StateObject private var nowPlaying = NowPlayingManager()
    @State private var currentTab: AppTab = .player
    
    let notchHeight: CGFloat = 32
    let collapsedWidth: CGFloat = 300
    let expandedWidth: CGFloat = 380

    var body: some View {
        let hasMedia = nowPlaying.currentSong != "No Music" && nowPlaying.currentSong != "NOT_PLAYING"
        let playerHeight: CGFloat = !nowPlaying.lyrics.isEmpty ? 164 : 100
        let expandedHeight: CGFloat = currentTab == .playlist ? 200 : playerHeight

        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                
                DynamicNotchShape(cornerRadius: isExpanded ? 24 : 16, blendRadius: 16)
                    .fill(Color.black)
                    .frame(width: isExpanded ? expandedWidth : collapsedWidth,
                           height: isExpanded ? expandedHeight : notchHeight)
                    .overlay(
                        DynamicNotchShape(cornerRadius: isExpanded ? 24 : 16, blendRadius: 16)
                            .stroke(Color.white.opacity(isExpanded ? 0.1 : 0.0), lineWidth: 1)
                    )

                VStack(spacing: 0) {
                    if !isExpanded {
                        HStack(spacing: 0) {
                            Group {
                                if hasMedia && nowPlaying.artworkURL != nil {
                                    AsyncImage(url: nowPlaying.artworkURL) { image in
                                        image.resizable().aspectRatio(contentMode: .fill)
                                    } placeholder: { Color.gray.opacity(0.3) }
                                    .frame(width: 20, height: 20)
                                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                } else {
                                    Image(systemName: "music.note")
                                        .foregroundColor(nowPlaying.isPlaying ? .white : .gray)
                                        .font(.system(size: 14, weight: .bold))
                                }
                            }
                            .frame(width: 24, alignment: .leading)
                            
                            Spacer()
                            
                            WaveformView(isPlaying: nowPlaying.isPlaying, color: nowPlaying.artworkDominantColor)
                                .frame(width: 24, alignment: .trailing)
                        }
                        .padding(.horizontal, 24)
                        .frame(height: notchHeight)
                        .transition(.opacity)
                        
                    } else {
                        VStack(spacing: 8) {
                            // Top Left Tab Switcher
                            HStack {
                                Button(action: {
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                        currentTab = currentTab == .player ? .playlist : .player
                                    }
                                }) {
                                    Image(systemName: currentTab == .player ? "list.bullet" : "music.note")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.white.opacity(0.6))
                                        .padding(8)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                
                                Spacer()
                            }
                            .frame(height: notchHeight - 8)
                            .padding(.horizontal, 16)
                            
                            // ⚡️ Content Router
                            if currentTab == .player {
                                PlayerTabView(nowPlaying: nowPlaying, expandedWidth: expandedWidth)
                                    .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .trailing)), removal: .opacity.combined(with: .move(edge: .leading))))
                            } else {
                                PlaylistTabView(nowPlaying: nowPlaying)
                                    .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .trailing)), removal: .opacity.combined(with: .move(edge: .leading))))
                            }
                        }
                        .padding(.bottom, 8)
                        .transition(.opacity)
                    }
                }
                .frame(width: isExpanded ? expandedWidth : collapsedWidth, height: isExpanded ? expandedHeight : notchHeight)
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isExpanded)
            .onHover { h in isExpanded = h }
            
            Spacer()
        }
        .frame(width: expandedWidth, height: 200)
        .edgesIgnoringSafeArea(.all)
    }
}
