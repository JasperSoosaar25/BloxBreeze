import SwiftUI
import WebKit

struct ReaderWebView: UIViewRepresentable {
    let url: URL
    @Binding var isLoading: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.userContentController.addUserScript(
            WKUserScript(source: Self.readerScript, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        )

        let view = WKWebView(frame: .zero, configuration: configuration)
        view.navigationDelegate = context.coordinator
        view.isOpaque = false
        view.backgroundColor = .clear
        view.scrollView.backgroundColor = .clear
        view.allowsBackForwardNavigationGestures = false
        view.load(URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 30))
        return view
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard webView.url != url, !webView.isLoading else { return }
        isLoading = true
        webView.load(URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 30))
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var parent: ReaderWebView

        init(parent: ReaderWebView) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.isLoading = false
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            if navigationAction.navigationType == .linkActivated {
                decisionHandler(.cancel)
                return
            }

            guard let destination = navigationAction.request.url,
                  let host = destination.host?.lowercased() else {
                decisionHandler(.cancel)
                return
            }

            let allowed = host == "about.roblox.com"
                || host == "corp.roblox.com"
                || host == "devforum.roblox.com"
                || destination.scheme == "about"

            decisionHandler(allowed ? .allow : .cancel)
        }
    }

    private static let readerScript = #"""
    (() => {
      const style = document.createElement('style');
      style.textContent = `
        :root { color-scheme: light dark; }
        html { background: transparent !important; }
        body {
          background: transparent !important;
          color: CanvasText !important;
          font-family: -apple-system, BlinkMacSystemFont, sans-serif !important;
          font-size: 18px !important;
          line-height: 1.62 !important;
          margin: 0 auto !important;
          max-width: 760px !important;
          padding: 24px 20px 140px !important;
          overflow-x: hidden !important;
        }
        header, footer, nav, aside, dialog,
        [class*="cookie" i], [id*="cookie" i],
        [class*="navigation" i], [class*="footer" i],
        [class*="related" i], [class*="social" i],
        [class*="share" i], [class*="newsletter" i],
        [class*="breadcrumb" i], [aria-label*="navigation" i] {
          display: none !important;
        }
        main, article, [class*="article" i] {
          max-width: 760px !important;
          margin: 0 auto !important;
        }
        h1 { font-size: 2.15rem !important; line-height: 1.08 !important; letter-spacing: -0.035em !important; }
        h2 { font-size: 1.55rem !important; line-height: 1.2 !important; margin-top: 1.7em !important; }
        h3 { font-size: 1.25rem !important; }
        p, li { font-size: 1rem !important; line-height: 1.62 !important; }
        img, video, iframe { max-width: 100% !important; height: auto !important; border-radius: 22px !important; }
        a { color: inherit !important; text-decoration: none !important; pointer-events: none !important; }
        button { display: none !important; }
        pre, code { white-space: pre-wrap !important; word-break: break-word !important; }
      `;
      document.head.appendChild(style);
      document.querySelectorAll('a').forEach(a => {
        a.removeAttribute('href');
        a.removeAttribute('target');
      });
      document.querySelectorAll('script[src*="analytics" i], script[src*="ads" i]').forEach(node => node.remove());
    })();
    """#
}

