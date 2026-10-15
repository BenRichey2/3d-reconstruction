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

}