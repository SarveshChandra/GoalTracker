import AppKit
import Foundation

guard CommandLine.arguments.count == 2 else {
    fputs("usage: generate_app_icon.swift <output-resources-dir>\n", stderr)
    exit(2)
}

let resourcesURL = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let iconsetURL = resourcesURL.appendingPathComponent("GoalTracker.iconset", isDirectory: true)
try? FileManager.default.removeItem(at: iconsetURL)
try FileManager.default.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

struct IconVariant {
    let points: Int
    let scale: Int

    var pixels: Int { points * scale }

    var fileName: String {
        scale == 1 ? "icon_\(points)x\(points).png" : "icon_\(points)x\(points)@\(scale)x.png"
    }
}

let variants = [
    IconVariant(points: 16, scale: 1),
    IconVariant(points: 16, scale: 2),
    IconVariant(points: 32, scale: 1),
    IconVariant(points: 32, scale: 2),
    IconVariant(points: 128, scale: 1),
    IconVariant(points: 128, scale: 2),
    IconVariant(points: 256, scale: 1),
    IconVariant(points: 256, scale: 2),
    IconVariant(points: 512, scale: 1),
    IconVariant(points: 512, scale: 2)
]

func drawIcon(pixels: Int) -> NSImage {
    let side = CGFloat(pixels)
    let image = NSImage(size: NSSize(width: side, height: side))
    let unit = side / 1024.0

    func scaled(_ value: CGFloat) -> CGFloat {
        value * unit
    }

    image.lockFocus()
    defer { image.unlockFocus() }

    NSGraphicsContext.current?.cgContext.setShouldAntialias(true)
    NSGraphicsContext.current?.imageInterpolation = .none

    let fullRect = NSRect(x: 0, y: 0, width: side, height: side)
    NSColor.clear.setFill()
    fullRect.fill()

    let backgroundRect = fullRect.insetBy(dx: scaled(62), dy: scaled(62))
    let background = NSBezierPath(
        roundedRect: backgroundRect,
        xRadius: scaled(205),
        yRadius: scaled(205)
    )
    NSColor(calibratedRed: 1.00, green: 0.94, blue: 0.58, alpha: 1.0).setFill()
    background.fill()

    let targetRed = NSColor(calibratedRed: 0.66, green: 0.04, blue: 0.03, alpha: 1.0)
    targetRed.setStroke()

    let outerTarget = NSBezierPath(ovalIn: fullRect.insetBy(dx: scaled(228), dy: scaled(228)))
    outerTarget.lineWidth = scaled(46)
    outerTarget.stroke()

    let middleTarget = NSBezierPath(ovalIn: fullRect.insetBy(dx: scaled(356), dy: scaled(356)))
    middleTarget.lineWidth = scaled(38)
    middleTarget.stroke()

    let innerTarget = NSBezierPath(ovalIn: fullRect.insetBy(dx: scaled(480), dy: scaled(480)))
    innerTarget.lineWidth = scaled(34)
    innerTarget.stroke()

    let focusLine = NSBezierPath()
    focusLine.move(to: NSPoint(x: scaled(512), y: scaled(180)))
    focusLine.line(to: NSPoint(x: scaled(512), y: scaled(844)))
    focusLine.lineWidth = scaled(24)
    focusLine.lineCapStyle = .butt
    focusLine.stroke()

    let horizontalLine = NSBezierPath()
    horizontalLine.move(to: NSPoint(x: scaled(180), y: scaled(512)))
    horizontalLine.line(to: NSPoint(x: scaled(844), y: scaled(512)))
    horizontalLine.lineWidth = scaled(24)
    horizontalLine.lineCapStyle = .butt
    horizontalLine.stroke()

    let centerDot = NSBezierPath(ovalIn: fullRect.insetBy(dx: scaled(484), dy: scaled(484)))
    targetRed.setFill()
    centerDot.fill()

    return image
}

for variant in variants {
    let image = drawIcon(pixels: variant.pixels)
    guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        fputs("failed to create CGImage for \(variant.fileName)\n", stderr)
        exit(1)
    }

    let rep = NSBitmapImageRep(cgImage: cgImage)
    rep.size = image.size
    guard let data = rep.representation(using: .png, properties: [:]) else {
        fputs("failed to create PNG for \(variant.fileName)\n", stderr)
        exit(1)
    }

    try data.write(to: iconsetURL.appendingPathComponent(variant.fileName), options: .atomic)
}
