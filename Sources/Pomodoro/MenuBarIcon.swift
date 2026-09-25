import AppKit

extension NSImage {
    @MainActor static let sakuraTimer: NSImage = {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: true) { _ in
            let ctx = NSGraphicsContext.current!
            let t = NSAffineTransform()
            t.translateX(by: 9, yBy: 9.6)
            t.scale(by: 0.5)
            t.concat()

            let petal = NSBezierPath()
            petal.move(to: NSPoint(x: 0, y: 0))
            petal.curve(
                to: NSPoint(x: -7, y: -13.6), controlPoint1: NSPoint(x: -4, y: -2.5),
                controlPoint2: NSPoint(x: -8.2, y: -9))
            petal.curve(
                to: NSPoint(x: -1.3, y: -15.8), controlPoint1: NSPoint(x: -6.3, y: -16.4),
                controlPoint2: NSPoint(x: -3, y: -17.2))
            petal.line(to: NSPoint(x: 0, y: -13.8))
            petal.line(to: NSPoint(x: 1.3, y: -15.8))
            petal.curve(
                to: NSPoint(x: 7, y: -13.6), controlPoint1: NSPoint(x: 3, y: -17.2),
                controlPoint2: NSPoint(x: 6.3, y: -16.4))
            petal.curve(
                to: NSPoint(x: 0, y: 0), controlPoint1: NSPoint(x: 8.2, y: -9),
                controlPoint2: NSPoint(x: 4, y: -2.5))
            petal.close()
            let petals = (0..<5).map { k -> NSBezierPath in
                let p = petal.copy() as! NSBezierPath
                let r = AffineTransform(rotationByDegrees: 36 + 72 * CGFloat(k))
                p.transform(using: r)
                return p
            }

            NSColor.black.set()
            petals.forEach { $0.fill() }

            ctx.compositingOperation = .destinationOut
            let seams = NSBezierPath()
            for k in 1..<5 {
                let a = CGFloat(k) * 72 * .pi / 180
                seams.move(to: NSPoint(x: 0, y: 0))
                seams.line(to: NSPoint(x: 18 * sin(a), y: -18 * cos(a)))
            }
            seams.lineWidth = 1.4
            seams.stroke()
            NSBezierPath(ovalIn: NSRect(x: -7.2, y: -7.2, width: 14.4, height: 14.4)).fill()
            NSBezierPath(rect: NSRect(x: -2.4, y: -15, width: 4.8, height: 8)).fill()  // crown clearance
            NSBezierPath(
                roundedRect: NSRect(x: -4.4, y: -19.2, width: 8.8, height: 5.8), xRadius: 2,
                yRadius: 2
            ).fill()

            ctx.compositingOperation = .sourceOver
            NSBezierPath(rect: NSRect(x: -1.2, y: -15, width: 2.4, height: 6)).fill()
            NSBezierPath(
                roundedRect: NSRect(x: -3.2, y: -18, width: 6.4, height: 3.4), xRadius: 1.2,
                yRadius: 1.2
            ).fill()
            let hands = NSBezierPath()
            hands.move(to: NSPoint(x: 0, y: -4.6))
            hands.line(to: .zero)
            hands.line(to: NSPoint(x: -3.6, y: 2))
            hands.lineWidth = 2
            hands.lineCapStyle = .round
            hands.lineJoinStyle = .round
            hands.stroke()
            return true
        }
        image.isTemplate = true
        return image
    }()
}
