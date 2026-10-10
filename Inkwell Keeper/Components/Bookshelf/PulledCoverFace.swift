//
//  PulledCoverFace.swift
//  Inkwell Keeper
//
//  A pulled binder's front cover: the pre-rendered image when there is one, the
//  live cover otherwise.
//

import SwiftUI

struct PulledCoverFace: View {
    let container: StorageContainer
    let snapshot: PullSnapshot?

    var body: some View {
        if let face = snapshot?.face {
            face.resizable()
        } else {
            ClosedBinderCover(container: container)
        }
    }
}
