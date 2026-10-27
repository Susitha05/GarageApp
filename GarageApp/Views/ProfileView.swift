import SwiftUI
import PhotosUI
import UIKit

struct ProfileView: View {
    @Environment(AppState.self) private var app
    @Environment(AuthService.self) private var auth
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var pickerItem: PhotosPickerItem?
    @State private var isSaving = false

    var body: some View {
        Form {
            Section {
                VStack(spacing: 12) {
                    AvatarView(data: app.profileImageData, size: 110)
                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        Label("Change photo", systemImage: "photo")
                    }
                    if app.profileImageData != nil {
                        Button("Remove photo", role: .destructive) { removePhoto() }.font(.footnote)
                    }
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            }
            Section("Personal info") {
                TextField("Full name", text: $name).textContentType(.name)
                LabeledContent("Email", value: app.email)
            }
            Section {
                Button {
                    save()
                } label: {
                    if isSaving { ProgressView().frame(maxWidth: .infinity) } else { Text("Save").frame(maxWidth: .infinity) }
                }
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
            }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { name = app.userName }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task { @MainActor in
                defer { pickerItem = nil }
                guard let data = try? await item.loadTransferable(type: Data.self) else { return }
                // Resize off the main thread, then come back to update the UI.
                let small = await Task.detached(priority: .userInitiated) {
                    UIImage(data: data).flatMap { ImageResizer.squareJPEG(from: $0) }
                }.value
                guard let small else { return }
                app.profileImageData = small
                await auth.updateProfile(photo: small)
            }
        }
    }

    private func save() {
        isSaving = true
        Task { @MainActor in
            let clean = name.trimmingCharacters(in: .whitespaces)
            app.userName = clean
            await auth.updateProfile(name: clean)
            isSaving = false
            dismiss()
        }
    }

    private func removePhoto() {
        app.profileImageData = nil
        Task { @MainActor in await auth.updateProfile(photo: Data()) }
    }
}

/// 256×256 square JPEG (~20–40 KB) so it fits comfortably in a Firestore document.
enum ImageResizer {
    static func squareJPEG(from image: UIImage, side: CGFloat = 256) -> Data? {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format)
        let result = renderer.image { _ in
            let ratio = max(side / image.size.width, side / image.size.height)
            let w = image.size.width * ratio, h = image.size.height * ratio
            image.draw(in: CGRect(x: (side - w) / 2, y: (side - h) / 2, width: w, height: h))
        }
        return result.jpegData(compressionQuality: 0.7)
    }
}

#Preview {
    NavigationStack { ProfileView() }
        .environment(AppState(role: .customer))
        .environment(AuthService.preview())
}
