// BackgroundViewController.swift
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

class BackgroundViewController: UITableViewController {

    var manager:Manager?
    var requests = [Request]()

    override func viewDidLoad() {
        super.viewDidLoad()
        manager = Manager.backgroundSession(BackgroundSessionId)
        manager?.getAllRequestsWithCompletionHandler { requests in
            let sorted = requests.sort { r1, r2 in
                let d1 = r1[self.DateKey] as! NSDate
                let d2 = r2[self.DateKey] as! NSDate
                return d1.compare(d2) == NSComparisonResult.OrderedAscending
            }
            dispatch_async(dispatch_get_main_queue()) { () -> Void in
                self.tableView.beginUpdates()
                for r in sorted {
                    self.connectRequest(r)
                }
                self.tableView.endUpdates()
            }
        }
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.Add, target: self, action: "addDownload:")
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    private func handleProgressForRequest(request:Request?) {
        if let req = request {
            dispatch_async(dispatch_get_main_queue()) { [weak self] () -> Void in
                if let index = self?.requests.indexOf({ r in r == req }) {
                    if let cell = self?.tableView.cellForRowAtIndexPath(NSIndexPath(forRow: index, inSection: 0)) as? BackgroundDownloadCell {
                        cell.progress.progress = Float(req.progress.fractionCompleted)
                    }
                }
            }
        }
    }
    
    private func handleResponseForRequest(request:Request?, error:NSError?) {
        if let error = error {
            print("Failed with error: \(error)")
        } else {
            print("Downloaded file successfully")
        }
        if let req = request {
            if let index = self.requests.indexOf({ r in r == req}) {
                self.requests.removeAtIndex(index)
                self.tableView.deleteRowsAtIndexPaths([NSIndexPath(forRow: index, inSection: 0)], withRowAnimation: UITableViewRowAnimation.Automatic)
            }
        }
    }
    
    func connectRequest(request:Request) {
        // Set progress and response handling for the request
        request
            .progress { [weak self, request] _, _, _ in self?.handleProgressForRequest(request) }
            .response { [weak self, request] _, _, _, error in self?.handleResponseForRequest(request, error: error) }

        // Add to rows displayed in table view
        requests.append(request)
        tableView.insertRowsAtIndexPaths([NSIndexPath(forRow: requests.count-1, inSection: 0)], withRowAnimation: UITableViewRowAnimation.Automatic)
    }
    
    // Keys for data storage in requests
    private let TitleKey = "title"
    private let DateKey = "date"
    private let TestFileUrl = "https://azspeastus.blob.core.windows.net/private/100MB.bin?sv=2015-04-05&sr=b&sig=n64qKqYkEV4Kxm%2F0ZXclaZDtNkw%2BHDyIOrlmuCqZKJc%3D&se=2015-12-29T14%3A30%3A32Z&sp=r"
    
    @IBAction func addDownload(sender: UIBarButtonItem) {
        let destination = Alamofire.Request.suggestedDownloadDestination(directory: .DocumentDirectory, domain: .UserDomainMask)
        if let request = manager?.download(.GET, TestFileUrl, destination:destination) {
            request[TitleKey] = "Started at \(NSDate().description)"
            request[DateKey] = NSDate()
            connectRequest(request)
        }
    }
    
    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return requests.count
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("BackgroundDownloadCell", forIndexPath: indexPath) as! BackgroundDownloadCell
        
        let request = requests[indexPath.row]
        cell.label.text = request[TitleKey] as? String
        cell.progress.progress = Float(request.progress.fractionCompleted)
        
        return cell
    }
}

