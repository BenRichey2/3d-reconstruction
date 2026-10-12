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

    @Test func centerPixel() throws {

        let width = 3
        let height = 3
        let depthVal: Float = 5.0
        // For a 3x3 pixel image, the center pixel is at (1,1) = idx 3 * 1 + 1 = 4
        // NOTE: to make the math easy, always use odd numbers for depth image's width
        //       and height so there is an exact center pixel.
        let centerIdx = 4

        var depth: [Float] = Array(repeating: 0.0, count: width * height)
        depth[centerIdx] = depthVal
        let frame = DepthFrame(
            transform: matrix_identity_float4x4,
            intrinsics: Intrinsics(fx: 1.0, fy: 1.0, cx: 1.0, cy: 1.0),
            depthWidth: width,
            depthHeight: height,
            depthValues: depth,
            confScores: Array(repeating: 2, count: width * height)
        )

        let points = frame.worldPoints()
        try #require(points.count == 1)
        #expect(points[0] == SIMD3<Float>(0, 0, -depthVal))
    }

    @Test func offCenterPixel() throws {
        /*
        Testing the pixels around the center have the correct signs.
        Pixel to the right of center should have +x
        Pixel below the center should have -y
        */

        let width = 3
        let height = 3
        let depthVal: Float = 5.0
        // For a 3x3 pixel image, the center pixel is at (1,1) = idx 3 * 1 + 1 = 4
        // NOTE: to make the math easy, always use odd numbers for depth image's width
        //       and height so there is an exact center pixel.
        let centerIdx = 4

        // Test +x first.
        var depth: [Float] = Array(repeating: 0.0, count: width * height)
        depth[centerIdx + 1] = depthVal
        let frame = DepthFrame(
            transform: matrix_identity_float4x4,
            intrinsics: Intrinsics(fx: 2.0, fy: 4.0, cx: 1.0, cy: 1.0),
            depthWidth: width,
            depthHeight: height,
            depthValues: depth,
            confScores: Array(repeating: 2, count: width * height)
        )

        let points = frame.worldPoints()
        try #require(points.count == 1)
        #expect(points[0] == SIMD3<Float>(2.5, 0.0, -5.0))

        // Test -y next.
        depth[centerIdx + 1] = 0.0
        depth[centerIdx + width] = depthVal
        let frame2 = DepthFrame(
            transform: matrix_identity_float4x4,
            intrinsics: Intrinsics(fx: 2.0, fy: 4.0, cx: 1.0, cy: 1.0),
            depthWidth: width,
            depthHeight: height,
            depthValues: depth,
            confScores: Array(repeating: 2, count: width * height)
        )

        let points2 = frame2.worldPoints()
        try #require(points2.count == 1)
        #expect(points2[0] == SIMD3<Float>(0.0, -1.25, -5.0))
    }
}
