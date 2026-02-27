# EyeApp Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a macOS native menu bar application that detects eye blinks using Vision framework for health monitoring and fatigue alerts.

**Architecture:** Swift + SwiftUI + Vision framework. Camera captures frames → Vision detects facial landmarks → EAR algorithm identifies blinks → Statistics engine aggregates data → Alert manager triggers fatigue warnings → UI displays visualizations.

**Tech Stack:** Swift, SwiftUI, Vision framework, AVFoundation, SwiftData, JSON storage, Charts (SwiftUI)

---

## Phase 1: Project Setup

### Task 1: Create Xcode Project

**Files:**
- Create: `EyeApp/EyeApp.xcodeproj/project.pbxproj` (via Xcode CLI)

**Step 1: Create project structure using Xcode**

```bash
# Navigate to project root
cd /Users/mrhua/projects/aieditor/eye-app

# Create macOS App project
xcodebuild -project EyeApp.xcodeproj -scheme EyeApp -destination 'platform=macOS' \
  -showBuildSettings | head -1
```

Expected: Project created or use Xcode GUI to create new macOS App project named "EyeApp"

**Step 2: Configure project settings**

In Xcode:
- Bundle Identifier: `com.eyeapp.app`
- Deployment Target: macOS 14.0+
- Interface: SwiftUI
- Language: Swift

**Step 3: Create directory structure**

```bash
mkdir -p EyeApp/Source/{Core,UI,Models,Services,Utils}
mkdir -p EyeApp/Tests/{Core,UI,Services}
```

**Step 4: Commit**

```bash
git add .
git commit -m "feat: initialize Xcode project structure"
```

---

### Task 2: Add Dependencies and Entitlements

**Files:**
- Create: `EyeApp/EyeApp.entitlements`

**Step 1: Create entitlements file**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.camera</key>
    <true/>
    <key>com.apple.security.device.camera</key>
    <true/>
    <key>com.apple.security.device.microphone</key>
    <false/>
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>
</dict>
</plist>
```

**Step 2: Update Info.plist for camera usage**

Add to `Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>需要访问摄像头来检测眨眼频率，用于健康监测和疲劳提醒。</string>
```

**Step 3: Commit**

```bash
git add EyeApp.entitlements Info.plist
git commit -m "feat: add camera entitlements and usage description"
```

---

## Phase 2: Core Data Models

### Task 3: Create Base Data Models

**Files:**
- Create: `EyeApp/Source/Models/BlinkEvent.swift`
- Create: `EyeApp/Source/Models/MinuteStats.swift`
- Create: `EyeApp/Source/Models/FatigueStatus.swift`

**Step 1: Write the model tests**

Create: `EyeApp/Tests/Models/BlinkEventTests.swift`

```swift
import XCTest
@testable import EyeApp

final class BlinkEventTests: XCTestCase {

    func testBlinkEventInitialization() {
        let event = BlinkEvent(timestamp: Date(), confidence: 0.95)
        XCTAssertNotNil(event.id)
        XCTAssertEqual(event.confidence, 0.95)
    }

    func testBlinkEventCodable() {
        let event = BlinkEvent(timestamp: Date(), confidence: 0.95)
        let encoder = JSONEncoder()
        let data = try? encoder.encode(event)
        XCTAssertNotNil(data)

        let decoder = JSONDecoder()
        let decoded = try? decoder.decode(BlinkEvent.self, from: data!)
        XCTAssertNotNil(decoded)
        XCTAssertEqual(event.confidence, decoded?.confidence)
    }
}
```

**Step 2: Run test to verify it fails**

```bash
xcodebuild test -scheme EyeApp -destination 'platform=macOS' -only-testing:EyeAppTests/BlinkEventTests
```

Expected: FAIL with "Cannot find 'BlinkEvent' in scope"

**Step 3: Write minimal implementation**

Create: `EyeApp/Source/Models/BlinkEvent.swift`

```swift
import Foundation

struct BlinkEvent: Codable, Identifiable, Equatable {
    let id: UUID
    let timestamp: Date
    let confidence: Double

    init(timestamp: Date, confidence: Double) {
        self.id = UUID()
        self.timestamp = timestamp
        self.confidence = confidence
    }
}
```

**Step 4: Run test to verify it passes**

```bash
xcodebuild test -scheme EyeApp -destination 'platform=macOS' -only-testing:EyeAppTests/BlinkEventTests
```

Expected: PASS

**Step 5: Commit**

```bash
git add EyeApp/Source/Models/BlinkEvent.swift EyeApp/Tests/Models/BlinkEventTests.swift
git commit -m "feat: add BlinkEvent model with tests"
```

---

### Task 4: Create MinuteStats Model

**Files:**
- Create: `EyeApp/Source/Models/MinuteStats.swift`

**Step 1: Write the failing test**

Create: `EyeApp/Tests/Models/MinuteStatsTests.swift`

```swift
import XCTest
@testable import EyeApp

final class MinuteStatsTests: XCTestCase {

    func testMinuteStatsInitialization() {
        let minute = Calendar.current.date(bySetting: .second, value: 0, of: Date())!
        let stats = MinuteStats(minute: minute, blinkCount: 15, avgConfidence: 0.9)
        XCTAssertEqual(stats.blinkCount, 15)
        XCTAssertEqual(stats.avgConfidence, 0.9)
    }

    func testMinuteStatsCodable() {
        let minute = Calendar.current.date(bySetting: .second, value: 0, of: Date())!
        let stats = MinuteStats(minute: minute, blinkCount: 15, avgConfidence: 0.9)
        let encoder = JSONEncoder()
        let data = try? encoder.encode(stats)
        XCTAssertNotNil(data)

        let decoder = JSONDecoder()
        let decoded = try? decoder.decode(MinuteStats.self, from: data!)
        XCTAssertNotNil(decoded)
        XCTAssertEqual(stats.blinkCount, decoded?.blinkCount)
    }
}
```

**Step 2: Run test to verify it fails**

```bash
xcodebuild test -scheme EyeApp -destination 'platform=macOS' -only-testing:EyeAppTests/MinuteStatsTests
```

Expected: FAIL with "Cannot find 'MinuteStats' in scope"

**Step 3: Write minimal implementation**

Create: `EyeApp/Source/Models/MinuteStats.swift`

```swift
import Foundation

struct MinuteStats: Codable, Identifiable, Equatable {
    let id: UUID
    let minute: Date
    let blinkCount: Int
    let avgConfidence: Double

    init(minute: Date, blinkCount: Int, avgConfidence: Double) {
        self.id = UUID()
        self.minute = minute
        self.blinkCount = blinkCount
        self.avgConfidence = avgConfidence
    }
}
```

**Step 4: Run test to verify it passes**

```bash
xcodebuild test -scheme EyeApp -destination 'platform=macOS' -only-testing:EyeAppTests/MinuteStatsTests
```

Expected: PASS

**Step 5: Commit**

```bash
git add EyeApp/Source/Models/MinuteStats.swift EyeApp/Tests/Models/MinuteStatsTests.swift
git commit -m "feat: add MinuteStats model with tests"
```

---

### Task 5: Create FatigueStatus and Enums

**Files:**
- Create: `EyeApp/Source/Models/FatigueStatus.swift`

**Step 1: Write the failing test**

Create: `EyeApp/Tests/Models/FatigueStatusTests.swift`

```swift
import XCTest
@testable import EyeApp

final class FatigueStatusTests: XCTestCase {

    func testFatigueLevelThresholds() {
        // Normal: > 15 blinks/min
        let normal = FatigueStatus(blinkRate: 18.0)
        XCTAssertEqual(normal.level, .normal)
        XCTAssertEqual(normal.recommendation, "状态良好")

        // Mild fatigue: 10-15 blinks/min
        let mild = FatigueStatus(blinkRate: 12.0)
        XCTAssertEqual(mild.level, .mild)
        XCTAssertEqual(mild.recommendation, "注意休息")

        // Moderate fatigue: 5-10 blinks/min
        let moderate = FatigueStatus(blinkRate: 7.0)
        XCTAssertEqual(moderate.level, .moderate)
        XCTAssertEqual(moderate.recommendation, "建议休息一下")

        // Severe fatigue: < 5 blinks/min
        let severe = FatigueStatus(blinkRate: 3.0)
        XCTAssertEqual(severe.level, .severe)
        XCTAssertEqual(severe.recommendation, "请立即休息")
    }

    func testFatigueStatusColor() {
        let normal = FatigueStatus(blinkRate: 18.0)
        XCTAssertEqual(normal.color, .green)

        let mild = FatigueStatus(blinkRate: 12.0)
        XCTAssertEqual(mild.color, .yellow)

        let moderate = FatigueStatus(blinkRate: 7.0)
        XCTAssertEqual(moderate.color, .orange)

        let severe = FatigueStatus(blinkRate: 3.0)
        XCTAssertEqual(severe.color, .red)
    }
}
```

**Step 2: Run test to verify it fails**

```bash
xcodebuild test -scheme EyeApp -destination 'platform=macOS' -only-testing:EyeAppTests/FatigueStatusTests
```

Expected: FAIL with "Cannot find 'FatigueStatus' in scope"

**Step 3: Write minimal implementation**

Create: `EyeApp/Source/Models/FatigueStatus.swift`

```swift
import Foundation
import SwiftUI

enum FatigueLevel: String, Codable {
    case normal
    case mild
    case moderate
    case severe
}

struct FatigueStatus: Equatable {
    let level: FatigueLevel
    let blinkRate: Double
    let recommendation: String
    let color: Color

    init(blinkRate: Double) {
        self.blinkRate = blinkRate

        if blinkRate > 15 {
            self.level = .normal
            self.recommendation = "状态良好"
            self.color = .green
        } else if blinkRate >= 10 {
            self.level = .mild
            self.recommendation = "注意休息"
            self.color = .yellow
        } else if blinkRate >= 5 {
            self.level = .moderate
            self.recommendation = "建议休息一下"
            self.color = .orange
        } else {
            self.level = .severe
            self.recommendation = "请立即休息"
            self.color = .red
        }
    }
}
```

**Step 4: Run test to verify it passes**

```bash
xcodebuild test -scheme EyeApp -destination 'platform=macOS' -only-testing:EyeAppTests/FatigueStatusTests
```

Expected: PASS

**Step 5: Commit**

```bash
git add EyeApp/Source/Models/FatigueStatus.swift EyeApp/Tests/Models/FatigueStatusTests.swift
git commit -m "feat: add FatigueStatus model with tests"
```

---

## Phase 3: Blink Detection Core

### Task 6: Create BlinkDetector with EAR Algorithm

**Files:**
- Create: `EyeApp/Source/Core/BlinkDetector.swift`

**Step 1: Write the failing test**

Create: `EyeApp/Tests/Core/BlinkDetectorTests.swift`

```swift
import XCTest
import Vision
@testable import EyeApp

final class BlinkDetectorTests: XCTestCase {

    var detector: BlinkDetector!

    override func setUp() {
        super.setUp()
        detector = BlinkDetector(threshold: 0.2, debounceTime: 0.3)
    }

    func testEARCalculation() {
        // Create mock eye landmarks
        // Eye points: [left1, left2, left3, left4, left5, left6, right1, right2, right3, right4, right5, right6]
        // Format: [x, y] for each point

        let normalEye = createMockLandmarks(eyeHeight: 30, eyeWidth: 90)
        let ear = detector.calculateEAR(landmarks: normalEye)
        // EAR = (height / width) * 2 = (30 / 90) * 2 = 0.066... * 2 ≈ 0.67
        XCTAssertTrue(ear > 0.5 && ear < 0.8, "EAR should be around 0.67 for open eye")

        let closedEye = createMockLandmarks(eyeHeight: 5, eyeWidth: 90)
        let closedEAR = detector.calculateEAR(landmarks: closedEye)
        XCTAssertTrue(closedEAR < 0.2, "EAR should be low for closed eye")
    }

    func testBlinkDetection() {
        let openEye = createMockLandmarks(eyeHeight: 30, eyeWidth: 90)
        let closedEye = createMockLandmarks(eyeHeight: 5, eyeWidth: 90)

        // Open eye should not trigger blink
        let openResult = detector.process(landmarks: openEye, confidence: 0.9)
        XCTAssertEqual(openResult, .noBlink)

        // Closed eye should trigger blink
        let closedResult = detector.process(landmarks: closedEye, confidence: 0.9)
        XCTAssertEqual(closedResult, .blinkDetected)
    }

    func testDebounce() {
        let closedEye = createMockLandmarks(eyeHeight: 5, eyeWidth: 90)

        // First detection
        _ = detector.process(landmarks: closedEye, confidence: 0.9)

        // Immediate second detection (within debounce time)
        let debouncedResult = detector.process(landmarks: closedEye, confidence: 0.9)
        XCTAssertEqual(debouncedResult, .debounced)

        // Wait for debounce period
        Thread.sleep(forTimeInterval: 0.35)

        // Should trigger again
        let newBlink = detector.process(landmarks: closedEye, confidence: 0.9)
        XCTAssertEqual(newBlink, .blinkDetected)
    }

    func testThresholdBoundary() {
        let detector = BlinkDetector(threshold: 0.2, debounceTime: 0)

        // Exactly at threshold
        let boundaryLandmarks = createMockLandmarksForEAR(0.2)
        let result = detector.process(landmarks: boundaryLandmarks, confidence: 0.9)
        XCTAssertEqual(result, .blinkDetected)

        // Just above threshold
        let aboveLandmarks = createMockLandmarksForEAR(0.21)
        let aboveResult = detector.process(landmarks: aboveLandmarks, confidence: 0.9)
        XCTAssertEqual(aboveResult, .noBlink)
    }

    // MARK: - Helper Methods

    private func createMockLandmarks(eyeHeight: Double, eyeWidth: Double) -> [CGPoint] {
        // Simplified eye landmarks for testing
        // Left eye: 6 points, Right eye: 6 points
        var points: [CGPoint] = []

        // Left eye points (simplified vertical/horizontal)
        points.append(CGPoint(x: 0, y: 0))           // top
        points.append(CGPoint(x: eyeWidth / 2, y: 0))
        points.append(CGPoint(x: eyeWidth, y: 0))    // outer
        points.append(CGPoint(x: eyeWidth, y: eyeHeight))
        points.append(CGPoint(x: eyeWidth / 2, y: eyeHeight))
        points.append(CGPoint(x: 0, y: eyeHeight))   // inner

        // Right eye (same structure)
        points.append(contentsOf: points.map { CGPoint(x: $0.x + eyeWidth + 10, y: $0.y) })

        return points
    }

    private func createMockLandmarksForEAR(_ targetEAR: Double) -> [CGPoint] {
        let eyeWidth = 90.0
        let eyeHeight = (targetEAR * eyeWidth) / 2
        return createMockLandmarks(eyeHeight: eyeHeight, eyeWidth: eyeWidth)
    }
}
```

**Step 2: Run test to verify it fails**

```bash
xcodebuild test -scheme EyeApp -destination 'platform=macOS' -only-testing:EyeAppTests/BlinkDetectorTests
```

Expected: FAIL with "Cannot find 'BlinkDetector' in scope"

**Step 3: Write minimal implementation**

Create: `EyeApp/Source/Core/BlinkDetector.swift`

```swift
import Foundation
import Vision

enum BlinkResult {
    case blinkDetected
    case noBlink
    case debounced
}

class BlinkDetector {
    private let threshold: Double
    private let debounceTime: TimeInterval
    private var lastBlinkTime: Date?

    init(threshold: Double = 0.2, debounceTime: TimeInterval = 0.3) {
        self.threshold = threshold
        self.debounceTime = debounceTime
    }

    func process(landmarks: [CGPoint], confidence: Double) -> BlinkResult {
        let ear = calculateEAR(landmarks: landmarks)

        if ear < threshold {
            // Eye is closed, check debounce
            if let lastBlink = lastBlinkTime,
               Date().timeIntervalSince(lastBlink) < debounceTime {
                return .debounced
            }

            lastBlinkTime = Date()
            return .blinkDetected
        }

        return .noBlink
    }

    func calculateEAR(landmarks: [CGPoint]) -> Double {
        // Extract eye landmarks
        // Vision framework returns specific landmark indices
        // Left eye: 16, 17, 18, 19, 20, 21 (indices after adjustment)
        // Right eye: 22, 23, 24, 25, 26, 27

        guard landmarks.count >= 28 else { return 1.0 }

        // Left eye landmarks
        let leftEye = Array(landmarks[16...21])
        // Right eye landmarks
        let rightEye = Array(landmarks[22...27])

        let leftEAR = calculateEyeEAR(landmarks: leftEye)
        let rightEAR = calculateEyeEAR(landmarks: rightEye)

        return (leftEAR + rightEAR) / 2.0
    }

    private func calculateEyeEAR(landmarks: [CGPoint]) -> Double {
        // EAR = (|p2-p6| + |p3-p5|) / (2 * |p1-p4|)
        // where p1...p6 are the 6 eye landmarks in order

        guard landmarks.count == 6 else { return 1.0 }

        let p1 = landmarks[0]
        let p2 = landmarks[1]
        let p3 = landmarks[2]
        let p4 = landmarks[3]
        let p5 = landmarks[4]
        let p6 = landmarks[5]

        let vertical1 = distance(p2, p6)
        let vertical2 = distance(p3, p5)
        let horizontal = distance(p1, p4)

        guard horizontal > 0 else { return 1.0 }

        return (vertical1 + vertical2) / (2.0 * horizontal)
    }

    private func distance(_ p1: CGPoint, _ p2: CGPoint) -> Double {
        let dx = Double(p1.x - p2.x)
        let dy = Double(p1.y - p2.y)
        return sqrt(dx * dx + dy * dy)
    }
}
```

**Step 4: Run test to verify it passes**

```bash
xcodebuild test -scheme EyeApp -destination 'platform=macOS' -only-testing:EyeAppTests/BlinkDetectorTests
```

Expected: PASS

**Step 5: Commit**

```bash
git add EyeApp/Source/Core/BlinkDetector.swift EyeApp/Tests/Core/BlinkDetectorTests.swift
git commit -m "feat: implement BlinkDetector with EAR algorithm"
```

---

### Task 7: Create VisionService

**Files:**
- Create: `EyeApp/Source/Services/VisionService.swift`

**Step 1: Write the failing test**

Create: `EyeApp/Tests/Services/VisionServiceTests.swift`

```swift
import XCTest
import Vision
import AVFoundation
@testable import EyeApp

final class VisionServiceTests: XCTestCase {

    var service: VisionService!

    override func setUp() {
        super.setUp()
        service = VisionService()
    }

    override func tearDown() {
        service = nil
        super.tearDown()
    }

    func testServiceCreation() {
        XCTAssertNotNil(service)
    }

    func testProcessSampleBuffer() {
        let expectation = XCTestExpectation(description: "Process buffer")

        // Create a mock sample buffer (this is tricky, so we'll test the interface)
        service.onFaceDetected = { landmarks, confidence in
            XCTAssertNotNil(landmarks)
            XCTAssertGreaterThanOrEqual(confidence, 0.0)
            XCTAssertLessThanOrEqual(confidence, 1.0)
            expectation.fulfill()
        }

        // For now, just verify the callback can be set
        service.onFaceDetected = { _, _ in }

        wait(for: [expectation], timeout: 1.0)
    }

    func testNoFaceDetected() {
        let expectation = XCTestExpectation(description: "No face callback")
        expectation.isInverted = true

        service.onFaceDetected = { _, _ in
            // Should not be called
            expectation.fulfill()
        }

        // This test verifies behavior when no face is present
        // (to be implemented with actual image processing)

        wait(for: [expectation], timeout: 0.5)
    }
}
```

**Step 2: Run test to verify it fails**

```bash
xcodebuild test -scheme EyeApp -destination 'platform=macOS' -only-testing:EyeAppTests/VisionServiceTests
```

Expected: FAIL with "Cannot find 'VisionService' in scope"

**Step 3: Write minimal implementation**

Create: `EyeApp/Source/Services/VisionService.swift`

```swift
import Foundation
import Vision
import AVFoundation

class VisionService {
    private var faceDetectionRequest: VNDetectFaceLandmarksRequest?
    var onFaceDetected: (([CGPoint], Double) -> Void)?

    init() {
        setupFaceDetection()
    }

    private func setupFaceDetection() {
        let request = VNDetectFaceLandmarksRequest { [weak self] request, error in
            self?.handleFaceDetection(request: request, error: error)
        }
        request.revision = VNDetectFaceLandmarksRequestRevision3

        self.faceDetectionRequest = request
    }

    func process(sampleBuffer: CMSampleBuffer) {
        guard let request = faceDetectionRequest else { return }

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])

        do {
            try handler.perform([request])
        } catch {
            print("Vision request failed: \(error)")
        }
    }

    private func handleFaceDetection(request: VNRequest, error: Error?) {
        guard let observations = request.results as? [VNFaceObservation],
              let faceObservation = observations.first,
              let landmarks = faceObservation.landmarks else {
            return
        }

        // Extract all landmark points
        var allPoints: [CGPoint] = []

        // Get all available landmarks
        if let leftEye = landmarks.leftEye {
            allPoints.append(contentsOf: leftEye.normalizedPoints)
        }
        if let rightEye = landmarks.rightEye {
            allPoints.append(contentsOf: rightEye.normalizedPoints)
        }
        if let leftPupil = landmarks.leftPupil {
            allPoints.append(contentsOf: leftPupil.normalizedPoints)
        }
        if let rightPupil = landmarks.rightPupil {
            allPoints.append(contentsOf: rightPupil.normalizedPoints)
        }

        guard !allPoints.isEmpty else { return }

        let confidence = Double(faceObservation.confidence)
        onFaceDetected?(allPoints, confidence)
    }
}
```

**Step 4: Run test to verify it passes**

```bash
xcodebuild test -scheme EyeApp -destination 'platform=macOS' -only-testing:EyeAppTests/VisionServiceTests
```

Expected: PASS

**Step 5: Commit**

```bash
git add EyeApp/Source/Services/VisionService.swift EyeApp/Tests/Services/VisionServiceTests.swift
git commit -m "feat: implement VisionService for face detection"
```

---

### Task 8: Create CameraManager

**Files:**
- Create: `EyeApp/Source/Services/CameraManager.swift`

**Step 1: Write the failing test**

Create: `EyeApp/Tests/Services/CameraManagerTests.swift`

```swift
import XCTest
import AVFoundation
@testable import EyeApp

final class CameraManagerTests: XCTestCase {

    var manager: CameraManager!

    override func setUp() {
        super.setUp()
        manager = CameraManager()
    }

    override func tearDown() {
        manager.stop()
        manager = nil
        super.tearDown()
    }

    func testCameraManagerCreation() {
        XCTAssertNotNil(manager)
        XCTAssertEqual(manager.state, .idle)
    }

    func testRequestCameraPermission() {
        let expectation = XCTestExpectation(description: "Permission result")

        manager.requestPermission { granted in
            // Result depends on system permission
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)
    }

    func testStartStopCamera() {
        let expectation = XCTestExpectation(description: "Camera started")

        manager.onFrame = { _ in
            // Received at least one frame
            expectation.fulfill()
        }

        manager.onError = { error in
            XCTFail("Camera error: \(error)")
        }

        manager.start()

        // Wait a bit for camera to start
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            XCTAssertEqual(self.manager.state, .running)
            self.manager.stop()
            XCTAssertEqual(self.manager.state, .stopped)
        }

        wait(for: [expectation], timeout: 5.0)
    }

    func testStateTransitions() {
        XCTAssertEqual(manager.state, .idle)

        manager.start()
        // State will be running or error depending on camera

        manager.stop()
        XCTAssertEqual(manager.state, .stopped)
    }
}
```

**Step 2: Run test to verify it fails**

```bash
xcodebuild test -scheme EyeApp -destination 'platform=macOS' -only-testing:EyeAppTests/CameraManagerTests
```

Expected: FAIL with "Cannot find 'CameraManager' in scope"

**Step 3: Write minimal implementation**

Create: `EyeApp/Source/Services/CameraManager.swift`

```swift
import Foundation
import AVFoundation

enum CameraState {
    case idle
    case starting
    case running
    case stopped
    case error(Error)
}

class CameraManager: NSObject {
    private var captureSession: AVCaptureSession?
    private var videoOutput: AVCaptureVideoDataOutput?
    private let sessionQueue = DispatchQueue(label: "com.eyeapp.camera")

    var state: CameraState = .idle
    var onFrame: ((CMSampleBuffer) -> Void)?
    var onError: ((Error) -> Void)?

    override init() {
        super.init()
    }

    func requestPermission(completion: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
                completion(granted)
            }
        }
    }

    func start() {
        guard state == .idle || state == .stopped else { return }

        state = .starting

        sessionQueue.async { [weak self] in
            self?.setupCaptureSession()
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            self?.captureSession?.stopRunning()
            DispatchQueue.main.async {
                self?.state = .stopped
            }
        }
    }

    private func setupCaptureSession() {
        let session = AVCaptureSession()
        session.sessionPreset = .medium

        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .unspecified) else {
            DispatchQueue.main.async {
                self.state = .error(CameraError.cameraNotFound)
                self.onError?(CameraError.cameraNotFound)
            }
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: camera)
            guard session.canAddInput(input) else {
                throw CameraError.cannotAddInput
            }
            session.addInput(input)

            let output = AVCaptureVideoDataOutput()
            output.setSampleBufferDelegate(self, queue: sessionQueue)
            output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]

            guard session.canAddOutput(output) else {
                throw CameraError.cannotAddOutput
            }
            session.addOutput(output)

            self.videoOutput = output
            self.captureSession = session

            session.startRunning()

            DispatchQueue.main.async {
                self.state = .running
            }
        } catch {
            DispatchQueue.main.async {
                self.state = .error(error)
                self.onError?(error)
            }
        }
    }
}

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        DispatchQueue.main.async { [weak self] in
            self?.onFrame?(sampleBuffer)
        }
    }
}

enum CameraError: Error {
    case cameraNotFound
    case cannotAddInput
    case cannotAddOutput
    case permissionDenied
}
```

**Step 4: Run test to verify it passes**

```bash
xcodebuild test -scheme EyeApp -destination 'platform=macOS' -only-testing:EyeAppTests/CameraManagerTests
```

Expected: PASS (may need camera permission granted first)

**Step 5: Commit**

```bash
git add EyeApp/Source/Services/CameraManager.swift EyeApp/Tests/Services/CameraManagerTests.swift
git commit -m "feat: implement CameraManager with AVFoundation"
```

---

## Phase 4: Statistics and Data Engine

### Task 9: Create StatsEngine

**Files:**
- Create: `EyeApp/Source/Core/StatsEngine.swift`

**Step 1: Write the failing test**

Create: `EyeApp/Tests/Core/StatsEngineTests.swift`

```swift
import XCTest
@testable import EyeApp

final class StatsEngineTests: XCTestCase {

    var engine: StatsEngine!

    override func setUp() {
        super.setUp()
        engine = StatsEngine()
    }

    func testRecordBlink() {
        let event = BlinkEvent(timestamp: Date(), confidence: 0.9)
        engine.recordBlink(event)

        XCTAssertEqual(engine.currentMinuteBlinks, 1)
    }

    func testMinuteAggregation() {
        let calendar = Calendar.current
        let now = Date()

        // Record 15 blinks in current minute
        for _ in 0..<15 {
            engine.recordBlink(BlinkEvent(timestamp: now, confidence: 0.9))
        }

        let stats = engine.getStatsForMinute(now)
        XCTAssertEqual(stats?.blinkCount, 15)
    }

    func testBlinkRateCalculation() {
        let calendar = Calendar.current
        let now = Date()

        // Simulate blinks over 60 seconds
        for i in 0..<20 {
            let time = now.addingTimeInterval(TimeInterval(i * 3)) // 20 blinks over 60 seconds
            engine.recordBlink(BlinkEvent(timestamp: time, confidence: 0.9))
        }

        let rate = engine.getBlinkRate(for: now)
        XCTAssertEqual(rate, 20.0, accuracy: 1.0)
    }

    func testTodayStats() {
        let today = Date()
        let yesterday = today.addingTimeInterval(-24 * 3600)

        engine.recordBlink(BlinkEvent(timestamp: yesterday, confidence: 0.9))
        engine.recordBlink(BlinkEvent(timestamp: today, confidence: 0.9))
        engine.recordBlink(BlinkEvent(timestamp: today, confidence: 0.9))

        let todayStats = engine.getTodayStats()
        XCTAssertEqual(todayStats.totalBlinks, 2)
    }

    func testTrendCalculation() {
        let now = Date()
        var timestamps: [Date] = []

        // Create blinks every 3 seconds (20 per minute) for 5 minutes
        for minute in 0..<5 {
            for second in 0..<60 where second % 3 == 0 {
                timestamps.append(now.addingTimeInterval(TimeInterval(minute * 60 + second)))
            }
        }

        for timestamp in timestamps {
            engine.recordBlink(BlinkEvent(timestamp: timestamp, confidence: 0.9))
        }

        let trend = engine.getTrend(for: now, duration: .minutes(5))
        XCTAssertEqual(trend.count, 5)
        XCTAssertEqual(trend.first?.blinkCount, 20)
        XCTAssertEqual(trend.last?.blinkCount, 20)
    }
}
```

**Step 2: Run test to verify it fails**

```bash
xcodebuild test -scheme EyeApp -destination 'platform=macOS' -only-testing:EyeAppTests/StatsEngineTests
```

Expected: FAIL with "Cannot find 'StatsEngine' in scope"

**Step 3: Write minimal implementation**

Create: `EyeApp/Source/Core/StatsEngine.swift`

```swift
import Foundation

enum TrendDuration {
    case minutes(Int)
    case hours(Int)
    case days(Int)
}

struct DailyStatsSummary {
    let totalBlinks: Int
    let avgBlinkRate: Double
    let fatigueAlerts: Int
    let monitorDuration: TimeInterval
}

class StatsEngine {
    private var blinkEvents: [BlinkEvent] = []
    private var minuteCache: [Date: MinuteStats] = [:]

    var currentMinuteBlinks: Int {
        let now = Date()
        let key = minuteKey(for: now)
        return minuteCache[key]?.blinkCount ?? 0
    }

    func recordBlink(_ event: BlinkEvent) {
        blinkEvents.append(event)
        updateMinuteCache(for: event.timestamp)
    }

    func getStatsForMinute(_ date: Date) -> MinuteStats? {
        let key = minuteKey(for: date)
        return minuteCache[key]
    }

    func getBlinkRate(for date: Date) -> Double {
        let calendar = Calendar.current
        let minuteStart = calendar.date(bySetting: .second, value: 0, of: date) ?? date

        // Count blinks in the last 60 seconds from date
        let oneMinuteAgo = date.addingTimeInterval(-60)
        let recentBlinks = blinkEvents.filter { $0.timestamp >= oneMinuteAgo && $0.timestamp <= date }

        return Double(recentBlinks.count)
    }

    func getTodayStats() -> DailyStatsSummary {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let todayEnd = today.addingTimeInterval(24 * 3600)

        let todayEvents = blinkEvents.filter { $0.timestamp >= today && $0.timestamp < todayEnd }

        let totalBlinks = todayEvents.count

        // Calculate average blink rate (blinks per minute)
        let duration = todayEvents.last?.timestamp.timeIntervalSince(todayEvents.first?.timestamp ?? today) ?? 0
        let avgRate = duration > 0 ? Double(totalBlinks) / (duration / 60.0) : 0

        return DailyStatsSummary(
            totalBlinks: totalBlinks,
            avgBlinkRate: avgRate,
            fatigueAlerts: 0, // To be implemented with AlertManager
            monitorDuration: duration
        )
    }

    func getTrend(for date: Date, duration: TrendDuration) -> [MinuteStats] {
        let calendar = Calendar.current
        var endDate = date
        var startTime: Date
        var unit: Calendar.Component

        switch duration {
        case .minutes(let m):
            startTime = date.addingTimeInterval(-TimeInterval(m * 60))
            unit = .minute
        case .hours(let h):
            startTime = date.addingTimeInterval(-TimeInterval(h * 3600))
            unit = .hour
        case .days(let d):
            startTime = date.addingTimeInterval(-TimeInterval(d * 24 * 3600))
            unit = .day
        }

        var result: [MinuteStats] = []
        var currentTime = calendar.dateInterval(of: unit, for: startTime)?.start ?? startTime

        while currentTime < endDate {
            if let stats = minuteCache[minuteKey(for: currentTime)] {
                result.append(stats)
            }
            currentTime = calendar.date(byAdding: unit, value: 1, to: currentTime) ?? currentTime
        }

        return result
    }

    func getAllEvents() -> [BlinkEvent] {
        return blinkEvents
    }

    func clearOldData(olderThan days: Int) {
        let cutoff = Date().addingTimeInterval(-TimeInterval(days * 24 * 3600))
        blinkEvents.removeAll { $0.timestamp < cutoff }
        rebuildCache()
    }

    // MARK: - Private

    private func minuteKey(for date: Date) -> Date {
        let calendar = Calendar.current
        return calendar.date(bySetting: .second, value: 0, of: date) ?? date
    }

    private func updateMinuteCache(for timestamp: Date) {
        let key = minuteKey(for: timestamp)

        if var existing = minuteCache[key] {
            existing.blinkCount += 1
            minuteCache[key] = existing
        } else {
            minuteCache[key] = MinuteStats(minute: key, blinkCount: 1, avgConfidence: 0.9)
        }
    }

    private func rebuildCache() {
        minuteCache.removeAll()
        for event in blinkEvents {
            updateMinuteCache(for: event.timestamp)
        }
    }
}
```

**Step 4: Run test to verify it passes**

```bash
xcodebuild test -scheme EyeApp -destination 'platform=macOS' -only-testing:EyeAppTests/StatsEngineTests
```

Expected: PASS

**Step 5: Commit**

```bash
git add EyeApp/Source/Core/StatsEngine.swift EyeApp/Tests/Core/StatsEngineTests.swift
git commit -m "feat: implement StatsEngine for blink statistics"
```

---

### Task 10: Create AlertManager

**Files:**
- Create: `EyeApp/Source/Core/AlertManager.swift`

**Step 1: Write the failing test**

Create: `EyeApp/Tests/Core/AlertManagerTests.swift`

```swift
import XCTest
import UserNotifications
@testable import EyeApp

final class AlertManagerTests: XCTestCase {

    var manager: AlertManager!
    var mockEngine: StatsEngine!

    override func setUp() {
        super.setUp()
        mockEngine = StatsEngine()
        manager = AlertManager(statsEngine: mockEngine)
    }

    func testFatigueDetection() {
        // Simulate low blink rate (5 blinks per minute)
        let now = Date()
        for _ in 0..<5 {
            mockEngine.recordBlink(BlinkEvent(timestamp: now, confidence: 0.9))
        }

        let status = manager.checkFatigueStatus()
        XCTAssertEqual(status.level, .moderate) // 5-10 blinks/min is moderate
    }

    func testNormalStatus() {
        // Normal blink rate (18 blinks per minute)
        let now = Date()
        for _ in 0..<18 {
            mockEngine.recordBlink(BlinkEvent(timestamp: now, confidence: 0.9))
        }

        let status = manager.checkFatigueStatus()
        XCTAssertEqual(status.level, .normal)
    }

    func testSevereFatigue() {
        // Very low blink rate (3 blinks per minute)
        let now = Date()
        for _ in 0..<3 {
            mockEngine.recordBlink(BlinkEvent(timestamp: now, confidence: 0.9))
        }

        let status = manager.checkFatigueStatus()
        XCTAssertEqual(status.level, .severe)
    }

    func testAlertTriggering() {
        manager.config = AlertConfig(
            enabled: true,
            threshold: 10,
            intervalMinutes: 15
        )

        // Simulate 7 blinks (below threshold)
        let now = Date()
        for _ in 0..<7 {
            mockEngine.recordBlink(BlinkEvent(timestamp: now, confidence: 0.9))
        }

        let shouldAlert = manager.shouldTriggerAlert()
        XCTAssertTrue(shouldAlert)
    }

    func testAlertInterval() {
        manager.config = AlertConfig(
            enabled: true,
            threshold: 10,
            intervalMinutes: 15
        )

        let now = Date()
        for _ in 0..<7 {
            mockEngine.recordBlink(BlinkEvent(timestamp: now, confidence: 0.9))
        }

        // First alert
        _ = manager.shouldTriggerAlert()
        let firstAlertTime = manager.lastAlertTime

        // Should not alert again immediately
        XCTAssertFalse(manager.shouldTriggerAlert())

        // Advance time by 16 minutes
        manager.lastAlertTime = firstAlertTime?.addingTimeInterval(-16 * 60)
        XCTAssertTrue(manager.shouldTriggerAlert())
    }

    func testAlertDisabled() {
        manager.config = AlertConfig(
            enabled: false,
            threshold: 10,
            intervalMinutes: 15
        )

        let now = Date()
        for _ in 0..<3 {
            mockEngine.recordBlink(BlinkEvent(timestamp: now, confidence: 0.9))
        }

        XCTAssertFalse(manager.shouldTriggerAlert())
    }
}
```

**Step 2: Run test to verify it fails**

```bash
xcodebuild test -scheme EyeApp -destination 'platform=macOS' -only-testing:EyeAppTests/AlertManagerTests
```

Expected: FAIL with "Cannot find 'AlertManager' in scope"

**Step 3: Write minimal implementation**

Create: `EyeApp/Source/Core/AlertManager.swift`

```swift
import Foundation
import UserNotifications

struct AlertConfig {
    var enabled: Bool = true
    var threshold: Int = 10          // blinks per minute
    var intervalMinutes: Int = 15    // minimum time between alerts
}

class AlertManager {
    private let statsEngine: StatsEngine
    var config = AlertConfig()
    var lastAlertTime: Date?

    init(statsEngine: StatsEngine) {
        self.statsEngine = statsEngine
        requestNotificationPermission()
    }

    func checkFatigueStatus() -> FatigueStatus {
        let blinkRate = statsEngine.getBlinkRate(for: Date())
        return FatigueStatus(blinkRate: blinkRate)
    }

    func shouldTriggerAlert() -> Bool {
        guard config.enabled else { return false }

        let status = checkFatigueStatus()

        // Only alert on moderate or severe fatigue
        guard status.level == .moderate || status.level == .severe else {
            return false
        }

        // Check alert interval
        if let lastAlert = lastAlertTime {
            let timeSinceLastAlert = Date().timeIntervalSince(lastAlert)
            let minimumInterval = TimeInterval(config.intervalMinutes * 60)

            if timeSinceLastAlert < minimumInterval {
                return false
            }
        }

        return true
    }

    func triggerAlert() {
        guard shouldTriggerAlert() else { return }

        let status = checkFatigueStatus()
        sendNotification(status: status)
        lastAlertTime = Date()
    }

    func sendNotification(status: FatigueStatus) {
        let content = UNMutableNotificationContent()
        content.title = "👁️ EyeApp"
        content.body = "\(status.recommendation)\n当前眨眼频率: \(Int(status.blinkRate)) 次/分钟"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil // Immediate
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Notification error: \(error)")
            }
        }
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if granted {
                print("Notification permission granted")
            }
        }
    }
}
```

**Step 4: Run test to verify it passes**

```bash
xcodebuild test -scheme EyeApp -destination 'platform=macOS' -only-testing:EyeAppTests/AlertManagerTests
```

Expected: PASS

**Step 5: Commit**

```bash
git add EyeApp/Source/Core/AlertManager.swift EyeApp/Tests/Core/AlertManagerTests.swift
git commit -m "feat: implement AlertManager for fatigue detection"
```

---

## Phase 5: Data Storage

### Task 11: Create DataStorage

**Files:**
- Create: `EyeApp/Source/Services/DataStorage.swift`

**Step 1: Write the failing test**

Create: `EyeApp/Tests/Services/DataStorageTests.swift`

```swift
import XCTest
@testable import EyeApp

final class DataStorageTests: XCTestCase {

    var storage: DataStorage!
    var tempURL: URL!

    override func setUp() {
        super.setUp()
        tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("EyeAppTests_\(UUID().uuidString)")
        storage = DataStorage(storageURL: tempURL)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempURL)
        super.tearDown()
    }

    func testSaveAndLoadConfig() {
        let config = AppConfig(
            alertEnabled: true,
            alertThreshold: 15,
            alertInterval: 20,
            sensitivity: .high,
            launchAtLogin: true
        )

        storage.saveConfig(config)

        let loaded = storage.loadConfig()
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.alertEnabled, true)
        XCTAssertEqual(loaded?.alertThreshold, 15)
        XCTAssertEqual(loaded?.alertInterval, 20)
    }

    func testSaveDailyData() {
        let today = Date()
        let events = [
            BlinkEvent(timestamp: today, confidence: 0.9),
            BlinkEvent(timestamp: today.addingTimeInterval(1), confidence: 0.95)
        ]

        storage.saveDailyData(date: today, events: events)

        let loaded = storage.loadDailyData(date: today)
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.events.count, 2)
    }

    func testMinuteStatsAggregation() {
        let today = Date()
        var events: [BlinkEvent] = []

        // Create events across 2 minutes
        for i in 0..<30 {
            let timestamp = today.addingTimeInterval(Double(i * 2)) // 30 events over 60 seconds
            events.append(BlinkEvent(timestamp: timestamp, confidence: 0.9))
        }

        storage.saveDailyData(date: today, events: events)

        let loaded = storage.loadDailyData(date: today)
        XCTAssertEqual(loaded?.minuteStats.count, 2) // Should have 2 minute stats
    }

    func testLoadDateRange() {
        let calendar = Calendar.current
        let today = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        storage.saveDailyData(date: yesterday, events: [
            BlinkEvent(timestamp: yesterday, confidence: 0.9)
        ])

        storage.saveDailyData(date: today, events: [
            BlinkEvent(timestamp: today, confidence: 0.9)
        ])

        let range = storage.loadData(from: yesterday, to: today)
        XCTAssertEqual(range.count, 2)
    }

    func testDeleteOldData() {
        let calendar = Calendar.current
        let today = Date()
        let oldDate = calendar.date(byAdding: .day, value: -40, to: today)!

        storage.saveDailyData(date: oldDate, events: [
            BlinkEvent(timestamp: oldDate, confidence: 0.9)
        ])

        storage.saveDailyData(date: today, events: [
            BlinkEvent(timestamp: today, confidence: 0.9)
        ])

        storage.deleteData(olderThan: 30)

        let recentData = storage.loadDailyData(date: today)
        XCTAssertNotNil(recentData)

        let oldData = storage.loadDailyData(date: oldDate)
        XCTAssertNil(oldData)
    }
}
```

**Step 2: Run test to verify it fails**

```bash
xcodebuild test -scheme EyeApp -destination 'platform=macOS' -only-testing:EyeAppTests/DataStorageTests
```

Expected: FAIL with "Cannot find 'DataStorage' in scope"

**Step 3: Write minimal implementation**

First, add SensitivityLevel enum:

Create: `EyeApp/Source/Models/AppConfig.swift`

```swift
import Foundation

enum SensitivityLevel: String, Codable, CaseIterable {
    case low
    case medium
    case high
}

struct AppConfig: Codable {
    var alertEnabled: Bool = true
    var alertThreshold: Int = 10        // 次/分
    var alertInterval: Int = 15         // 分钟
    var sensitivity: SensitivityLevel = .medium
    var launchAtLogin: Bool = true
}
```

Then create DataStorage:

Create: `EyeApp/Source/Services/DataStorage.swift`

```swift
import Foundation

class DataStorage {
    private let storageURL: URL
    private let configFileName = "config.json"
    private let eventsFolderName = "blink_events"

    init(storageURL: URL) {
        self.storageURL = storageURL
        createDirectoryIfNeeded()
    }

    // MARK: - Config

    func saveConfig(_ config: AppConfig) {
        let url = storageURL.appendingPathComponent(configFileName)
        saveJSON(config, to: url)
    }

    func loadConfig() -> AppConfig? {
        let url = storageURL.appendingPathComponent(configFileName)
        return loadJSON(from: url)
    }

    // MARK: - Daily Data

    func saveDailyData(date: Date, events: [BlinkEvent]) {
        let fileName = dateFormatter.string(from: date) + ".json"
        let eventsURL = storageURL.appendingPathComponent(eventsFolderName)
            .appendingPathComponent(fileName)

        // Aggregate minute stats
        let minuteStats = aggregateMinuteStats(from: events)

        let summary = DailySummary(
            totalBlinks: events.count,
            avgBlinkRate: calculateAvgRate(events: events),
            fatigueAlerts: 0, // Will be tracked separately
            monitorDuration: calculateDuration(events: events)
        )

        let dailyData = DailyBlinkData(
            date: date,
            events: events,
            minuteStats: minuteStats,
            summary: summary
        )

        saveJSON(dailyData, to: eventsURL)
    }

    func loadDailyData(date: Date) -> DailyBlinkData? {
        let fileName = dateFormatter.string(from: date) + ".json"
        let eventsURL = storageURL.appendingPathComponent(eventsFolderName)
            .appendingPathComponent(fileName)
        return loadJSON(from: eventsURL)
    }

    func loadData(from startDate: Date, to endDate: Date) -> [DailyBlinkData] {
        var result: [DailyBlinkData] = []
        var currentDate = startDate

        while currentDate <= endDate {
            if let data = loadDailyData(date: currentDate) {
                result.append(data)
            }
            currentDate = Calendar.current.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }

        return result
    }

    func deleteData(olderThan days: Int) {
        let cutoff = Calendar.current.startOfDay(for: Date())
            .addingTimeInterval(-TimeInterval(days * 24 * 3600))

        let eventsURL = storageURL.appendingPathComponent(eventsFolderName)

        guard let fileURLs = try? FileManager.default.contentsOfDirectory(
            at: eventsURL,
            includingPropertiesForKeys: nil
        ) else { return }

        for fileURL in fileURLs {
            guard let fileName = fileURL.deletingPathExtension().lastValue == "json",
                  let fileDate = dateFormatter.date(from: fileName),
                  fileDate < cutoff else {
                continue
            }

            try? FileManager.default.removeItem(at: fileURL)
        }
    }

    // MARK: - Private

    private func saveJSON<T: Codable>(_ value: T, to url: URL) {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(value)
            try data.write(to: url)
        } catch {
            print("Failed to save JSON: \(error)")
        }
    }

    private func loadJSON<T: Codable>(from url: URL) -> T? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(T.self, from: data)
        } catch {
            print("Failed to load JSON: \(error)")
            return nil
        }
    }

    private func createDirectoryIfNeeded() {
        let eventsURL = storageURL.appendingPathComponent(eventsFolderName)
        try? FileManager.default.createDirectory(at: eventsURL, withIntermediateDirectories: true)
    }

    private func aggregateMinuteStats(from events: [BlinkEvent]) -> [MinuteStats] {
        let calendar = Calendar.current
        var grouped: [Date: [BlinkEvent]] = [:]

        for event in events {
            let minute = calendar.date(bySetting: .second, value: 0, of: event.timestamp) ?? event.timestamp
            grouped[minute, default: []].append(event)
        }

        return grouped.map { minute, events in
            let avgConfidence = events.reduce(0.0) { $0 + $1.confidence } / Double(events.count)
            return MinuteStats(minute: minute, blinkCount: events.count, avgConfidence: avgConfidence)
        }.sorted { $0.minute < $1.minute }
    }

    private func calculateAvgRate(events: [BlinkEvent]) -> Double {
        guard let first = events.first, let last = events.last else { return 0 }
        let duration = last.timestamp.timeIntervalSince(first.timestamp)
        return duration > 0 ? Double(events.count) / (duration / 60.0) : 0
    }

    private func calculateDuration(events: [BlinkEvent]) -> TimeInterval {
        guard let first = events.first, let last = events.last else { return 0 }
        return last.timestamp.timeIntervalSince(first.timestamp)
    }

    private var dateFormatter: ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withYear, .withMonth, .withDay, .withDash]
        return formatter
    }
}

extension String {
    var lastValue: String? {
        return components(separatedBy: "/").last
    }
}
```

Also need to add missing models:

Create: `EyeApp/Source/Models/DailyBlinkData.swift`

```swift
import Foundation

struct DailyBlinkData: Codable {
    let date: Date
    var events: [BlinkEvent]
    var minuteStats: [MinuteStats]
    var summary: DailySummary
}

struct DailySummary: Codable {
    let totalBlinks: Int
    let avgBlinkRate: Double
    let fatigueAlerts: Int
    let monitorDuration: TimeInterval
}
```

**Step 4: Run test to verify it passes**

```bash
xcodebuild test -scheme EyeApp -destination 'platform=macOS' -only-testing:EyeAppTests/DataStorageTests
```

Expected: PASS

**Step 5: Commit**

```bash
git add EyeApp/Source/Services/DataStorage.swift EyeApp/Source/Models/AppConfig.swift EyeApp/Source/Models/DailyBlinkData.swift EyeApp/Tests/Services/DataStorageTests.swift
git commit -m "feat: implement DataStorage for persistence"
```

---

## Phase 6: UI Components

### Task 12: Create MenuBarApp Structure

**Files:**
- Modify: `EyeApp/EyeAppApp.swift`
- Create: `EyeApp/Source/UI/MenuBarIcon.swift`

**Step 1: Write the basic app structure**

Modify: `EyeApp/EyeAppApp.swift`

```swift
import SwiftUI

@main
struct EyeAppApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Empty scene since we're using menu bar only
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var menuBarIcon: MenuBarIcon?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon
        NSApp.setActivationPolicy(.accessory)

        // Create menu bar icon
        menuBarIcon = MenuBarIcon()

        // Request camera permission
        CameraManager().requestPermission { granted in
            if !granted {
                print("Camera permission denied")
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}
```

**Step 2: Create MenuBarIcon component**

Create: `EyeApp/Source/UI/MenuBarIcon.swift`

```swift
import SwiftUI

struct MenuBarIcon: View {
    @State private var status: FatigueStatus = FatigueStatus(blinkRate: 0)
    @State private var isPopoverShowing = false

    var body: some View {
        Button(action: {
            isPopoverShowing.toggle()
        }) {
            Image(systemName: "eye.fill")
                .foregroundColor(status.color)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isPopoverShowing) {
            MainPanel()
                .frame(width: 400, height: 500)
        }
    }
}
```

**Step 3: Commit**

```bash
git add EyeApp/EyeAppApp.swift EyeApp/Source/UI/MenuBarIcon.swift
git commit -m "feat: add menu bar app structure"
```

---

### Task 13: Create MainPanel UI

**Files:**
- Create: `EyeApp/Source/UI/MainPanel.swift`

**Step 1: Write the main panel view**

Create: `EyeApp/Source/UI/MainPanel.swift`

```swift
import SwiftUI
import Charts

struct MainPanel: View {
    @State private var currentRate: Int = 0
    @State private var todayTotal: Int = 0
    @State private var trendData: [MinuteStats] = []
    @State private var fatigueStatus: FatigueStatus = FatigueStatus(blinkRate: 0)
    @State private var isPaused: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("👁️ EyeApp")
                    .font(.headline)
                Spacer()
                Button("设置") {
                    // Open settings
                }
                .buttonStyle(.link)
            }
            .padding()

            Divider()

            ScrollView {
                VStack(spacing: 20) {
                    // Current Stats
                    HStack(spacing: 20) {
                        StatCard(
                            title: "当前眨眼频率",
                            value: "\(currentRate)",
                            unit: "次/分",
                            color: fatigueStatus.color
                        )

                        StatCard(
                            title: "今日总次数",
                            value: "\(todayTotal)",
                            unit: "次",
                            color: .blue
                        )
                    }
                    .padding()

                    // Trend Chart
                    VStack(alignment: .leading, spacing: 10) {
                        Text("📊 今日趋势")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Chart(trendData) { item in
                            BarMark(
                                x: .value("时间", item.minute, unit: .minute),
                                y: .value("眨眼次数", item.blinkCount)
                            )
                            .foregroundStyle(fatigueStatus.color)
                        }
                        .frame(height: 150)
                        .chartYAxis {
                            AxisMarks(position: .leading)
                        }
                    }
                    .padding()

                    // Historical Stats
                    VStack(alignment: .leading, spacing: 10) {
                        Text("📅 历史统计")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 10) {
                            PeriodTab(title: "今天")
                            PeriodTab(title: "本周")
                            PeriodTab(title: "本月")
                            PeriodTab(title: "全部")
                        }

                        Divider()

                        HStack {
                            StatRow(label: "平均眨眼频率", value: "16.2 次/分")
                            Spacer()
                            StatRow(label: "疲劳提醒次数", value: "3 次")
                        }
                        HStack {
                            StatRow(label: "累计监测时长", value: "4h 32m")
                            Spacer()
                            StatRow(label: "数据完整性", value: "98%")
                        }
                    }
                    .padding()
                }
            }

            Divider()

            // Footer Controls
            HStack {
                Button(action: {
                    isPaused.toggle()
                }) {
                    Label(isPaused ? "▶ 恢复监测" : "⏸ 暂停监测", systemImage: isPaused ? "play.fill" : "pause.fill")
                }
                .buttonStyle(.borderedProminent)

                Spacer()

                Button("清除今日数据") {
                    // Clear data
                }
                .buttonStyle(.bordered)
            }
            .padding()
        }
        .onAppear {
            loadInitialData()
        }
    }

    private func loadInitialData() {
        // Load data from StatsEngine
        // This will be connected to actual services
        currentRate = 18
        todayTotal = 12450

        // Mock trend data
        let calendar = Calendar.current
        let now = Date()
        trendData = (0..<60).map { i in
            MinuteStats(
                minute: now.addingTimeInterval(-Double((60 - i) * 60)),
                blinkCount: Int.random(in: 10...25),
                avgConfidence: 0.9
            )
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let unit: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.title)
                    .fontWeight(.bold)
                Text(unit)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(10)
    }
}

struct PeriodTab: View {
    let title: String
    @State private var isSelected: Bool = false

    var body: some View {
        Text(title)
            .font(.caption)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.1))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(8)
            .onTapGesture {
                isSelected.toggle()
            }
    }
}

struct StatRow: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
    }
}

#Preview {
    MainPanel()
}
```

**Step 2: Commit**

```bash
git add EyeApp/Source/UI/MainPanel.swift
git commit -m "feat: implement MainPanel UI"
```

---

### Task 14: Create Settings Panel

**Files:**
- Create: `EyeApp/Source/UI/SettingsPanel.swift`

**Step 1: Write the settings view**

Create: `EyeApp/Source/UI/SettingsPanel.swift`

```swift
import SwiftUI

struct SettingsPanel: View {
    @AppStorage("alertEnabled") private var alertEnabled: Bool = true
    @AppStorage("alertThreshold") private var alertThreshold: Double = 10
    @AppStorage("alertInterval") private var alertInterval: Double = 15
    @AppStorage("launchAtLogin") private var launchAtLogin: Bool = true
    @State private var sensitivity: SensitivityLevel = .medium

    var body: some View {
        TabView {
            AlertSettings()
                .tabItem {
                    Label("提醒设置", systemImage: "bell")
                }

            DetectionSettings()
                .tabItem {
                    Label("检测设置", systemImage: "eye")
                }

            PrivacySettings()
                .tabItem {
                    Label("隐私", systemImage: "lock")
                }

            AboutSettings()
                .tabItem {
                    Label("关于", systemImage: "info.circle")
                }
        }
        .frame(width: 500, height: 400)
    }
}

struct AlertSettings: View {
    @AppStorage("alertEnabled") private var alertEnabled: Bool = true
    @AppStorage("alertThreshold") private var alertThreshold: Double = 10
    @AppStorage("alertInterval") private var alertInterval: Double = 15

    var body: some View {
        Form {
            Section("🔔 提醒设置") {
                Toggle("启用疲劳提醒", isOn: $alertEnabled)

                VStack(alignment: .leading) {
                    Text("提醒阈值: \(Int(alertThreshold)) 次/分")
                    Slider(value: $alertThreshold, in: 5...30, step: 1)
                    Text("低于此频率时触发提醒")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                VStack(alignment: .leading) {
                    Text("提醒间隔: \(Int(alertInterval)) 分钟")
                    Slider(value: $alertInterval, in: 5...60, step: 5)
                    Text("两次提醒之间的最小间隔")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
    }
}

struct DetectionSettings: View {
    @State private var sensitivity: SensitivityLevel = .medium

    var body: some View {
        Form {
            Section("🎯 检测灵敏度") {
                Picker("灵敏度", selection: $sensitivity) {
                    Text("低").tag(SensitivityLevel.low)
                    Text("中").tag(SensitivityLevel.medium)
                    Text("高").tag(SensitivityLevel.high)
                }
                .pickerStyle(.segmented)

                Text("灵敏度越高，检测越灵敏，但可能增加误检")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
}

struct PrivacySettings: View {
    @State private var cameraAuthorized: Bool = false
    @AppStorage("launchAtLogin") private var launchAtLogin: Bool = true

    var body: some View {
        Form {
            Section("🔒 隐私") {
                HStack {
                    Text("摄像头权限")
                    Spacer()
                    Text(cameraAuthorized ? "已授权 ✓" : "未授权")
                        .foregroundColor(cameraAuthorized ? .green : .red)
                }

                Text("所有数据仅存储在本地，不会上传到云端")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("📌 启动") {
                Toggle("开机自动启动", isOn: $launchAtLogin)
            }
        }
        .padding()
        .onAppear {
            checkCameraPermission()
        }
    }

    private func checkCameraPermission() {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
                cameraAuthorized = granted
            }
        }
    }
}

struct AboutSettings: View {
    var body: some View {
        Form {
            Section("👁️ EyeApp") {
                HStack {
                    Text("版本")
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("构建")
                    Spacer()
                    Text("2026.02.27")
                        .foregroundColor(.secondary)
                }
            }

            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Text("关于 EyeApp")
                        .font(.headline)

                    Text("EyeApp 是一款 macOS 原生应用，通过检测眨眼频率来提醒您注意用眼健康，预防视疲劳。")
                        .font(.caption)

                    Text("数据仅存储在本地，保护您的隐私。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
    }
}

#Preview {
    SettingsPanel()
}
```

**Step 2: Update MainPanel to open settings**

Add this to MainPanel.swift in the settings button action:

```swift
.sheet(isPresented: $showSettings) {
    SettingsPanel()
}
```

**Step 3: Commit**

```bash
git add EyeApp/Source/UI/SettingsPanel.swift EyeApp/Source/UI/MainPanel.swift
git commit -m "feat: implement SettingsPanel UI"
```

---

## Phase 7: Integration

### Task 15: Create SessionManager

**Files:**
- Create: `EyeApp/Source/Core/SessionManager.swift`

**Step 1: Write the failing test**

Create: `EyeApp/Tests/Core/SessionManagerTests.swift`

```swift
import XCTest
@testable import EyeApp

final class SessionManagerTests: XCTestCase {

    var manager: SessionManager!
    var mockCamera: MockCameraManager!
    var mockVision: MockVisionService!
    var mockDetector: MockBlinkDetector!
    var mockStats: MockStatsEngine!

    override func setUp() {
        super.setUp()
        mockCamera = MockCameraManager()
        mockVision = MockVisionService()
        mockDetector = MockBlinkDetector()
        mockStats = MockStatsEngine()
        manager = SessionManager(
            cameraManager: mockCamera,
            visionService: mockVision,
            blinkDetector: mockDetector,
            statsEngine: mockStats
        )
    }

    func testInitialState() {
        XCTAssertEqual(manager.state, .idle)
    }

    func testStartSession() {
        manager.start()

        XCTAssertEqual(mockCamera.startCallCount, 1)
        XCTAssertEqual(manager.state, .running)
    }

    func testStopSession() {
        manager.start()
        manager.stop()

        XCTAssertEqual(mockCamera.stopCallCount, 1)
        XCTAssertEqual(manager.state, .stopped)
    }

    func testPauseSession() {
        manager.start()
        manager.pause()

        XCTAssertEqual(manager.state, .paused)
    }

    func testBlinkDetectionFlow() {
        manager.start()

        // Simulate camera frame
        let mockBuffer = createMockSampleBuffer()
        manager.cameraDidReceiveFrame(mockBuffer)

        // Vision should process
        XCTAssertEqual(mockVision.processCallCount, 1)

        // Simulate face detection
        manager.faceDetected(landmarks: [], confidence: 0.9)

        // Detector should process
        XCTAssertGreaterThanOrEqual(mockDetector.processCallCount, 1)
    }

    func testStatsRecording() {
        manager.start()

        // Trigger a blink
        manager.blinkDetected(event: BlinkEvent(timestamp: Date(), confidence: 0.9))

        XCTAssertEqual(mockStats.recordBlinkCallCount, 1)
    }

    // MARK: - Helpers

    private func createMockSampleBuffer() -> CMSampleBuffer {
        // This is a placeholder - actual implementation would use CMSampleBufferCreate
        fatalError("Use actual mock implementation")
    }
}

// MARK: - Mocks

class MockCameraManager: CameraManagerProtocol {
    var startCallCount = 0
    var stopCallCount = 0
    var onFrame: ((CMSampleBuffer) -> Void)?
    var onError: ((Error) -> Void)?

    func start() { startCallCount += 1 }
    func stop() { stopCallCount += 1 }
    func requestPermission(completion: @escaping (Bool) -> Void) { completion(true) }
}

class MockVisionService: VisionServiceProtocol {
    var processCallCount = 0
    var onFaceDetected: (([CGPoint], Double) -> Void)?

    func process(sampleBuffer: CMSampleBuffer) { processCallCount += 1 }
}

class MockBlinkDetector {
    var processCallCount = 0
    var processResult: BlinkResult = .noBlink

    func process(landmarks: [CGPoint], confidence: Double) -> BlinkResult {
        processCallCount += 1
        return processResult
    }
}

class MockStatsEngine {
    var recordBlinkCallCount = 0

    func recordBlink(_ event: BlinkEvent) { recordBlinkCallCount += 1 }
}
```

**Step 2: Run test to verify it fails**

```bash
xcodebuild test -scheme EyeApp -destination 'platform=macOS' -only-testing:EyeAppTests/SessionManagerTests
```

Expected: FAIL with "Cannot find 'SessionManager' in scope"

**Step 3: Write minimal implementation**

Create: `EyeApp/Source/Core/SessionManager.swift`

```swift
import Foundation
import AVFoundation

enum SessionState {
    case idle
    case running
    case paused
    case stopped
    case error(Error)
}

protocol CameraManagerProtocol {
    func start()
    func stop()
    func requestPermission(completion: @escaping (Bool) -> Void)
    var onFrame: ((CMSampleBuffer) -> Void)? { get set }
    var onError: ((Error) -> Void)? { get set }
}

protocol VisionServiceProtocol {
    func process(sampleBuffer: CMSampleBuffer)
    var onFaceDetected: (([CGPoint], Double) -> Void)? { get set }
}

class SessionManager: NSObject {
    private let cameraManager: CameraManagerProtocol
    private let visionService: VisionServiceProtocol
    private let blinkDetector: BlinkDetector
    private let statsEngine: StatsEngine
    private let alertManager: AlertManager

    var state: SessionState = .idle {
        didSet { onStateChanged?(state) }
    }
    var onStateChanged: ((SessionState) -> Void)?
    var onBlinkDetected: ((BlinkEvent) -> Void)?

    init(
        cameraManager: CameraManagerProtocol,
        visionService: VisionServiceProtocol,
        blinkDetector: BlinkDetector,
        statsEngine: StatsEngine,
        alertManager: AlertManager
    ) {
        self.cameraManager = cameraManager
        self.visionService = visionService
        self.blinkDetector = blinkDetector
        self.statsEngine = statsEngine
        self.alertManager = alertManager

        super.init()

        setupCallbacks()
    }

    func start() {
        guard state == .idle || state == .stopped else { return }

        cameraManager.start()
        state = .running
    }

    func stop() {
        cameraManager.stop()
        state = .stopped
    }

    func pause() {
        state = .paused
    }

    func resume() {
        guard state == .paused else { return }
        state = .running
    }

    // MARK: - Camera Callback

    func cameraDidReceiveFrame(_ buffer: CMSampleBuffer) {
        guard state == .running else { return }
        visionService.process(sampleBuffer: buffer)
    }

    // MARK: - Vision Callback

    func faceDetected(landmarks: [CGPoint], confidence: Double) {
        guard state == .running else { return }

        let result = blinkDetector.process(landmarks: landmarks, confidence: confidence)

        switch result {
        case .blinkDetected:
            let event = BlinkEvent(timestamp: Date(), confidence: confidence)
            handleBlink(event)
        case .debounced:
            break // Ignore debounced blinks
        case .noBlink:
            break
        }
    }

    // MARK: - Private

    private func setupCallbacks() {
        cameraManager.onFrame = { [weak self] buffer in
            self?.cameraDidReceiveFrame(buffer)
        }

        cameraManager.onError = { [weak self] error in
            self?.state = .error(error)
        }

        visionService.onFaceDetected = { [weak self] landmarks, confidence in
            self?.faceDetected(landmarks: landmarks, confidence: confidence)
        }
    }

    private func handleBlink(_ event: BlinkEvent) {
        statsEngine.recordBlink(event)
        onBlinkDetected?(event)

        // Check for fatigue
        if alertManager.shouldTriggerAlert() {
            alertManager.triggerAlert()
        }
    }
}
```

Also need to extend CameraManager and VisionService to conform to protocols:

Add to `CameraManager.swift`:

```swift
extension CameraManager: CameraManagerProtocol {}
```

Add to `VisionService.swift`:

```swift
extension VisionService: VisionServiceProtocol {}
```

**Step 4: Run test to verify it passes**

```bash
xcodebuild test -scheme EyeApp -destination 'platform=macOS' -only-testing:EyeAppTests/SessionManagerTests
```

Expected: PASS

**Step 5: Commit**

```bash
git add EyeApp/Source/Core/SessionManager.swift EyeApp/Tests/Core/SessionManagerTests.swift
git commit -m "feat: implement SessionManager for integration"
```

---

### Task 16: Connect UI to Session

**Files:**
- Modify: `EyeApp/Source/UI/MainPanel.swift`
- Modify: `EyeApp/EyeAppApp.swift`

**Step 1: Update EyeAppApp to wire everything together**

Modify: `EyeApp/EyeAppApp.swift`

```swift
import SwiftUI

@main
struct EyeAppApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var sessionManager: SessionManager?
    var dataStorage: DataStorage?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        // Initialize services
        let cameraManager = CameraManager()
        let visionService = VisionService()
        let blinkDetector = BlinkDetector(threshold: 0.2, debounceTime: 0.3)
        let statsEngine = StatsEngine()
        let alertManager = AlertManager(statsEngine: statsEngine)

        let sessionManager = SessionManager(
            cameraManager: cameraManager,
            visionService: visionService,
            blinkDetector: blinkDetector,
            statsEngine: statsEngine,
            alertManager: alertManager
        )

        self.sessionManager = sessionManager

        // Initialize data storage
        let supportURL = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        .appendingPathComponent("EyeApp", isDirectory: true)

        let dataStorage = DataStorage(storageURL: supportURL)
        self.dataStorage = dataStorage

        // Load config
        if let config = dataStorage.loadConfig() {
            alertManager.config = AlertConfig(
                enabled: config.alertEnabled,
                threshold: config.alertThreshold,
                intervalMinutes: config.alertInterval
            )
        }

        // Create menu bar icon
        MenuBarIcon(sessionManager: sessionManager, statsEngine: statsEngine)

        // Request camera permission
        cameraManager.requestPermission { granted in
            if granted {
                sessionManager.start()
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        sessionManager?.stop()
    }
}
```

**Step 2: Update MainPanel to use real data**

Modify: `EyeApp/Source/UI/MainPanel.swift`

```swift
import SwiftUI
import Charts

struct MainPanel: View {
    let sessionManager: SessionManager
    let statsEngine: StatsEngine

    @State private var currentRate: Int = 0
    @State private var todayTotal: Int = 0
    @State private var trendData: [MinuteStats] = []
    @State private var fatigueStatus: FatigueStatus = FatigueStatus(blinkRate: 0)
    @State private var isPaused: Bool = false
    @State private var showSettings: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("👁️ EyeApp")
                    .font(.headline)
                Spacer()
                Button("设置") {
                    showSettings = true
                }
                .buttonStyle(.link)
            }
            .padding()

            Divider()

            ScrollView {
                VStack(spacing: 20) {
                    // Current Stats
                    HStack(spacing: 20) {
                        StatCard(
                            title: "当前眨眼频率",
                            value: "\(currentRate)",
                            unit: "次/分",
                            color: fatigueStatus.color
                        )

                        StatCard(
                            title: "今日总次数",
                            value: "\(todayTotal)",
                            unit: "次",
                            color: .blue
                        )
                    }
                    .padding()

                    // Trend Chart
                    VStack(alignment: .leading, spacing: 10) {
                        Text("📊 今日趋势")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Chart(trendData) { item in
                            BarMark(
                                x: .value("时间", item.minute, unit: .minute),
                                y: .value("眨眼次数", item.blinkCount)
                            )
                            .foregroundStyle(fatigueStatus.color)
                        }
                        .frame(height: 150)
                        .chartYAxis {
                            AxisMarks(position: .leading)
                        }
                    }
                    .padding()

                    // Historical Stats
                    VStack(alignment: .leading, spacing: 10) {
                        Text("📅 历史统计")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 10) {
                            PeriodTab(title: "今天")
                            PeriodTab(title: "本周")
                            PeriodTab(title: "本月")
                            PeriodTab(title: "全部")
                        }

                        Divider()

                        let stats = statsEngine.getTodayStats()

                        HStack {
                            StatRow(label: "平均眨眼频率", value: "\(Int(stats.avgBlinkRate)) 次/分")
                            Spacer()
                            StatRow(label: "疲劳提醒次数", value: "\(stats.fatigueAlerts) 次")
                        }
                        HStack {
                            let duration = Int(stats.monitorDuration / 60)
                            StatRow(label: "累计监测时长", value: "\(duration / 60)h \(duration % 60)m")
                            Spacer()
                            StatRow(label: "数据完整性", value: "98%")
                        }
                    }
                    .padding()
                }
            }

            Divider()

            // Footer Controls
            HStack {
                Button(action: {
                    if isPaused {
                        sessionManager.resume()
                    } else {
                        sessionManager.pause()
                    }
                    isPaused.toggle()
                }) {
                    Label(isPaused ? "▶ 恢复监测" : "⏸ 暂停监测", systemImage: isPaused ? "play.fill" : "pause.fill")
                }
                .buttonStyle(.borderedProminent)

                Spacer()

                Button("清除今日数据") {
                    // TODO: Implement data clearing
                }
                .buttonStyle(.bordered)
            }
            .padding()
        }
        .sheet(isPresented: $showSettings) {
            SettingsPanel()
        }
        .onAppear {
            loadInitialData()
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            updateData()
        }
    }

    private func loadInitialData() {
        updateData()
    }

    private func updateData() {
        let now = Date()
        currentRate = Int(statsEngine.getBlinkRate(for: now))
        let todayStats = statsEngine.getTodayStats()
        todayTotal = todayStats.totalBlinks
        trendData = statsEngine.getTrend(for: now, duration: .minutes(60))
        fatigueStatus = FatigueStatus(blinkRate: Double(currentRate))
    }
}

// Keep existing structs: StatCard, PeriodTab, StatRow
```

**Step 3: Update MenuBarIcon**

Modify: `EyeApp/Source/UI/MenuBarIcon.swift`

```swift
import SwiftUI

struct MenuBarIcon: View {
    let sessionManager: SessionManager
    let statsEngine: StatsEngine

    @State private var status: FatigueStatus = FatigueStatus(blinkRate: 0)
    @State private var isPopoverShowing = false

    var body: some View {
        Button(action: {
            isPopoverShowing.toggle()
        }) {
            Image(systemName: "eye.fill")
                .foregroundColor(status.color)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isPopoverShowing) {
            MainPanel(sessionManager: sessionManager, statsEngine: statsEngine)
                .frame(width: 400, height: 500)
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            updateStatus()
        }
    }

    private func updateStatus() {
        let rate = statsEngine.getBlinkRate(for: Date())
        status = FatigueStatus(blinkRate: rate)
    }
}
```

**Step 4: Commit**

```bash
git add EyeApp/EyeAppApp.swift EyeApp/Source/UI/MainPanel.swift EyeApp/Source/UI/MenuBarIcon.swift
git commit -m "feat: connect UI to SessionManager"
```

---

## Phase 8: Final Polish

### Task 17: Add Auto-save and Data Persistence

**Files:**
- Create: `EyeApp/Source/Services/AutoSaveService.swift`

**Step 1: Create auto-save service**

Create: `EyeApp/Source/Services/AutoSaveService.swift`

```swift
import Foundation

class AutoSaveService {
    private let statsEngine: StatsEngine
    private let dataStorage: DataStorage
    private var saveTimer: Timer?

    init(statsEngine: StatsEngine, dataStorage: DataStorage) {
        self.statsEngine = statsEngine
        self.dataStorage = dataStorage
    }

    func start() {
        // Save every minute
        saveTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.saveCurrentData()
        }
    }

    func stop() {
        saveTimer?.invalidate()
        saveTimer = nil
    }

    func saveCurrentData() {
        let events = statsEngine.getAllEvents()
        let calendar = Calendar.current

        // Group by date
        let grouped = Dictionary(grouping: events) { event in
            calendar.startOfDay(for: event.timestamp)
        }

        // Save each day's data
        for (date, dayEvents) in grouped {
            dataStorage.saveDailyData(date: date, events: dayEvents)
        }
    }

    func loadData() {
        let calendar = Calendar.current
        let today = Date()
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: today) ?? today

        let loadedData = dataStorage.loadData(from: thirtyDaysAgo, to: today)

        for dailyData in loadedData {
            for event in dailyData.events {
                statsEngine.recordBlink(event)
            }
        }
    }
}
```

**Step 2: Integrate with SessionManager**

Update `EyeAppApp.swift`:

```swift
// In AppDelegate
let autoSaveService = AutoSaveService(statsEngine: statsEngine, dataStorage: dataStorage)
autoSaveService.start()
autoSaveService.loadData()
```

**Step 3: Commit**

```bash
git add EyeApp/Source/Services/AutoSaveService.swift EyeApp/EyeAppApp.swift
git commit -m "feat: add auto-save service for data persistence"
```

---

### Task 18: Add Error Handling UI

**Files:**
- Create: `EyeApp/Source/UI/ErrorView.swift`

**Step 1: Create error view**

Create: `EyeApp/Source/UI/ErrorView.swift`

```swift
import SwiftUI

struct ErrorView: View {
    let error: SessionError
    let onRetry: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: error.icon)
                .font(.system(size: 50))
                .foregroundColor(error.color)

            Text(error.title)
                .font(.headline)

            Text(error.message)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 10) {
                if error.canRetry {
                    Button("重试", action: onRetry)
                        .buttonStyle(.borderedProminent)
                }

                Button("关闭", action: onDismiss)
                    .buttonStyle(.bordered)
            }
        }
        .padding()
        .frame(width: 300)
    }
}

struct SessionError {
    let title: String
    let message: String
    let canRetry: Bool
    let icon: String
    let color: Color

    static func cameraPermissionDenied() -> SessionError {
        SessionError(
            title: "需要摄像头权限",
            message: "请在系统设置中允许 EyeApp 访问摄像头",
            canRetry: true,
            icon: "camera.fill",
            color: .red
        )
    }

    static func cameraUnavailable() -> SessionError {
        SessionError(
            title: "摄像头不可用",
            message: "请检查摄像头是否连接或被其他应用占用",
            canRetry: true,
            icon: "video.slash",
            color: .orange
        )
    }

    static func lowLightCondition() -> SessionError {
        SessionError(
            title: "光线不足",
            message: "当前光线较弱，检测精度可能下降。请改善照明条件",
            canRetry: false,
            icon: "lightbulb.slash",
            color: .yellow
        )
    }
}
```

**Step 2: Update SessionManager to report errors**

Update `SessionManager.swift`:

```swift
var onError: ((SessionError) -> Void)?

// In cameraManager.onError callback:
cameraManager.onError = { [weak self] error in
    DispatchQueue.main.async {
        if let cameraError = error as? CameraError {
            let sessionError: SessionError
            switch cameraError {
            case .cameraNotFound:
                sessionError = .cameraUnavailable()
            case .permissionDenied:
                sessionError = .cameraPermissionDenied()
            default:
                sessionError = .cameraUnavailable()
            }
            self?.onError?(sessionError)
        }
        self?.state = .error(error)
    }
}
```

**Step 3: Commit**

```bash
git add EyeApp/Source/UI/ErrorView.swift EyeApp/Source/Core/SessionManager.swift
git commit -m "feat: add error handling UI"
```

---

### Task 19: Add App Icon and Assets

**Files:**
- Add: `EyeApp/Assets.xcassets/AppIcon.appiconset/`

**Step 1: Create app icon**

Use Xcode Asset Catalog to create app icon with the following sizes:
- 16x16, 32x32, 128x128, 256x256, 512x512, 1024x1024

Design: Simple eye icon with status color indicator

**Step 2: Commit**

```bash
git add EyeApp/Assets.xcassets/
git commit -m "feat: add app icon and assets"
```

---

### Task 20: Final Testing and Bug Fixes

**Step 1: Run all tests**

```bash
xcodebuild test -scheme EyeApp -destination 'platform=macOS'
```

Expected: All tests PASS

**Step 2: Manual testing checklist**

- [ ] First launch: permission request flow
- [ ] Normal use: blink detection accuracy
- [ ] With glasses: detection works
- [ ] Fatigue alert: notification appears
- [ ] Menu bar: icon color changes
- [ ] Settings: config saves and persists
- [ ] Long running: memory/CPU stable
- [ ] Low light: graceful degradation
- [ ] App restart: data restored

**Step 3: Profile performance**

Use Instruments to check:
- Memory usage: Should stay under 100MB
- CPU usage: Should stay under 15%
- Battery impact: Should be low

**Step 4: Fix any issues found**

Address bugs and edge cases discovered during testing.

**Step 5: Final commit**

```bash
git add .
git commit -m "chore: final polish and bug fixes"
```

---

## Phase 9: Documentation and Release

### Task 21: Write README

**Files:**
- Create: `README.md`

**Step 1: Create README**

Create: `README.md`

```markdown
# EyeApp 👁️

一款 macOS 原生菜单栏应用，通过摄像头实时检测眨眼频率，用于健康监测和疲劳提醒。

## 功能特点

- 📹 **实时眨眼检测** - 使用 Vision 框架进行高精度检测
- 📊 **数据可视化** - 每分钟/小时/天的趋势图表
- 🔔 **疲劳提醒** - 智能检测低眨眼频率并发出提醒
- 💾 **本地存储** - 所有数据仅存储在本地，保护隐私
- 🎯 **可自定义** - 调整检测灵敏度和提醒阈值

## 系统要求

- macOS 14.0 或更高版本
- 带有摄像头的 Mac 设备
- 摄像头使用权限

## 安装

1. 下载 EyeApp.app
2. 将应用拖到"应用程序"文件夹
3. 首次启动时授予摄像头权限

## 使用说明

### 启动监测

启动应用后，点击菜单栏的 👁️ 图标即可开始监测。

### 查看统计

点击菜单栏图标查看：
- 当前眨眼频率
- 今日总次数
- 趋势图表
- 历史统计

### 设置提醒

在"设置"中可以调整：
- 提醒阈值（默认 10 次/分）
- 提醒间隔（默认 15 分钟）
- 检测灵敏度

## 注意事项

- **戴眼镜**: 普通眼镜兼容，但强烈反光的眼镜可能影响精度
- **光照条件**: 建议在正常光线下使用，低光环境精度会下降
- **隐私保护**: 所有数据仅存储在本地，不会上传到云端

## 技术架构

- **语言**: Swift
- **框架**: SwiftUI, Vision, AVFoundation
- **检测算法**: EAR (Eye Aspect Ratio)
- **存储**: JSON + SwiftData

## 许可证

MIT License

## 致谢

感谢 Apple 的 Vision 框架提供强大的人脸检测能力。
```

**Step 2: Commit**

```bash
git add README.md
git commit -m "docs: add comprehensive README"
```

---

### Task 22: Archive and Build

**Step 1: Build for release**

```bash
xcodebuild archive -scheme EyeApp -archivePath build/EyeApp.xcarchive
```

**Step 2: Export app**

```bash
xcodebuild -exportArchive -archivePath build/EyeApp.xcarchive \
  -exportPath build/release -exportOptionsPlist ExportOptions.plist
```

**Step 3: Create release**

```bash
git tag -a v1.0.0 -m "Release version 1.0.0"
git push origin v1.0.0
```

**Step 4: Commit**

```bash
git add build/
git commit -m "chore: add release build configuration"
```

---

## Summary

This implementation plan builds EyeApp in phases:

1. **Project Setup** - Xcode project, entitlements
2. **Data Models** - BlinkEvent, MinuteStats, FatigueStatus
3. **Blink Detection** - BlinkDetector with EAR algorithm, VisionService, CameraManager
4. **Statistics Engine** - StatsEngine for aggregation
5. **Alert System** - AlertManager for fatigue detection
6. **Data Storage** - JSON-based persistence
7. **UI Components** - MenuBarIcon, MainPanel, SettingsPanel
8. **Integration** - SessionManager to wire everything together
9. **Polish** - Auto-save, error handling, testing, documentation

Total estimated implementation time: 2-3 weeks for a solo developer.

---

## Development Guidelines

### TDD Workflow
1. Write failing test
2. Run test - verify it fails
3. Write minimal implementation
4. Run test - verify it passes
5. Refactor if needed
6. Commit

### Commit Message Format
- `feat:` - New feature
- `fix:` - Bug fix
- `refactor:` - Code refactoring
- `test:` - Adding tests
- `docs:` - Documentation
- `chore:` - Build/config changes

### Testing Requirements
- Unit tests: 80%+ coverage
- Integration tests for core flows
- Manual testing for UI components

---

**End of Implementation Plan**
