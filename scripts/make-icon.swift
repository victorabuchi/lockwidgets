// Renders the app icon into the asset catalog: swift scripts/make-icon.swift
import AppKit

let size: CGFloat = 1024
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()
let ctx = NSGraphicsContext.current!.cgContext

// macOS icon grid: 824pt body centred on a 1024 canvas.
let body = CGRect(x: 100, y: 100, width: 824, height: 824)
let bodyPath = NSBezierPath(roundedRect: body, xRadius: 185, yRadius: 185)

ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: NSColor.black.withAlphaComponent(0.35).cgColor)
NSColor.black.setFill()
bodyPath.fill()
ctx.restoreGState()

bodyPath.addClip()
NSGradient(colors: [
    NSColor(red: 0.55, green: 0.42, blue: 0.98, alpha: 1),
    NSColor(red: 0.30, green: 0.22, blue: 0.78, alpha: 1),
    NSColor(red: 0.10, green: 0.08, blue: 0.34, alpha: 1),
])!.draw(in: body, angle: -60)
NSGradient(colors: [NSColor(red: 0.85, green: 0.7, blue: 1, alpha: 0.55), .clear])!
    .draw(fromCenter: CGPoint(x: 330, y: 760), radius: 0, toCenter: CGPoint(x: 330, y: 760), radius: 520, options: [])

// Light sweep, a nod to the macOS wallpaper.
let sweep = NSBezierPath()
sweep.move(to: CGPoint(x: 560, y: 924))
sweep.curve(to: CGPoint(x: 924, y: 380), controlPoint1: CGPoint(x: 700, y: 760), controlPoint2: CGPoint(x: 760, y: 470))
sweep.lineWidth = 10
NSColor.white.withAlphaComponent(0.5).setStroke()
sweep.stroke()

func card(_ rect: CGRect, _ draw: (CGRect) -> Void) {
    let path = NSBezierPath(roundedRect: rect, xRadius: 44, yRadius: 44)
    NSColor.white.withAlphaComponent(0.2).setFill()
    path.fill()
    NSColor.white.withAlphaComponent(0.35).setStroke()
    path.lineWidth = 4
    path.stroke()
    draw(rect)
}

func bar(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ alpha: CGFloat) {
    NSColor.white.withAlphaComponent(alpha).setFill()
    NSBezierPath(roundedRect: CGRect(x: x, y: y, width: w, height: h), xRadius: h / 2, yRadius: h / 2).fill()
}

// Clock card
card(CGRect(x: 200, y: 620, width: 460, height: 200)) { r in
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 120, weight: .bold).rounded,
        .foregroundColor: NSColor.white,
    ]
    NSAttributedString(string: "9:41", attributes: attributes).draw(at: CGPoint(x: r.minX + 40, y: r.minY + 40))
}
// Weather card
card(CGRect(x: 200, y: 400, width: 460, height: 190)) { r in
    let config = NSImage.SymbolConfiguration(pointSize: 90, weight: .regular)
        .applying(.init(paletteColors: [.white, NSColor(red: 1, green: 0.8, blue: 0.2, alpha: 1)]))
    NSImage(systemSymbolName: "cloud.sun.fill", accessibilityDescription: nil)!
        .withSymbolConfiguration(config)!
        .draw(in: CGRect(x: r.minX + 40, y: r.minY + 45, width: 120, height: 100))
    bar(r.minX + 200, r.minY + 110, 200, 30, 0.9)
    bar(r.minX + 200, r.minY + 60, 140, 26, 0.5)
}
// Lyrics card
card(CGRect(x: 200, y: 180, width: 460, height: 190)) { r in
    bar(r.minX + 40, r.minY + 125, 300, 22, 0.4)
    bar(r.minX + 40, r.minY + 80, 380, 30, 1)
    bar(r.minX + 40, r.minY + 40, 260, 22, 0.4)
}

image.unlockFocus()

extension NSFont {
    var rounded: NSFont {
        guard let descriptor = fontDescriptor.withDesign(.rounded) else { return self }
        return NSFont(descriptor: descriptor, size: pointSize) ?? self
    }
}

let out = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon-1024.png")
let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
try! rep.representation(using: .png, properties: [:])!.write(to: out)
