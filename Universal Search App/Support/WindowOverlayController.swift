import SwiftUI
import UIKit

private class OverlayHostingController<Content: View>: UIHostingController<Content> {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
    }
}

private class PassthroughWindow: UIWindow {
    var passthroughHitTest = false

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let hit = super.hitTest(point, with: event) else { return nil }
        if passthroughHitTest, let rootView = rootViewController?.view, hit === rootView {
            return nil
        }
        return hit
    }
}

@MainActor
@Observable
final class WindowOverlayController {
    private var overlayWindow: UIWindow?
    private var hostingController: UIHostingController<AnyView>?

    var isPresented: Bool = false

    func show<Content: View>(@ViewBuilder content: @escaping () -> Content) {
        guard overlayWindow == nil else {
            hostingController?.rootView = AnyView(content())
            return
        }

        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })
                ?? UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene }).first
        else { return }

        let window = PassthroughWindow(windowScene: scene)
        window.windowLevel = .alert + 1
        window.backgroundColor = .clear
        window.passthroughHitTest = false

        let hc = UIHostingController(rootView: AnyView(content()))
        hc.view.backgroundColor = .clear
        hc.view.isOpaque = false
        window.rootViewController = hc
        window.isHidden = false
        window.makeKeyAndVisible()

        overlayWindow = window
        hostingController = hc
        isPresented = true
    }

    func update<Content: View>(@ViewBuilder content: @escaping () -> Content) {
        hostingController?.rootView = AnyView(content())
    }

    func dismiss() {
        overlayWindow?.isHidden = true
        overlayWindow?.rootViewController = nil
        overlayWindow = nil
        hostingController = nil
        isPresented = false
    }
}
