import AppKit

// Genera cada frame del chita en código — sin archivos de imagen
enum CheetahSprite {

    static let size = NSSize(width: 22, height: 22)

    // MARK: - API pública

    static func restFrame(_ index: Int) -> NSImage {
        switch index % 4 {
        case 0: return drawRest(eyeOpen: true,  tail: 0)
        case 1: return drawRest(eyeOpen: true,  tail: 1)
        case 2: return drawRest(eyeOpen: false, tail: 1)
        default: return drawRest(eyeOpen: false, tail: 0)
        }
    }

    static func runFrame(_ index: Int) -> NSImage {
        return drawRun(phase: index % 6)
    }

    // MARK: - Descanso

    private static func drawRest(eyeOpen: Bool, tail: Int) -> NSImage {
        NSImage(size: size, flipped: false) { rect in
            let ctx = NSGraphicsContext.current!.cgContext

            // Cuerpo principal (elipse horizontal)
            let body = CGRect(x: 3, y: 5, width: 14, height: 8)
            ctx.setFillColor(NSColor(red: 0.82, green: 0.67, blue: 0.35, alpha: 1).cgColor)
            ctx.fillEllipse(in: body)

            // Cabeza
            let head = CGRect(x: 13, y: 9, width: 7, height: 6)
            ctx.fillEllipse(in: head)

            // Orejas
            ctx.setFillColor(NSColor(red: 0.70, green: 0.55, blue: 0.28, alpha: 1).cgColor)
            let earL = CGRect(x: 14, y: 14, width: 2, height: 2)
            let earR = CGRect(x: 17, y: 14, width: 2, height: 2)
            ctx.fill([earL, earR])

            // Ojo
            ctx.setFillColor(NSColor(red: 0.15, green: 0.10, blue: 0.05, alpha: 1).cgColor)
            if eyeOpen {
                ctx.fillEllipse(in: CGRect(x: 17, y: 11, width: 2, height: 2))
            } else {
                ctx.setStrokeColor(NSColor(red: 0.15, green: 0.10, blue: 0.05, alpha: 1).cgColor)
                ctx.setLineWidth(0.8)
                ctx.move(to: CGPoint(x: 17, y: 12))
                ctx.addLine(to: CGPoint(x: 19, y: 12))
                ctx.strokePath()
            }

            // Patas (acostadas)
            ctx.setFillColor(NSColor(red: 0.75, green: 0.60, blue: 0.30, alpha: 1).cgColor)
            ctx.fill(CGRect(x: 4, y: 3, width: 3, height: 3))
            ctx.fill(CGRect(x: 8, y: 3, width: 3, height: 3))
            ctx.fill(CGRect(x: 12, y: 3, width: 3, height: 3))

            // Cola
            ctx.setStrokeColor(NSColor(red: 0.70, green: 0.55, blue: 0.28, alpha: 1).cgColor)
            ctx.setLineWidth(1.5)
            ctx.setLineCap(.round)
            ctx.move(to: CGPoint(x: 3, y: 9))
            let tipY: CGFloat = tail == 0 ? 14 : 16
            ctx.addQuadCurve(to: CGPoint(x: 1, y: tipY), control: CGPoint(x: 0, y: 10))
            ctx.strokePath()

            // Manchas
            ctx.setFillColor(NSColor(red: 0.40, green: 0.28, blue: 0.10, alpha: 0.6).cgColor)
            for spot in [(CGFloat(6), CGFloat(10)), (9, 12), (12, 10), (7, 7)] {
                ctx.fillEllipse(in: CGRect(x: spot.0, y: spot.1, width: 1.5, height: 1.5))
            }

            return true
        }
    }

    // MARK: - Corrida

    private static func drawRun(phase: Int) -> NSImage {
        // Posición del pie en cada fase (6 fases del ciclo)
        // frontFoot: pie delantero, backFoot: pie trasero, bodyY: centro vertical del cuerpo
        let legPhases: [(frontFoot: CGPoint, backFoot: CGPoint, bodyY: CGFloat)] = [
            (CGPoint(x: 18, y: 5),  CGPoint(x: 4,  y: 5),  12),  // 0: despegue
            (CGPoint(x: 19, y: 8),  CGPoint(x: 2,  y: 3),  13),  // 1: extensión trasera
            (CGPoint(x: 18, y: 11), CGPoint(x: 2,  y: 3),  14),  // 2: vuelo (punto alto)
            (CGPoint(x: 17, y: 13), CGPoint(x: 3,  y: 5),  13),  // 3: aterrizaje
            (CGPoint(x: 16, y: 10), CGPoint(x: 4,  y: 8),  12),  // 4: empuje
            (CGPoint(x: 17, y: 6),  CGPoint(x: 5,  y: 11), 12),  // 5: recogida
        ]

        let p = legPhases[phase % 6]
        let bodyY = p.bodyY

        // Puntos de anclaje (cadera/hombro) en el cuerpo
        let frontHip = CGPoint(x: 15, y: bodyY - 3)
        let backHip  = CGPoint(x: 7,  y: bodyY - 3)

        // Calcula la rodilla: punto medio hip→pie desplazado perpendicularmente
        // Pata delantera: rodilla dobla hacia adelante (+x)
        // Pata trasera: corvejón dobla hacia atrás (-x), ambas hacia abajo (-y)
        func kneeFor(hip: CGPoint, foot: CGPoint, dx: CGFloat, dy: CGFloat) -> CGPoint {
            CGPoint(
                x: (hip.x + foot.x) / 2 + dx,
                y: (hip.y + foot.y) / 2 + dy
            )
        }

        let frontKnee = kneeFor(hip: frontHip, foot: p.frontFoot, dx:  2.5, dy: -2.5)
        let backKnee  = kneeFor(hip: backHip,  foot: p.backFoot,  dx: -2.5, dy: -2.5)

        // Segundo par de patas (ligeramente desplazado, más oscuro) para sensación de profundidad
        let frontHip2   = CGPoint(x: frontHip.x - 1,      y: frontHip.y - 1)
        let backHip2    = CGPoint(x: backHip.x  + 1,      y: backHip.y  - 1)
        let frontFoot2  = CGPoint(x: p.frontFoot.x - 1,   y: p.frontFoot.y - 1)
        let backFoot2   = CGPoint(x: p.backFoot.x  + 1,   y: p.backFoot.y  - 1)
        let frontKnee2  = kneeFor(hip: frontHip2, foot: frontFoot2, dx:  2.5, dy: -2.5)
        let backKnee2   = kneeFor(hip: backHip2,  foot: backFoot2,  dx: -2.5, dy: -2.5)

        return NSImage(size: size, flipped: false) { _ in
            let ctx = NSGraphicsContext.current!.cgContext

            let bodyColor  = NSColor(red: 0.82, green: 0.67, blue: 0.35, alpha: 1.0).cgColor
            let darkColor  = NSColor(red: 0.40, green: 0.28, blue: 0.10, alpha: 0.6).cgColor
            let legColor   = NSColor(red: 0.75, green: 0.60, blue: 0.30, alpha: 1.0).cgColor
            let legColor2  = NSColor(red: 0.60, green: 0.47, blue: 0.20, alpha: 0.55).cgColor

            ctx.setLineWidth(1.8)
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)

            // --- Patas del segundo par (fondo, más oscuras) ---
            ctx.setStrokeColor(legColor2)

            ctx.move(to: backHip2)
            ctx.addLine(to: backKnee2)
            ctx.addLine(to: backFoot2)
            ctx.strokePath()

            ctx.move(to: frontHip2)
            ctx.addLine(to: frontKnee2)
            ctx.addLine(to: frontFoot2)
            ctx.strokePath()

            // --- Pata trasera principal (detrás del cuerpo) ---
            ctx.setStrokeColor(legColor)
            ctx.move(to: backHip)
            ctx.addLine(to: backKnee)
            ctx.addLine(to: p.backFoot)
            ctx.strokePath()

            // --- Cuerpo ---
            ctx.setFillColor(bodyColor)
            ctx.fillEllipse(in: CGRect(x: 5, y: bodyY - 4, width: 12, height: 7))

            // --- Cabeza ---
            let headX: CGFloat = 14
            let headY: CGFloat = bodyY - 2
            ctx.fillEllipse(in: CGRect(x: headX, y: headY, width: 6, height: 5))

            // Orejas
            ctx.setFillColor(NSColor(red: 0.70, green: 0.55, blue: 0.28, alpha: 1).cgColor)
            ctx.fillEllipse(in: CGRect(x: headX + 0.5, y: headY + 3.5, width: 1.5, height: 1.5))
            ctx.fillEllipse(in: CGRect(x: headX + 3.0, y: headY + 3.5, width: 1.5, height: 1.5))

            // Ojo
            ctx.setFillColor(NSColor(red: 0.10, green: 0.05, blue: 0.02, alpha: 1).cgColor)
            ctx.fillEllipse(in: CGRect(x: headX + 3.5, y: headY + 1.5, width: 1.8, height: 1.8))

            // --- Pata delantera principal (encima del cuerpo) ---
            ctx.setStrokeColor(legColor)
            ctx.move(to: frontHip)
            ctx.addLine(to: frontKnee)
            ctx.addLine(to: p.frontFoot)
            ctx.strokePath()

            // --- Cola ---
            ctx.setStrokeColor(NSColor(red: 0.70, green: 0.55, blue: 0.28, alpha: 1).cgColor)
            ctx.setLineWidth(1.5)
            ctx.move(to: CGPoint(x: 5, y: bodyY - 1))
            ctx.addQuadCurve(to: CGPoint(x: 1, y: bodyY + 2), control: CGPoint(x: 2, y: bodyY - 3))
            ctx.strokePath()

            // --- Manchas ---
            ctx.setFillColor(darkColor)
            for spot: (CGFloat, CGFloat) in [(7, bodyY), (10, bodyY + 1), (12, bodyY - 1)] {
                ctx.fillEllipse(in: CGRect(x: spot.0, y: spot.1, width: 1.5, height: 1.5))
            }

            return true
        }
    }
}
