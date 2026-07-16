// Renders the Mouse Trail app icon to icon_1024.png.
// Run via: swift makeicon.swift
import Cocoa

let size: CGFloat = 1024
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()
guard let ctx = NSGraphicsContext.current?.cgContext else { fatalError("no context") }

// Big Sur-style squircle: 824x824 content area centered on a 1024 canvas.
let iconRect = CGRect(x: 100, y: 100, width: 824, height: 824)
let squircle = NSBezierPath(roundedRect: iconRect, xRadius: 185, yRadius: 185)

// Subtle drop shadow behind the tile.
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 36,
              color: NSColor.black.withAlphaComponent(0.35).cgColor)
NSColor(calibratedRed: 0.09, green: 0.10, blue: 0.20, alpha: 1).setFill()
squircle.fill()
ctx.restoreGState()

// Background gradient: deep indigo night sky.
squircle.addClip()
let gradient = NSGradient(colors: [
    NSColor(calibratedRed: 0.16, green: 0.17, blue: 0.34, alpha: 1),
    NSColor(calibratedRed: 0.07, green: 0.07, blue: 0.16, alpha: 1),
])!
gradient.draw(in: iconRect, angle: -90)

// Trail path: an S-curve sweeping from lower-left to upper-right.
func curvePoint(_ t: CGFloat) -> CGPoint {
    // Cubic bezier control points in canvas coordinates.
    let p0 = CGPoint(x: 205, y: 250)
    let p1 = CGPoint(x: 500, y: 130)
    let p2 = CGPoint(x: 380, y: 660)
    let p3 = CGPoint(x: 700, y: 690)
    let u = 1 - t
    let x = u*u*u*p0.x + 3*u*u*t*p1.x + 3*u*t*t*p2.x + t*t*t*p3.x
    let y = u*u*u*p0.y + 3*u*u*t*p1.y + 3*u*t*t*p2.y + t*t*t*p3.y
    return CGPoint(x: x, y: y)
}

ctx.setLineCap(.round)
ctx.setLineJoin(.round)

let steps = 160
// Three passes like the in-app comet: halo, glow, core.
let passes: [(widthScale: CGFloat, alphaScale: CGFloat, whiten: CGFloat)] = [
    (2.1, 0.20, 0.0),
    (1.25, 0.55, 0.1),
    (0.6, 1.0, 0.45),
]
for pass in passes {
    for i in 1...steps {
        let t0 = CGFloat(i - 1) / CGFloat(steps)
        let t1 = CGFloat(i) / CGFloat(steps)
        let hue = 0.999 - t1 * 0.75          // red at head, violet at tail
        let taper = 0.12 + 0.88 * t1         // thin tail, fat head
        var color = NSColor(hue: hue, saturation: 0.85, brightness: 1.0, alpha: 1)
        if pass.whiten > 0 { color = color.blended(withFraction: pass.whiten, of: .white) ?? color }
        ctx.setStrokeColor(color.withAlphaComponent(pass.alphaScale * (0.25 + 0.75 * t1)).cgColor)
        ctx.setLineWidth(72 * taper * pass.widthScale)
        ctx.move(to: curvePoint(t0))
        ctx.addLine(to: curvePoint(t1))
        ctx.strokePath()
    }
}

// Cursor arrow at the head of the trail (classic macOS arrow, white w/ dark outline).
let arrow = NSBezierPath()
let pts: [(CGFloat, CGFloat)] = [
    (0, 0), (0, -14.5), (3.9, -10.8), (6.3, -16.1),
    (8.9, -14.9), (6.5, -9.7), (11.9, -9.7),
]
let scale: CGFloat = 17.5
let origin = CGPoint(x: 690, y: 700 + 145)  // hotspot near trail head
for (i, p) in pts.enumerated() {
    let point = CGPoint(x: origin.x + p.0 * scale, y: origin.y + p.1 * scale)
    if i == 0 { arrow.move(to: point) } else { arrow.line(to: point) }
}
arrow.close()

ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -6), blur: 20,
              color: NSColor.black.withAlphaComponent(0.5).cgColor)
NSColor.white.setFill()
arrow.fill()
ctx.restoreGState()
NSColor(calibratedWhite: 0.1, alpha: 1).setStroke()
arrow.lineWidth = 7
arrow.lineJoinStyle = .round
arrow.stroke()

image.unlockFocus()

// Write PNG.
guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    fatalError("failed to encode png")
}
let out = URL(fileURLWithPath: "icon_1024.png")
try! png.write(to: out)
print("wrote \(out.path)")
