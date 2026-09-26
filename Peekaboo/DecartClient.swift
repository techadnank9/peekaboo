import UIKit

/// Turns a shot into a cartoon of the kid with Decart's Lucy image model.
/// The API key lives in DecartKey.txt, which is git-ignored; without it the
/// Cartoon Me feature stays hidden.
enum DecartClient {
    static let apiKey: String? = Bundle.main.url(forResource: "DecartKey", withExtension: "txt")
        .flatMap { try? String(contentsOf: $0, encoding: .utf8) }?
        .trimmingCharacters(in: .whitespacesAndNewlines)

    static var isAvailable: Bool { !(apiKey ?? "").isEmpty }

    static func cartoonize(_ image: UIImage, as character: Attractor) async throws -> UIImage {
        guard let apiKey, !apiKey.isEmpty else { throw URLError(.userAuthenticationRequired) }

        let prompt = "Turn this child into a cute Pixar-style 3D cartoon character, same pose and expression, "
            + "big sparkling eyes, playing with a friendly \(character.title), bright colorful background"
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
