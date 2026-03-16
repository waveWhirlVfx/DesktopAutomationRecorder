import Vision
import CoreGraphics
import AppKit

// MARK: - VisionBridge
// OCR-based element location for replay fallback

final class VisionBridge {
    static let shared = VisionBridge()
    private init() {}

    /// Take a screenshot and find the center point of text matching `text`
    func findText(_ text: String, in region: CGRect?) async -> CGPoint? {
        return await Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return nil }
            guard let image = self.captureScreen() else { return nil }
            return self.runOCR(on: image, searchText: text, region: region)
        }.value
    }

    private func captureScreen() -> CGImage? {
        return CGDisplayCreateImage(CGMainDisplayID())
    }

    private func runOCR(on image: CGImage, searchText: String, region: CGRect?) -> CGPoint? {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .fast
        request.usesLanguageCorrection = false

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try? handler.perform([request])

        guard let observations = request.results else { return nil }
        let screenSize = NSScreen.main?.frame.size ?? CGSize(width: 1920, height: 1080)

        for obs in observations {
            guard let candidate = obs.topCandidates(1).first,
                  candidate.string.lowercased().contains(searchText.lowercased()) else { continue }
            // Convert normalized Vision coordinates to screen coordinates
            let box = obs.boundingBox
            let x = box.midX * screenSize.width
            let y = (1 - box.midY) * screenSize.height // flip Y
            return CGPoint(x: x, y: y)
        }
        return nil
    }
}
