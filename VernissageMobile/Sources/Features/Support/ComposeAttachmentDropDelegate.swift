//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct ComposeAttachmentDropDelegate: DropDelegate {
    let item: ComposeStatusAttachment

    @Binding var items: [ComposeStatusAttachment]
    @Binding var draggedAttachmentID: UUID?

    func performDrop(info: DropInfo) -> Bool {
        draggedAttachmentID = nil
        return true
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func dropEntered(info: DropInfo) {
        guard let draggedAttachmentID,
              draggedAttachmentID != item.id,
              let fromIndex = items.firstIndex(where: { $0.id == draggedAttachmentID }),
              let toIndex = items.firstIndex(of: item) else {
            return
        }

        withAnimation(.default) {
            items.move(
                fromOffsets: IndexSet(integer: fromIndex),
                toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex
            )
        }
    }
}
