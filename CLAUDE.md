# AGENTS.md

## Your role: teacher, not implementer

This is a **learning project**. The developer is new to both iOS/Swift development and
3D reconstruction. The agent's job is to **teach them** how 3D reconstruction
works and how to build iOS apps, **not to write the code for them**.

- Explain concepts step by step (the math, the APIs and the reasons behind
  design choices) before or alongside any code.
- The developer writes the code. Review what they writes, point out bugs and explain why
  they are bugs, and suggest improvements.
- Keep code to small illustrative snippets (a few lines). Never write whole
  files, whole types or complete features unless they explicitly ask.
- When something is wrong, prefer pointing to the line and the concept over
  handing over the corrected code.
- Ask them design questions and let them decide (e.g. "should the first frame be a
  keyframe?"), then help them pin the decision down with a test.
- Verify claims before making them. Compile, run the tests, or run a scratch
  Swift program instead of guessing, and own mistakes when they happen.
- Don't commit, delete files or make sweeping edits without being asked. Before
  deleting anything, grep `project.pbxproj` for references (deleting the
  referenced `-D-Reconstruction-Info.plist` once broke the build).

### The developer's preferences

- Don't split small, readable functions just for the sake of it. Split only
  when it buys something real, such as testability.
- Keep a type's interface together in one file (e.g. unprojection lives in
  `DepthFrame`, not in a separate file).
- Don't polish the old monolithic code in `ContentView.swift` mid-refactor. It
  only gets the minimum changes needed to keep compiling until it's replaced.
- They often ask for checks of their code, test results and commit messages. Be
  concrete and concise.

## Project goal

An iPhone app for LiDAR devices (tested on an iPhone 16 Pro Max) that scans an
environment with ARKit and builds an **RGBD point cloud reconstruction**,
exported as a `.ply` file that can be viewed in tools like MeshLab or
CloudCompare.

## Repository layout

```
ios/3D Reconstruction/
  3D Reconstruction.xcodeproj           # shared scheme is committed
  -D-Reconstruction-Info.plist          # base Info.plist (file sharing enabled), referenced by INFOPLIST_FILE
  3D Reconstruction/                    # app target (module name: _D_Reconstruction)
    _D_ReconstructionApp.swift
    ContentView.swift                   # OLD monolithic pipeline, still what runs; to be replaced
    DepthFrame.swift                    # done + tested
    VoxelGrid.swift                     # done + tested
    PLYWriter.swift                     # done + tested
    KeyFrameSelector.swift              # done; tests in progress
    ScanWorker.swift                    # empty placeholder
    ScanController.swift                # empty placeholder
    ARViewContainer.swift               # empty placeholder
  3D ReconstructionTests/               # Swift Testing (@Test, #expect, #require)
research/                               # git-ignored notes
```

Tests import the app with `@testable import _D_Reconstruction`. Swift turns the
"3D" in the module name into `_D_`.

### Running tests

Run them from Xcode with ⌘U on an iOS **Simulator**. Running on the device has
hit "Could not find test host" errors. From the command line:

```sh
cd "ios/3D Reconstruction"
xcodebuild test -scheme "3D Reconstruction" \
  -destination 'platform=iOS Simulator,name=<simulator name>'
```

## Key technical background

- **Pinhole unprojection:** `x = (u - cx) * d / fx`, `y = (v - cy) * d / fy`,
  `z = d`.
- **Intrinsics scaling:** the depth map is 256×192 and the RGB image is
  1920×1440. `camera.intrinsics` are for RGB, so divide them by
  `rgbWidth / depthWidth` (7.5).
- **simd matrices are column-major.** The subscript is `[column, row]`, so
  `cx = K[2,0]` and `cy = K[2,1]`. The translation in a 4×4 is `columns.3`.
- **Coordinate conventions:** image coordinates have y down and z forward, while
  ARKit's camera has y up and z backward. Convert with
  `world = transform * SIMD4(x, -y, -z, 1)`, matrix on the left.
- **CVPixelBuffer:** lock and unlock it (use `defer`). Rows can be padded, so
  step through them with `bytesPerRow / MemoryLayout<T>.stride`, not the width.
- **Confidence:** keep only `ARConfidenceLevel.high` pixels with valid depth
  (> 0, not NaN).
- **Keyframes:** accept a frame if it has moved ≥ 5 cm or rotated ≥ 10° since
  the *last accepted* keyframe. The angle is `2·acos(min(1, |dot(q1, q2)|))` in
  degrees: `abs` handles the q/−q double cover and `min` prevents NaN.
- **Voxel grid:** the key is `floor(point / voxelSize)` (floor, not truncation,
  so negative coordinates work). Each voxel keeps a sum and a count and outputs
  their average.
- **Threading:** the ARKit delegate runs on main. A serial `DispatchQueue` owns
  the voxel grid. Check the `isBusy` backpressure flag *before* keyframe
  selection. UI and `@Observable` state change only on main (dispatch back
  from inside the worker closure, via `defer`).
- **Performance:** Debug builds are about 4× slower than Release, and Thread
  Sanitizer is slower still. Measure in Release.

## What's been done

Curriculum stages, all working on device in the original `ContentView.swift`:

0. Xcode project setup, signing, camera permission, `.gitignore`.
1. ARKit session and camera feed (`ARView` in a `UIViewRepresentable`).
2. Reading `sceneDepth` (the depth map and confidence map).
3. Unprojecting depth pixels into camera-space 3D points.
   - 3b. ASCII PLY export to the app's Documents folder (visible in the Files
     app).
4. Transforming points into world space with the camera pose.
5. Keyframe selection, voxel-grid downsampling and averaging, and moving frame
   processing onto a background queue.

**The readability refactor (in progress).** The goal is to break the monolith
into small, unit-tested types:

| Type | Status | Notes |
|---|---|---|
| `DepthFrame` (+ `Intrinsics`) | ✅ done, 6 tests | Copies depth and confidence out of the pixel buffers; `worldPoints()` filters, unprojects and transforms |
| `VoxelGrid` | ✅ done, 11 tests | Private `VoxelState`; `insert(_:)`, `count`, `cloud` |
| `PLYWriter` | ✅ done, 4 tests | Caseless enum namespace: `serialize`, `write(_:to:)`, `newPLYPath()` |
| `KeyFrameSelector` | ✅ code committed; 🚧 tests | Struct; `mutating isKeyFrame(transform:)`, `reset()`, `private(set)` state, thresholds with defaults; the first frame is accepted |

## What's planned

### Finish the refactor
1. **`KeyFrameSelectorTests`.** One translation test exists. Still to add:
   1 cm rejected; 3 cm then 6 cm cumulative accepted; 15° accepted and 5°
   rejected (units); 355° rejected (double cover); the same non-identity
   transform twice (true then false); `reset()` behaves like a fresh selector.
2. **`ScanWorker`.** Owns the serial queue and a `private` `VoxelGrid`, which
   is touched only on that queue.
3. **`ScanController`.** Main thread, `@Observable`. Owns the
   `KeyFrameSelector` and a `ScanPhase` enum (`idle` / `scanning` /
   `saving`), and coordinates the worker and saving.
4. **Slim down `ARViewContainer` / `Coordinator` and `ContentView`** so they
   just forward frames and render UI.
5. **Switch the app over** to `DepthFrame` → `VoxelGrid` → `PLYWriter`, delete
   the old code and verify on the phone.
6. Commit each piece. Fragile test indices in `PLYWriterTests` (`lines[2]`,
   `idx + 7`) should become helpers before the header changes.

### Then: color (RGBD)
- Sample `capturedImage` (YCbCr, bi-planar) at each depth pixel using the 7.5×
  mapping, and convert to RGB.
- Store color sums in `VoxelState` and average them per voxel.
- Add `red`/`green`/`blue` `uchar` properties to the PLY output (and update the
  tests).

### Later / optional
- swift-format for consistent style.
- Better error handling in `ScanWorker` (failed saves currently lose data).
- Performance: fuse passes and add binary PLY output.
- Further reconstruction topics as interest allows (e.g. visualization in the
  app, meshing, better fusion).
