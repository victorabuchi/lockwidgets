// Renders the app icon: swift scripts/make-icon.swift [out.png]
// A lock screen in miniature: the island with a song at the top, the time, and a Now Playing card.
import AppKit

let size: CGFloat = 1024
let body = CGRect(x: 100, y: 100, width: 824, height: 824)

func bitmap(_ draw: (CGContext) -> Void) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    draw(NSGraphicsContext.current!.cgContext)
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

func capsule(_ rect: CGRect) -> NSBezierPath {
    NSBezierPath(roundedRect: rect, xRadius: rect.height / 2, yRadius: rect.height / 2)
}

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xff) / 255, green: CGFloat((hex >> 8) & 0xff) / 255, blue: CGFloat(hex & 0xff) / 255, alpha: alpha)
}

/// A black island with a song's artwork on the left and its waveform on the right.
func drawIsland(_ ctx: CGContext, _ island: CGRect) {
    NSColor.black.setFill()
    capsule(island).fill()
    let edge = capsule(island.insetBy(dx: 2, dy: 2))
    edge.lineWidth = 3
    NSColor.white.withAlphaComponent(0.10).setStroke()
    edge.stroke()
    let h = island.height
    drawArtwork(ctx, CGRect(x: island.minX + h * 0.2, y: island.minY + h * 0.2, width: h * 0.6, height: h * 0.6), radius: h * 0.16)
    let wave = CGRect(x: island.maxX - h * 0.82, y: island.minY + h * 0.24, width: h * 0.62, height: h * 0.52)
    let bars = NSBezierPath()
    let barWidth = wave.width / 7
    for (i, height) in [0.45, 1, 0.7, 0.9].enumerated() {
        let barHeight = wave.height * height
        bars.append(capsule(CGRect(x: wave.minX + CGFloat(i) * 2 * barWidth, y: wave.midY - barHeight / 2, width: barWidth, height: barHeight)))
    }
    ctx.saveGState()
    bars.addClip()
    NSGradient(colors: [color(0x5EE6D0), color(0xB46BFF)])!.draw(in: wave, angle: 90)
    ctx.restoreGState()
}

/// Album artwork: a warm gradient with a soft shine.
func drawArtwork(_ ctx: CGContext, _ rect: CGRect, radius: CGFloat) {
    ctx.saveGState()
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).addClip()
    NSGradient(colors: [color(0xFF8A3D), color(0xFF3D7F), color(0x8B3DFF)])!.draw(in: rect, angle: -45)
    let shine = CGPoint(x: rect.minX + rect.width * 0.3, y: rect.maxY - rect.height * 0.3)
    NSGradient(colors: [NSColor.white.withAlphaComponent(0.55), NSColor.white.withAlphaComponent(0)])!
        .draw(fromCenter: shine, radius: 0, toCenter: shine, radius: rect.width * 0.7, options: [])
    ctx.restoreGState()
}

// A lock screen in miniature: the island at the top, the time, and a Now Playing card.
let icon = bitmap { ctx in
    let squircle = NSBezierPath(roundedRect: body, xRadius: 185, yRadius: 185)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: NSColor.black.withAlphaComponent(0.35).cgColor)
    NSColor.black.setFill()
    squircle.fill()
    ctx.restoreGState()

    ctx.saveGState()
    squircle.addClip()
    // The wallpaper.
    NSGradient(colors: [color(0x1D3CB0), color(0x6A2FD8), color(0xF0663A)])!.draw(in: body, angle: -60)
    for (x, y, r, glow) in [(260.0, 300.0, 420.0, color(0xFF7A45, 0.55)), (820.0, 820.0, 460.0, color(0x3D7BFF, 0.6)), (700.0, 260.0, 380.0, color(0xC24BFF, 0.45))] {
        NSGradient(colors: [glow, glow.withAlphaComponent(0)])!
            .draw(fromCenter: CGPoint(x: x, y: y), radius: 0, toCenter: CGPoint(x: x, y: y), radius: r, options: [])
    }

    drawIsland(ctx, CGRect(x: 312, y: 760, width: 400, height: 112))

    let time = NSAttributedString(string: "9:41", attributes: [
        .font: NSFont.systemFont(ofSize: 250, weight: .semibold).rounded,
        .foregroundColor: NSColor.white.withAlphaComponent(0.92),
    ])
    time.draw(at: CGPoint(x: 512 - time.size().width / 2, y: 430))

    // A frosted Now Playing card.
    let card = NSBezierPath(roundedRect: CGRect(x: 210, y: 190, width: 604, height: 190), xRadius: 56, yRadius: 56)
    NSColor.white.withAlphaComponent(0.22).setFill()
    card.fill()
    card.lineWidth = 4
    NSColor.white.withAlphaComponent(0.4).setStroke()
    card.stroke()
    drawArtwork(ctx, CGRect(x: 250, y: 230, width: 110, height: 110), radius: 26)
    NSColor.white.withAlphaComponent(0.95).setFill()
    capsule(CGRect(x: 395, y: 300, width: 300, height: 26)).fill()
    NSColor.white.withAlphaComponent(0.55).setFill()
    capsule(CGRect(x: 395, y: 248, width: 200, height: 22)).fill()

    // Glass sheen across the top half.
    NSGradient(colors: [NSColor.white.withAlphaComponent(0.14), NSColor.white.withAlphaComponent(0)])!
        .draw(in: CGRect(x: 100, y: 560, width: 824, height: 364), angle: -90)
    ctx.restoreGState()

    let rim = NSBezierPath(roundedRect: body.insetBy(dx: 1.5, dy: 1.5), xRadius: 184, yRadius: 184)
    rim.lineWidth = 3
    NSColor.white.withAlphaComponent(0.18).setStroke()
    rim.stroke()
}

extension NSFont {
    var rounded: NSFont {
        guard let descriptor = fontDescriptor.withDesign(.rounded) else { return self }
        return NSFont(descriptor: descriptor, size: pointSize) ?? self
    }
}

let out = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon-1024.png")
try! icon.representation(using: .png, properties: [:])!.write(to: out)
