//
//  CameraAccess.swift
//  RecipeFlow
//

import SwiftUI
import AVFoundation

enum CameraAccess {
    /// Calls `granted` if the camera may be used, otherwise `denied`.
    /// iOS asks the first time; after a "no" the user has to use Settings.
    @MainActor
    static func request(granted: @escaping @MainActor () -> Void, denied: @escaping @MainActor () -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            granted()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { allowed in
                Task { @MainActor in
                    if allowed { granted() } else { denied() }
                }
            }
        default:
            denied()
        }
    }
}

extension View {
    /// Explains that camera access is off and offers a shortcut to Settings.
    func cameraDeniedAlert(isPresented: Binding<Bool>) -> some View {
        alert("Camera access is off", isPresented: isPresented) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Allow camera access in Settings to take a photo.")
        }
    }
}
