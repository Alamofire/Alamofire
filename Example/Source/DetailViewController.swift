//
//  DetailViewController.swift
//
//  Copyright (c) 2014-2018 Alamofire Software Foundation (http://alamofire.org/)
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

import Alamofire
import UIKit

class DetailViewController: UITableViewController {
    enum Sections: Int {
        case headers, body
    }

    var request: Request? {
        didSet {
            oldValue?.cancel()

            title = request?.description
            request?.onURLRequestCreation { [weak self] _ in
                self?.title = self?.request?.description
            }

            refreshControl?.endRefreshing()
            headers.removeAll()
            body = nil
            elapsedTime = nil
        }
    }

    var headers: [String: String] = [:]
    var body: String?
    var elapsedTime: TimeInterval?
    var segueIdentifier: String?

    static let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter
    }()

    // MARK: View Lifecycle

    override func awakeFromNib() {
        super.awakeFromNib()
        refreshControl?.addTarget(self, action: #selector(DetailViewController.refresh), for: .valueChanged)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        refresh()
    }

    // MARK: IBActions

    @IBAction func refresh() {
        guard let request = request else {
            return
        }

        refreshControl?.isHidden = false
        refreshControl?.beginRefreshing()

        let start = CACurrentMediaTime()

        let requestComplete: (HTTPURLResponse?, Result<String, AFError>) -> Void = { response, result in
            let end = CACurrentMediaTime()
            self.elapsedTime = end - start

            if let response = response {
                for (field, value) in response.allHeaderFields {
                    self.headers["\(field)"] = "\(value)"
                }
            }

            if let segueIdentifier = self.segueIdentifier {
                switch segueIdentifier {
                case "GET", "POST", "PUT", "DELETE":
                    if case let .success(value) = result { self.body = value }
                case "DOWNLOAD":
                    self.body = self.downloadedBodyString()
                default:
                    break
                }
            }

            self.tableView.reloadData()
            self.refreshControl?.endRefreshing()
        }

        if let request = request as? DataRequest {
            request.responseString { response in
                requestComplete(response.response, response.result)
            }
        } else if let request = request as? DownloadRequest {
            request.responseString { response in
                requestComplete(response.response, response.result)
            }
        }
    }

    private func downloadedBodyString() -> String {
        let fileManager = FileManager.default
        let cachesDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]

        do {
            let contents = try fileManager.contentsOfDirectory(at: cachesDirectory,
                                                               includingPropertiesForKeys: nil,
                                                               options: .skipsHiddenFiles)

            if let fileURL = contents.first, let data = try? Data(contentsOf: fileURL) {
                let json = try JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions())
                let prettyData = try JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)

                if let prettyString = String(data: prettyData, encoding: String.Encoding.utf8) {
                    try fileManager.removeItem(at: fileURL)
                    return prettyString
                }
            }
        } catch {
            // No-op
        }

        return ""
    }
}

// MARK: - UITableViewDataSource

extension DetailViewController {
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Sections(rawValue: section)! {
        case .headers:
            return headers.count
        case .body:
            return body == nil ? 0 : 1
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch Sections(rawValue: indexPath.section)! {
        case .headers:
            let cell = tableView.dequeueReusableCell(withIdentifier: "Header")!
            let field = headers.keys.sorted(by: <)[indexPath.row]
            let value = headers[field]

            cell.textLabel?.text = field
            cell.detailTextLabel?.text = value

            return cell
        case .body:
            let cell = tableView.dequeueReusableCell(withIdentifier: "Body")!
            cell.textLabel?.text = body

            return cell
        }
    }
}

// MARK: - UITableViewDelegate

extension DetailViewController {
    override func numberOfSections(in tableView: UITableView) -> Int {
        2
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if self.tableView(tableView, numberOfRowsInSection: section) == 0 {
            return ""
        }

        switch Sections(rawValue: section)! {
        case .headers:
            return "Headers"
        case .body:
            return "Body"
        }
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch Sections(rawValue: indexPath.section)! {
        case .body:
            return 300
        default:
            return tableView.rowHeight
        }
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        if Sections(rawValue: section) == .body, let elapsedTime = elapsedTime {
            let elapsedTimeText = DetailViewController.numberFormatter.string(from: elapsedTime as NSNumber) ?? "???"
            return "Elapsed Time: \(elapsedTimeText) sec"
        }

        return ""
    }
}
