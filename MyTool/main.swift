import Foundation
import Vision
import AppKit

// MARK: - Models

struct OCRBlock: Codable {
    let text: String
    let confidence: Float
    let boundingBox: BoundingBox
}

struct BoundingBox: Codable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double
}

struct OCRResult: Codable {
    let fullText: String
    let blocks: [OCRBlock]
}

enum LanguageMode: String {
    case auto
    case ar
    case en
    case dual

    var languageCodes: [String] {
        switch self {
        case .auto, .dual: return ["ar-SA", "en-US"]
        case .ar:          return ["ar-SA"]
        case .en:          return ["en-US"]
        }
    }
}

// MARK: - OCR Engine

final class OCREngine {
    static func process(imagePath: String, languageMode: LanguageMode) -> Result<OCRResult, Error> {
        let fileURL = URL(fileURLWithPath: (imagePath as NSString).expandingTildeInPath)
        
        guard let image = NSImage(contentsOf: fileURL),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            let error = NSError(domain: "MacOCRCLI", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to load image at \(imagePath)"])
            return .failure(error)
        }

        let semaphore = DispatchSemaphore(value: 0)
        var result: Result<OCRResult, Error>!

        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        let request = VNRecognizeTextRequest { req, err in
            defer { semaphore.signal() }

            if let err = err {
                result = .failure(err)
                return
            }

            guard let observations = req.results as? [VNRecognizedTextObservation] else {
                result = .success(OCRResult(fullText: "", blocks: []))
                return
            }

            let blocks = observations.compactMap { obs -> OCRBlock? in
                guard let candidate = obs.topCandidates(1).first else { return nil }
                return OCRBlock(
                    text: candidate.string,
                    confidence: candidate.confidence,
                    boundingBox: BoundingBox(
                        x: Double(obs.boundingBox.origin.x),
                        y: Double(obs.boundingBox.origin.y),
                        width: Double(obs.boundingBox.width),
                        height: Double(obs.boundingBox.height)
                    )
                )
            }

            let fullText = blocks.map { $0.text }.joined(separator: "\n")
            result = .success(OCRResult(fullText: fullText, blocks: blocks))
        }

        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.revision = VNRecognizeTextRequestRevision3
        request.recognitionLanguages = languageMode.languageCodes

        if #available(macOS 13.0, *), languageMode == .auto {
            request.automaticallyDetectsLanguage = true
        }

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try requestHandler.perform([request])
            } catch {
                result = .failure(error)
                semaphore.signal()
            }
        }

        semaphore.wait()
        return result
    }
}

// MARK: - CLI Argument Parser & Entrypoint

func printUsage() {
    let usage = """
    macocr - macOS Vision Native OCR CLI Tool

    USAGE:
      macocr <image-path> [options]

    OPTIONS:
      -l, --lang <mode>    Language mode: auto (default), ar, en, dual
      -j, --json           Output structured JSON including bounding boxes & confidence
      -o, --output <path>  Write output to file instead of stdout
      -h, --help           Show this help message

    EXAMPLES:
      macocr sample.png
      macocr document.jpg --lang ar --output output.txt
      macocr receipt.png --json
    """
    print(usage)
}

func main() {
    let args = Array(CommandLine.arguments.dropFirst())

    if args.isEmpty || args.contains("-h") || args.contains("--help") {
        printUsage()
        exit(0)
    }

    var imagePath: String?
    var langMode: LanguageMode = .auto
    var jsonOutput = false
    var outputPath: String?

    var i = 0
    while i < args.count {
        let arg = args[i]
        switch arg {
        case "-l", "--lang":
            i += 1
            if i < args.count, let mode = LanguageMode(rawValue: args[i]) {
                langMode = mode
            } else {
                fputs("Error: Invalid language mode. Choose from: auto, ar, en, dual\n", stderr)
                exit(1)
            }
        case "-j", "--json":
            jsonOutput = true
        case "-o", "--output":
            i += 1
            if i < args.count {
                outputPath = args[i]
            } else {
                fputs("Error: Missing output path\n", stderr)
                exit(1)
            }
        default:
            if !arg.hasPrefix("-") && imagePath == nil {
                imagePath = arg
            } else {
                fputs("Error: Unknown argument '\(arg)'\n", stderr)
                exit(1)
            }
        }
        i += 1
    }

    guard let inputPath = imagePath else {
        fputs("Error: No image path provided.\n\n", stderr)
        printUsage()
        exit(1)
    }

    switch OCREngine.process(imagePath: inputPath, languageMode: langMode) {
    case .failure(let error):
        fputs("OCR Error: \(error.localizedDescription)\n", stderr)
        exit(1)

    case .success(let result):
        let outputString: String
        if jsonOutput {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            if let data = try? encoder.encode(result), let jsonStr = String(data: data, encoding: .utf8) {
                outputString = jsonStr
            } else {
                fputs("Error: Failed to serialize JSON output.\n", stderr)
                exit(1)
            }
        } else {
            outputString = result.fullText
        }

        if let outPath = outputPath {
            let fileURL = URL(fileURLWithPath: (outPath as NSString).expandingTildeInPath)
            do {
                try outputString.write(to: fileURL, atomically: true, encoding: .utf8)
            } catch {
                fputs("Error writing to output file: \(error.localizedDescription)\n", stderr)
                exit(1)
            }
        } else {
            print(outputString)
        }
    }
}

main()
