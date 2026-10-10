//
//  CloudKitSchemaDebugRow.swift
//  Inkwell Keeper
//
//  DEBUG only: a Settings › Debug Options row that pushes the full CloudKit schema
//  to Development before it's deployed to Production. See CloudKitSchemaInitializer.
//

#if DEBUG
import SwiftUI

struct CloudKitSchemaDebugRow: View {
    @State private var isRunning = false
    @State private var result: String?

    var body: some View {
        Button {
            run()
        } label: {
            HStack {
                Label("Push CloudKit Schema (Dev)", systemImage: "icloud.and.arrow.up")
                    .foregroundStyle(.orange)
                Spacer()
                if isRunning { ProgressView() }
            }
        }
        .disabled(isRunning)
        .alert("CloudKit Schema", isPresented: Binding(get: { result != nil }, set: { if !$0 { result = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(result ?? "")
        }
    }

    private func run() {
        isRunning = true
        Task {
            do {
                try await CloudKitSchemaInitializer.initializeDevelopmentSchema()
                result = "Done. Every model's full schema is in the Development environment — deploy it to Production in the CloudKit Console."
            } catch {
                result = "Failed: \(error.localizedDescription)"
            }
            isRunning = false
        }
    }
}
#endif
