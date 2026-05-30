// AUTO-GENERATED from gstack/ios-qa/templates/Bridges.swift.template
// HermesiOS local additions: full DEBUG-only gstack QA bridge for screenshots,
// accessibility elements, tap, swipe, and type interactions.

#if DEBUG && canImport(UIKit)

import Foundation
import UIKit

@MainActor
public enum DebugBridgeUIWiring {
    /// Install all bridge resolvers. Idempotent and DEBUG-only.
    public static func installAll() {
        ScreenshotBridge.resolver = { ScreenshotBridgeImpl.capturePNG() }
        ElementsBridge.resolver = { ElementsBridgeImpl.snapshot() }
        MutationBridge.resolver = { op, payload in MutationBridgeImpl.dispatch(op: op, payload: payload) }
    }
}

// MARK: - ScreenshotBridge implementation

@MainActor
enum ScreenshotBridgeImpl {
    static func capturePNG() -> Data? {
        guard let scene = activeScene(), let window = activeKeyWindow(in: scene) else { return nil }
        let bounds = window.bounds
        let format = UIGraphicsImageRendererFormat()
        format.scale = window.screen.scale
        format.opaque = window.isOpaque
        let renderer = UIGraphicsImageRenderer(bounds: bounds, format: format)
        let image = renderer.image { _ in
            window.drawHierarchy(in: bounds, afterScreenUpdates: false)
        }
        return image.pngData()
    }
}

// MARK: - ElementsBridge implementation

@MainActor
enum ElementsBridgeImpl {
    static func snapshot() -> [JSONDict] {
        guard let scene = activeScene(), let window = activeKeyWindow(in: scene) else {
            DebugBridgeElementRegistry.shared.replace(entries: [])
            return []
        }

        var builder = ElementSnapshotBuilder(window: window)
        builder.collect(view: window, parentPath: "", depth: 0)
        DebugBridgeElementRegistry.shared.replace(entries: builder.registryEntries)
        return builder.elements
    }
}

@MainActor
private final class DebugBridgeElementRegistry {
    static let shared = DebugBridgeElementRegistry()

    struct Entry {
        let id: String
        let stableID: String
        weak var target: NSObject?
        weak var window: UIWindow?
        let frame: CGRect
        let path: String
    }

    private var entriesByID: [String: Entry] = [:]
    private var orderedEntries: [Entry] = []

    func replace(entries: [Entry]) {
        orderedEntries = entries
        entriesByID = Dictionary(uniqueKeysWithValues: entries.map { ($0.id, $0) })
    }

    func resolve(payload: JSONDict) -> Entry? {
        refreshIfEmpty()
        if let id = DebugBridgePayload.string(payload, keys: ["element_id", "id"]), let entry = entriesByID[id] {
            return entry
        }
        if let identifier = DebugBridgePayload.string(payload, keys: ["identifier", "accessibility_identifier"]) {
            return orderedEntries.first { accessibilityIdentifier(for: $0.target) == identifier }
        }
        if let label = DebugBridgePayload.string(payload, keys: ["label", "text", "name"]) {
            return orderedEntries.first { ($0.target?.accessibilityLabel ?? "").localizedCaseInsensitiveContains(label) }
        }
        if let point = DebugBridgePayload.point(payload) {
            return entry(at: point)
        }
        return nil
    }

    func entry(at point: CGPoint) -> Entry? {
        refreshIfEmpty()
        return orderedEntries.reversed().first { $0.frame.contains(point) }
    }

    private func refreshIfEmpty() {
        guard orderedEntries.isEmpty else { return }
        _ = ElementsBridgeImpl.snapshot()
    }
}

@MainActor
private struct ElementSnapshotBuilder {
    private weak var window: UIWindow?
    private var nextID = 0
    var elements: [JSONDict] = []
    var registryEntries: [DebugBridgeElementRegistry.Entry] = []

    init(window: UIWindow) {
        self.window = window
    }

    mutating func collect(view: UIView, parentPath: String, depth: Int) {
        guard let window else { return }
        guard !view.isHidden, view.alpha >= 0.01 else { return }

        let frame = view.convert(view.bounds, to: window)
        guard window.bounds.intersects(frame) else { return }

        let className = String(describing: type(of: view))
        let path = parentPath.isEmpty ? className : "\(parentPath) > \(className)"
        let isInteractive = view is UIControl || view is UIScrollView || view is UITextInput
        let isHosting = className.contains("Hosting") || className.contains("SwiftUI")
        let shouldEmit = view.isAccessibilityElement
            || !(view.accessibilityLabel ?? "").isEmpty
            || !(view.accessibilityIdentifier ?? "").isEmpty
            || isInteractive
            || isHosting

        if shouldEmit {
            append(target: view, frame: frame, path: path, depth: depth, isUserInteractionEnabled: view.isUserInteractionEnabled)
        }

        _ = view.accessibilityElementCount()
        if let axElements = view.accessibilityElements, !axElements.isEmpty {
            for (index, rawElement) in axElements.enumerated() {
                if let childView = rawElement as? UIView {
                    collect(view: childView, parentPath: path, depth: depth + 1)
                } else if let object = rawElement as? NSObject {
                    append(accessibilityObject: object, parentPath: path, index: index, depth: depth + 1)
                }
            }
        } else {
            let count = view.accessibilityElementCount()
            if count > 0 {
                for index in 0..<count {
                    guard let object = view.accessibilityElement(at: index) as? NSObject else { continue }
                    if let childView = object as? UIView {
                        collect(view: childView, parentPath: path, depth: depth + 1)
                    } else {
                        append(accessibilityObject: object, parentPath: path, index: index, depth: depth + 1)
                    }
                }
            }
        }

        for subview in view.subviews {
            collect(view: subview, parentPath: path, depth: depth + 1)
        }
    }

    private mutating func append(accessibilityObject object: NSObject, parentPath: String, index: Int, depth: Int) {
        guard let window else { return }
        let className = String(describing: type(of: object))
        let path = "\(parentPath) > \(className)[\(index)]"
        let screenFrame = object.accessibilityFrame
        let frame = window.convert(screenFrame, from: nil)
        guard frame.isFiniteNonEmpty, window.bounds.intersects(frame) else { return }
        append(target: object, frame: frame, path: path, depth: depth, isUserInteractionEnabled: true)
    }

    private mutating func append(target: NSObject, frame: CGRect, path: String, depth: Int, isUserInteractionEnabled: Bool) {
        guard let window else { return }
        let id = "e\(nextID)"
        nextID += 1
        let label = target.accessibilityLabel ?? ""
        let identifier = accessibilityIdentifier(for: target)
        let value = target.accessibilityValue ?? ""
        let traits = target.accessibilityTraits
        let role = roleName(for: traits, target: target)
        let stableID = stableElementID(identifier: identifier, label: label, path: path, role: role)
        let enabled = !traits.contains(.notEnabled)
        let center = CGPoint(x: frame.midX, y: frame.midY)
        let hittable = frame.isFiniteNonEmpty && window.bounds.contains(center) && isUserInteractionEnabled && enabled

        elements.append([
            "id": id,
            "stable_id": stableID,
            "path": path,
            "depth": depth,
            "class": String(describing: type(of: target)),
            "role": role,
            "label": label,
            "identifier": identifier,
            "value": value,
            "traits": NSNumber(value: Int64(bitPattern: traits.rawValue)),
            "frame": frame.jsonDictionary,
            "center": ["x": NSNumber(value: Double(center.x)), "y": NSNumber(value: Double(center.y))],
            "enabled": enabled,
            "selected": traits.contains(.selected),
            "hittable": hittable,
            "is_user_interaction_enabled": isUserInteractionEnabled,
        ])

        registryEntries.append(DebugBridgeElementRegistry.Entry(
            id: id,
            stableID: stableID,
            target: target,
            window: window,
            frame: frame,
            path: path
        ))
    }

    private func roleName(for traits: UIAccessibilityTraits, target: NSObject) -> String {
        if target is UITextField || target is UITextView || traits.contains(.searchField) { return "text_input" }
        if traits.contains(.button) { return "button" }
        if traits.contains(.link) { return "link" }
        if traits.contains(.image) { return "image" }
        if traits.contains(.header) { return "header" }
        if traits.contains(.keyboardKey) { return "keyboard_key" }
        if target is UIScrollView { return "scroll_view" }
        if target is UIControl { return "control" }
        return "element"
    }

    private func stableElementID(identifier: String, label: String, path: String, role: String) -> String {
        if !identifier.isEmpty { return "identifier:\(identifier)" }
        if !label.isEmpty { return "label:\(role):\(label)" }
        return "path:\(path)"
    }
}

// MARK: - MutationBridge implementation

@MainActor
enum MutationBridgeImpl {
    static func dispatch(op: String, payload: JSONDict) -> BridgeMutationResult {
        switch op {
        case "tap": return handleTap(payload)
        case "type": return handleType(payload)
        case "swipe": return handleSwipe(payload)
        default: return .failure("unknown_mutation", ["supported": ["tap", "type", "swipe"]])
        }
    }

    private static func handleTap(_ payload: JSONDict) -> BridgeMutationResult {
        guard let scene = activeScene(), let window = activeKeyWindow(in: scene) else {
            return .failure("window_unavailable")
        }

        let resolved = DebugBridgeElementRegistry.shared.resolve(payload: payload)
        let point = DebugBridgePayload.point(payload) ?? resolved?.frame.center
        if let target = resolved?.target, let result = activate(target: target, point: point, window: resolved?.window ?? window) {
            return result
        }

        guard let point else { return .failure("missing_target", ["accepted": ["element_id", "id", "identifier", "label", "x/y"]]) }
        guard window.bounds.contains(point), let hit = window.hitTest(point, with: nil) else {
            return .failure("no_hit_target", ["point": point.jsonDictionary])
        }

        var node: UIView? = hit
        while let current = node {
            if let result = activate(target: current, point: point, window: window) {
                return result
            }
            node = current.superview
        }
        return .failure("no_actionable_target", ["point": point.jsonDictionary, "hit_class": String(describing: type(of: hit))])
    }

    private static func handleType(_ payload: JSONDict) -> BridgeMutationResult {
        let text = DebugBridgePayload.string(payload, keys: ["text", "value", "input"]) ?? ""
        let shouldClear = DebugBridgePayload.bool(payload, keys: ["clear", "replace"], defaultValue: true)
        let shouldAppend = DebugBridgePayload.bool(payload, keys: ["append"], defaultValue: false)
        let shouldSubmit = DebugBridgePayload.bool(payload, keys: ["submit", "return", "press_return"], defaultValue: false)

        if DebugBridgePayload.hasTarget(payload) {
            _ = handleTap(payload)
        }

        guard let scene = activeScene(), let window = activeKeyWindow(in: scene) else {
            return .failure("window_unavailable")
        }
        guard let responder = findFirstResponder(in: window) else {
            return .failure("no_first_responder")
        }

        if let field = responder as? UITextField {
            if shouldAppend {
                field.insertText(text)
            } else {
                replaceText(in: field, text: shouldClear ? text : ((field.text ?? "") + text))
            }
            field.sendActions(for: .editingChanged)
            if shouldSubmit {
                field.sendActions(for: .editingDidEndOnExit)
            }
            return .success(["target": "UITextField", "submitted": shouldSubmit])
        }

        if let textView = responder as? UITextView {
            if shouldAppend {
                textView.insertText(text)
            } else {
                replaceText(in: textView, text: shouldClear ? text : (textView.text + text))
            }
            textView.delegate?.textViewDidChange?(textView)
            if shouldSubmit { textView.insertText("\n") }
            return .success(["target": "UITextView", "submitted": shouldSubmit])
        }

        if let textInput = responder as? (UIResponder & UITextInput) {
            textInput.insertText(text)
            return .success(["target": String(describing: type(of: responder)), "submitted": false])
        }

        return .failure("first_responder_not_text_input", ["responder": String(describing: type(of: responder))])
    }

    private static func handleSwipe(_ payload: JSONDict) -> BridgeMutationResult {
        guard let scene = activeScene(), let window = activeKeyWindow(in: scene) else {
            return .failure("window_unavailable")
        }

        let resolved = DebugBridgeElementRegistry.shared.resolve(payload: payload)
        let direction = DebugBridgePayload.string(payload, keys: ["direction"])
        if let target = resolved?.target, let direction, let axDirection = accessibilityScrollDirection(direction) {
            if target.accessibilityScroll(axDirection) {
                return .success(["action": "accessibility_scroll", "direction": direction])
            }
        }

        let fromPoint = DebugBridgePayload.point(payload, xKeys: ["from_x", "start_x", "x"], yKeys: ["from_y", "start_y", "y"])
            ?? resolved?.frame.center
            ?? CGPoint(x: window.bounds.midX, y: window.bounds.midY)
        let toPoint = DebugBridgePayload.point(payload, xKeys: ["to_x", "end_x"], yKeys: ["to_y", "end_y"])
        let vector = swipeVector(payload: payload, window: window, from: fromPoint, to: toPoint)

        guard let scroll = nearestScrollView(from: resolved?.target, point: fromPoint, window: window) else {
            return .failure("scroll_view_not_found", ["point": fromPoint.jsonDictionary])
        }

        let maxX = max(0, scroll.contentSize.width - scroll.bounds.width + scroll.adjustedContentInset.right)
        let maxY = max(0, scroll.contentSize.height - scroll.bounds.height + scroll.adjustedContentInset.bottom)
        let targetOffset = CGPoint(
            x: max(-scroll.adjustedContentInset.left, min(maxX, scroll.contentOffset.x + vector.dx)),
            y: max(-scroll.adjustedContentInset.top, min(maxY, scroll.contentOffset.y + vector.dy))
        )
        scroll.setContentOffset(targetOffset, animated: false)
        scroll.layoutIfNeeded()
        return .success([
            "action": "content_offset",
            "dx": NSNumber(value: Double(vector.dx)),
            "dy": NSNumber(value: Double(vector.dy)),
            "content_offset": targetOffset.jsonDictionary,
            "scroll_class": String(describing: type(of: scroll)),
        ])
    }

    private static func activate(target: NSObject, point: CGPoint?, window: UIWindow) -> BridgeMutationResult? {
        if let field = target as? UITextField {
            _ = field.becomeFirstResponder()
            return .success(["action": "focus", "target": "UITextField"])
        }
        if let textView = target as? UITextView {
            _ = textView.becomeFirstResponder()
            return .success(["action": "focus", "target": "UITextView"])
        }
        if target.accessibilityActivate() {
            return .success(["action": "accessibility_activate", "target": String(describing: type(of: target))])
        }
        guard let view = target as? UIView else { return nil }

        if let field = nearestAncestor(of: view, matching: UITextField.self) {
            _ = field.becomeFirstResponder()
            return .success(["action": "focus", "target": "UITextField"])
        }
        if let textView = nearestAncestor(of: view, matching: UITextView.self) {
            _ = textView.becomeFirstResponder()
            return .success(["action": "focus", "target": "UITextView"])
        }
        if let control = nearestAncestor(of: view, matching: UIControl.self) {
            if let segmented = control as? UISegmentedControl, let point {
                let local = segmented.convert(point, from: window)
                let width = max(segmented.bounds.width / CGFloat(max(segmented.numberOfSegments, 1)), 1)
                let index = min(max(Int(local.x / width), 0), max(segmented.numberOfSegments - 1, 0))
                segmented.selectedSegmentIndex = index
                segmented.sendActions(for: .valueChanged)
                return .success(["action": "segmented_value_changed", "segment": index])
            }
            if let toggle = control as? UISwitch {
                toggle.setOn(!toggle.isOn, animated: true)
                toggle.sendActions(for: .valueChanged)
                return .success(["action": "switch_value_changed", "is_on": toggle.isOn])
            }
            control.sendActions(for: .touchDown)
            control.sendActions(for: .primaryActionTriggered)
            control.sendActions(for: .touchUpInside)
            return .success(["action": "control_events", "target": String(describing: type(of: control))])
        }
        return nil
    }

    private static func replaceText(in input: UITextInput, text: String) {
        let start = input.beginningOfDocument
        let end = input.endOfDocument
        if let range = input.textRange(from: start, to: end) {
            input.replace(range, withText: text)
        } else {
            input.insertText(text)
        }
    }

    private static func findFirstResponder(in view: UIView) -> UIResponder? {
        if view.isFirstResponder { return view }
        for subview in view.subviews {
            if let found = findFirstResponder(in: subview) { return found }
        }
        return nil
    }

    private static func nearestScrollView(from target: NSObject?, point: CGPoint, window: UIWindow) -> UIScrollView? {
        if let view = target as? UIView, let scroll = nearestAncestor(of: view, matching: UIScrollView.self) {
            return scroll
        }
        if let hit = window.hitTest(point, with: nil), let scroll = nearestAncestor(of: hit, matching: UIScrollView.self) {
            return scroll
        }
        return findFirstScrollView(in: window)
    }

    private static func findFirstScrollView(in view: UIView) -> UIScrollView? {
        if let scroll = view as? UIScrollView, scroll.contentSize.height > scroll.bounds.height || scroll.contentSize.width > scroll.bounds.width {
            return scroll
        }
        for subview in view.subviews {
            if let found = findFirstScrollView(in: subview) { return found }
        }
        return nil
    }

    private static func nearestAncestor<T: UIView>(of view: UIView, matching type: T.Type) -> T? {
        var current: UIView? = view
        while let node = current {
            if let typed = node as? T { return typed }
            current = node.superview
        }
        return nil
    }

    private static func swipeVector(payload: JSONDict, window: UIWindow, from: CGPoint, to: CGPoint?) -> (dx: CGFloat, dy: CGFloat) {
        if let to {
            return (dx: from.x - to.x, dy: from.y - to.y)
        }
        let distance = DebugBridgePayload.cgFloat(payload, keys: ["distance", "amount"])
            ?? max(80, min(window.bounds.width, window.bounds.height) * 0.55)
        switch DebugBridgePayload.string(payload, keys: ["direction"])?.lowercased() {
        case "down": return (dx: 0, dy: -distance)
        case "left": return (dx: distance, dy: 0)
        case "right": return (dx: -distance, dy: 0)
        default: return (dx: 0, dy: distance)
        }
    }

    private static func accessibilityScrollDirection(_ direction: String) -> UIAccessibilityScrollDirection? {
        switch direction.lowercased() {
        case "up": return .up
        case "down": return .down
        case "left": return .left
        case "right": return .right
        case "next": return .next
        case "previous", "prev": return .previous
        default: return nil
        }
    }
}

// MARK: - Shared helpers

private func accessibilityIdentifier(for target: NSObject?) -> String {
    (target as? UIAccessibilityIdentification)?.accessibilityIdentifier ?? ""
}

@MainActor
private func activeScene() -> UIWindowScene? {
    UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .first { $0.activationState == .foregroundActive }
        ?? (UIApplication.shared.connectedScenes.first as? UIWindowScene)
}

@MainActor
private func activeKeyWindow(in scene: UIWindowScene) -> UIWindow? {
    scene.windows.first(where: { $0.isKeyWindow }) ?? scene.windows.first
}

private enum DebugBridgePayload {
    static func hasTarget(_ payload: JSONDict) -> Bool {
        string(payload, keys: ["element_id", "id", "identifier", "accessibility_identifier", "label", "name"]) != nil || point(payload) != nil
    }

    static func point(_ payload: JSONDict) -> CGPoint? {
        point(payload, xKeys: ["x", "tap_x", "center_x"], yKeys: ["y", "tap_y", "center_y"])
    }

    static func point(_ payload: JSONDict, xKeys: [String], yKeys: [String]) -> CGPoint? {
        guard let x = cgFloat(payload, keys: xKeys), let y = cgFloat(payload, keys: yKeys) else { return nil }
        return CGPoint(x: x, y: y)
    }

    static func cgFloat(_ payload: JSONDict, keys: [String]) -> CGFloat? {
        for key in keys {
            if let number = payload[key] as? NSNumber { return CGFloat(truncating: number) }
            if let double = payload[key] as? Double { return CGFloat(double) }
            if let int = payload[key] as? Int { return CGFloat(int) }
            if let string = payload[key] as? String, let double = Double(string) { return CGFloat(double) }
        }
        return nil
    }

    static func string(_ payload: JSONDict, keys: [String]) -> String? {
        for key in keys {
            if let value = payload[key] as? String, !value.isEmpty { return value }
        }
        return nil
    }

    static func bool(_ payload: JSONDict, keys: [String], defaultValue: Bool) -> Bool {
        for key in keys {
            if let value = payload[key] as? Bool { return value }
            if let number = payload[key] as? NSNumber { return number.boolValue }
            if let string = payload[key] as? String {
                switch string.lowercased() {
                case "true", "yes", "1": return true
                case "false", "no", "0": return false
                default: break
                }
            }
        }
        return defaultValue
    }
}

private extension CGRect {
    var isFiniteNonEmpty: Bool {
        origin.x.isFinite && origin.y.isFinite && size.width.isFinite && size.height.isFinite && width > 0 && height > 0
    }

    var center: CGPoint { CGPoint(x: midX, y: midY) }

    var jsonDictionary: JSONDict {
        [
            "x": NSNumber(value: Double(origin.x)),
            "y": NSNumber(value: Double(origin.y)),
            "w": NSNumber(value: Double(size.width)),
            "h": NSNumber(value: Double(size.height)),
        ]
    }
}

private extension CGPoint {
    var jsonDictionary: JSONDict {
        [
            "x": NSNumber(value: Double(x)),
            "y": NSNumber(value: Double(y)),
        ]
    }
}

#endif // DEBUG && canImport(UIKit)
