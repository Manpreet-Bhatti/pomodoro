import AppKit

let dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let out = URL(fileURLWithPath: CommandLine.arguments[1])
let svg = NSImage(contentsOf: dir.appendingPathComponent("AppIcon.svg"))!
let set = FileManager.default.temporaryDirectory.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: set)
try FileManager.default.createDirectory(at: set, withIntermediateDirectories: true)

for pt in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let px = pt * scale
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
            samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
            bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        svg.draw(in: NSRect(x: 0, y: 0, width: px, height: px))
        NSGraphicsContext.current = nil
        let name = "icon_\(pt)x\(pt)\(scale == 2 ? "@2x" : "").png"
        try rep.representation(using: .png, properties: [:])!.write(
            to: set.appendingPathComponent(name))
    }
}

let p = Process()
p.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
p.arguments = ["-c", "icns", set.path, "-o", out.path]
try p.run()
p.waitUntilExit()
