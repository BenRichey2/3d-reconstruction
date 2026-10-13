struct VoxelGrid {
    private struct VoxelState {
        var sum: SIMD3<Float> = .zero
        var count = 0
        static func += (left: inout VoxelState, right: VoxelState) {
            left.sum += right.sum
            left.count += right.count
        }
    }
    let voxelSize: Float
    private var voxels: [SIMD3<Int32>: VoxelState] = [:]
    var count: Int { voxels.count }
    var cloud: [SIMD3<Float>] { voxels.values.map {$0.sum / Float($0.count)} }
}

extension VoxelGrid {
    mutating func insert(_ point: SIMD3<Float>) {
        let voxel = SIMD3<Int32>((point / voxelSize).rounded(.down))
        voxels[voxel, default: VoxelState()] += VoxelState(sum: point, count: 1)
    }
}