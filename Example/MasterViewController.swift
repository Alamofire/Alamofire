// MasterViewController.swift
//
// Copyright (c) 2014–2015 Alamofire Software Foundation (http://alamofire.org/)
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

class MasterViewController: UITableViewController {

    @IBOutlet weak var titleImageView: UIImageView!

    var detailViewController: DetailViewController? = nil
    var objects = NSMutableArray()

    override func awakeFromNib() {
        super.awakeFromNib()

        self.navigationItem.titleView = self.titleImageView
    }

    // MARK: - UIViewController

    override func viewDidLoad() {
        super.viewDidLoad()

        if let split = self.splitViewController {
            let controllers = split.viewControllers
            detailViewController = (controllers.last as! UINavigationController).topViewController as? DetailViewController
        }
    }

    // MARK: - UIStoryboardSegue

    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if let detailViewController = (segue.destinationViewController as! UINavigationController).topViewController as? DetailViewController {
            func requestForSegue(segue: UIStoryboardSegue) -> Request? {
                switch segue.identifier as String! {
                    case "GET":
                        return Alamofire.request(.GET, URLString: "http://httpbin.org/get")
                    case "POST":
                        return Alamofire.request(.POST, URLString: "http://httpbin.org/post")
                    case "PUT":
                        return Alamofire.request(.PUT, URLString: "http://httpbin.org/put")
                    case "DELETE":
                        return Alamofire.request(.DELETE, URLString: "http://httpbin.org/delete")
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

