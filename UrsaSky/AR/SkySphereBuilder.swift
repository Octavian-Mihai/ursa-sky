import SceneKit
import UIKit

enum SkySphereBuilder {
    static let radius: Float = 12

    static func starNode(stars: [Star], magLimit: Double, jd: Double, latitude: Double, longitude: Double) -> (SCNNode, [Int]) {
        let visible = stars.filter { $0.mag <= magLimit }
        var positions: [SCNVector3] = []
        var colors: [SCNVector3] = []
        var sizes: [Float] = []
        var hrIndex: [Int] = []
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
            let d = HorizontalConvert.sceneDirection(altAz: h) * radius
            positions.append(SCNVector3(d.x, d.y, d.z))
            colors.append(spectralColor(star.spect, mag: star.mag))
            sizes.append(pointSize(mag: star.mag))
            hrIndex.append(star.hr)
        }
        let node = SCNNode()
        node.name = "stars"
        guard !positions.isEmpty else { return (node, hrIndex) }
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
        return (node, hrIndex)
    }

    static func lineNode(lines: [ConstellationLine], starsByHR: [Int: Star], jd: Double, latitude: Double, longitude: Double) -> SCNNode {
        var positions: [SCNVector3] = []
        var indices: [UInt32] = []
        for line in lines {
            guard let a = starsByHR[line.starA], let b = starsByHR[line.starB] else { continue }
            let ha = HorizontalConvert.altAz(equatorialJ2000: a.equatorial, jd: jd, latitude: latitude, longitudeEast: longitude, applyNutation: true, applyRefraction: false)
            let hb = HorizontalConvert.altAz(equatorialJ2000: b.equatorial, jd: jd, latitude: latitude, longitudeEast: longitude, applyNutation: true, applyRefraction: false)
            // Drop segments that are entirely below the horizon.
            guard ha.alt > -0.6 || hb.alt > -0.6 else { continue }
            let da = HorizontalConvert.sceneDirection(altAz: ha) * radius
            let db = HorizontalConvert.sceneDirection(altAz: hb) * radius
            let i = UInt32(positions.count)
            positions.append(SCNVector3(da.x, da.y, da.z))
            positions.append(SCNVector3(db.x, db.y, db.z))
            indices.append(i)
            indices.append(i + 1)
        }
        let node = SCNNode()
        node.name = "lines"
        guard positions.count >= 2 else { return node }
        let src = SCNGeometrySource(vertices: positions)
        let idxData = indices.withUnsafeBufferPointer { Data(buffer: $0) }
        let element = SCNGeometryElement(data: idxData, primitiveType: .line, primitiveCount: indices.count / 2, bytesPerIndex: 4)
        let geom = SCNGeometry(sources: [src], elements: [element])
        let mat = SCNMaterial()
        mat.diffuse.contents = UIColor(white: 0.55, alpha: 0.55)
        mat.lightingModel = .constant
        mat.writesToDepthBuffer = false
        geom.materials = [mat]
        node.geometry = geom
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
