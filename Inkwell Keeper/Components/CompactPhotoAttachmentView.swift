//
//  CompactPhotoAttachmentView.swift
//  Inkwell Keeper
//

import SwiftUI
import PhotosUI

/// A compact photo attachment section for add card modals.
/// Shows thumbnails of attached photos and allows adding via camera or photo library.
struct CompactPhotoAttachmentView: View {
    @Binding var imageAttachments: [Data]

    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showingCamera = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "camera.fill")
                    .font(.subheadline)
                    .foregroundColor(.lorcanaGold)
                Text("Attach Card Photo")
                    .font(.headline)
                    .foregroundColor(.lorcanaGold)
                Spacer()
                if !imageAttachments.isEmpty {
                    Text("\(imageAttachments.count)")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }

            if imageAttachments.isEmpty {
                HStack(spacing: 12) {
                    Button {
                        showingCamera = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "camera")
                                .font(.caption)
                            Text("Take Photo")
                                .font(.caption)
                        }
                        .foregroundColor(.lorcanaGold)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.lorcanaGold.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [6]))
                        )
                    }

                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        HStack(spacing: 6) {
                            Image(systemName: "photo")
                                .font(.caption)
                            Text("Choose Photo")
                                .font(.caption)
                        }
                        .foregroundColor(.lorcanaGold)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.lorcanaGold.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [6]))
                        )
                    }
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(imageAttachments.enumerated()), id: \.offset) { index, imageData in
                            if let uiImage = UIImage(data: imageData) {
                                ZStack(alignment: .topTrailing) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 70, height: 95)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                        )

                                    Button {
                                        imageAttachments.remove(at: index)
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.caption)
                                            .foregroundColor(.white)
                                            .background(Circle().fill(Color.black.opacity(0.6)))
                                    }
                                    .offset(x: 4, y: -4)
                                }
                            }
                        }

                        // Add more button
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
                            VStack(spacing: 4) {
                                Image(systemName: "plus")
                                    .font(.caption)
                                    .foregroundColor(.lorcanaGold)
                            }
                            .frame(width: 40, height: 95)
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
            }

            Text("Optional — attach a photo of your physical card")
                .font(.caption2)
                .foregroundColor(.gray)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.lorcanaDark.opacity(0.6))
        )
        .onChange(of: selectedPhotoItem) { newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data),
                   let compressed = uiImage.jpegData(compressionQuality: 0.8) {
                    await MainActor.run {
                        imageAttachments.append(compressed)
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
                }
            }
        }
    }
}
