import Testing
@testable import _D_Reconstruction

struct PLYWriterTests {

    @Test func headerCountMatchesDataLines() throws {
        let points: [SIMD3<Float>] = Array(
            repeating: SIMD3<Float>(0.0, 0.0, 0.0),
            count: 3
        )
        let serialStr = PLYWriter.serialize(points: points)
        let lines = serialStr.split(separator: "\n")
        let count = try #require(Int(lines[2].split(separator: " ")[2]))
        #expect(count == 3)
        let endIdx = try #require(
            lines.firstIndex(where: {$0.contains("end_header")})
        )
        let numSavedPoints = lines.count - endIdx - 1
        #expect(numSavedPoints == 3)
    }

    @Test func endsWithNewline() {
        let points: [SIMD3<Float>] = Array(
            repeating: SIMD3<Float>(0.0, 0.0, 0.0),
            count: 3
        )
        let serialStr = PLYWriter.serialize(points: points)
        #expect(serialStr.hasSuffix("\n"))
    }

    @Test func checkNumbers() throws {
        var points: [SIMD3<Float>] = []
        points.append(SIMD3<Float>(0.0, 0.0, 0.0))
        points.append(SIMD3<Float>(-1.0, 2.0, 7.23))
        points.append(SIMD3<Float>(-2.34, 3.14159, 87.0))
        let serialStr = PLYWriter.serialize(points: points)
        let lines = serialStr.split(separator: "\n")
        for idx in 0..<points.count {
            let point = points[idx]
            let strPoint = lines[idx + 7]
            let strVals = strPoint.split(separator: " ")
            try #require(strVals.count == 3)
            let newPoint = SIMD3<Float>(strVals.compactMap {Float($0)})
            #expect(newPoint == point)
        }
    }

    @Test func emptyCloud() throws {
        let points: [SIMD3<Float>] = []
        let serialStr = PLYWriter.serialize(points: points)
        let lines = serialStr.split(separator: "\n")
        let count = try #require(Int(lines[2].split(separator: " ")[2]))
        #expect(count == 0)
        #expect(serialStr.hasSuffix("end_header\n"))
    }

}
