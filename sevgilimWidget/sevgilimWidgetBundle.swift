//
//  sevgilimWidgetBundle.swift
//  sevgilimWidget
//
//  Created by adil emre  on 30.12.2025.
//

import WidgetKit
import SwiftUI

@main
struct sevgilimWidgetBundle: WidgetBundle {
    var body: some Widget {
        sevgilimWidget()
        PartnerLocationWidget()
        sevgilimWidgetControl()
        sevgilimWidgetLiveActivity()
    }
}
