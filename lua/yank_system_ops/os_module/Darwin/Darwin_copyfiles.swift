#!/usr/bin/env swift
import Foundation
import AppKit

let args = CommandLine.arguments.dropFirst() // skip script name

guard !args.isEmpty else {
    fputs("No files provided\n", stderr)
    exit(1)
}

var urls: [URL] = []

for path in args {
    let url = URL(fileURLWithPath: path)
    guard FileManager.default.fileExists(atPath: url.path) else {
        fputs("File not found: \(path)\n", stderr)
        continue
    }
    urls.append(url)
}

if urls.isEmpty {
    fputs("No valid files to copy\n", stderr)
    exit(1)
}

let pasteboard = NSPasteboard.general
pasteboard.clearContents()
pasteboard.writeObjects(urls as [NSPasteboardWriting])
