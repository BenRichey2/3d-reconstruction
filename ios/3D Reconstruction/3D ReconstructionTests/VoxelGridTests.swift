import Testing
import simd
@testable import _D_Reconstruction

struct VoxelGridTests {

    let voxelSize: Float = 0.02

    @Test func emptyGrid() {
        let grid = VoxelGrid(voxelSize: voxelSize)
        #expect(grid.count == 0)
        #expect(grid.cloud.isEmpty)
    }

    @Test func singlePoint() {
        var grid = VoxelGrid(voxelSize: voxelSize)
        let point = SIMD3<Float>(0.0, 1.0, 2.0)
        grid.insert(point)
        #expect(grid.count == 1)
        #expect(grid.cloud == [point])
    }

    @Test func sameVoxel() {
        var grid = VoxelGrid(voxelSize: 2.0)
        let point1 = SIMD3<Float>(0.0, 0.0, 0.0)
        let point2 = SIMD3<Float>(1.0, 1.0, 1.0)
        grid.insert(point1)
        grid.insert(point2)
        #expect(grid.count == 1)
        #expect(grid.cloud == [SIMD3<Float>(0.5, 0.5, 0.5)])
    }

    @Test func sameVoxelAvg() {
        var grid = VoxelGrid(voxelSize: 4.0)
        let point1 = SIMD3<Float>(0.0, 0.0, 0.0)
        let point2 = SIMD3<Float>(1.0, 1.0, 1.0)
        let point3 = SIMD3<Float>(2.0, 2.0, 2.0)
        let point4 = SIMD3<Float>(3.0, 3.0, 3.0)
        grid.insert(point1)
        grid.insert(point2)
        grid.insert(point3)
        grid.insert(point4)
        #expect(grid.count == 1)
        #expect(grid.cloud == [SIMD3<Float>(6.0 / 4.0, 6.0 / 4.0, 6.0 / 4.0)])
    }

    @Test func differentVoxel() {
        var grid = VoxelGrid(voxelSize: 2.0)
        let point1 = SIMD3<Float>(1.0, 1.0, 1.0)
        let point2 = SIMD3<Float>(2.0, 2.0, 2.0)
        grid.insert(point1)
        grid.insert(point2)
        #expect(grid.count == 2)
        #expect(grid.cloud.contains(point1))
        #expect(grid.cloud.contains(point2))
    }

    @Test func straddleZero() {
        var grid = VoxelGrid(voxelSize: 0.5)
        let point1 = SIMD3<Float>(0.25, 0.25, 0.25)
        let point2 = SIMD3<Float>(-0.25, -0.25, -0.25)
        grid.insert(point1)
        grid.insert(point2)
        #expect(grid.count == 2)
        #expect(grid.cloud.contains(point1))
        #expect(grid.cloud.contains(point2))
    }

    @Test func voxelSizeWorks() {
        var highResGrid = VoxelGrid(voxelSize: 0.5)
        var lowResGrid = VoxelGrid(voxelSize: 1.0)
        let point1 = SIMD3<Float>(0.2, 0.2, 0.2)
        let point2 = SIMD3<Float>(0.6, 0.6, 0.6)
        highResGrid.insert(point1)
        highResGrid.insert(point2)
        lowResGrid.insert(point1)
        lowResGrid.insert(point2)
        #expect(highResGrid.count == 2)
        #expect(lowResGrid.count == 1)
    }

    @Test(arguments: [0, 1, 2]) func singleAxisDiff(axis: Int) {
        var grid = VoxelGrid(voxelSize: voxelSize)
        let point1 = SIMD3<Float>(1.0, 2.0, 3.0)
        var point2 = SIMD3<Float>(1.0, 2.0, 3.0)
        point2[axis] += 0.2
        grid.insert(point1)
        grid.insert(point2)
        #expect(grid.count == 2)
    }

    @Test func onBoundary() {
        var grid = VoxelGrid(voxelSize: 0.5)
        let point1 = SIMD3<Float>(0.5, 0.5, 0.5)
        let point2 = SIMD3<Float>(0.7, 0.5, 0.5)
        grid.insert(point1)
        grid.insert(point2)
        #expect(grid.count == 1)
    }

}
