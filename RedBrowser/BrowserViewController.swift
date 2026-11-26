import UIKit
import WebKit

final class BrowserViewController: UIViewController, WKNavigationDelegate, WKUIDelegate {
    private let background = UIColor(red: 248 / 255, green: 247 / 255, blue: 244 / 255, alpha: 1)
    private let ink = UIColor(red: 35 / 255, green: 30 / 255, blue: 30 / 255, alpha: 1)
    private let content = UIView()
    private let toolbar = UIView()
    private let hostLabel = UILabel()
    private let backButton = UIButton(type: .system)
    private let homeButton = UIButton(type: .system)
    private let homeWebView: WKWebView = {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.setURLSchemeHandler(HomePageSchemeHandler(), forURLScheme: HomePageSchemeHandler.scheme)
        return WKWebView(frame: .zero, configuration: configuration)
    }()
    private var remoteWebView: WKWebView?
    private var requestedURL: URL?
    private var toolbarObservations: [NSKeyValueObservation] = []

    override var preferredStatusBarStyle: UIStatusBarStyle { .darkContent }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = background
        view.tintColor = ink

        let stack = UIStackView(arrangedSubviews: [toolbar, content])
        stack.axis = .vertical
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        let safeArea = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: safeArea.topAnchor),
            stack.bottomAnchor.constraint(equalTo: safeArea.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor)
        ])

        configureToolbar()
        toolbar.isHidden = true

        homeWebView.isOpaque = false
        homeWebView.backgroundColor = background
        homeWebView.scrollView.backgroundColor = background
        addWebView(homeWebView)
        loadHome()
    }

    private func configureToolbar() {
        let symbol = UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
        backButton.setImage(UIImage(systemName: "chevron.backward", withConfiguration: symbol), for: .normal)
        backButton.accessibilityLabel = "后退"
        backButton.addTarget(self, action: #selector(goBack), for: .touchUpInside)
        homeButton.setImage(UIImage(systemName: "house", withConfiguration: symbol), for: .normal)
        homeButton.accessibilityLabel = "首页"
        homeButton.addTarget(self, action: #selector(closePage), for: .touchUpInside)

        hostLabel.textAlignment = .center
        hostLabel.font = .preferredFont(forTextStyle: .subheadline)
        hostLabel.adjustsFontForContentSizeCategory = true
        hostLabel.lineBreakMode = .byTruncatingMiddle
        hostLabel.textColor = ink
        hostLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let row = UIStackView(arrangedSubviews: [backButton, hostLabel, homeButton])
        row.translatesAutoresizingMaskIntoConstraints = false
        row.alignment = .center
        row.spacing = 8
        toolbar.addSubview(row)

        let divider = UIView()
        divider.backgroundColor = ink.withAlphaComponent(0.12)
        divider.translatesAutoresizingMaskIntoConstraints = false
        toolbar.addSubview(divider)

        let toolbarHeight = toolbar.heightAnchor.constraint(equalToConstant: 45)
        toolbarHeight.priority = UILayoutPriority(999)
        NSLayoutConstraint.activate([
            toolbarHeight,
            row.centerYAnchor.constraint(equalTo: toolbar.centerYAnchor),
            row.leadingAnchor.constraint(equalTo: toolbar.leadingAnchor, constant: 8),
            row.trailingAnchor.constraint(equalTo: toolbar.trailingAnchor, constant: -8),
            backButton.widthAnchor.constraint(equalToConstant: 44),
            backButton.heightAnchor.constraint(equalToConstant: 44),
            homeButton.widthAnchor.constraint(equalTo: backButton.widthAnchor),
            homeButton.heightAnchor.constraint(equalTo: backButton.heightAnchor),
            divider.heightAnchor.constraint(equalToConstant: 1),
            divider.leadingAnchor.constraint(equalTo: toolbar.leadingAnchor),
            divider.trailingAnchor.constraint(equalTo: toolbar.trailingAnchor),
            divider.bottomAnchor.constraint(equalTo: toolbar.bottomAnchor)
        ])
    }

    private func addWebView(_ webView: WKWebView) {
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(webView)
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: content.topAnchor),
            webView.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: content.trailingAnchor)
        ])
    }

    private func loadHome() {
        homeWebView.load(URLRequest(url: HomePageSchemeHandler.homeURL))
    }

    private func openPage(_ request: URLRequest) {
        let webView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        webView.allowsBackForwardNavigationGestures = true
        addWebView(webView)
        remoteWebView = webView
        requestedURL = request.url
        homeWebView.isHidden = true
        toolbar.isHidden = false
        refreshToolbar(for: webView)
        toolbarObservations = [
            webView.observe(\.url) { [weak self] webView, _ in self?.refreshToolbar(for: webView) },
            webView.observe(\.canGoBack) { [weak self] webView, _ in self?.refreshToolbar(for: webView) }
        ]
        webView.load(request)
    }

    @objc private func closePage() {
        let webView = remoteWebView
        remoteWebView = nil
        requestedURL = nil
        toolbarObservations.removeAll()
        webView?.stopLoading()
        webView?.removeFromSuperview()
        toolbar.isHidden = true
        homeWebView.isHidden = false
    }

    @objc private func goBack() {
        remoteWebView?.goBack()
    }

    private func refreshToolbar(for webView: WKWebView) {
        guard webView === remoteWebView else { return }
        hostLabel.text = webView.url?.host ?? requestedURL?.host
        backButton.isEnabled = webView.canGoBack
    }

    private func isHTTPS(_ url: URL?) -> Bool {
        url?.scheme?.lowercased() == "https" && url?.host?.isEmpty == false
    }

    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        let url = action.request.url
        if webView === homeWebView {
            if url == HomePageSchemeHandler.homeURL {
                decisionHandler(.allow)
                return
            }
            decisionHandler(.cancel)
            if action.targetFrame?.isMainFrame != false && isHTTPS(url) && remoteWebView == nil {
                openPage(action.request)
            }
            return
        }

        guard webView === remoteWebView else {
            decisionHandler(.cancel)
            return
        }
        if action.targetFrame?.isMainFrame == false {
            decisionHandler(.allow)
        } else if isHTTPS(url) {
            if action.targetFrame != nil {
                requestedURL = url
            }
            decisionHandler(.allow)
        } else {
            decisionHandler(.cancel)
        }
    }

    func webView(_ webView: WKWebView, decidePolicyFor response: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        if webView === remoteWebView && response.isForMainFrame && !isHTTPS(response.response.url) {
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if webView === remoteWebView && action.targetFrame == nil && isHTTPS(action.request.url) {
            webView.load(action.request)
        }
        return nil
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        handleLoadError(error, in: webView)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        handleLoadError(error, in: webView)
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        if webView === homeWebView {
            loadHome()
        } else {
            showRetry(for: webView, url: webView.url ?? requestedURL)
        }
    }

    private func handleLoadError(_ error: Error, in webView: WKWebView) {
        let failure = error as NSError
        if failure.domain == NSURLErrorDomain && failure.code == NSURLErrorCancelled { return }
        let failedURL = failure.userInfo[NSURLErrorFailingURLErrorKey] as? URL
        showRetry(for: webView, url: failedURL ?? requestedURL)
    }

    private func showRetry(for webView: WKWebView, url: URL?) {
        guard webView === remoteWebView, let url, isHTTPS(url), presentedViewController == nil else { return }
        refreshToolbar(for: webView)
        let alert = UIAlertController(title: "无法打开网页", message: url.host, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "重新加载", style: .default) { [weak webView] _ in
            webView?.load(URLRequest(url: url))
        })
        present(alert, animated: true)
    }
}
