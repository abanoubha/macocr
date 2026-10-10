# macocr

`macocr` is a fast, lightweight command-line OCR tool for macOS built on Apple's native **Vision framework**. It runs on-device without external neural network models, APIs, or C++ dependencies.

## Features

- **Native Speed:** Uses Apple Vision neural engine (`VNRecognizeTextRequest`).
- **Multilingual Support:** Supports English, Arabic (`ar-SA`), and combined/auto-detection modes.
- **RTL Script Support:** Handles complex Arabic script alignment and diacritics using Vision Revision 3.
- **Structured JSON Output:** Exports recognized lines, confidence scores, and normalized bounding box coordinates (`x`, `y`, `width`, `height`).
- **Zero Dependencies:** Pure Swift framework integration (`Vision` + `AppKit`).

## Requirements

- macOS 13.0 (Ventura) or later
- Xcode 14+ or Swift toolchain (`swiftc`)

## Build & Install

### Quick Compilation via Terminal

```bash
# Clone repository
git clone [https://github.com/YOUR_USERNAME/macocr.git](https://github.com/YOUR_USERNAME/macocr.git)
cd macocr

# Compile executable with release optimizations
swiftc -O main.swift -framework Vision -framework AppKit -o macocr

# Install to binary path
sudo mv macocr /usr/local/bin/
