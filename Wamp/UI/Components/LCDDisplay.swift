import Cocoa
import Combine

class LCDDisplay: NSView {
    var text: String = "" {
        didSet {
            scrollOffset = 0
            pauseTicksRemaining = initialPauseTicks
            needsDisplay = true
        }
    }
    var isScrolling = true

    private var scrollOffset: CGFloat = 0
    private var scrollTimer: Timer?
    private let scrollSpeed: CGFloat = 0.5
    private let separator = "   ***   "
    private var pauseTicksRemaining: Int = 0
    private let initialPauseTicks: Int = 45 // 1.5s initial pause at 30 fps
    private var skinObserver: AnyCancellable?
    private var overlayText: String?
    private var overlayClearTimer: Timer?

    func showOverlay(_ text: String, duration: TimeInterval = 1.0) {
        overlayText = text
        needsDisplay = true
        overlayClearTimer?.invalidate()
        overlayClearTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            self?.overlayText = nil
            self?.needsDisplay = true
        }
    }

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.masksToBounds = true
        startScrolling()
        skinObserver = SkinManager.shared.$currentSkin
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.scrollOffset = 0
                self.pauseTicksRemaining = self.initialPauseTicks
                self.needsDisplay = true
            }
    }

    required init?(coder: NSCoder) { fatalError() }

    private func textWidth(_ str: String) -> CGFloat {
        if WinampTheme.skinIsActive {
            return TextSpriteRenderer.width(of: str)
        } else {
            let attrs: [NSAttributedString.Key: Any] = [
                .font: WinampTheme.trackTitleFont,
                .foregroundColor: WinampTheme.greenBright
            ]
            return str.size(withAttributes: attrs).width
        }
    }

    private func startScrolling() {
        let timer = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            guard let self = self, self.isScrolling, !self.text.isEmpty, self.overlayText == nil else { return }

            let titleWidth = self.textWidth(self.text)
            guard titleWidth > self.bounds.width else {
                if self.scrollOffset != 0 {
                    self.scrollOffset = 0
                    self.needsDisplay = true
                }
                return
            }

            if self.pauseTicksRemaining > 0 {
                self.pauseTicksRemaining -= 1
                return
            }

            let cycleText = self.text + self.separator
            let cycleWidth = self.textWidth(cycleText)
            self.scrollOffset += self.scrollSpeed
            if self.scrollOffset >= cycleWidth {
                self.scrollOffset -= cycleWidth
            }
            self.needsDisplay = true
        }
        RunLoop.main.add(timer, forMode: .common)
        scrollTimer = timer
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        if WinampTheme.skinIsActive {
            drawSkinned()
        } else {
            drawBuiltIn()
        }
    }

    private func drawSkinned() {
        guard let textSheet = WinampTheme.provider.textSheet else { return }
        if let overlay = overlayText {
            let y = (bounds.height - TextSpriteRenderer.glyphHeight) / 2
            TextSpriteRenderer.draw(overlay, at: NSPoint(x: 2, y: y), sheet: textSheet)
            return
        }
        guard !text.isEmpty else { return }
        let titleWidth = TextSpriteRenderer.width(of: text)
        let y = (bounds.height - TextSpriteRenderer.glyphHeight) / 2

        if titleWidth <= bounds.width || !isScrolling {
            TextSpriteRenderer.draw(text, at: NSPoint(x: 2, y: y), sheet: textSheet)
        } else {
            let cycleText = text + separator
            let cycleWidth = TextSpriteRenderer.width(of: cycleText)
            var startX = 2.0 - scrollOffset
            while startX < bounds.width {
                TextSpriteRenderer.draw(cycleText, at: NSPoint(x: startX, y: y), sheet: textSheet)
                startX += cycleWidth
            }
        }
    }

    private func drawBuiltIn() {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: WinampTheme.trackTitleFont,
            .foregroundColor: WinampTheme.greenBright
        ]

        if let overlay = overlayText {
            let size = overlay.size(withAttributes: attrs)
            let y = (bounds.height - size.height) / 2
            overlay.draw(at: NSPoint(x: 2, y: y), withAttributes: attrs)
            return
        }
        guard !text.isEmpty else { return }
        let titleWidth = text.size(withAttributes: attrs).width
        let y = (bounds.height - size(attrs: attrs).height) / 2

        if titleWidth <= bounds.width || !isScrolling {
            text.draw(at: NSPoint(x: 2, y: y), withAttributes: attrs)
        } else {
            let cycleText = text + separator
            let cycleWidth = cycleText.size(withAttributes: attrs).width
            var startX = 2.0 - scrollOffset
            while startX < bounds.width {
                cycleText.draw(at: NSPoint(x: startX, y: y), withAttributes: attrs)
                startX += cycleWidth
            }
        }
    }

    private func size(attrs: [NSAttributedString.Key: Any]) -> NSSize {
        text.size(withAttributes: attrs)
    }

    deinit {
        scrollTimer?.invalidate()
        overlayClearTimer?.invalidate()
    }
}
