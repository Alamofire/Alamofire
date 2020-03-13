//
//  HostingController.swift
//  watchOS Example WatchKit Extension
//
//  Created by Jon Shier on 3/11/20.
//  Copyright © 2020 Alamofire. All rights reserved.
//

import Foundation
import SwiftUI
import WatchKit

class HostingController: WKHostingController<ContentView> {
    let networking = Networking()

    override var body: ContentView {
        ContentView(networking: networking)
    }
}
