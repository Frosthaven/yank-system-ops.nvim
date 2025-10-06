#!/usr/bin/env swift
import Foundation
import AppKit

// Ensure target directory is provided
guard CommandLine.arguments.count >= 2 else {
    fputs("Usage: Darwin_extractarchive.swift <target_dir>\n", stderr)
    exit(1)
}

let targetDir = CommandLine.arguments[1]
let fm = FileManager.default

// Validate target directory
var isDir: ObjCBool = false
guard fm.fileExists(atPath: targetDir, isDirectory: &isDir), isDir.boolValue else {
    fputs("Target directory does not exist: \(targetDir)\n", stderr)
    exit(1)
}

// Get the file from the clipboard
let pasteboard = NSPasteboard.general
guard let files = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL], let archiveURL = files.first else {
    fputs("No file found in clipboard\n", stderr)
    exit(1)
}

// Determine destination path in targetDir
let destURL = URL(fileURLWithPath: targetDir).appendingPathComponent(archiveURL.lastPathComponent)

// Copy the archive to target directory
do {
    if fm.fileExists(atPath: destURL.path) {
        try fm.removeItem(at: destURL)
    }
    try fm.copyItem(at: archiveURL, to: destURL)
    print(destURL.path)  // Lua will read this path
} catch {
    fputs("Failed to copy archive: \(error)\n", stderr)
    exit(1)
}
