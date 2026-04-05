//  Copyright © MonitorControl. @JoniVR, @theOneyouseek, @waydabber and others

import AppKit
import os.log

class MenuHandler: NSMenu, NSMenuDelegate {
  var combinedSliderHandler: [Command: SliderHandler] = [:]

  var lastMenuRelevantDisplayId: CGDirectDisplayID = 0

  func clearMenu() {
    var items: [NSMenuItem] = []
    for i in 0 ..< self.items.count {
      items.append(self.items[i])
    }
    for item in items {
      self.removeItem(item)
    }
    self.combinedSliderHandler.removeAll()
  }

  func menuWillOpen(_: NSMenu) {
    self.updateMenuRelevantDisplay()
    app.keyboardShortcuts.disengage()
  }

  func closeMenu() {
    self.cancelTrackingWithoutAnimation()
  }

  func updateMenus(dontClose: Bool = false) {
    os_log("Menu update initiated", type: .info)
    if !dontClose {
      self.cancelTrackingWithoutAnimation()
    }
    let menuIconPref = prefs.integer(forKey: PrefKey.menuIcon.rawValue)
    var showIcon = false
    if menuIconPref == MenuIcon.show.rawValue {
      showIcon = true
    } else if menuIconPref == MenuIcon.externalOnly.rawValue {
      let externalDisplays = DisplayManager.shared.displays.filter {
        CGDisplayIsBuiltin($0.identifier) == 0
      }
      if externalDisplays.count > 0 {
        showIcon = true
      }
    }
    app.updateStatusItemVisibility(showIcon)
    self.clearMenu()
    let currentDisplay = DisplayManager.shared.getCurrentDisplay()
    var displays: [Display] = []
    if !prefs.bool(forKey: PrefKey.hideAppleFromMenu.rawValue) {
      displays.append(contentsOf: DisplayManager.shared.getAppleDisplays())
    }
    displays.append(contentsOf: DisplayManager.shared.getOtherDisplays())
    displays = displays.sorted { lhs, rhs in
      let lhsTitle = lhs.readPrefAsString(key: .friendlyName).isEmpty
        ? lhs.name
        : lhs.readPrefAsString(key: .friendlyName)
      let rhsTitle = rhs.readPrefAsString(key: .friendlyName).isEmpty
        ? rhs.name
        : rhs.readPrefAsString(key: .friendlyName)
      return lhsTitle.localizedStandardCompare(rhsTitle) == .orderedDescending
    }
    let relevant = prefs.integer(forKey: PrefKey.multiSliders.rawValue) == MultiSliders.relevant.rawValue
    let combine = prefs.integer(forKey: PrefKey.multiSliders.rawValue) == MultiSliders.combine.rawValue
    let numOfDisplays = displays.filter { !$0.isDummy }.count
    if numOfDisplays != 0 {
      let asSubMenu: Bool = (displays.count > 3 && !relevant && !combine && app.macOS10()) ? true : false
      var iterator = 0
      for display in displays where (!relevant || DisplayManager.resolveEffectiveDisplayID(display.identifier) == DisplayManager.resolveEffectiveDisplayID(currentDisplay!.identifier)) && !display.isDummy {
        iterator += 1
        if !relevant, !combine, iterator != 1, app.macOS10() {
          self.insertItem(NSMenuItem.separator(), at: 0)
        }
        self.updateDisplayMenu(display: display, asSubMenu: asSubMenu, numOfDisplays: numOfDisplays)
      }
      if combine {
        self.addCombinedDisplayMenuBlock()
      }
    }
    self.addDefaultMenuOptions()
  }

  func addSliderItem(monitorSubMenu: NSMenu, sliderHandler: SliderHandler) {
    let item = NSMenuItem()
    item.view = sliderHandler.view
    monitorSubMenu.insertItem(item, at: 0)
    if app.macOS10() {
      let sliderHeaderItem = NSMenuItem()
      let attrs: [NSAttributedString.Key: Any] = [.foregroundColor: NSColor.systemGray, .font: NSFont.systemFont(ofSize: 12)]
      sliderHeaderItem.attributedTitle = NSAttributedString(string: sliderHandler.title, attributes: attrs)
      monitorSubMenu.insertItem(sliderHeaderItem, at: 0)
    }
  }

  func setupMenuSliderHandler(command: Command, display: Display, title: String) -> SliderHandler {
    if prefs.integer(forKey: PrefKey.multiSliders.rawValue) == MultiSliders.combine.rawValue, let combinedHandler = self.combinedSliderHandler[command] {
      combinedHandler.addDisplay(display)
      display.sliderHandler[command] = combinedHandler
      return combinedHandler
    } else {
      let sliderHandler = SliderHandler(display: display, command: command, title: title)
      if prefs.integer(forKey: PrefKey.multiSliders.rawValue) == MultiSliders.combine.rawValue {
        self.combinedSliderHandler[command] = sliderHandler
      }
      display.sliderHandler[command] = sliderHandler
      return sliderHandler
    }
  }

  func addDisplayMenuBlock(addedSliderHandlers: [SliderHandler], blockName: String, monitorSubMenu: NSMenu, numOfDisplays: Int, asSubMenu: Bool) {
    if #available(macOS 26.0, *), !asSubMenu, prefs.integer(forKey: PrefKey.multiSliders.rawValue) != MultiSliders.relevant.rawValue, addedSliderHandlers.count > 0 {
      let item = NSMenuItem()
      item.view = MenuDisplayGlassBlockView(
        title: blockName,
        sliderViews: addedSliderHandlers.compactMap(\.view)
      )
      monitorSubMenu.insertItem(item, at: 0)
      return
    } else if numOfDisplays > 1, prefs.integer(forKey: PrefKey.multiSliders.rawValue) != MultiSliders.relevant.rawValue, !DEBUG_MACOS10, #available(macOS 11.0, *) {
      class BlockView: NSView {
        override func draw(_: NSRect) {
          let radius = prefs.bool(forKey: PrefKey.showTickMarks.rawValue) ? CGFloat(4) : CGFloat(11)
          let outerMargin = CGFloat(15)
          let blockRect = self.frame.insetBy(dx: outerMargin, dy: outerMargin / 2 + 2).offsetBy(dx: 0, dy: outerMargin / 2 * -1 + 7)
          for i in 1 ... 5 {
            let blockPath = NSBezierPath(roundedRect: blockRect.insetBy(dx: CGFloat(i) * -1, dy: CGFloat(i) * -1), xRadius: radius + CGFloat(i) * 0.5, yRadius: radius + CGFloat(i) * 0.5)
            NSColor.black.withAlphaComponent(0.1 / CGFloat(i)).setStroke()
            blockPath.stroke()
          }
          let blockPath = NSBezierPath(roundedRect: blockRect, xRadius: radius, yRadius: radius)
          if [NSAppearance.Name.darkAqua, NSAppearance.Name.vibrantDark].contains(effectiveAppearance.name) {
            NSColor.systemGray.withAlphaComponent(0.3).setStroke()
            blockPath.stroke()
          }
          if ![NSAppearance.Name.darkAqua, NSAppearance.Name.vibrantDark].contains(effectiveAppearance.name) {
            NSColor.white.withAlphaComponent(0.5).setFill()
            blockPath.fill()
          }
        }
      }
      var contentWidth: CGFloat = 0
      var contentHeight: CGFloat = 0
      for addedSliderHandler in addedSliderHandlers {
        contentWidth = max(addedSliderHandler.view!.frame.width, contentWidth)
        contentHeight += addedSliderHandler.view!.frame.height
      }
      let margin = CGFloat(13)
      var blockNameView: NSTextField?
      if blockName != "" {
        contentHeight += 21
        let attrs: [NSAttributedString.Key: Any] = [.foregroundColor: NSColor.textColor, .font: NSFont.boldSystemFont(ofSize: 12)]
        blockNameView = NSTextField(labelWithAttributedString: NSAttributedString(string: blockName, attributes: attrs))
        blockNameView?.frame.size.width = contentWidth - margin * 2
        blockNameView?.alphaValue = 0.5
      }
      let itemView = BlockView(frame: NSRect(x: 0, y: 0, width: contentWidth + margin * 2, height: contentHeight + margin * 2))
      var sliderPosition = CGFloat(margin * -1 + 1)
      for addedSliderHandler in addedSliderHandlers {
        addedSliderHandler.view!.setFrameOrigin(NSPoint(x: margin, y: margin + sliderPosition + 13))
        itemView.addSubview(addedSliderHandler.view!)
        sliderPosition += addedSliderHandler.view!.frame.height
      }
      if let blockNameView = blockNameView {
        blockNameView.setFrameOrigin(NSPoint(x: margin + 13, y: contentHeight - 8))
        itemView.addSubview(blockNameView)
      }
      let item = NSMenuItem()
      item.view = itemView
      if addedSliderHandlers.count != 0 {
        monitorSubMenu.insertItem(item, at: 0)
      }
    } else {
      for addedSliderHandler in addedSliderHandlers {
        self.addSliderItem(monitorSubMenu: monitorSubMenu, sliderHandler: addedSliderHandler)
      }
    }
    self.appendMenuHeader(friendlyName: blockName, monitorSubMenu: monitorSubMenu, asSubMenu: asSubMenu, numOfDisplays: numOfDisplays)
  }

  func addCombinedDisplayMenuBlock() {
    if let sliderHandler = self.combinedSliderHandler[.audioSpeakerVolume] {
      self.addSliderItem(monitorSubMenu: self, sliderHandler: sliderHandler)
    }
    if let sliderHandler = self.combinedSliderHandler[.contrast] {
      self.addSliderItem(monitorSubMenu: self, sliderHandler: sliderHandler)
    }
    if let sliderHandler = self.combinedSliderHandler[.brightness] {
      self.addSliderItem(monitorSubMenu: self, sliderHandler: sliderHandler)
    }
  }

  func updateDisplayMenu(display: Display, asSubMenu: Bool, numOfDisplays: Int) {
    os_log("Addig menu items for display %{public}@", type: .info, "\(display.identifier)")
    let monitorSubMenu: NSMenu = asSubMenu ? NSMenu() : self
    var addedSliderHandlers: [SliderHandler] = []
    display.sliderHandler[.audioSpeakerVolume] = nil
    if let otherDisplay = display as? OtherDisplay, !otherDisplay.isSw(), !display.readPrefAsBool(key: .unavailableDDC, for: .audioSpeakerVolume), !prefs.bool(forKey: PrefKey.hideVolume.rawValue) {
      let title = NSLocalizedString("Volume", comment: "Shown in menu")
      addedSliderHandlers.append(self.setupMenuSliderHandler(command: .audioSpeakerVolume, display: display, title: title))
    }
    display.sliderHandler[.contrast] = nil
    if let otherDisplay = display as? OtherDisplay, !otherDisplay.isSw(), !display.readPrefAsBool(key: .unavailableDDC, for: .contrast), prefs.bool(forKey: PrefKey.showContrast.rawValue) {
      let title = NSLocalizedString("Contrast", comment: "Shown in menu")
      addedSliderHandlers.append(self.setupMenuSliderHandler(command: .contrast, display: display, title: title))
    }
    display.sliderHandler[.brightness] = nil
    if !display.readPrefAsBool(key: .unavailableDDC, for: .brightness), !prefs.bool(forKey: PrefKey.hideBrightness.rawValue) {
      let title = NSLocalizedString("Brightness", comment: "Shown in menu")
      addedSliderHandlers.append(self.setupMenuSliderHandler(command: .brightness, display: display, title: title))
    }
    if prefs.integer(forKey: PrefKey.multiSliders.rawValue) != MultiSliders.combine.rawValue {
      self.addDisplayMenuBlock(addedSliderHandlers: addedSliderHandlers, blockName: display.readPrefAsString(key: .friendlyName) != "" ? display.readPrefAsString(key: .friendlyName) : display.name, monitorSubMenu: monitorSubMenu, numOfDisplays: numOfDisplays, asSubMenu: asSubMenu)
    }
    if addedSliderHandlers.count > 0, prefs.integer(forKey: PrefKey.menuIcon.rawValue) == MenuIcon.sliderOnly.rawValue {
      app.updateStatusItemVisibility(true)
    }
  }

  private func appendMenuHeader(friendlyName: String, monitorSubMenu: NSMenu, asSubMenu: Bool, numOfDisplays: Int) {
    let monitorMenuItem = NSMenuItem()
    if asSubMenu {
      monitorMenuItem.title = "\(friendlyName)"
      monitorMenuItem.submenu = monitorSubMenu
      self.insertItem(monitorMenuItem, at: 0)
    } else if app.macOS10(), numOfDisplays > 1 {
      let attrs: [NSAttributedString.Key: Any] = [.foregroundColor: NSColor.systemGray, .font: NSFont.boldSystemFont(ofSize: 12)]
      monitorMenuItem.attributedTitle = NSAttributedString(string: "\(friendlyName)", attributes: attrs)
      self.insertItem(monitorMenuItem, at: 0)
    }
  }

  func updateMenuRelevantDisplay() {
    if prefs.integer(forKey: PrefKey.multiSliders.rawValue) == MultiSliders.relevant.rawValue {
      if let display = DisplayManager.shared.getCurrentDisplay(), display.identifier != self.lastMenuRelevantDisplayId {
        os_log("Menu must be refreshed as relevant display changed since last time.")
        self.lastMenuRelevantDisplayId = display.identifier
        self.updateMenus(dontClose: true)
      }
    }
  }

  func addDefaultMenuOptions() {
    if !DEBUG_MACOS10, #available(macOS 11.0, *), prefs.integer(forKey: PrefKey.menuItemStyle.rawValue) == MenuItemStyle.icon.rawValue {
      let iconSize = CGFloat(18)
      let viewWidth = max(130, self.size.width)
      var compensateForBlock: CGFloat = 0
      if viewWidth > 230 { // if there are display blocks, we need to compensate a bit for the negative inset of the blocks
        compensateForBlock = 4
      }

      let menuItemView = NSView(frame: NSRect(x: 0, y: 0, width: viewWidth, height: iconSize + 10))

      let settingsIcon = NSButton()
      settingsIcon.bezelStyle = .regularSquare
      settingsIcon.isBordered = false
      settingsIcon.setButtonType(.momentaryChange)
      settingsIcon.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: NSLocalizedString("Settings…", comment: "Shown in menu"))
      settingsIcon.alternateImage = NSImage(systemSymbolName: "gearshape.fill", accessibilityDescription: NSLocalizedString("Settings…", comment: "Shown in menu"))
      settingsIcon.alphaValue = 0.3
      settingsIcon.frame = NSRect(x: menuItemView.frame.maxX - iconSize * 3 - 20 - 17 + compensateForBlock, y: menuItemView.frame.origin.y + 5, width: iconSize, height: iconSize)
      settingsIcon.imageScaling = .scaleProportionallyUpOrDown
      settingsIcon.action = #selector(app.prefsClicked)

      let updateIcon = NSButton()
      updateIcon.bezelStyle = .regularSquare
      updateIcon.isBordered = false
      updateIcon.setButtonType(.momentaryChange)
      var symbolName = prefs.bool(forKey: PrefKey.showTickMarks.rawValue) ? "arrow.left.arrow.right.square" : "arrow.triangle.2.circlepath.circle"
      updateIcon.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: NSLocalizedString("Check for updates…", comment: "Shown in menu"))
      updateIcon.alternateImage = NSImage(systemSymbolName: symbolName + ".fill", accessibilityDescription: NSLocalizedString("Check for updates…", comment: "Shown in menu"))

      updateIcon.alphaValue = 0.3
      updateIcon.frame = NSRect(x: menuItemView.frame.maxX - iconSize * 2 - 14 - 17 + compensateForBlock, y: menuItemView.frame.origin.y + 5, width: iconSize, height: iconSize)
      updateIcon.imageScaling = .scaleProportionallyUpOrDown
      updateIcon.action = #selector(app.updaterController.checkForUpdates(_:))
      updateIcon.target = app.updaterController

      let quitIcon = NSButton()
      quitIcon.bezelStyle = .regularSquare
      quitIcon.isBordered = false
      quitIcon.setButtonType(.momentaryChange)
      symbolName = prefs.bool(forKey: PrefKey.showTickMarks.rawValue) ? "multiply.square" : "xmark.circle"
      quitIcon.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: NSLocalizedString("Quit", comment: "Shown in menu"))
      quitIcon.alternateImage = NSImage(systemSymbolName: symbolName + ".fill", accessibilityDescription: NSLocalizedString("Quit", comment: "Shown in menu"))
      quitIcon.alphaValue = 0.3
      quitIcon.frame = NSRect(x: menuItemView.frame.maxX - iconSize - 17 + compensateForBlock, y: menuItemView.frame.origin.y + 5, width: iconSize, height: iconSize)
      quitIcon.imageScaling = .scaleProportionallyUpOrDown
      quitIcon.action = #selector(app.quitClicked)

      menuItemView.addSubview(settingsIcon)
      menuItemView.addSubview(updateIcon)
      menuItemView.addSubview(quitIcon)
      let item = NSMenuItem()
      item.view = menuItemView
      self.insertItem(item, at: self.items.count)
    } else if prefs.integer(forKey: PrefKey.menuItemStyle.rawValue) != MenuItemStyle.hide.rawValue {
      if app.macOS10() {
        self.insertItem(NSMenuItem.separator(), at: self.items.count)
      }
      self.insertItem(withTitle: NSLocalizedString("Settings…", comment: "Shown in menu"), action: #selector(app.prefsClicked), keyEquivalent: ",", at: self.items.count)
      let updateItem = NSMenuItem(title: NSLocalizedString("Check for updates…", comment: "Shown in menu"), action: #selector(app.updaterController.checkForUpdates(_:)), keyEquivalent: "")
      updateItem.target = app.updaterController
      self.insertItem(updateItem, at: self.items.count)
      self.insertItem(withTitle: NSLocalizedString("Quit", comment: "Shown in menu"), action: #selector(app.quitClicked), keyEquivalent: "q", at: self.items.count)
    }
  }
}

@available(macOS 26.0, *)
private final class MenuDisplayGlassBlockView: NSView {
  private let cardWidth = CGFloat(420)
  private let containerView = NSGlassEffectContainerView()
  private let glassView = NSGlassEffectView()
  private let titleLabel: NSTextField
  private let contentStack = NSStackView()
  private let strokeLayer = CAShapeLayer()
  private let shadowLayer = CAShapeLayer()

  init(title: String, sliderViews: [NSView]) {
    self.titleLabel = NSTextField(labelWithString: title)
    let sliderHeight = sliderViews.reduce(CGFloat(0)) { partialResult, sliderView in
      partialResult + max(sliderView.fittingSize.height, sliderView.frame.height)
    }
    let titleHeight = title.isEmpty ? CGFloat(0) : CGFloat(20)
    let visibleViewCount = sliderViews.count + (title.isEmpty ? 0 : 1)
    let contentHeight = 18 + titleHeight + sliderHeight + CGFloat(max(0, visibleViewCount - 1)) * 8 + 16
    let totalHeight = max(90, contentHeight + 12)

    super.init(frame: NSRect(x: 0, y: 0, width: self.cardWidth, height: totalHeight))

    self.wantsLayer = true

    self.shadowLayer.fillColor = NSColor.black.withAlphaComponent(0.18).cgColor
    self.shadowLayer.shadowColor = NSColor.black.cgColor
    self.shadowLayer.shadowOpacity = 0.20
    self.shadowLayer.shadowRadius = 12
    self.shadowLayer.shadowOffset = CGSize(width: 0, height: -5)
    self.layer?.addSublayer(self.shadowLayer)

    self.containerView.translatesAutoresizingMaskIntoConstraints = false
    self.containerView.spacing = 0

    self.glassView.translatesAutoresizingMaskIntoConstraints = false
    self.glassView.style = .regular
    self.glassView.tintColor = NSColor.controlAccentColor.withAlphaComponent(0.10)
    self.containerView.contentView = self.glassView

    self.glassView.wantsLayer = true
    self.strokeLayer.fillColor = NSColor.clear.cgColor
    self.strokeLayer.strokeColor = NSColor.white.withAlphaComponent(0.22).cgColor
    self.strokeLayer.lineWidth = 1
    self.glassView.layer?.addSublayer(self.strokeLayer)

    self.titleLabel.translatesAutoresizingMaskIntoConstraints = false
    self.titleLabel.font = NSFont.systemFont(ofSize: 15, weight: .semibold)
    self.titleLabel.textColor = NSColor.labelColor

    self.contentStack.translatesAutoresizingMaskIntoConstraints = false
    self.contentStack.orientation = .vertical
    self.contentStack.alignment = .leading
    self.contentStack.spacing = 8
    self.contentStack.edgeInsets = NSEdgeInsets(top: 18, left: 20, bottom: 16, right: 20)
    self.contentStack.addArrangedSubview(self.titleLabel)
    sliderViews.forEach { self.contentStack.addArrangedSubview($0) }

    self.glassView.contentView = self.contentStack
    self.addSubview(self.containerView)

    NSLayoutConstraint.activate([
      self.containerView.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 10),
      self.containerView.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -10),
      self.containerView.topAnchor.constraint(equalTo: self.topAnchor, constant: 6),
      self.containerView.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: -6),
      self.widthAnchor.constraint(equalToConstant: self.cardWidth),
    ])

    self.layoutSubtreeIfNeeded()
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    nil
  }

  override var fittingSize: NSSize {
    let contentHeight = self.contentStack.fittingSize.height
    return NSSize(width: self.cardWidth, height: max(90, contentHeight + 12))
  }

  override var intrinsicContentSize: NSSize {
    self.fittingSize
  }

  override func layout() {
    super.layout()

    let cardFrame = self.bounds.insetBy(dx: 10, dy: 6)
    let cornerRadius = min(22, cardFrame.height / 2.6)
    self.glassView.cornerRadius = cornerRadius

    self.shadowLayer.path = CGPath(
      roundedRect: cardFrame.insetBy(dx: 2, dy: 2),
      cornerWidth: cornerRadius,
      cornerHeight: cornerRadius,
      transform: nil
    )
    self.strokeLayer.frame = self.glassView.bounds
    self.strokeLayer.path = CGPath(
      roundedRect: self.glassView.bounds.insetBy(dx: 0.5, dy: 0.5),
      cornerWidth: max(0, cornerRadius - 0.5),
      cornerHeight: max(0, cornerRadius - 0.5),
      transform: nil
    )
  }
}
