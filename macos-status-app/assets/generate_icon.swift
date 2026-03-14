import AppKit
import Foundation

let scriptURL = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL
let assetsURL = scriptURL.deletingLastPathComponent()
let iconsetURL = assetsURL.appendingPathComponent("AppIcon.iconset", isDirectory: true)
let icnsURL = assetsURL.appendingPathComponent("AppIcon.icns")
let projectRootURL = assetsURL.deletingLastPathComponent().deletingLastPathComponent()
let sourceImageURL = projectRootURL.appendingPathComponent("resource/logo.png")

let iconDefinitions: [(name: String, size: CGFloat)] = [
  ("icon_16x16.png", 16),
  ("icon_16x16@2x.png", 32),
  ("icon_32x32.png", 32),
  ("icon_32x32@2x.png", 64),
  ("icon_128x128.png", 128),
  ("icon_128x128@2x.png", 256),
  ("icon_256x256.png", 256),
  ("icon_256x256@2x.png", 512),
  ("icon_512x512.png", 512),
  ("icon_512x512@2x.png", 1024)
]

let fileManager = FileManager.default
try fileManager.createDirectory(at: iconsetURL, withIntermediateDirectories: true)
guard let sourceImage = NSImage(contentsOf: sourceImageURL) else {
  fatalError("Failed to load source image at \(sourceImageURL.path)")
}

func drawIcon(size: CGFloat, from sourceImage: NSImage) -> NSImage {
  let image = NSImage(size: NSSize(width: size, height: size))
  image.lockFocus()

  NSGraphicsContext.current?.imageInterpolation = .high

  let canvas = NSRect(x: 0, y: 0, width: size, height: size)
  sourceImage.draw(in: canvas, from: .zero, operation: .copy, fraction: 1.0)

  image.unlockFocus()
  return image
}

for definition in iconDefinitions {
  let image = drawIcon(size: definition.size, from: sourceImage)
  guard
    let tiffData = image.tiffRepresentation,
    let rep = NSBitmapImageRep(data: tiffData),
    let pngData = rep.representation(using: .png, properties: [:])
  else {
    fatalError("Failed to encode PNG for \(definition.name)")
  }

  try pngData.write(to: iconsetURL.appendingPathComponent(definition.name))
}

if fileManager.fileExists(atPath: icnsURL.path) {
  try fileManager.removeItem(at: icnsURL)
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconsetURL.path, "-o", icnsURL.path]

try process.run()
process.waitUntilExit()

guard process.terminationStatus == 0 else {
  fatalError("iconutil failed with status \(process.terminationStatus)")
}

print("Using source image: \(sourceImageURL.path)")
print("Generated \(icnsURL.path)")
