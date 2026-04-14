import SwiftUI

struct LyricsOverlayView: View {
    @ObservedObject var controller: LyricsOverlayController
    @State private var lastMagnification: CGFloat = 1.0

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.08, green: 0.09, blue: 0.11).opacity(0.90),
                            Color(red: 0.14, green: 0.15, blue: 0.18).opacity(0.78)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(.white.opacity(0.17), lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 10) {
                header
                lyricsBody
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .gesture(
            MagnificationGesture()
                .onChanged { value in
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

    private var header: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(controller.isPlaying ? Color.green.opacity(0.92) : Color.gray.opacity(0.8))
                .frame(width: 8, height: 8)
            Text(controller.title)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.95))
                .lineLimit(1)
            Text("·")
                .foregroundStyle(.white.opacity(0.4))
            Text(controller.artist)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.72))
                .lineLimit(1)
            Spacer()
            Text("\(Int(controller.scale * 100))%")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.55))
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
                                scale: controller.scale
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

private struct AnimatedLyricLine: View {
    let text: String
    let isCurrent: Bool
    let progress: Double
    let scale: CGFloat

    var body: some View {
        let lyricFont = Font.system(size: 31 * scale, weight: isCurrent ? .bold : .semibold, design: .rounded)

        ZStack(alignment: .leading) {
            Text(text)
                .font(lyricFont)
                .foregroundStyle(.white.opacity(isCurrent ? 0.30 : 0.48))
                .lineLimit(2)
                .minimumScaleFactor(0.7)

            GeometryReader { geo in
                Text(text)
                    .font(lyricFont)
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .mask(alignment: .leading) {
                        Rectangle()
                            .frame(width: geo.size.width * progress)
                    }
                    .animation(.linear(duration: 0.24), value: progress)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 1)
    }
}
