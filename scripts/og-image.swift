// Composes the website's link preview: swift scripts/og-image.swift page.png icon.png out.jpg
// page.png is the website photographed at 2x, 1280 points wide. The MacBook in its hero is found by its dark lid and
// placed under the app icon and name, running off the bottom edge so the lock screen fills the picture.
import AppKit

let args = CommandLine.arguments
let page = NSImage(contentsOfFile: args[1])!.cgImage(forProposedRect: nil, context: nil, hints: nil)!
let icon = NSImage(contentsOfFile: args[2])!
let pixels = NSBitmapImageRep(cgImage: page)
let scale = CGFloat(page.width) / 1280

// The lid: the first near-black row down the middle of the page, below the hero's text.
var lidTop = Int(420 * scale)
while lidTop < pixels.pixelsHigh, let c = pixels.colorAt(x: pixels.pixelsWide / 2, y: lidTop)?.usingColorSpace(.sRGB), c.brightnessComponent > 0.12 {
    lidTop += 1
}
let mac = page.cropping(to: CGRect(x: 128 * scale, y: CGFloat(lidTop) - 6 * scale, width: 1024 * scale, height: 700 * scale))!

let size = CGSize(width: 1200, height: 630)
let out = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width), pixelsHigh: Int(size.height), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: out)
NSGraphicsContext.current!.imageInterpolation = .high
NSColor.white.setFill() // The page's own white, so the photographed MacBook blends in.
CGRect(origin: .zero, size: size).fill()

// The icon and the name, centred along the top, as in the website's top bar.
let title = NSAttributedString(string: "Notchlight", attributes: [
    .font: NSFont.systemFont(ofSize: 64, weight: .bold),
    .foregroundColor: NSColor(srgbRed: 0.114, green: 0.114, blue: 0.122, alpha: 1),
    .kern: -1.3,
])
let iconSide: CGFloat = 84, gap: CGFloat = 18, top: CGFloat = 50
let left = (size.width - iconSide - gap - title.size().width) / 2
icon.draw(in: CGRect(x: left, y: size.height - top - iconSide, width: iconSide, height: iconSide))
title.draw(at: CGPoint(x: left + iconSide + gap, y: size.height - top - iconSide + (iconSide - title.size().height) / 2))

// The MacBook, 1000 points wide, from just under the name to past the bottom edge.
let width: CGFloat = 1000, height = width * CGFloat(mac.height) / CGFloat(mac.width)
NSGraphicsContext.current!.cgContext.draw(mac, in: CGRect(x: (size.width - width) / 2, y: size.height - 166 - height, width: width, height: height))
NSGraphicsContext.restoreGraphicsState()
try! out.representation(using: .jpeg, properties: [.compressionFactor: 0.86])!.write(to: URL(fileURLWithPath: args[3]))
