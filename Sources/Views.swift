import ServiceManagement
import SwiftUI

enum PanelTab: String, CaseIterable, Identifiable {
    case color, effects, modes
    var id: String { rawValue }
    var title: String {
        switch self {
        case .color: "Renk"
        case .effects: "Efekt"
        case .modes: "Şerit"
        }
    }
    var symbol: String {
        switch self {
        case .color: "paintpalette.fill"
        case .effects: "sparkles"
        case .modes: "light.strip.2"
        }
    }
}

struct PanelView: View {
    @State private var tab: PanelTab = .color

    var body: some View {
        VStack(spacing: 14) {
            HeaderView()
            StripPreview()
            TabBar(tab: $tab)
            ZStack {
                switch tab {
                case .color: ColorTab().transition(.blurReplace.combined(with: .scale(0.96)))
                case .effects: EffectsTab().transition(.blurReplace.combined(with: .scale(0.96)))
                case .modes: ModesTab().transition(.blurReplace.combined(with: .scale(0.96)))
                }
            }
            .frame(height: 268)
            BrightnessRow()
            FooterView()
        }
        .padding(16)
        .frame(width: 340)
        .background(alignment: .top) { AmbientGlow() }
    }
}

// MARK: Üst kısım

struct HeaderView: View {
    @Environment(StripController.self) private var strip

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Şerit")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                StatusPill()
            }
            Spacer()
            PowerButton()
        }
    }
}

struct StatusPill: View {
    @Environment(StripController.self) private var strip

    private var dot: Color {
        switch strip.link {
        case .connected: .green
        case .scanning, .connecting: .orange
        default: .red
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(dot)
                .frame(width: 7, height: 7)
                .shadow(color: dot.opacity(0.9), radius: 4)
                .phaseAnimator([1.0, 0.35]) { v, p in
                    v.opacity(strip.isConnected ? 1 : p)
                } animation: { _ in .easeInOut(duration: 0.8) }
            Text(strip.statusText)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .contentTransition(.opacity)
        }
        .animation(.smooth, value: strip.link)
    }
}

struct PowerButton: View {
    @Environment(StripController.self) private var strip

    var body: some View {
        Button { strip.togglePower() } label: {
            Image(systemName: "power")
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(strip.isOn ? Color.white : Color.secondary)
                .frame(width: 46, height: 46)
                .symbolEffect(.bounce, value: strip.isOn)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .glassEffect(strip.isOn ? .regular.tint(strip.iconColor.color.opacity(0.75)).interactive() : .regular.interactive(), in: .circle)
        .shadow(color: strip.isOn ? strip.iconColor.color.opacity(0.7) : .clear, radius: 14)
        .animation(.smooth(duration: 0.6), value: strip.isOn)
        .animation(.smooth(duration: 0.6), value: strip.iconColor)
        .help(strip.isOn ? "Kapat" : "Aç")
    }
}

/// Şeridin kendisi: o an giden rengi 30 fps gösterir.
struct StripPreview: View {
    @Environment(StripController.self) private var strip

    var body: some View {
        let on = strip.isOn
        let c = strip.liveColor.color
        ZStack {
            Capsule().fill(.white.opacity(0.06))
            if case .hardware = strip.source, on {
                TimelineView(.animation) { ctx in
                    let t = ctx.date.timeIntervalSinceReferenceDate
                    Capsule().fill(LinearGradient(
                        colors: (0...6).map { RGB.hsv(Double($0) / 6 - t * 0.25, 1, 1).color },
                        startPoint: .leading, endPoint: .trailing))
                }
                .transition(.opacity)
            } else {
                Capsule().fill(c)
            }
            HStack(spacing: 0) {
                ForEach(0..<26, id: \.self) { _ in
                    Circle()
                        .fill(.white.opacity(on ? 0.45 : 0.1))
                        .frame(width: 3.5, height: 3.5)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 6)
        }
        .frame(height: 16)
        .overlay(Capsule().strokeBorder(.white.opacity(0.18), lineWidth: 0.5))
        .shadow(color: on ? c.opacity(0.9) : .clear, radius: 10)
        .shadow(color: on ? c.opacity(0.55) : .clear, radius: 26)
        .padding(.vertical, 4)
        .animation(.smooth(duration: 0.5), value: strip.source)
    }
}

struct AmbientGlow: View {
    @Environment(StripController.self) private var strip

    var body: some View {
        Ellipse()
            .fill(strip.iconColor.color)
            .frame(width: 300, height: 170)
            .blur(radius: 80)
            .opacity(strip.isOn ? 0.5 : 0)
            .offset(y: -40)
            .animation(.easeInOut(duration: 0.9), value: strip.iconColor)
            .animation(.easeInOut(duration: 0.9), value: strip.isOn)
            .allowsHitTesting(false)
    }
}

struct TabBar: View {
    @Binding var tab: PanelTab
    @Namespace private var ns

    var body: some View {
        HStack(spacing: 2) {
            ForEach(PanelTab.allCases) { t in
                Button {
                    withAnimation(.spring(duration: 0.45, bounce: 0.25)) { tab = t }
                } label: {
                    Label(t.title, systemImage: t.symbol)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(tab == t ? Color.primary : Color.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background {
                            if tab == t {
                                Capsule()
                                    .fill(.white.opacity(0.16))
                                    .matchedGeometryEffect(id: "sel", in: ns)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .glassEffect(.regular, in: .capsule)
    }
}

// MARK: Renk

struct ColorTab: View {
    var body: some View {
        VStack(spacing: 16) {
            ColorWheel()
                .frame(width: 200, height: 200)
                .padding(.top, 6)
            PresetRow()
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

struct ColorWheel: View {
    @Environment(StripController.self) private var strip
    @State private var dragging = false

    var body: some View {
        GeometryReader { geo in
            let r = min(geo.size.width, geo.size.height) / 2
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let a = strip.hue * 2 * .pi
            let d = strip.saturation * (r - 4)
            ZStack {
                Circle().fill(AngularGradient(
                    colors: stride(from: 0.0, through: 1.0, by: 1.0 / 12).map { RGB.hsv($0, 1, 1).color },
                    center: .center))
                Circle().fill(RadialGradient(colors: [.white, .white.opacity(0)], center: .center, startRadius: 0, endRadius: r))
                Circle().strokeBorder(.white.opacity(0.3), lineWidth: 1)
                Circle()
                    .fill(strip.baseColor.color)
                    .frame(width: dragging ? 34 : 26, height: dragging ? 34 : 26)
                    .overlay(Circle().strokeBorder(.white, lineWidth: 3))
                    .shadow(color: .black.opacity(0.35), radius: 5, y: 2)
                    .position(x: center.x + cos(a) * d, y: center.y + sin(a) * d)
            }
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { v in
                        if !dragging { withAnimation(.spring(duration: 0.25)) { dragging = true } }
                        let dx = v.location.x - center.x, dy = v.location.y - center.y
                        var ang = atan2(dy, dx)
                        if ang < 0 { ang += 2 * .pi }
                        strip.pickColor(hue: ang / (2 * .pi), saturation: min(1, hypot(dx, dy) / (r - 4)), smooth: false)
                    }
                    .onEnded { _ in withAnimation(.spring(duration: 0.3, bounce: 0.4)) { dragging = false } }
            )
        }
        .shadow(color: strip.baseColor.color.opacity(0.45), radius: 22)
    }
}

struct PresetRow: View {
    @Environment(StripController.self) private var strip

    var body: some View {
        HStack(spacing: 9) {
            ForEach(Preset.all) { p in
                let sel = strip.source == .solid && abs(strip.hue - p.h) < 0.005 && abs(strip.saturation - p.s) < 0.01
                Button {
                    strip.pickColor(hue: p.h, saturation: p.s, smooth: true)
                } label: {
                    Circle()
                        .fill(p.rgb.color)
                        .frame(width: 24, height: 24)
                        .overlay(Circle().strokeBorder(.white.opacity(sel ? 1 : 0.25), lineWidth: sel ? 2.5 : 1))
                        .shadow(color: p.rgb.color.opacity(sel ? 0.9 : 0), radius: 8)
                        .scaleEffect(sel ? 1.18 : 1)
                }
                .buttonStyle(HoverPop())
            }
        }
        .animation(.spring(duration: 0.4, bounce: 0.45), value: strip.hue)
        .animation(.spring(duration: 0.4, bounce: 0.45), value: strip.saturation)
    }
}

// MARK: Efektler

struct EffectsTab: View {
    @Environment(StripController.self) private var strip

    var body: some View {
        VStack(spacing: 10) {
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                    ForEach(EffectKind.allCases) { EffectCard(kind: $0) }
                }
                .padding(.vertical, 2)
            }
            .scrollIndicators(.never)
            GlassSlider(value: Binding(get: { strip.hwSpeed }, set: { strip.setHWSpeed($0) }),
                        range: 0...100, icon: "hare.fill", tint: .white, format: { "\(Int($0))" })
        }
    }
}

struct EffectCard: View {
    @Environment(StripController.self) private var strip
    let kind: EffectKind

    var body: some View {
        let sel = strip.source == .hardware(kind.mode)
        let speed = 0.3 + strip.hwSpeed / 50
        Button { strip.startHardware(kind.mode) } label: {
            HStack(spacing: 9) {
                TimelineView(.animation(minimumInterval: 1.0 / 24)) { ctx in
                    let t = ctx.date.timeIntervalSinceReferenceDate * speed
                    let c0 = kind.color(t)
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(LinearGradient(colors: [c0.color, kind.color(t + 0.8).color, kind.color(t + 1.6).color],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .overlay(Image(systemName: kind.symbol).font(.system(size: 13, weight: .bold)).foregroundStyle(.white.opacity(0.9)).shadow(radius: 2))
                        .shadow(color: sel ? c0.color.opacity(0.9) : .clear, radius: 8)
                }
                .frame(width: 34, height: 34)
                VStack(alignment: .leading, spacing: 1) {
                    Text(kind.title).font(.system(size: 12, weight: .semibold))
                    Text(kind.subtitle).font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(7)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.white.opacity(sel ? 0.15 : 0.05)))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(sel ? Color.white.opacity(0.6) : Color.white.opacity(0.08), lineWidth: sel ? 1.5 : 1))
            .contentShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(HoverPop())
        .animation(.smooth(duration: 0.35), value: sel)
    }
}

// MARK: Şeridin dahili modları

struct ModesTab: View {
    @Environment(StripController.self) private var strip
    @State private var group = 0
    @Namespace private var ns

    var body: some View {
        VStack(spacing: 10) {
            ScrollView(.horizontal) {
                HStack(spacing: 5) {
                    ForEach(HWCatalog.groups) { g in
                        Button {
                            withAnimation(.spring(duration: 0.4, bounce: 0.3)) { group = g.id }
                        } label: {
                            Label(g.title, systemImage: g.symbol)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(group == g.id ? Color.primary : Color.secondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background {
                                    if group == g.id {
                                        Capsule().fill(.white.opacity(0.16)).matchedGeometryEffect(id: "grp", in: ns)
                                    } else {
                                        Capsule().fill(.white.opacity(0.04))
                                    }
                                }
                                .contentShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .scrollIndicators(.never)

            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)], spacing: 6) {
                    ForEach(HWCatalog.groups[group].modes) { m in
                        let sel = strip.source == .hardware(m.id)
                        Button { strip.startHardware(m.id) } label: {
                            Text(m.name)
                                .font(.system(size: 11, weight: sel ? .bold : .medium))
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 6)
                                .background(Capsule().fill(sel ? AnyShapeStyle(rainbow) : AnyShapeStyle(Color.white.opacity(0.06))))
                                .foregroundStyle(sel ? Color.white : Color.primary)
                                .contentShape(Capsule())
                        }
                        .buttonStyle(HoverPop())
                    }
                }
                .id(group)
                .transition(.blurReplace)
            }
            .scrollIndicators(.never)

            GlassSlider(value: Binding(get: { strip.hwSpeed }, set: { strip.setHWSpeed($0) }),
                        range: 0...100, icon: "speedometer", tint: .white, format: { "\(Int($0))" })
        }
    }

    private var rainbow: LinearGradient {
        LinearGradient(colors: [.pink, .purple, .blue, .cyan], startPoint: .leading, endPoint: .trailing)
    }
}

// MARK: Alt kısım

struct BrightnessRow: View {
    @Environment(StripController.self) private var strip

    var body: some View {
        GlassSlider(value: Binding(get: { strip.brightness }, set: { strip.setBrightness($0) }),
                    range: 1...100, icon: "sun.max.fill", tint: strip.iconColor.color,
                    format: { "%\(Int($0.rounded()))" })
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .glassEffect(.regular, in: .capsule)
    }
}

struct FooterView: View {
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        HStack {
            Toggle("Açılışta başlat", isOn: $launchAtLogin)
                .toggleStyle(.switch)
                .controlSize(.mini)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .onChange(of: launchAtLogin) { _, on in
                    do {
                        if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
                    } catch {
                        launchAtLogin = SMAppService.mainApp.status == .enabled
                    }
                }
            Spacer()
            Button("Çık") { NSApp.terminate(nil) }
                .buttonStyle(.glass)
                .controlSize(.small)
        }
    }
}

// MARK: Ortak parçalar

struct GlassSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let icon: String
    let tint: Color
    let format: (Double) -> String
    @State private var dragging = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 18)
                .symbolEffect(.bounce, value: dragging)
            GeometryReader { geo in
                let w = geo.size.width
                let f = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
                let knob: CGFloat = dragging ? 20 : 16
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.1)).frame(height: 6)
                    Capsule()
                        .fill(LinearGradient(colors: [tint.opacity(0.3), tint], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(6, w * f), height: 6)
                        .shadow(color: tint.opacity(0.6), radius: dragging ? 6 : 3)
                    Circle()
                        .fill(.white)
                        .frame(width: knob, height: knob)
                        .shadow(color: .black.opacity(0.3), radius: 3, y: 1)
                        .offset(x: min(max(0, w * f - knob / 2), w - knob))
                }
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { g in
                            if !dragging { dragging = true }
                            let p = min(max(0, g.location.x / w), 1)
                            value = range.lowerBound + p * (range.upperBound - range.lowerBound)
                        }
                        .onEnded { _ in dragging = false }
                )
            }
            .frame(height: 22)
            Text(format(value))
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 38, alignment: .trailing)
                .contentTransition(.numericText(value: value))
        }
        .animation(.spring(duration: 0.25, bounce: 0.4), value: dragging)
    }
}

struct HoverPop: ButtonStyle {
    @State private var hover = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : (hover ? 1.03 : 1))
            .brightness(hover ? 0.04 : 0)
            .onHover { h in withAnimation(.spring(duration: 0.25)) { hover = h } }
            .animation(.spring(duration: 0.2, bounce: 0.5), value: configuration.isPressed)
    }
}
