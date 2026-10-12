import ARKit
import simd


struct Intrinsics {
    let fx: Float
    let fy: Float
    let cx: Float
    let cy: Float
}

extension Intrinsics {
    init(intrinsics: simd_float3x3, factor: Float) {
        self.fx = intrinsics[0,0] / factor
        self.fy = intrinsics[1,1] / factor
        self.cx = intrinsics[2,0] / factor
        self.cy = intrinsics[2,1] / factor
    }
}

struct DepthFrame {
    let transform: simd_float4x4
    let intrinsics: Intrinsics
    let depthWidth: Int
    let depthHeight: Int
    let depthValues: [Float]
    let confScores: [UInt8]

}

extension DepthFrame {

    init(frame: ARFrame) throws {

        self.transform = frame.camera.transform

        guard let depthData = frame.sceneDepth else { throw DepthFrameValidationError.noDepthData }
        let depthBuf: CVPixelBuffer = depthData.depthMap
        self.depthWidth = CVPixelBufferGetWidth(depthBuf)
        self.depthHeight = CVPixelBufferGetHeight(depthBuf)

        let img: CVPixelBuffer = frame.capturedImage
        let rgbWidth = CVPixelBufferGetWidth(img)

        self.intrinsics = Intrinsics(
            intrinsics: frame.camera.intrinsics,
            factor: Float(rgbWidth) / Float(self.depthWidth)
        )

        guard let confBuf: CVPixelBuffer = depthData.confidenceMap else {
            throw DepthFrameValidationError.noConfData
        }

        self.depthValues = try Self.copyRows(
            of: depthBuf,
            as: Float32.self
        )
        self.confScores = try Self.copyRows(
            of: confBuf,
            as: UInt8.self
        )
    }

    private static func copyRows<T>(
        of buffer: CVPixelBuffer,
        as type: T.Type
    ) throws -> [T] {

        let bufWidth = CVPixelBufferGetWidth(buffer)
        let bufHeight = CVPixelBufferGetHeight(buffer)

        let lockFlags = CVPixelBufferLockFlags.readOnly

        let status = CVPixelBufferLockBaseAddress(buffer, lockFlags)
        guard status == kCVReturnSuccess else {
            throw DepthFrameValidationError.failedLockBaseAddress
        }
        defer { CVPixelBufferUnlockBaseAddress(buffer, lockFlags) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(buffer) else {
            throw DepthFrameValidationError.failedGetBaseAddress
        }

        let itemsPerRow = CVPixelBufferGetBytesPerRow(buffer) / MemoryLayout<T>.stride
        let pointer = baseAddress.assumingMemoryBound(to: T.self)

        var copy: [T] = []
        copy.reserveCapacity(bufWidth * bufHeight)
        for v in 0..<bufHeight {
            let row = UnsafeBufferPointer(
                start: pointer + v * itemsPerRow,
                count: bufWidth
            )
            copy.append(contentsOf: row)
        }
        return copy
    }

    func depth(u: Int, v: Int) -> Float {
        return self.depthValues[v * self.depthWidth + u]
    }

    func confidence(u: Int, v: Int) -> UInt8 {
        return self.confScores[v * self.depthWidth + u]
    }

    func worldPoints() -> [SIMD3<Float>] {
        var cloud: [SIMD3<Float>] = []
        cloud.reserveCapacity(depthWidth * depthHeight)
        let k = intrinsics
        for v in 0..<depthHeight {
            for u in 0..<depthWidth {
                let conf = confidence(u: u, v: v)
                let depth = depth(u: u, v: v)
                guard conf == ARConfidenceLevel.high.rawValue, depth > 0 else { continue }
                // unproject depth to camera space
                let x = (Float(u) - k.cx) * depth / k.fx
                let y = (Float(v) - k.cy) * depth / k.fy
                // Flip from image convention to camera convention and transform to world space
                let point = transform * SIMD4<Float>(
                    x: x,
                    y: -y,
                    z: -depth,
                    w: 1
                )
                cloud.append(SIMD3<Float>(x: point.x, y: point.y, z: point.z))
            }
        }
        return cloud
    }
}

enum DepthFrameValidationError: Error {
    case noDepthData
    case noConfData
    case failedLockBaseAddress
    case failedGetBaseAddress
}
