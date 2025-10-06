#!/usr/bin/env swift
import Foundation
import AppKit

// Ensure a target directory is provided
guard CommandLine.arguments.count > 1 else {
    fputs("Usage: Darwin_pastefiles.swift <target_dir>\n", stderr)
    exit(1)
}

let targetDir = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)

// Read file/folder URLs from clipboard
let pasteboard = NSPasteboard.general
guard let items = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
      !items.isEmpty else {
    fputs("No file URLs found in clipboard\n", stderr)
    exit(1)
}

var copiedCount = 0
for srcURL in items {
    let destURL = targetDir.appendingPathComponent(srcURL.lastPathComponent)

    do {
        // If destination exists, remove it first
        if FileManager.default.fileExists(atPath: destURL.path) {
            try FileManager.default.removeItem(at: destURL)
        }

        // Copy the item (file or directory)
        try FileManager.default.copyItem(at: srcURL, to: destURL)
        copiedCount += 1
    } catch {
        fputs("Failed to copy \(srcURL.path) → \(destURL.path): \(error)\n", stderr)
    }
}
