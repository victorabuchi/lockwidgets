import AppKit
import ApplicationServices

/// Reads the lyrics Apple Music itself is showing, through the Accessibility API.
/// Apple doesn't offer its lyrics to other apps, so this mirrors Music's own lyrics view.
enum MusicLyricsReader {
    static var isTrusted: Bool { AXIsProcessTrusted() }

    /// Shows the system prompt that sends the user to Accessibility settings.
    static func requestTrust() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    static func openAccessibilitySettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }

    static var musicApp: AXUIElement? {
        NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Music").first
            .map { AXUIElementCreateApplication($0.processIdentifier) }
    }

    // MARK: Diagnostics

    /// Writes Music's accessibility tree to a text file, to learn how its lyrics view is built.
    static func dumpTree(to url: URL) {
        guard let app = musicApp else {
            try? "Music is not running".write(to: url, atomically: true, encoding: .utf8)
            return
        }
        var lines: [String] = []
        dump(app, depth: 0, into: &lines)
        try? lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
    }

    private static func dump(_ element: AXUIElement, depth: Int, into lines: inout [String]) {
        guard depth < 40, lines.count < 20000 else { return }
        var names: CFArray?
        AXUIElementCopyAttributeNames(element, &names)
        let attributes = (names as? [String]) ?? []
        var parts = [string(element, kAXRoleAttribute) ?? "?"]
        for key in [kAXSubroleAttribute, kAXIdentifierAttribute, kAXTitleAttribute, kAXDescriptionAttribute, kAXValueAttribute, kAXRoleDescriptionAttribute] {
            if let value = string(element, key), !value.isEmpty {
                parts.append("\(key)=\(value.prefix(120).replacingOccurrences(of: "\n", with: "⏎"))")
            }
        }
        for key in ["AXSelected", "AXFocused", "AXEnabled"] where attributes.contains(key) {
            var value: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, key as CFString, &value) == .success, let flag = value as? Bool, flag {
                parts.append(key)
            }
        }
        var frame = CGRect.zero
        var positionValue: CFTypeRef?
        var sizeValue: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &positionValue) == .success,
           AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeValue) == .success
        {
            AXValueGetValue(positionValue as! AXValue, .cgPoint, &frame.origin)
            AXValueGetValue(sizeValue as! AXValue, .cgSize, &frame.size)
            parts.append("frame=\(Int(frame.minX)),\(Int(frame.minY)) \(Int(frame.width))x\(Int(frame.height))")
        }
        let extra = attributes.filter { !["AXRole", "AXSubrole", "AXIdentifier", "AXTitle", "AXDescription", "AXValue", "AXRoleDescription", "AXChildren", "AXParent", "AXPosition", "AXSize", "AXWindow", "AXTopLevelUIElement", "AXFrame", "AXSelected", "AXFocused", "AXEnabled"].contains($0) }
        if !extra.isEmpty { parts.append("attrs=\(extra.joined(separator: ","))") }
        lines.append(String(repeating: "  ", count: depth) + parts.joined(separator: " | "))

        var children: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children) == .success,
           let list = children as? [AXUIElement]
        {
            for child in list { dump(child, depth: depth + 1, into: &lines) }
        }
    }

    static func string(_ element: AXUIElement, _ attribute: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        if let text = value as? String { return text }
        if let attributed = value as? NSAttributedString { return attributed.string }
        return nil
    }
}
