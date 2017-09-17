//
//  MasterViewController.swift
//
//  Copyright (c) 2014-2017 Alamofire Software Foundation (http://alamofire.org/)
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

class MasterViewController: UITableViewController {

    @IBOutlet weak var titleImageView: UIImageView!

    var detailViewController: DetailViewController? = nil
    var objects = NSMutableArray()

    // MARK: - View Lifecycle

    override func awakeFromNib() {
        super.awakeFromNib()

        navigationItem.titleView = titleImageView
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        if let split = splitViewController {
            let controllers = split.viewControllers

            if
                let navigationController = controllers.last as? UINavigationController,
                let topViewController = navigationController.topViewController as? DetailViewController
            {
                detailViewController = topViewController
            }
        }
    }

    // MARK: - UIStoryboardSegue

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if
            let navigationController = segue.destination as? UINavigationController,
            let detailViewController = navigationController.topViewController as? DetailViewController
        {
            func requestForSegue(_ segue: UIStoryboardSegue) -> Request? {
                switch segue.identifier! {
                case "GET":
                    detailViewController.segueIdentifier = "GET"
                    return Alamofire.request("https://httpbin.org/get")
                case "POST":
                    detailViewController.segueIdentifier = "POST"
                    return Alamofire.request("https://httpbin.org/post", method: .post)
                case "PUT":
                    detailViewController.segueIdentifier = "PUT"
                    return Alamofire.request("https://httpbin.org/put", method: .put)
                case "DELETE":
                    detailViewController.segueIdentifier = "DELETE"
                    return Alamofire.request("https://httpbin.org/delete", method: .delete)
                case "DOWNLOAD":
                    detailViewController.segueIdentifier = "DOWNLOAD"
                    let destination = DownloadRequest.suggestedDownloadDestination(
                        for: .cachesDirectory,
                        in: .userDomainMask
                    )
                    return Alamofire.download("https://httpbin.org/stream/1", to: destination)
                default:
                    return nil
                }
            }

            if let request = requestForSegue(segue) {
                detailViewController.request = request
            }
        }
    }
}

