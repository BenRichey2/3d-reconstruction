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
}

enum DepthFrameValidationError: Error {
    case noDepthData
    case noConfData
    case failedLockBaseAddress
    case failedGetBaseAddress
}
