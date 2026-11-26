import Foundation
import WebKit

// A fixed origin keeps the home page's storage independent of the app bundle path.
final class HomePageSchemeHandler: NSObject, WKURLSchemeHandler {
    static let scheme = "redbrowser"
    static let host = "home"
    static let homeURL = URL(string: "\(scheme)://\(host)/index.html")!

    func webView(_ webView: WKWebView, start task: WKURLSchemeTask) {
        guard let url = task.request.url, url.scheme == Self.scheme, url.host == Self.host else {
            task.didFailWithError(URLError(.unsupportedURL))
            return
        }

        let resource: (name: String, extension: String, mimeType: String, encoding: String?)
        switch url.path {
        case "/index.html": resource = ("index", "html", "text/html", "utf-8")
        case "/platform.png": resource = ("apple", "png", "image/png", nil)
        default:
            task.didFailWithError(URLError(.fileDoesNotExist))
            return
        }

        guard let file = Bundle.main.url(forResource: resource.name, withExtension: resource.extension) else {
            task.didFailWithError(URLError(.fileDoesNotExist))
            return
        }

        do {
            let data = try Data(contentsOf: file)
            let response = URLResponse(url: url, mimeType: resource.mimeType, expectedContentLength: data.count, textEncodingName: resource.encoding)
            task.didReceive(response)
            task.didReceive(data)
            task.didFinish()
        } catch {
            task.didFailWithError(error)
        }
    }

    func webView(_ webView: WKWebView, stop task: WKURLSchemeTask) {}
}
