//
//  CardImageAttachmentView.swift
//  Inkwell Keeper
//
//  Created by Claude on 3/19/26.
//

import SwiftUI
import PhotosUI

struct CardImageAttachmentView: View {
    @Binding var imageAttachments: [Data]
    let onSave: () -> Void

    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showingImageSource = false
    @State private var showingCamera = false
    @State private var selectedImageIndex: Int?
    @State private var showingDeleteConfirmation = false
    @State private var imageToDeleteIndex: Int?

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "camera.fill")
                    .font(.subheadline)
                    .foregroundColor(.lorcanaGold)
                Text("My Card Photos")
                    .font(.headline)
                    .foregroundColor(.lorcanaGold)
                Spacer()
                Text("\(imageAttachments.count)")
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            if !imageAttachments.isEmpty {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(Array(imageAttachments.enumerated()), id: \.offset) { index, imageData in
                        if let uiImage = UIImage(data: imageData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 100)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                )
                                .onTapGesture {
                                    selectedImageIndex = index
                                }
                                .contextMenu {
                                    Button(role: .destructive) {
                                        imageToDeleteIndex = index
                                        showingDeleteConfirmation = true
                                    } label: {
                                        Label("Delete Photo", systemImage: "trash")
                                    }
                                }
                        }
                    }

                    addPhotoButton
                }
            } else {
                addPhotoButton
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.lorcanaDark.opacity(0.8))
        )
        .onChange(of: selectedPhotoItem) { newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data),
                   let compressed = uiImage.jpegData(compressionQuality: 0.8) {
                    await MainActor.run {
                        imageAttachments.append(compressed)
                        onSave()
                    }
                }
                await MainActor.run {
                    selectedPhotoItem = nil
                }
            }
        }
        .sheet(isPresented: $showingCamera) {
            CameraImagePicker { image in
                if let compressed = image.jpegData(compressionQuality: 0.8) {
                    imageAttachments.append(compressed)
                    onSave()
                }
            }
        }
        .fullScreenCover(item: $selectedImageIndex) { index in
            FullscreenPhotoViewer(
                images: imageAttachments,
                selectedIndex: index,
                onDelete: { deleteIndex in
                    imageAttachments.remove(at: deleteIndex)
                    onSave()
                }
            )
        }
        .confirmationDialog("Add Photo", isPresented: $showingImageSource) {
            Button("Take Photo") {
                showingCamera = true
            }
            // PhotosPicker is handled separately since it's not a simple button
        } message: {
            Text("Choose a source for your card photo")
        }
        .alert("Delete Photo", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let index = imageToDeleteIndex {
                    imageAttachments.remove(at: index)
                    onSave()
                }
            }
        } message: {
            Text("Are you sure you want to delete this photo?")
        }
    }

    private var addPhotoButton: some View {
        Menu {
            Button {
                showingCamera = true
            } label: {
                Label("Take Photo", systemImage: "camera")
            }

            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                Label("Choose from Library", systemImage: "photo.on.rectangle")
            }
        } label: {
            VStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundColor(.lorcanaGold)
                Text("Add Photo")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: imageAttachments.isEmpty ? .infinity : nil)
            .frame(height: 100)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.lorcanaGold.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [6]))
                    )
            )
        }
    }
}

// MARK: - Int extension for Identifiable conformance in fullScreenCover
extension Int: @retroactive Identifiable {
    public var id: Int { self }
}

// MARK: - Camera Image Picker
struct CameraImagePicker: UIViewControllerRepresentable {
    let onImageCaptured: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraImagePicker

        init(_ parent: CameraImagePicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImageCaptured(image)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - Fullscreen Photo Viewer
struct FullscreenPhotoViewer: View {
    let images: [Data]
    @State var selectedIndex: Int
    let onDelete: (Int) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var showingDeleteConfirmation = false

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                TabView(selection: $selectedIndex) {
                    ForEach(Array(images.enumerated()), id: \.offset) { index, imageData in
                        if let uiImage = UIImage(data: imageData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .tag(index)
                        }
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .automatic))
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }

                ToolbarItem(placement: .principal) {
                    Text("\(selectedIndex + 1) of \(images.count)")
                        .font(.subheadline)
                        .foregroundColor(.white)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingDeleteConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .alert("Delete Photo", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                let indexToDelete = selectedIndex
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    onDelete(indexToDelete)
                }
            }
        } message: {
            Text("Are you sure you want to delete this photo?")
        }
    }
}
