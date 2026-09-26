import AVFoundation
import UIKit

/// Turns a shot into a cartoon of the kid with Decart's Lucy image model.
/// The API key lives in DecartKey.txt, which is git-ignored; without it the
/// Cartoon Me feature stays hidden.
enum DecartClient {
    static let apiKey: String? = Bundle.main.url(forResource: "DecartKey", withExtension: "txt")
        .flatMap { try? String(contentsOf: $0, encoding: .utf8) }?
        .trimmingCharacters(in: .whitespacesAndNewlines)

    static var isAvailable: Bool { !(apiKey ?? "").isEmpty }

    static func cartoonize(_ image: UIImage, prompt: String) async throws -> UIImage {
        guard let apiKey, !apiKey.isEmpty else { throw URLError(.userAuthenticationRequired) }

        let boundary = "peekaboo-\(UUID().uuidString)"
        var body = Data()
        func field(_ name: String, _ value: String) {
            body.append("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"\r\n\r\n\(value)\r\n".data(using: .utf8)!)
        }
        field("prompt", prompt)
        field("resolution", "480p")
        body.append("--\(boundary)\r\nContent-Disposition: form-data; name=\"data\"; filename=\"shot.jpg\"\r\nContent-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(image.downscaled(maxSide: 1024).jpegData(compressionQuality: 0.85) ?? Data())
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        var request = URLRequest(url: URL(string: "https://api.decart.ai/v1/generate/lucy-image-2")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await URLSession.shared.upload(for: request, from: body)
        guard (response as? HTTPURLResponse)?.statusCode == 200, let cartoon = UIImage(data: data) else {
            throw URLError(.badServerResponse)
        }
        return cartoon
    }
}

private extension UIImage {
    func downscaled(maxSide: CGFloat) -> UIImage {
        let scale = min(1, maxSide / max(size.width, size.height))
        guard scale < 1 else { return self }
        let target = CGSize(width: size.width * scale, height: size.height * scale)
        return UIGraphicsImageRenderer(size: target).image { _ in draw(in: CGRect(origin: .zero, size: target)) }
    }
}

// MARK: - Virtual try-on


extension DecartClient {
    /// Dresses the kid in the photo with Lucy VTON. The model edits video, so
    /// the photo becomes a two-second clip first; the result is a short video
    /// of the kid in the costume.
    static func tryOn(_ image: UIImage, outfit: String) async throws -> URL {
        guard let apiKey, !apiKey.isEmpty else { throw URLError(.userAuthenticationRequired) }
        let clip = try await makeClip(from: image)

        let boundary = "peekaboo-\(UUID().uuidString)"
        var body = Data()
        body.append("--\(boundary)\r\nContent-Disposition: form-data; name=\"prompt\"\r\n\r\nThe child is wearing \(outfit)\r\n".data(using: .utf8)!)
        body.append("--\(boundary)\r\nContent-Disposition: form-data; name=\"data\"; filename=\"clip.mp4\"\r\nContent-Type: video/mp4\r\n\r\n".data(using: .utf8)!)
        body.append(try Data(contentsOf: clip))
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        var submit = URLRequest(url: URL(string: "https://api.decart.ai/v1/jobs/lucy-vton-latest")!)
        submit.httpMethod = "POST"
        submit.timeoutInterval = 60
        submit.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        submit.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        let (submitted, _) = try await URLSession.shared.upload(for: submit, from: body)
        struct Job: Decodable { let job_id: String?; let status: String? }
        guard let jobID = try JSONDecoder().decode(Job.self, from: submitted).job_id else {
            throw URLError(.badServerResponse)
        }

        // Poll until the job finishes, for up to about 90 seconds.
        for _ in 0..<45 {
            try await Task.sleep(for: .seconds(2))
            var poll = URLRequest(url: URL(string: "https://api.decart.ai/v1/jobs/\(jobID)")!)
            poll.setValue(apiKey, forHTTPHeaderField: "x-api-key")
            let (data, _) = try await URLSession.shared.data(for: poll)
            let status = try JSONDecoder().decode(Job.self, from: data).status ?? ""
            if status == "completed" { break }
            if status == "failed" || status == "error" { throw URLError(.badServerResponse) }
        }

        var fetch = URLRequest(url: URL(string: "https://api.decart.ai/v1/jobs/\(jobID)/content")!)
        fetch.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        let (video, response) = try await URLSession.shared.data(for: fetch)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("tryon-\(jobID).mp4")
        try video.write(to: url)
        return url
    }

    /// A two-second, 24 fps H.264 clip of the still photo.
    private static func makeClip(from image: UIImage) async throws -> URL {
        let size = CGSize(width: 480, height: 640)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("clip-\(UUID().uuidString).mp4")
        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: size.width,
            AVVideoHeightKey: size.height,
        ])
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
            kCVPixelBufferWidthKey as String: size.width,
            kCVPixelBufferHeightKey as String: size.height,
        ])
        writer.add(input)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        guard let buffer = pixelBuffer(from: image, size: size) else { throw URLError(.cannotCreateFile) }
        for frame in 0..<48 {
            while !input.isReadyForMoreMediaData { try await Task.sleep(for: .milliseconds(5)) }
            adaptor.append(buffer, withPresentationTime: CMTime(value: CMTimeValue(frame), timescale: 24))
        }
        input.markAsFinished()
        await writer.finishWriting()
        return url
    }

    private static func pixelBuffer(from image: UIImage, size: CGSize) -> CVPixelBuffer? {
        var buffer: CVPixelBuffer?
        CVPixelBufferCreate(kCFAllocatorDefault, Int(size.width), Int(size.height), kCVPixelFormatType_32ARGB,
                            [kCVPixelBufferCGImageCompatibilityKey: true, kCVPixelBufferCGBitmapContextCompatibilityKey: true] as CFDictionary,
                            &buffer)
        guard let buffer else { return nil }
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        guard let context = CGContext(data: CVPixelBufferGetBaseAddress(buffer), width: Int(size.width), height: Int(size.height),
                                      bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue),
              let cgImage = image.cgImage else { return nil }
        // Aspect-fill the photo into the frame.
        let scale = max(size.width / CGFloat(cgImage.width), size.height / CGFloat(cgImage.height))
        let drawn = CGSize(width: CGFloat(cgImage.width) * scale, height: CGFloat(cgImage.height) * scale)
        context.draw(cgImage, in: CGRect(x: (size.width - drawn.width) / 2, y: (size.height - drawn.height) / 2,
                                         width: drawn.width, height: drawn.height))
        return buffer
    }
}
