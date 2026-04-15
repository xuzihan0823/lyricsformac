import SwiftUI

struct LyricsOverlayView: View {
    @ObservedObject var controller: LyricsOverlayController
    @State private var lastMagnification: CGFloat = 1.0

    var body: some View {
        ZStack {
            backgroundCard

            VStack(alignment: .leading, spacing: 10) {
                header
                lyricsBody
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
        }
        .gesture(
            MagnificationGesture()
                .onChanged { value in
                    guard !controller.isClickThrough else { return }
                    let delta = value / lastMagnification
                    lastMagnification = value
                    controller.zoom(by: delta)
                }
                .onEnded { _ in
                    lastMagnification = 1.0
                }
        )
        .frame(minWidth: 380, minHeight: 120)
    }

    private var style: ThemeStyle {
        ThemeStyle(theme: controller.theme)
    }

    private var backgroundCard: some View {
        Group {
            if controller.theme == .frosted {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.ultraThinMaterial.opacity(0.72))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.12),
                                        Color.white.opacity(0.04)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(Color.white.opacity(0.16), lineWidth: 0.8)
                    )
            } else {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.08, green: 0.09, blue: 0.11).opacity(0.46),
                                Color(red: 0.14, green: 0.15, blue: 0.18).opacity(0.26)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(Color.white.opacity(0.10), lineWidth: 0.8)
                    )
            }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(controller.isPlaying ? Color.green.opacity(0.72) : Color.gray.opacity(0.55))
                .frame(width: 7, height: 7)

            Text(controller.lyricsSource)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(style.secondaryText)
                .lineLimit(1)

            if controller.showTrackInfo {
                Text("·")
                    .foregroundStyle(style.secondaryText)

                Text(controller.title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(style.primaryText)
                    .lineLimit(1)

                Text("·")
                    .foregroundStyle(style.secondaryText)

                Text(controller.artist)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(style.secondaryText)
                    .lineLimit(1)
            }

            Spacer()

            ControlIconButton(
                symbol: controller.showTrackInfo ? "text.alignleft" : "text.alignleft",
                tooltip: controller.showTrackInfo ? "隐藏歌曲信息" : "显示歌曲信息",
                style: style
            ) {
                controller.toggleTrackInfo()
            }

            ControlIconButton(
                symbol: controller.isLocked ? "lock.fill" : "lock.open",
                tooltip: "锁定窗口",
                style: style
            ) {
                controller.toggleLock()
            }

            ControlIconButton(
                symbol: controller.isClickThrough ? "cursorarrow.click.2" : "cursorarrow.rays",
                tooltip: "点击穿透",
                style: style
            ) {
                controller.toggleClickThrough()
            }

            ControlIconButton(
                symbol: "circle.lefthalf.filled",
                tooltip: "切换透明度",
                style: style
            ) {
                controller.cycleOpacity()
            }

            ControlIconButton(
                symbol: controller.theme == .graphite ? "sun.max" : "moon.stars",
                tooltip: "切换主题",
                style: style
            ) {
                controller.toggleTheme()
            }

            ControlIconButton(
                symbol: "xmark",
                tooltip: "关闭悬浮窗",
                style: style
            ) {
                controller.closeOverlay()
            }
        }
    }

    private var lyricsBody: some View {
        GeometryReader { _ in
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(controller.lines) { line in
                            AnimatedLyricLine(
                                text: line.text,
                                isCurrent: controller.currentLineID == line.id,
                                progress: controller.currentLineID == line.id ? controller.lineProgress : 0,
                                scale: controller.scale,
                                style: style
                            )
                            .id(line.id)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .onChange(of: controller.currentLineID) { id in
                    guard let id else { return }
                    withAnimation(.interpolatingSpring(stiffness: 190, damping: 23)) {
                        proxy.scrollTo(id, anchor: .center)
                    }
                }
            }
        }
    }
}

private struct ThemeStyle {
    let primaryText: Color
    let secondaryText: Color
    let lyricDim: Color
    let lyricHighlight: Color
    let chipBackground: Color
    let chipBorder: Color

    init(theme: OverlayTheme) {
        switch theme {
        case .graphite:
            primaryText = Color.white.opacity(0.88)
            secondaryText = Color.white.opacity(0.60)
            lyricDim = Color.white.opacity(0.30)
            lyricHighlight = Color.white.opacity(0.90)
            chipBackground = Color.white.opacity(0.05)
            chipBorder = Color.white.opacity(0.10)
        case .frosted:
            primaryText = Color.black.opacity(0.76)
            secondaryText = Color.black.opacity(0.46)
            lyricDim = Color.black.opacity(0.24)
            lyricHighlight = Color.black.opacity(0.82)
            chipBackground = Color.white.opacity(0.18)
            chipBorder = Color.white.opacity(0.22)
        }
    }
}

private struct ControlIconButton: View {
    let symbol: String
    let tooltip: String
    let style: ThemeStyle
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(style.primaryText)
                .frame(width: 22, height: 22)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(style.chipBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(style.chipBorder, lineWidth: 0.8)
                )
        }
        .buttonStyle(.plain)
        .help(tooltip)
    }
}

private struct AnimatedLyricLine: View {
    let text: String
    let isCurrent: Bool
    let progress: Double
    let scale: CGFloat
    let style: ThemeStyle

    var body: some View {
        let lyricFont = Font.system(size: 31 * scale, weight: isCurrent ? .bold : .semibold, design: .rounded)

        ZStack(alignment: .leading) {
            Text(text)
                .font(lyricFont)
                .foregroundStyle(isCurrent ? style.lyricDim.opacity(0.80) : style.lyricDim)
                .lineLimit(2)
                .minimumScaleFactor(0.7)

            GeometryReader { geo in
                Text(text)
                    .font(lyricFont)
                    .foregroundStyle(style.lyricHighlight)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .mask(alignment: .leading) {
                        Rectangle().frame(width: geo.size.width * progress)
                    }
                    .animation(.linear(duration: 0.24), value: progress)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 1)
    }
}
