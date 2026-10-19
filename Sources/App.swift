import AppKit
import SwiftUI

@main
struct SeritApp: App {
    @State private var strip = StripController()

    var body: some Scene {
        MenuBarExtra {
            PanelView()
                .environment(strip)
        } label: {
            Image(nsImage: MenuIcon.make(color: strip.iconColor, lit: strip.isOn && strip.isConnected))
        }
        .menuBarExtraStyle(.window)
    }
}

enum MenuIcon {
    /// Küçük LED şerit: yanıkken o anki renkte ve üstünde ışık çizgileriyle, sönükken şablon (menü çubuğu rengini alır).
    static func make(color: RGB, lit: Bool) -> NSImage {
        let img = NSImage(size: NSSize(width: 22, height: 16), flipped: false) { _ in
            let body = NSBezierPath(roundedRect: NSRect(x: 1.5, y: 3, width: 19, height: 6.5), xRadius: 3.25, yRadius: 3.25)
            body.lineWidth = 1.2
            if lit {
                color.nsColor.setFill()
                body.fill()
                NSColor.labelColor.withAlphaComponent(0.55).setStroke()
                body.stroke()
                NSColor.white.withAlphaComponent(0.9).setFill()
                for i in 0..<5 { NSBezierPath(ovalIn: NSRect(x: 4 + Double(i) * 3.4, y: 5.25, width: 2, height: 2)).fill() }
                color.nsColor.setStroke()
                for x in [6.0, 11.0, 16.0] {
                    let ray = NSBezierPath()
                    ray.move(to: NSPoint(x: x, y: 11.5))
                    ray.line(to: NSPoint(x: x, y: 14.5))
                    ray.lineWidth = 1.6
                    ray.lineCapStyle = .round
                    ray.stroke()
                }
            } else {
                NSColor.black.setStroke()
                body.stroke()
                NSColor.black.setFill()
                for i in 0..<5 { NSBezierPath(ovalIn: NSRect(x: 4 + Double(i) * 3.4, y: 5.25, width: 2, height: 2)).fill() }
            }
            return true
        }
        img.isTemplate = !lit
        return img
    }
}
