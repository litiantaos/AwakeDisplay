import Cocoa

final class AboutWindowController: NSObject {
    private var windowController: NSWindowController?

    func show() {
        if windowController == nil {
            let contentWidth: CGFloat = 260
            let contentHeight: CGFloat = 200

            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: contentWidth, height: contentHeight),
                styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.isMovableByWindowBackground = true
            window.center()
            window.isReleasedWhenClosed = false

            let contentView = NSView(frame: NSRect(x: 0, y: 0, width: contentWidth, height: contentHeight))

            let imageView = NSImageView(frame: NSRect(x: (contentWidth - 64) / 2, y: contentHeight - 100, width: 64, height: 64))
            imageView.image = NSApplication.shared.applicationIconImage
            contentView.addSubview(imageView)

            let nameLabel = NSTextField(labelWithString: "AwakeDisplay")
            nameLabel.font = NSFont.boldSystemFont(ofSize: 16)
            nameLabel.alignment = .center
            nameLabel.isEditable = false
            nameLabel.isBordered = false
            nameLabel.drawsBackground = false
            nameLabel.frame = NSRect(x: 0, y: contentHeight - 130, width: contentWidth, height: 20)
            contentView.addSubview(nameLabel)

            let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
            let versionLabel = NSTextField(labelWithString: "版本 \(version)")
            versionLabel.font = NSFont.systemFont(ofSize: 11)
            versionLabel.textColor = NSColor.secondaryLabelColor
            versionLabel.alignment = .center
            versionLabel.isEditable = false
            versionLabel.isBordered = false
            versionLabel.drawsBackground = false
            versionLabel.frame = NSRect(x: 0, y: contentHeight - 156, width: contentWidth, height: 16)
            contentView.addSubview(versionLabel)

            let linkButton = NSButton(frame: NSRect(x: 0, y: 20, width: contentWidth, height: 16))
            linkButton.title = "GitHub: litiantaos/AwakeDisplay"
            linkButton.bezelStyle = .inline
            linkButton.isBordered = false
            linkButton.setButtonType(.momentaryChange)
            linkButton.alignment = .center

            let linkFont = NSFont.systemFont(ofSize: 11)
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .center

            let attributedTitle = NSAttributedString(string: "GitHub: litiantaos/AwakeDisplay", attributes: [
                .foregroundColor: NSColor.linkColor,
                .font: linkFont,
                .paragraphStyle: paragraphStyle,
                .cursor: NSCursor.pointingHand
            ])
            linkButton.attributedTitle = attributedTitle

            linkButton.target = self
            linkButton.action = #selector(openGitHub)
            contentView.addSubview(linkButton)

            window.contentView = contentView
            windowController = NSWindowController(window: window)
        }

        windowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func openGitHub() {
        if let url = URL(string: "https://github.com/litiantaos/AwakeDisplay") {
            NSWorkspace.shared.open(url)
        }
    }
}
