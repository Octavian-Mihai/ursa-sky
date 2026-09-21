import SceneKit
import simd
import UIKit

enum SkySphereBuilder {
    static let radius: Float = 12
    /// SceneKit `.line` primitives are 1 px hairlines. This cylinder radius
    /// reads as ~2.5–3× that width from the camera at the origin.
    static let constellationLineRadius: CGFloat = 0.022
    static let constellationGlowRadius: CGFloat = 0.048

    static func starNode(stars: [Star], magLimit: Double, jd: Double, latitude: Double, longitude: Double) -> (SCNNode, [Int], [SIMD3<Double>]) {
        let visible = stars.filter { $0.mag <= magLimit }
        var positions: [SCNVector3] = []
        var colors: [SCNVector3] = []
        var sizes: [Float] = []
        var hrIndex: [Int] = []
        var directions: [SIMD3<Double>] = []
        positions.reserveCapacity(visible.count)
        for star in visible {
            let h = HorizontalConvert.altAz(
                equatorialJ2000: star.equatorial,
                jd: jd,
                latitude: latitude,
                longitudeEast: longitude,
                applyNutation: true,
                applyRefraction: star.mag < 2
            )
            // Keep a sliver below the mathematical horizon for refraction; hide the rest.
            guard h.alt > -0.6 else { continue }
            let unit = HorizontalConvert.sceneDirection(altAz: h)
            let d = unit * radius
            positions.append(SCNVector3(d.x, d.y, d.z))
            colors.append(spectralColor(star.spect, mag: star.mag))
            sizes.append(pointSize(mag: star.mag))
            hrIndex.append(star.hr)
            directions.append(SIMD3<Double>(Double(unit.x), Double(unit.y), Double(unit.z)))
        }
        let node = SCNNode()
        node.name = "stars"
        guard !positions.isEmpty else { return (node, hrIndex, directions) }
        let src = SCNGeometrySource(vertices: positions)
        let colorData = colors.withUnsafeBufferPointer { Data(buffer: $0) }
        let colorSrc = SCNGeometrySource(
            data: colorData,
            semantic: .color,
            vectorCount: colors.count,
            usesFloatComponents: true,
            componentsPerVector: 3,
            bytesPerComponent: MemoryLayout<Float>.size,
            dataOffset: 0,
            dataStride: MemoryLayout<SCNVector3>.size
        )
        var indices = (0..<positions.count).map { UInt32($0) }
        let idxData = indices.withUnsafeBufferPointer { Data(buffer: $0) }
        let element = SCNGeometryElement(data: idxData, primitiveType: .point, primitiveCount: positions.count, bytesPerIndex: 4)
        element.pointSize = 6
        element.minimumPointScreenSpaceRadius = 1
        element.maximumPointScreenSpaceRadius = 18
        let geom = SCNGeometry(sources: [src, colorSrc], elements: [element])
        let mat = SCNMaterial()
        mat.lightingModel = .constant
        mat.writesToDepthBuffer = false
        geom.materials = [mat]
        node.geometry = geom
        _ = sizes
        return (node, hrIndex, directions)
    }

    static func lineNode(lines: [ConstellationLine], starsByHR: [Int: Star], jd: Double, latitude: Double, longitude: Double) -> SCNNode {
        let node = SCNNode()
        node.name = "lines"
        let stroke = lineMaterial(color: UIColor(white: 0.78, alpha: 0.82), emission: 0.28)
        let glow = lineMaterial(color: UIColor(white: 0.85, alpha: 0.22), emission: 0.12)
        for line in lines {
            guard let a = starsByHR[line.starA], let b = starsByHR[line.starB] else { continue }
            let ha = HorizontalConvert.altAz(equatorialJ2000: a.equatorial, jd: jd, latitude: latitude, longitudeEast: longitude, applyNutation: true, applyRefraction: false)
            let hb = HorizontalConvert.altAz(equatorialJ2000: b.equatorial, jd: jd, latitude: latitude, longitudeEast: longitude, applyNutation: true, applyRefraction: false)
            // Drop segments that are entirely below the horizon.
            guard ha.alt > -0.6 || hb.alt > -0.6 else { continue }
            let da = HorizontalConvert.sceneDirection(altAz: ha) * radius
            let db = HorizontalConvert.sceneDirection(altAz: hb) * radius
            let from = SCNVector3(da.x, da.y, da.z)
            let to = SCNVector3(db.x, db.y, db.z)
            if let core = cylinderSegment(from: from, to: to, radius: constellationLineRadius, material: stroke) {
                node.addChildNode(core)
            }
            if let halo = cylinderSegment(from: from, to: to, radius: constellationGlowRadius, material: glow) {
                node.addChildNode(halo)
            }
        }
        return node
    }

    private static func lineMaterial(color: UIColor, emission: CGFloat) -> SCNMaterial {
        let mat = SCNMaterial()
        mat.diffuse.contents = color
        mat.emission.contents = UIColor(white: emission, alpha: 1)
        mat.lightingModel = .constant
        mat.writesToDepthBuffer = false
        mat.isDoubleSided = true
        mat.blendMode = .alpha
        return mat
    }

    private static func cylinderSegment(from: SCNVector3, to: SCNVector3, radius: CGFloat, material: SCNMaterial) -> SCNNode? {
        let dx = to.x - from.x
        let dy = to.y - from.y
        let dz = to.z - from.z
        let length = CGFloat(sqrt(dx * dx + dy * dy + dz * dz))
        guard length > 1e-5 else { return nil }
        let cyl = SCNCylinder(radius: radius, height: length)
        cyl.radialSegmentCount = 6
        cyl.heightSegmentCount = 1
        cyl.materials = [material]
        let node = SCNNode(geometry: cyl)
        node.position = SCNVector3((from.x + to.x) * 0.5, (from.y + to.y) * 0.5, (from.z + to.z) * 0.5)
        let dir = simd_normalize(simd_float3(dx, dy, dz))
        let yAxis = simd_float3(0, 1, 0)
        let axis = simd_cross(yAxis, dir)
        let axisLen = simd_length(axis)
        if axisLen < 1e-6 {
            if dir.y < 0 { node.eulerAngles.x = .pi }
        } else {
            let angle = acos(max(-1, min(1, simd_dot(yAxis, dir))))
            node.simdOrientation = simd_quatf(angle: angle, axis: simd_normalize(axis))
        }
        return node
    }

    static func markerNode(named name: String, altAz: Horizontal, color: UIColor, size: CGFloat) -> SCNNode {
        let d = HorizontalConvert.sceneDirection(altAz: altAz) * radius
        let sph = SCNSphere(radius: size)
        sph.segmentCount = 8
        let mat = SCNMaterial()
        mat.diffuse.contents = color
        mat.lightingModel = .constant
        sph.materials = [mat]
        let node = SCNNode(geometry: sph)
        node.position = SCNVector3(d.x, d.y, d.z)
        node.name = name
        return node
    }

    static func pointSize(mag: Double) -> Float {
        let s = 14 - mag * 1.6
        return Float(max(1.5, min(16, s)))
    }

    static func spectralColor(_ spect: String?, mag: Double) -> SCNVector3 {
        let dim = Float(max(0.25, min(1.0, (7.2 - mag) / 7.2)))
        guard let s = spect?.uppercased().first else {
            return SCNVector3(dim, dim, dim)
        }
        switch s {
        case "O", "B": return SCNVector3(0.65 * dim, 0.78 * dim, dim)
        case "A": return SCNVector3(0.85 * dim, 0.9 * dim, dim)
        case "F": return SCNVector3(dim, dim, 0.92 * dim)
        case "G": return SCNVector3(dim, 0.95 * dim, 0.7 * dim)
        case "K": return SCNVector3(dim, 0.78 * dim, 0.5 * dim)
        case "M": return SCNVector3(dim, 0.55 * dim, 0.4 * dim)
        default: return SCNVector3(dim, dim, dim)
        }
    }
}
