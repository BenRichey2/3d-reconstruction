import simd

struct KeyFrameSelector {
    private(set) var lastKeyFrameTransform: simd_float4x4? = nil
    private(set) var acceptedCount: Int = 0
    let minRotation: Float
    let minTranslation: Float
}

extension KeyFrameSelector {

    init(minRotation minRot: Float = 10.0, minTranslation minTrans: Float = 0.05) {
        minRotation = minRot
        minTranslation = minTrans
    }

    mutating func isKeyFrame(transform: simd_float4x4) -> Bool {
        guard let lastTransform = lastKeyFrameTransform else {
            accept(transform)
            return true
        }
        let transDist = simd_distance(
            lastTransform.columns.3,
            transform.columns.3
        )
        if transDist >= minTranslation {
            accept(transform)
            return true
        }
        let lastQuat = simd_normalize(simd_quaternion(lastTransform))
        let currentQuat = simd_normalize(simd_quaternion(transform))
        let dot = simd_dot(lastQuat, currentQuat)
        let angle = 2.0 * acos(min(1, abs(dot))) * 180.0 / .pi
        if angle >= minRotation {
            accept(transform)
            return true
        }
        return false
    }

    mutating func reset() {
        lastKeyFrameTransform = nil
        acceptedCount = 0
    }

    private mutating func accept(_ transform: simd_float4x4) {
        lastKeyFrameTransform = transform
        acceptedCount += 1
    }
}
