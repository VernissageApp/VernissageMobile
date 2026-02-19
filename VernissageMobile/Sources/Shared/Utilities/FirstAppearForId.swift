//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct FirstAppearForId<ID: Equatable>: ViewModifier {
    let id: ID
    let action: () async -> Void

    @State private var hasAppearedForId: [ID] = []

    init(id: ID, action: @escaping () async -> Void) {
        self.id = id
        self.action = action
    }
    
    func body(content: Content) -> some View {
        content.task(id: id) {
            guard hasAppearedForId.contains(id) == false else { return }
            hasAppearedForId.append(id)
            
            await action()
        }
    }
}
