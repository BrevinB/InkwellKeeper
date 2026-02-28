//
//  CardImageAttachmentView.swift
//  Inkwell Keeper
//

import SwiftUI
import PhotosUI

struct CardImageAttachmentView: View {
    let collectedCard: CollectedCard
    @EnvironmentObject var collectionManager: CollectionManager
    @State private var attachments: [CardImageAttachment] = []
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showingImageSource = false
    @State private var showingCamera = false
    @State private var showingFullscreenImage: CardImageAttachment?
    @State private var attachmentToDelete: CardImageAttachment?

    private let imageStorage = CardImageStorageService.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("My Card Photos")
                    .font(.headline)
                    .foregroundColor(.lorcanaGold)
                Spacer()
                addPhotoButton
            }

            if attachments.isEmpty {
                emptyState
            } else {
                imageGrid
            }
        }
        .onAppear {
            loadAttachments()
        }
        .confirmationDialog("Add Photo", isPresented: $showingImageSource) {
            Button("Take Photo") { showingCamera = true }
            Button("Choose from Library") { } // Handled by PhotosPicker overlay below
            Button("Cancel", role: .cancel) { }
        }
        .fullScreenCover(item: $showingFullscreenImage) { attachment in
            FullscreenAttachmentViewer(
                attachment: attachment,
                onDelete: {
                    removeAttachment(attachment)
                    showingFullscreenImage = nil
                }
            )
        }
        .fullScreenCover(isPresented: $showingCamera) {
            CameraCaptureView { image in
                addImage(image)
            }
        }
        .alert("Delete Photo", isPresented: Binding(
            get: { attachmentToDelete != nil },
            set: { if !$0 { attachmentToDelete = nil } }
        )) {
            Button("Cancel", role: .cancel) { attachmentToDelete = nil }
            Button("Delete", role: .destructive) {
                if let attachment = attachmentToDelete {
                    removeAttachment(attachment)
                    attachmentToDelete = nil
                }
            }
        } message: {
            Text("Are you sure you want to delete this photo?")
        }
    }

    private var addPhotoButton: some View {
        Menu {
            Button(action: { showingCamera = true }) {
                Label("Take Photo", systemImage: "camera")
            }
            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                Label("Choose from Library", systemImage: "photo.on.rectangle")
            }
        } label: {
            Image(systemName: "plus.circle.fill")
                .font(.title3)
                .foregroundColor(.lorcanaGold)
        }
        .onChange(of: selectedPhotoItem) { newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await MainActor.run {
                        addImage(image)
                    }
                }
                selectedPhotoItem = nil
            }
        }
    }

    private var emptyState: some View {
        HStack {
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: "camera.badge.ellipsis")
                    .font(.title2)
                    .foregroundColor(.gray)
                Text("No photos yet")
                    .font(.caption)
                    .foregroundColor(.gray)
                Text("Add photos of your real card")
                    .font(.caption2)
                    .foregroundColor(.gray.opacity(0.7))
            }
            .padding(.vertical, 16)
            Spacer()
        }
    }

    private var imageGrid: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(attachments, id: \.id) { attachment in
                    attachmentThumbnail(attachment)
                }
            }
        }
    }

    private func attachmentThumbnail(_ attachment: CardImageAttachment) -> some View {
        Group {
            if let image = imageStorage.loadImage(fileName: attachment.fileName) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 90, height: 126)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.lorcanaGold.opacity(0.3), lineWidth: 1)
                    )
                    .onTapGesture {
                        showingFullscreenImage = attachment
                    }
                    .contextMenu {
                        Button(role: .destructive) {
                            attachmentToDelete = attachment
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 90, height: 126)
                    .overlay(
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.gray)
                    )
            }
        }
    }

    private func addImage(_ image: UIImage) {
        if let attachment = collectionManager.addImageAttachment(to: collectedCard, image: image) {
            withAnimation {
                attachments.append(attachment)
            }
        }
    }

    private func removeAttachment(_ attachment: CardImageAttachment) {
        collectionManager.removeImageAttachment(attachment)
        withAnimation {
            attachments.removeAll { $0.id == attachment.id }
        }
    }

    private func loadAttachments() {
        attachments = collectionManager.getImageAttachments(for: collectedCard)
    }
}

// MARK: - Fullscreen Attachment Viewer

struct FullscreenAttachmentViewer: View {
    let attachment: CardImageAttachment
    let onDelete: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0

    private let imageStorage = CardImageStorageService.shared

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let image = imageStorage.loadImage(fileName: attachment.fileName) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaleEffect(scale)
                    .gesture(
                        MagnifyGesture()
                            .onChanged { value in
                                scale = lastScale * value.magnification
                            }
                            .onEnded { _ in
                                lastScale = scale
                                if scale < 1.0 {
                                    withAnimation { scale = 1.0 }
                                    lastScale = 1.0
                                }
                            }
                    )
                    .onTapGesture(count: 2) {
                        withAnimation {
                            if scale > 1.0 {
                                scale = 1.0
                                lastScale = 1.0
                            } else {
                                scale = 2.5
                                lastScale = 2.5
                            }
                        }
                    }
            }

            VStack {
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundColor(.white)
                    }
                    Spacer()
                    Button(role: .destructive, action: onDelete) {
                        Image(systemName: "trash.circle.fill")
                            .font(.title)
                            .foregroundColor(.red)
                    }
                }
                .padding()
                Spacer()

                Text(attachment.dateAdded, style: .date)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.bottom, 8)
            }
        }
    }
}

// MARK: - Camera Capture View

struct CameraCaptureView: UIViewControllerRepresentable {
    let onCapture: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture, dismiss: dismiss)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onCapture: (UIImage) -> Void
        let dismiss: DismissAction

        init(onCapture: @escaping (UIImage) -> Void, dismiss: DismissAction) {
            self.onCapture = onCapture
            self.dismiss = dismiss
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                onCapture(image)
            }
            dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismiss()
        }
    }
}

