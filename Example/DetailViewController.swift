// DetailViewController.swift
//
// Copyright (c) 2014 Alamofire (http://alamofire.org)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

import UIKit
import Alamofire

class DetailViewController: UITableViewController {
    enum Sections: Int {
        case Headers, Body
    }

    var request: Alamofire.Request? {
        didSet {
            oldValue?.cancel()

            self.title = self.request?.description
            self.refreshControl?.endRefreshing()
            self.headers.removeAll()
            self.body = nil
            self.elapsedTime = nil
        }
    }

    var headers: [String: String] = [:]
    var body: String?
    var elapsedTime: NSTimeInterval?

    override func awakeFromNib() {
        super.awakeFromNib()
        self.refreshControl?.addTarget(self, action: "refresh", forControlEvents: .ValueChanged)

    }

    // MARK: - UIViewController

    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)

        self.refresh()
    }

    // MARK: - IBAction

    @IBAction func refresh() {
        if self.request == nil {
            return
        }

        self.refreshControl?.beginRefreshing()

        let start = CACurrentMediaTime()
        self.request?.responseString { (request, response, body, error) in
            let end = CACurrentMediaTime()
            self.elapsedTime = end - start

            for (field, value) in response!.allHeaderFields {
                self.headers["\(field)"] = "\(value)"
            }

            self.body = body

            self.tableView.reloadData()
            self.refreshControl?.endRefreshing()
        }
    }

    // MARK: UITableViewDataSource

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Sections(rawValue: section)! {
        case .Headers:
            return self.headers.count
        case .Body:
            return self.body == nil ? 0 : 1
        default:
            return 0
        }
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {

        switch Sections(rawValue: indexPath.section)! {
        case .Headers:
            let cell = self.tableView.dequeueReusableCellWithIdentifier("Header") as UITableViewCell
            let field = self.headers.keys.array.sorted(<)[indexPath.row]
            let value = self.headers[field]

            cell.textLabel?.text = field
            cell.detailTextLabel!.text = value

            return cell
        case .Body:
            let cell = self.tableView.dequeueReusableCellWithIdentifier("Body") as UITableViewCell

            cell.textLabel?.text = self.body

            return cell
        }
    }

    // MARK: UITableViewDelegate

    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 2
    }

    override func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String {
        if self.tableView(tableView, numberOfRowsInSection: section) == 0 {
            return ""
        }

        switch Sections(rawValue: section)! {
        case .Headers:
            return "Headers"
        case .Body:
            return "Body"
        }
    }

    override func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        switch Sections(rawValue: indexPath.section)! {
        case .Body:
            return 300
        default:
            return tableView.rowHeight
        }
    }

    override func tableView(tableView: UITableView, titleForFooterInSection section: Int) -> String {
        if Sections(rawValue: section)! == .Body && self.elapsedTime != nil {
            let numberFormatter = NSNumberFormatter()
            numberFormatter.numberStyle = .DecimalStyle

            return "Elapsed Time: \(numberFormatter.stringFromNumber(self.elapsedTime!)) sec"
        }

        return ""
    }
}

