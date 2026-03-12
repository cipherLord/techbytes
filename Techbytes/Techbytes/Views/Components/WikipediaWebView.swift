import SwiftUI
import WebKit

struct WikipediaWebView: UIViewRepresentable {
    let htmlContent: String
    @Binding var dynamicHeight: CGFloat
    var onLinkTap: ((URL) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true

        let userScript = WKUserScript(
            source: Self.injectedScript,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
        config.userContentController.addUserScript(userScript)
        config.userContentController.add(context.coordinator, name: "heightHandler")
        config.userContentController.add(context.coordinator, name: "linkHandler")

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = UIColor(Color.darkVoid)
        webView.scrollView.backgroundColor = UIColor(Color.darkVoid)
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = false

        let baseURL = URL(string: "https://en.wikipedia.org")
        webView.loadHTMLString(htmlContent, baseURL: baseURL)

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.stopLoading()
        webView.loadHTMLString("", baseURL: nil)
        webView.navigationDelegate = nil
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "heightHandler")
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "linkHandler")
        webView.configuration.userContentController.removeAllUserScripts()
        webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { _ in }
    }

    // MARK: - Injected CSS + JS

    private static let injectedScript = """
    (function() {
        // --- CSS ---
        var style = document.createElement('style');
        style.textContent = `
            :root {
                --background: #151419 !important;
                --surface: #1b1b1e !important;
                --text-primary: #fbfbfb !important;
                --text-secondary: #878787 !important;
                --accent: #f56e0f !important;
            }

            body, html {
                background-color: #151419 !important;
                color: #fbfbfb !important;
                font-family: -apple-system, 'SF Pro Text', sans-serif !important;
                font-size: 17px !important;
                line-height: 1.65 !important;
                padding: 0 !important;
                margin: 0 !important;
                -webkit-text-size-adjust: 100% !important;
                overflow-x: hidden !important;
                word-wrap: break-word !important;
                overflow-wrap: break-word !important;
            }

            * {
                max-width: 100% !important;
                box-sizing: border-box !important;
            }

            /* --- Links --- */
            a { color: #f56e0f !important; text-decoration: none !important; }
            a:visited { color: #c45a0c !important; }

            /* --- Images --- */
            img {
                height: auto !important;
                border-radius: 8px !important;
            }

            /* --- Headings --- */
            h1, h2, h3, h4, h5, h6 {
                color: #fbfbfb !important;
                border-bottom: 1px solid #262626 !important;
                padding-bottom: 8px !important;
                margin-top: 28px !important;
            }
            h2 { font-size: 22px !important; }
            h3 { font-size: 19px !important; }
            p  { margin: 12px 0 !important; }

            /* --- Tables --- */
            .pcs-collapse-table-container,
            .pcs-collapse-table-content,
            .pcs-collapse-table-collapsed-container,
            .pcs-collapse-table-collapsed-bottom,
            .pcs-collapse-table-expand-button,
            .pcs-collapse-table-collapse-button,
            .pcs-wikidata-description,
            .pcs-edit-section-link-container,
            .section-heading .mw-editsection {
                display: none !important;
            }

            table {
                border-collapse: collapse !important;
                width: 100% !important;
                background: #1b1b1e !important;
                border-radius: 8px !important;
                overflow: hidden !important;
                font-size: 14px !important;
                margin: 12px 0 !important;
                display: table !important;
            }
            th, td {
                padding: 8px 10px !important;
                border: 1px solid #2a2a2e !important;
                color: #fbfbfb !important;
                word-break: break-word !important;
            }
            th {
                background: #262626 !important;
                font-weight: 600 !important;
            }
            tr:nth-child(even) {
                background: rgba(255,255,255,0.02) !important;
            }

            .wikitable {
                display: block !important;
                overflow-x: auto !important;
                -webkit-overflow-scrolling: touch !important;
            }

            /* --- Hatnotes / disambiguation --- */
            .hatnote, .dablink, .rellink, .main-article {
                background: rgba(245, 110, 15, 0.06) !important;
                border-left: 3px solid #f56e0f !important;
                border-radius: 0 8px 8px 0 !important;
                padding: 10px 14px !important;
                margin: 12px 0 !important;
                font-size: 14px !important;
                color: #b0b0b0 !important;
                font-style: italic !important;
                line-height: 1.5 !important;
            }
            .hatnote a, .dablink a, .rellink a {
                color: #f56e0f !important;
            }

            /* --- Article message boxes (ambox, ombox, tmbox, cmbox) --- */
            .ambox, .ombox, .tmbox, .cmbox, .fmbox, .imbox,
            .mbox-small, .plainlinks.ambox,
            table.ambox, table.ombox, table.tmbox,
            .shortdescription, .mw-indicators {
                display: none !important;
            }

            /* --- Elements to hide --- */
            .infobox, .sidebar, .navbox, .navbox-styles,
            .mw-editsection, .mw-empty-elt, .noprint,
            .mw-jump-link, .catlinks, .mw-authority-control,
            .pcs-header, .pcs-footer, .pcs-edit-section-link-container,
            .sistersitebox, .portalbox, .portal, .noviewer,
            .vertical-navbox, .toc, .nomobile, .mw-kartographer-container,
            .mw-references-wrap .mw-reference-text .mw-cite-backlink,
            header, .pcs-header-inner,
            .minerva-footer, .post-content footer,
            .mw-footer, #mw-mf-last-modified,
            .last-modified-bar, .talk-page-header,
            .ext-related-articles-card-list {
                display: none !important;
            }

            /* --- Figures and thumbnails --- */
            figure, .thumb, .thumbinner {
                margin: 16px 0 !important;
                padding: 0 !important;
                background: transparent !important;
                border: none !important;
            }
            figcaption, .thumbcaption {
                color: #878787 !important;
                font-size: 13px !important;
                margin-top: 6px !important;
                padding: 0 4px !important;
            }

            /* --- Blockquotes --- */
            blockquote {
                border-left: 3px solid #f56e0f !important;
                padding-left: 16px !important;
                margin-left: 0 !important;
                color: #c0c0c0 !important;
                font-style: italic !important;
            }

            /* --- Code / pre --- */
            code, pre {
                background: #1b1b1e !important;
                color: #f56e0f !important;
                border-radius: 4px !important;
                padding: 2px 6px !important;
                font-size: 15px !important;
            }
            pre {
                padding: 12px !important;
                overflow-x: auto !important;
            }

            /* --- References --- */
            .references, .reflist {
                font-size: 13px !important;
                color: #666 !important;
                border-top: 1px solid #262626 !important;
                padding-top: 12px !important;
                margin-top: 20px !important;
            }
            .references li { margin: 4px 0 !important; }
            sup.reference, sup.noprint, .mw-ref {
                font-size: 0 !important;
                line-height: 0 !important;
                vertical-align: baseline !important;
            }
            sup.reference a, .mw-ref a {
                font-size: 10px !important;
                color: #f56e0f !important;
                opacity: 0.5 !important;
                padding: 0 1px !important;
                vertical-align: super !important;
            }

            /* --- Lists --- */
            ul, ol { padding-left: 24px !important; }
            li { margin: 6px 0 !important; color: #fbfbfb !important; }

            /* --- Dividers --- */
            hr { border: none !important; border-top: 1px solid #262626 !important; }

            /* --- Definition lists (used in some articles) --- */
            dl { margin: 12px 0 !important; }
            dt {
                font-weight: 600 !important;
                color: #fbfbfb !important;
                margin-top: 8px !important;
            }
            dd {
                margin-left: 16px !important;
                color: #d0d0d0 !important;
            }

            /* --- Gallery --- */
            .gallery {
                display: flex !important;
                flex-wrap: wrap !important;
                gap: 8px !important;
                margin: 16px 0 !important;
            }
            .gallery .gallerybox {
                flex: 1 1 45% !important;
                margin: 0 !important;
            }
            .gallery .gallerytext {
                font-size: 12px !important;
                color: #878787 !important;
            }

            /* --- Collapsible sections (mobile-html) --- */
            .pcs-section-hidden { display: block !important; }
            section[data-mw-section] { display: block !important; }
        `;
        document.head.appendChild(style);

        // --- JS cleanup ---
        var selectors = [
            '.pcs-collapse-table-container',
            '.pcs-collapse-table-collapsed-container',
            '.pcs-collapse-table-expand-button',
            '.pcs-collapse-table-collapse-button',
            '.pcs-collapse-table-collapsed-bottom',
            '.pcs-edit-section-link-container',
            '.mw-editsection',
            '.ambox', '.ombox', '.tmbox', '.cmbox', '.fmbox', '.imbox',
            '.infobox', '.sidebar', '.navbox', '.navbox-styles',
            '.sistersitebox', '.portalbox', '.noprint',
            '.mw-authority-control', '.catlinks',
            'header', '.pcs-header', '.pcs-footer',
            '.minerva-footer', 'footer',
            '.shortdescription', '.mw-indicators',
            '.mw-kartographer-container',
            '.vertical-navbox', '.toc',
            '.ext-related-articles-card-list'
        ];
        selectors.forEach(function(sel) {
            document.querySelectorAll(sel).forEach(function(el) { el.remove(); });
        });

        // Expand any collapsed mobile-html sections
        document.querySelectorAll('section[data-mw-section]').forEach(function(sec) {
            sec.style.display = 'block';
            sec.classList.remove('pcs-section-hidden');
        });

        // Unwrap collapsible table wrappers so the actual table is visible
        document.querySelectorAll('.pcs-collapse-table-content').forEach(function(wrapper) {
            if (wrapper.parentNode) {
                while (wrapper.firstChild) {
                    wrapper.parentNode.insertBefore(wrapper.firstChild, wrapper);
                }
                wrapper.remove();
            }
        });

        // Make wide tables horizontally scrollable
        document.querySelectorAll('table').forEach(function(tbl) {
            if (tbl.closest('.navbox') || tbl.closest('.ambox')) return;
            if (!tbl.parentElement || !tbl.parentElement.classList.contains('table-scroll-wrap')) {
                var wrapper = document.createElement('div');
                wrapper.style.overflowX = 'auto';
                wrapper.style.webkitOverflowScrolling = 'touch';
                wrapper.style.margin = '12px 0';
                wrapper.style.borderRadius = '8px';
                wrapper.classList.add('table-scroll-wrap');
                tbl.parentNode.insertBefore(wrapper, tbl);
                wrapper.appendChild(tbl);
            }
        });

        // --- Link interception ---
        document.addEventListener('click', function(e) {
            var target = e.target;
            while (target && target.tagName !== 'A') {
                target = target.parentElement;
            }
            if (target && target.tagName === 'A') {
                var href = target.getAttribute('href');
                if (!href || href.startsWith('#') || href.toLowerCase().startsWith('javascript:') || href.toLowerCase().startsWith('data:') || href.toLowerCase().startsWith('vbscript:')) return;
                e.preventDefault();
                e.stopPropagation();
                if (href.startsWith('./')) {
                    href = 'https://en.wikipedia.org/wiki/' + href.substring(2);
                } else if (href.startsWith('../')) {
                    href = 'https://en.wikipedia.org/wiki/' + href.replace(/^\\.\\.\\//g, '');
                } else if (href.startsWith('/wiki/')) {
                    href = 'https://en.wikipedia.org' + href;
                } else if (href.startsWith('/')) {
                    href = 'https://en.wikipedia.org' + href;
                } else if (!href.startsWith('http')) {
                    href = 'https://en.wikipedia.org/wiki/' + href;
                }
                window.webkit.messageHandlers.linkHandler.postMessage(href);
            }
        }, true);

        // --- Height reporting (debounced to avoid feedback loops) ---
        var lastReportedHeight = 0;
        var heightUpdateCount = 0;
        function sendHeight() {
            var h = document.body.scrollHeight;
            if (Math.abs(h - lastReportedHeight) > 10) {
                lastReportedHeight = h;
                heightUpdateCount++;
                window.webkit.messageHandlers.heightHandler.postMessage(h);
            }
        }
        var resizeTimer = null;
        window.addEventListener('load', function() { setTimeout(sendHeight, 400); });
        new ResizeObserver(function() {
            if (heightUpdateCount > 20) return;
            if (resizeTimer) clearTimeout(resizeTimer);
            resizeTimer = setTimeout(sendHeight, 300);
        }).observe(document.body);
        setTimeout(sendHeight, 600);
        setTimeout(sendHeight, 2000);
    })();
    """

    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        let parent: WikipediaWebView

        init(parent: WikipediaWebView) {
            self.parent = parent
        }

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            if message.name == "linkHandler",
               let urlString = message.body as? String,
               let url = URL(string: urlString) {
                DispatchQueue.main.async {
                    self.parent.onLinkTap?(url)
                }
                return
            }

            if let height = message.body as? CGFloat, height > 0 {
                DispatchQueue.main.async {
                    if abs(self.parent.dynamicHeight - height) > 10 {
                        self.parent.dynamicHeight = height
                    }
                }
            }
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            if navigationAction.navigationType == .linkActivated,
               let url = navigationAction.request.url {
                let scheme = url.scheme?.lowercased() ?? ""
                if scheme == "https" || scheme == "http" {
                    parent.onLinkTap?(url)
                }
                decisionHandler(.cancel)
                return
            }
            if navigationAction.navigationType == .other || navigationAction.navigationType == .reload {
                decisionHandler(.allow)
                return
            }
            decisionHandler(.cancel)
        }
    }
}
