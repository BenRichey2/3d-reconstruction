//
//  DepthFrameTests.swift
//
//  Created by Ben Richey on 10/8/26.
//

import Testing
import simd
@testable import _D_Reconstruction

struct DepthFrameTests {

    let width = 3
    let height = 3
    let depthVal: Float = 5.0
    let centerIdx = 4

    @Test func buildAndAccess() {

        let width = 4
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

    @Test func centerPixel() throws {

        let testFrame = frame(
            withSinglePixelAt: centerIdx,
            depth: depthVal,
            width: width,
            height: height,
            intrinsics: Intrinsics(fx: 2.0, fy: 4.0, cx: 1.0, cy: 1.0)
        )

        let points = testFrame.worldPoints()
        try #require(points.count == 1)
        #expect(points[0] == SIMD3<Float>(0, 0, -depthVal))
    }

    @Test func rightOfCenterPixel() throws {
        let testFrame = frame(
            withSinglePixelAt: centerIdx + 1,
            depth: depthVal,
            width: width,
            height: height,
            intrinsics: Intrinsics(fx: 2.0, fy: 4.0, cx: 1.0, cy: 1.0)
        )

        let points = testFrame.worldPoints()
        try #require(points.count == 1)
        #expect(points[0] == SIMD3<Float>(2.5, 0.0, -5.0))
    }

    @Test func belowCenterPixel() throws {
        let testFrame = frame(
            withSinglePixelAt: centerIdx + width,
            depth: depthVal,
            width: width,
            height: height,
            intrinsics: Intrinsics(fx: 2.0, fy: 4.0, cx: 1.0, cy: 1.0)
        )
        let points = testFrame.worldPoints()
        try #require(points.count == 1)
        #expect(points[0] == SIMD3<Float>(0.0, -1.25, -depthVal))
    }

    @Test func translatedTransform() throws {
        var translated = matrix_identity_float4x4
        translated.columns.3 = SIMD4<Float>(1,2,3,1)
        let testFrame = frame(
            withSinglePixelAt: centerIdx,
            depth: depthVal,
            width: width,
            height: height,
            intrinsics: Intrinsics(fx: 1.0, fy: 1.0, cx: 1.0, cy: 1.0),
            transform: translated
        )

        let points = testFrame.worldPoints()
        try #require(points.count == 1)
        #expect(points[0] == SIMD3<Float>(1, 2, 3 - depthVal))
    }

    @Test func confFilter() throws {
        let testFrame = frame(
            withSinglePixelAt: centerIdx,
            depth: depthVal,
            width: width,
            height: height,
            intrinsics: Intrinsics(fx: 1.0, fy: 1.0, cx: 1.0, cy: 1.0),
            confVal: 1
        )
        let points = testFrame.worldPoints()
        #expect(points.isEmpty)
    }

    private func frame(
        withSinglePixelAt u: Int,
        depth: Float,
        width: Int,
        height: Int,
        intrinsics: Intrinsics,
        transform: simd_float4x4 = matrix_identity_float4x4,
        confVal: UInt8 = 2
    ) -> DepthFrame {
        var depthVals: [Float] = Array(repeating: 0.0, count: width * height)
        depthVals[u] = depth
        return DepthFrame(
            transform: transform,
            intrinsics: intrinsics,
            depthWidth: width,
            depthHeight: height,
            depthValues: depthVals,
            confScores: Array(repeating: confVal, count: width * height)
        )
    }
}
