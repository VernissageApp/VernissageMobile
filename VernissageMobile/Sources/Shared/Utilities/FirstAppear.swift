//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct FirstAppear: ViewModifier {
    let action: () async -> Void

    @State private var hasAppeared = false

    
    init(action: @escaping () async -> Void) {
        self.action = action
    }
    
    func body(content: Content) -> some View {
        content.task {
            guard !hasAppeared else { return }
            hasAppeared = true
            
            await action()
        }
    }
}
