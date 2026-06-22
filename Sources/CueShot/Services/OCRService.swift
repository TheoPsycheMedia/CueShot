import Foundation
import CoreGraphics
import Vision

struct OCRService {
    func recognizeText(in image: CGImage) async throws -> String? {
        try await withCheckedThrowingContinuation { continuation in
            var didResume = false

            func resumeOnce(_ result: Result<String?, Error>) {
                guard !didResume else { return }
                didResume = true

                switch result {
                case .success(let value):
                    continuation.resume(returning: value)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }

            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    resumeOnce(.failure(error))
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    resumeOnce(.success(nil))
                    return
                }

                let lines = observations.compactMap {
                    $0.topCandidates(1).first?.string.trimmingCharacters(in: .whitespacesAndNewlines)
                }.filter { !$0.isEmpty }

                let text = lines.joined(separator: "\n")
                resumeOnce(.success(text.isEmpty ? nil : text))
            }

            request.recognitionLevel = .fast
            request.usesLanguageCorrection = true
            let handler = VNImageRequestHandler(cgImage: image, options: [:])

            do {
                try handler.perform([request])
            } catch {
                resumeOnce(.failure(error))
            }
        }
    }
}
