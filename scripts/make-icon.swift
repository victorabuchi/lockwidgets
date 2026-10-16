// Renders the app icon: swift scripts/make-icon.swift [out.png]
// A night-blue screen with the notch at the top, lit at its edge and casting a soft beam of light.
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

ctx.saveGState()
bodyPath.addClip()

// The screen: deep night blue, a little warmer towards the bottom.
NSGradient(colors: [
    NSColor(red: 0.04, green: 0.05, blue: 0.14, alpha: 1),
    NSColor(red: 0.10, green: 0.08, blue: 0.30, alpha: 1),
    NSColor(red: 0.22, green: 0.12, blue: 0.42, alpha: 1),
])!.draw(in: body, angle: -90)

// The notch hangs from the top edge.
let notch = CGRect(x: 362, y: 924 - 122, width: 300, height: 122)
let radius: CGFloat = 50
func notchOutline(_ rect: CGRect) -> NSBezierPath {
    let path = NSBezierPath()
    path.move(to: CGPoint(x: rect.minX, y: rect.maxY + 2))
    path.line(to: CGPoint(x: rect.minX, y: rect.minY + radius))
    path.appendArc(withCenter: CGPoint(x: rect.minX + radius, y: rect.minY + radius), radius: radius, startAngle: 180, endAngle: 270)
    path.line(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
    path.appendArc(withCenter: CGPoint(x: rect.maxX - radius, y: rect.minY + radius), radius: radius, startAngle: 270, endAngle: 360)
    path.line(to: CGPoint(x: rect.maxX, y: rect.maxY + 2))
    return path
}

// A beam of light falling from the notch, widening as it goes.
let beam = NSBezierPath()
beam.move(to: CGPoint(x: notch.minX + 30, y: notch.minY + 10))
beam.line(to: CGPoint(x: notch.maxX - 30, y: notch.minY + 10))
beam.line(to: CGPoint(x: 924 + 40, y: 100))
beam.line(to: CGPoint(x: 100 - 40, y: 100))
beam.close()
ctx.saveGState()
beam.addClip()
NSGradient(colors: [
    NSColor(red: 0.72, green: 0.86, blue: 1.0, alpha: 0.55),
    NSColor(red: 0.55, green: 0.55, blue: 1.0, alpha: 0.18),
    NSColor(red: 0.45, green: 0.35, blue: 0.95, alpha: 0.0),
])!.draw(in: CGRect(x: 100, y: 100, width: 824, height: notch.minY - 90), angle: -90)
ctx.restoreGState()

// The glow right under the notch.
NSGradient(colors: [NSColor(red: 0.80, green: 0.92, blue: 1.0, alpha: 0.75), NSColor(red: 0.55, green: 0.6, blue: 1.0, alpha: 0)])!
    .draw(fromCenter: CGPoint(x: 512, y: notch.minY + 4), radius: 0, toCenter: CGPoint(x: 512, y: notch.minY + 4), radius: 300, options: [])

// A pool of light where the beam lands.
NSGradient(colors: [NSColor(red: 0.62, green: 0.70, blue: 1.0, alpha: 0.35), NSColor(red: 0.5, green: 0.4, blue: 1.0, alpha: 0)])!
    .draw(fromCenter: CGPoint(x: 512, y: 150), radius: 0, toCenter: CGPoint(x: 512, y: 150), radius: 380, options: [])

// The notch itself, with a lit rim.
ctx.saveGState()
ctx.setShadow(offset: .zero, blur: 40, color: NSColor(red: 0.6, green: 0.85, blue: 1.0, alpha: 0.9).cgColor)
let rim = notchOutline(notch)
rim.lineWidth = 12
NSColor(red: 0.78, green: 0.92, blue: 1.0, alpha: 1).setStroke()
rim.stroke()
ctx.restoreGState()
let fill = notchOutline(notch)
fill.close()
NSColor.black.setFill()
fill.fill()

ctx.restoreGState()
image.unlockFocus()

let out = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon-1024.png")
let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
try! rep.representation(using: .png, properties: [:])!.write(to: out)
