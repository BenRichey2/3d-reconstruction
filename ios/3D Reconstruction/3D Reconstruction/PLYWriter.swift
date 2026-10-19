import Foundation

enum PLYWriter {
    static func serialize(points: [SIMD3<Float>]) -> String {
        var strCloud = "ply\nformat ascii 1.0\n"
        strCloud += "element vertex \(points.count)\n"
        strCloud += "property float x\n"
        strCloud += "property float y\n"
        strCloud += "property float z\n"
        strCloud += "end_header\n"
        for point in points {
            strCloud += "\(point.x) \(point.y) \(point.z)\n"
        }
        return strCloud
    }
    static func write(_ points: [SIMD3<Float>], to url: URL) throws {
        let str = serialize(points: points)
        try str.write(to: url, atomically: true, encoding: .ascii)
    }
    static func newPLYPath() throws -> URL {
        guard let docDirectory = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first else {
            throw PLYError.failedDirectory
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
        let dateStr = formatter.string(from: Date())
        return docDirectory.appendingPathComponent("cloud_\(dateStr).ply")
    }
}

enum PLYError: Error {
    case failedDirectory
}