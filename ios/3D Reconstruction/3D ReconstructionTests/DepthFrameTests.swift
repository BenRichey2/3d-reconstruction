//
//  DepthFrameTests.swift
//
//  Created by Ben Richey on 10/8/26.
//

import Testing
import simd
@testable import _D_Reconstruction

struct DepthFrameTests {

    @Test func buildAndAccess() {

        let width = 4
        let height = 3
        let length = width * height

        let frame = DepthFrame(
            transform: matrix_identity_float4x4,
            intrinsics: Intrinsics(fx: 1.0, fy: 1.0, cx: 1.0, cy: 1.0),
            depthWidth: width,
            depthHeight: height,
            depthValues: (0..<length).map {Float($0)},
            confScores: Array(repeating: 1 as UInt8, count: length)
        )

        for v in 0..<height {
            for u in 0..<width {
                let depthVal = frame.depth(u: u, v: v)
                #expect(Float(v * width + u) == depthVal)
            }
        }
    }

}
