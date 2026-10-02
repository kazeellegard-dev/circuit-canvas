import CoreGraphics
import Foundation
import Testing
@testable import CircuitCanvas

@MainActor struct CanvasZoomTests {
    /// Feedback (2026-10-03): one pinch on a real iPad went straight to the limits. Spreading the fingers to
    /// twice their distance now zooms about 1.5x, and even a wide spread stays well inside the range.
    @Test func aPinchIsDamped() {
        let doubled = CanvasZoom.pinchScale(startScale: 1, gestureScale: 2)
        #expect(abs(doubled - pow(2, CanvasZoom.pinchSensitivity)) < 0.0001)
        #expect(doubled > 1.4 && doubled < 1.6)
        #expect(CanvasZoom.pinchScale(startScale: 1, gestureScale: 2.5) < CanvasZoom.maximumScale)
        #expect(CanvasZoom.pinchScale(startScale: 1, gestureScale: 0.5) > 0.6)
        #expect(CanvasZoom.pinchScale(startScale: 1, gestureScale: 1) == 1)
    }

    @Test func aPinchStaysWithinTheRange() {
        #expect(CanvasZoom.pinchScale(startScale: 2, gestureScale: 50) == CanvasZoom.maximumScale)
        #expect(CanvasZoom.pinchScale(startScale: 0.5, gestureScale: 0.01) == CanvasZoom.minimumScale)
        #expect(CanvasZoom.pinchScale(startScale: 1.3, gestureScale: 0) == 1.3)
        // Every zoom-menu preset is reachable by pinching too.
        for preset: CGFloat in [0.25, 0.5, 1, 1.5, 2] {
            #expect(preset >= CanvasZoom.minimumScale && preset <= CanvasZoom.maximumScale)
        }
    }

    /// The canvas point between the fingers stays between them while zooming, and follows them as they move.
    @Test func aPinchZoomsAroundTheFingers() {
        let startOffset = CGSize(width: -300, height: -120)
        let startCentroid = CGPoint(x: 400, y: 300)
        let anchor = CGPoint(x: (startCentroid.x - startOffset.width) / 1.2, y: (startCentroid.y - startOffset.height) / 1.2)
        for (scale, centroid) in [(CGFloat(1.8), startCentroid), (0.6, CGPoint(x: 460, y: 250))] {
            let offset = CanvasZoom.pinchOffset(startScale: 1.2, startOffset: startOffset, startCentroid: startCentroid, newScale: scale, centroid: centroid)
            #expect(abs(anchor.x * scale + offset.width - centroid.x) < 0.0001)
            #expect(abs(anchor.y * scale + offset.height - centroid.y) < 0.0001)
        }
    }
}
