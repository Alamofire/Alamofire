//
//  ContentView.swift
//  watchOS Example WatchKit Extension
//
//  Created by Jon Shier on 3/11/20.
//  Copyright © 2020 Alamofire. All rights reserved.
//

import Alamofire
import SwiftUI

struct ContentView: View {
    @ObservedObject var networking: Networking

    var body: some View {
        VStack {
            Button(action: { self.networking.performRequest() },
                   label: { Text("Perform Request") })
            Text(networking.message)
        }
    }
}

struct ContentViewPreviews: PreviewProvider {
    static let networking = Networking()

    static var previews: some View {
        ContentView(networking: networking)
    }
}
