import Flutter
import UIKit

class CupertinoTabBarPlatformView: NSObject, FlutterPlatformView, UITabBarDelegate {
  private let channel: FlutterMethodChannel
  private let container: UIView
  private var tabBar: UITabBar?
  private var tabBarLeft: UITabBar?
  private var tabBarRight: UITabBar?
  private var isSplit: Bool = false
  private var rightCountVal: Int = 1
  private var currentLabels: [String] = []
  private var currentSymbols: [String] = []
  private var currentInactiveSymbols: [String] = []
  private var itemStyle: [String: Any]? = nil
  private var selectedItemStyle: [String: Any]? = nil
  private var selectionIndicatorColor: UIColor? = nil
  private var leftInsetVal: CGFloat = 0
  private var rightInsetVal: CGFloat = 0
  private var splitSpacingVal: CGFloat = 8

  init(frame: CGRect, viewId: Int64, args: Any?, messenger: FlutterBinaryMessenger) {
    self.channel = FlutterMethodChannel(name: "CupertinoNativeTabBar_\(viewId)", binaryMessenger: messenger)
    self.container = UIView(frame: frame)

    var labels: [String] = []
    var symbols: [String] = []
    var inactiveSymbols: [String] = []
    var sizes: [NSNumber] = [] // ignored; use system metrics
    var colors: [NSNumber] = [] // ignored; use tintColor
    var selectedIndex: Int = 0
    var isDark: Bool = false
    var tint: UIColor? = nil
    var bg: UIColor? = nil
    var split: Bool = false
    var rightCount: Int = 1
    var leftInset: CGFloat = 0
    var rightInset: CGFloat = 0

    if let dict = args as? [String: Any] {
      labels = (dict["labels"] as? [String]) ?? []
      symbols = (dict["sfSymbols"] as? [String]) ?? []
      inactiveSymbols = (dict["sfSymbolsInactive"] as? [String]) ?? []
      itemStyle = dict["itemStyle"] as? [String: Any]
      selectedItemStyle = dict["selectedItemStyle"] as? [String: Any]
      if let n = dict["selectionIndicatorColor"] as? NSNumber { selectionIndicatorColor = Self.colorFromARGB(n.intValue) }
      sizes = (dict["sfSymbolSizes"] as? [NSNumber]) ?? []
      colors = (dict["sfSymbolColors"] as? [NSNumber]) ?? []
      if let v = dict["selectedIndex"] as? NSNumber { selectedIndex = v.intValue }
      if let v = dict["isDark"] as? NSNumber { isDark = v.boolValue }
      if let style = dict["style"] as? [String: Any] {
        if let n = style["tint"] as? NSNumber { tint = Self.colorFromARGB(n.intValue) }
        if let n = style["backgroundColor"] as? NSNumber { bg = Self.colorFromARGB(n.intValue) }
      }
      if let s = dict["split"] as? NSNumber { split = s.boolValue }
      if let rc = dict["rightCount"] as? NSNumber { rightCount = rc.intValue }
      if let sp = dict["splitSpacing"] as? NSNumber { splitSpacingVal = CGFloat(truncating: sp) }
      // content insets controlled by Flutter padding; keep zero here
    }

    super.init()

    container.backgroundColor = .clear
    if #available(iOS 13.0, *) { container.overrideUserInterfaceStyle = isDark ? .dark : .light }

    let appearance: UITabBarAppearance? = {
    if #available(iOS 13.0, *) { let ap = UITabBarAppearance(); ap.configureWithDefaultBackground(); return ap }
    return nil
  }()
    if #available(iOS 13.0, *), let ap = appearance { self.applyItemStyling(to: ap) }
    func buildItems(_ range: Range<Int>) -> [UITabBarItem] {
      var items: [UITabBarItem] = []
      for i in range {
        let selected = (i < symbols.count) ? Self.image(named: symbols[i]) : nil
        let unselected = (i < inactiveSymbols.count) ? Self.image(named: inactiveSymbols[i]) : nil
        let title = (i < labels.count) ? labels[i] : nil
        items.append(UITabBarItem(title: title, image: unselected ?? selected, selectedImage: selected))
      }
      return items
    }
    let count = max(labels.count, symbols.count)
    if split && count > rightCount {
      let leftEnd = count - rightCount
      let left = UITabBar(frame: .zero)
      let right = UITabBar(frame: .zero)
      tabBarLeft = left; tabBarRight = right
      left.translatesAutoresizingMaskIntoConstraints = false
      right.translatesAutoresizingMaskIntoConstraints = false
      left.delegate = self; right.delegate = self
      if let bg = bg { left.barTintColor = bg; right.barTintColor = bg }
      if #available(iOS 10.0, *), let tint = tint { left.tintColor = tint; right.tintColor = tint }
      if let ap = appearance { if #available(iOS 13.0, *) { left.standardAppearance = ap; right.standardAppearance = ap } }
      left.items = buildItems(0..<leftEnd)
      right.items = buildItems(leftEnd..<count)
      if selectedIndex < leftEnd, let items = left.items {
        left.selectedItem = items[selectedIndex]
        right.selectedItem = nil
      } else if let items = right.items {
        let idx = selectedIndex - leftEnd
        if idx >= 0 && idx < items.count { right.selectedItem = items[idx] }
        left.selectedItem = nil
      }
      container.addSubview(left); container.addSubview(right)
      // Compute content-fitting widths for both bars and apply symmetric spacing
      let spacing: CGFloat = splitSpacingVal
      let leftWidth = left.sizeThatFits(.zero).width + leftInset * 2
      let rightWidth = right.sizeThatFits(.zero).width + rightInset * 2
      let total = leftWidth + rightWidth + spacing
      // If total exceeds container, fall back to proportional widths
      if total > container.bounds.width {
        let rightFraction = CGFloat(rightCount) / CGFloat(count)
        NSLayoutConstraint.activate([
          right.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -rightInset),
          right.topAnchor.constraint(equalTo: container.topAnchor),
          right.bottomAnchor.constraint(equalTo: container.bottomAnchor),
          right.widthAnchor.constraint(equalTo: container.widthAnchor, multiplier: rightFraction),
          left.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: leftInset),
          left.trailingAnchor.constraint(equalTo: right.leadingAnchor, constant: -spacing),
          left.topAnchor.constraint(equalTo: container.topAnchor),
          left.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
      } else {
        NSLayoutConstraint.activate([
          // Right bar fixed width, pinned to trailing
          right.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -rightInset),
          right.topAnchor.constraint(equalTo: container.topAnchor),
          right.bottomAnchor.constraint(equalTo: container.bottomAnchor),
          right.widthAnchor.constraint(equalToConstant: rightWidth),
          // Left bar fixed width, pinned to leading
          left.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: leftInset),
          left.topAnchor.constraint(equalTo: container.topAnchor),
          left.bottomAnchor.constraint(equalTo: container.bottomAnchor),
          left.widthAnchor.constraint(equalToConstant: leftWidth),
          // Spacing between
          left.trailingAnchor.constraint(lessThanOrEqualTo: right.leadingAnchor, constant: -spacing),
        ])
      }
    } else {
      let bar = UITabBar(frame: .zero)
      tabBar = bar
      bar.delegate = self
      bar.translatesAutoresizingMaskIntoConstraints = false
      if let bg = bg { bar.barTintColor = bg }
      if #available(iOS 10.0, *), let tint = tint { bar.tintColor = tint }
      if let ap = appearance { if #available(iOS 13.0, *) { bar.standardAppearance = ap; if #available(iOS 15.0, *) { bar.scrollEdgeAppearance = ap } } }
      bar.items = buildItems(0..<count)
      if selectedIndex >= 0, let items = bar.items, selectedIndex < items.count { bar.selectedItem = items[selectedIndex] }
      container.addSubview(bar)
      NSLayoutConstraint.activate([
        bar.leadingAnchor.constraint(equalTo: container.leadingAnchor),
        bar.trailingAnchor.constraint(equalTo: container.trailingAnchor),
        bar.topAnchor.constraint(equalTo: container.topAnchor),
        bar.bottomAnchor.constraint(equalTo: container.bottomAnchor),
      ])
    }
    // Store split settings for future updates
    self.isSplit = split
    self.rightCountVal = rightCount
    self.currentLabels = labels
    self.currentSymbols = symbols
    self.currentInactiveSymbols = inactiveSymbols
    self.leftInsetVal = leftInset
    self.rightInsetVal = rightInset
channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { result(nil); return }
      switch call.method {
      case "getIntrinsicSize":
        if let bar = self.tabBar ?? self.tabBarLeft ?? self.tabBarRight {
          let size = bar.sizeThatFits(CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude))
          result(["width": Double(size.width), "height": Double(size.height)])
        } else {
          result(["width": Double(self.container.bounds.width), "height": 50.0])
        }
      case "setItems":
        if let args = call.arguments as? [String: Any] {
          let labels = (args["labels"] as? [String]) ?? []
          let symbols = (args["sfSymbols"] as? [String]) ?? []
          let inactiveSymbols = (args["sfSymbolsInactive"] as? [String]) ?? []
          let selectedIndex = (args["selectedIndex"] as? NSNumber)?.intValue ?? 0
          self.currentLabels = labels
          self.currentSymbols = symbols
          self.currentInactiveSymbols = inactiveSymbols
          func buildItems(_ range: Range<Int>) -> [UITabBarItem] {
            var items: [UITabBarItem] = []
            for i in range {
              let selected = (i < symbols.count) ? Self.image(named: symbols[i]) : nil
              let unselected = (i < inactiveSymbols.count) ? Self.image(named: inactiveSymbols[i]) : nil
              let title = (i < labels.count) ? labels[i] : nil
              items.append(UITabBarItem(title: title, image: unselected ?? selected, selectedImage: selected))
            }
            return items
          }
          let count = max(labels.count, symbols.count)
          if self.isSplit && count > self.rightCountVal, let left = self.tabBarLeft, let right = self.tabBarRight {
            let leftEnd = count - self.rightCountVal
            left.items = buildItems(0..<leftEnd)
            right.items = buildItems(leftEnd..<count)
            if selectedIndex < leftEnd, let items = left.items { left.selectedItem = items[selectedIndex]; right.selectedItem = nil }
            else if let items = right.items {
              let idx = selectedIndex - leftEnd
              if idx >= 0 && idx < items.count { right.selectedItem = items[idx]; left.selectedItem = nil }
            }
            result(nil)
          } else if let bar = self.tabBar {
            bar.items = buildItems(0..<count)
            if let items = bar.items, selectedIndex >= 0, selectedIndex < items.count { bar.selectedItem = items[selectedIndex] }
            result(nil)
          } else {
            result(FlutterError(code: "state_error", message: "Tab bars not initialized", details: nil))
          }
        } else { result(FlutterError(code: "bad_args", message: "Missing items", details: nil)) }
      case "setLayout":
        if let args = call.arguments as? [String: Any] {
          let split = (args["split"] as? NSNumber)?.boolValue ?? false
          let rightCount = (args["rightCount"] as? NSNumber)?.intValue ?? 1
          // Insets are controlled by Flutter padding; keep stored zeros here
          let leftInset = self.leftInsetVal
          let rightInset = self.rightInsetVal
          if let sp = args["splitSpacing"] as? NSNumber { self.splitSpacingVal = CGFloat(truncating: sp) }
          let selectedIndex = (args["selectedIndex"] as? NSNumber)?.intValue ?? 0
          // Remove existing bars
          self.tabBar?.removeFromSuperview(); self.tabBar = nil
          self.tabBarLeft?.removeFromSuperview(); self.tabBarLeft = nil
          self.tabBarRight?.removeFromSuperview(); self.tabBarRight = nil
          let labels = self.currentLabels
          let symbols = self.currentSymbols
          let inactiveSymbols = self.currentInactiveSymbols
          let appearance: UITabBarAppearance? = {
            if #available(iOS 13.0, *) { let ap = UITabBarAppearance(); ap.configureWithDefaultBackground(); return ap }
            return nil
          }()
          if #available(iOS 13.0, *), let ap = appearance { self.applyItemStyling(to: ap) }
          func buildItems(_ range: Range<Int>) -> [UITabBarItem] {
            var items: [UITabBarItem] = []
            for i in range {
              let selected = (i < symbols.count) ? Self.image(named: symbols[i]) : nil
              let unselected = (i < inactiveSymbols.count) ? Self.image(named: inactiveSymbols[i]) : nil
              let title = (i < labels.count) ? labels[i] : nil
              items.append(UITabBarItem(title: title, image: unselected ?? selected, selectedImage: selected))
            }
            return items
          }
          let count = max(labels.count, symbols.count)
          if split && count > rightCount {
            let leftEnd = count - rightCount
            let left = UITabBar(frame: .zero)
            let right = UITabBar(frame: .zero)
            self.tabBarLeft = left; self.tabBarRight = right
            left.translatesAutoresizingMaskIntoConstraints = false
            right.translatesAutoresizingMaskIntoConstraints = false
            left.delegate = self; right.delegate = self
            left.items = buildItems(0..<leftEnd)
            right.items = buildItems(leftEnd..<count)
            if selectedIndex < leftEnd, let items = left.items { left.selectedItem = items[selectedIndex]; right.selectedItem = nil }
            else if let items = right.items { let idx = selectedIndex - leftEnd; if idx >= 0 && idx < items.count { right.selectedItem = items[idx]; left.selectedItem = nil } }
            self.container.addSubview(left); self.container.addSubview(right)
            let spacing: CGFloat = splitSpacingVal
            let leftWidth = left.sizeThatFits(.zero).width + leftInset * 2
            let rightWidth = right.sizeThatFits(.zero).width + rightInset * 2
            let total = leftWidth + rightWidth + spacing
            if total > self.container.bounds.width {
              let rightFraction = CGFloat(rightCount) / CGFloat(count)
              NSLayoutConstraint.activate([
                right.trailingAnchor.constraint(equalTo: self.container.trailingAnchor, constant: -rightInset),
                right.topAnchor.constraint(equalTo: self.container.topAnchor),
                right.bottomAnchor.constraint(equalTo: self.container.bottomAnchor),
                right.widthAnchor.constraint(equalTo: self.container.widthAnchor, multiplier: rightFraction),
                left.leadingAnchor.constraint(equalTo: self.container.leadingAnchor, constant: leftInset),
                left.trailingAnchor.constraint(equalTo: right.leadingAnchor, constant: -spacing),
                left.topAnchor.constraint(equalTo: self.container.topAnchor),
                left.bottomAnchor.constraint(equalTo: self.container.bottomAnchor),
              ])
            } else {
              NSLayoutConstraint.activate([
                right.trailingAnchor.constraint(equalTo: self.container.trailingAnchor, constant: -rightInset),
                right.topAnchor.constraint(equalTo: self.container.topAnchor),
                right.bottomAnchor.constraint(equalTo: self.container.bottomAnchor),
                right.widthAnchor.constraint(equalToConstant: rightWidth),
                left.leadingAnchor.constraint(equalTo: self.container.leadingAnchor, constant: leftInset),
                left.topAnchor.constraint(equalTo: self.container.topAnchor),
                left.bottomAnchor.constraint(equalTo: self.container.bottomAnchor),
                left.widthAnchor.constraint(equalToConstant: leftWidth),
                left.trailingAnchor.constraint(lessThanOrEqualTo: right.leadingAnchor, constant: -spacing),
              ])
            }
          } else {
            let bar = UITabBar(frame: .zero)
            self.tabBar = bar
            bar.delegate = self
            bar.translatesAutoresizingMaskIntoConstraints = false
            bar.items = buildItems(0..<count)
            if let items = bar.items, selectedIndex >= 0, selectedIndex < items.count { bar.selectedItem = items[selectedIndex] }
            self.container.addSubview(bar)
            NSLayoutConstraint.activate([
              bar.leadingAnchor.constraint(equalTo: self.container.leadingAnchor),
              bar.trailingAnchor.constraint(equalTo: self.container.trailingAnchor),
              bar.topAnchor.constraint(equalTo: self.container.topAnchor),
              bar.bottomAnchor.constraint(equalTo: self.container.bottomAnchor),
            ])
          }
          self.isSplit = split; self.rightCountVal = rightCount; self.leftInsetVal = leftInset; self.rightInsetVal = rightInset
          result(nil)
        } else { result(FlutterError(code: "bad_args", message: "Missing layout", details: nil)) }
      case "setSelectedIndex":
        if let args = call.arguments as? [String: Any], let idx = (args["index"] as? NSNumber)?.intValue {
          // Single bar
          if let bar = self.tabBar, let items = bar.items, idx >= 0, idx < items.count {
            bar.selectedItem = items[idx]
            result(nil)
            return
          }
          // Split bars
          if let left = self.tabBarLeft, let leftItems = left.items {
            if idx < leftItems.count, idx >= 0 {
              left.selectedItem = leftItems[idx]
              self.tabBarRight?.selectedItem = nil
              result(nil)
              return
            }
            if let right = self.tabBarRight, let rightItems = right.items {
              let ridx = idx - leftItems.count
              if ridx >= 0, ridx < rightItems.count {
                right.selectedItem = rightItems[ridx]
                self.tabBarLeft?.selectedItem = nil
                result(nil)
                return
              }
            }
          }
          result(FlutterError(code: "bad_args", message: "Index out of range", details: nil))
        } else { result(FlutterError(code: "bad_args", message: "Missing index", details: nil)) }
      case "setStyle":
        if let args = call.arguments as? [String: Any] {
          if let n = args["tint"] as? NSNumber {
            let c = Self.colorFromARGB(n.intValue)
            if let bar = self.tabBar { bar.tintColor = c }
            if let left = self.tabBarLeft { left.tintColor = c }
            if let right = self.tabBarRight { right.tintColor = c }
          }
          if let n = args["backgroundColor"] as? NSNumber {
            let c = Self.colorFromARGB(n.intValue)
            if let bar = self.tabBar { bar.barTintColor = c }
            if let left = self.tabBarLeft { left.barTintColor = c }
            if let right = self.tabBarRight { right.barTintColor = c }
          }
          result(nil)
        } else { result(FlutterError(code: "bad_args", message: "Missing style", details: nil)) }
      case "setBrightness":
        if let args = call.arguments as? [String: Any], let isDark = (args["isDark"] as? NSNumber)?.boolValue {
          if #available(iOS 13.0, *) { self.container.overrideUserInterfaceStyle = isDark ? .dark : .light }
          result(nil)
        } else { result(FlutterError(code: "bad_args", message: "Missing isDark", details: nil)) }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  func view() -> UIView { container }

  func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
    // Single bar case
    if let single = self.tabBar, single === tabBar, let items = single.items, let idx = items.firstIndex(of: item) {
      channel.invokeMethod("valueChanged", arguments: ["index": idx])
      return
    }
    // Split left
    if let left = tabBarLeft, left === tabBar, let items = left.items, let idx = items.firstIndex(of: item) {
      tabBarRight?.selectedItem = nil
      channel.invokeMethod("valueChanged", arguments: ["index": idx])
      return
    }
    // Split right
    if let right = tabBarRight, right === tabBar, let items = right.items, let idx = items.firstIndex(of: item), let left = tabBarLeft, let leftItems = left.items {
      tabBarLeft?.selectedItem = nil
      channel.invokeMethod("valueChanged", arguments: ["index": leftItems.count + idx])
      return
    }
  }

  /// Paints the label and template icon of each selection state, and the
  /// indicator behind the selected one.
  @available(iOS 13.0, *)
  private func applyItemStyling(to appearance: UITabBarAppearance) {
    let item = UITabBarItemAppearance()
    Self.style(item.normal, from: itemStyle)
    Self.style(item.selected, from: selectedItemStyle)
    appearance.stackedLayoutAppearance = item
    appearance.inlineLayoutAppearance = item
    appearance.compactInlineLayoutAppearance = item
    if let indicator = selectionIndicatorColor { appearance.selectionIndicatorTintColor = indicator }
  }

  @available(iOS 13.0, *)
  private static func style(_ state: UITabBarItemStateAppearance, from spec: [String: Any]?) {
    guard let spec = spec else { return }
    var attributes = state.titleTextAttributes
    if let n = spec["color"] as? NSNumber {
      let color = colorFromARGB(n.intValue)
      attributes[.foregroundColor] = color
      state.iconColor = color
    }
    let size = (spec["fontSize"] as? NSNumber).map { CGFloat(truncating: $0) } ?? UIFont.smallSystemFontSize
    if let w = spec["fontWeight"] as? NSNumber {
      attributes[.font] = UIFont.systemFont(ofSize: size, weight: fontWeight(w.intValue))
    } else if spec["fontSize"] != nil {
      attributes[.font] = UIFont.systemFont(ofSize: size)
    }
    state.titleTextAttributes = attributes
  }

  private static func fontWeight(_ value: Int) -> UIFont.Weight {
    switch value {
    case ..<150: return .ultraLight
    case ..<250: return .thin
    case ..<350: return .light
    case ..<450: return .regular
    case ..<550: return .medium
    case ..<650: return .semibold
    case ..<750: return .bold
    case ..<850: return .heavy
    default: return .black
    }
  }

  /// Resolves a name to an SF Symbol, falling back to an asset catalog image.
  private static func image(named name: String) -> UIImage? {
    guard !name.isEmpty else { return nil }
    return UIImage(systemName: name) ?? UIImage(named: name)
  }

  private static func colorFromARGB(_ argb: Int) -> UIColor {
    let a = CGFloat((argb >> 24) & 0xFF) / 255.0
    let r = CGFloat((argb >> 16) & 0xFF) / 255.0
    let g = CGFloat((argb >> 8) & 0xFF) / 255.0
    let b = CGFloat(argb & 0xFF) / 255.0
    return UIColor(red: r, green: g, blue: b, alpha: a)
  }
}
