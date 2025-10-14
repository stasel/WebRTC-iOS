import SwiftUI
import WebRTC




import SwiftUI
import WebRTC
import UIKit

/// SwiftUI wrapper around WebRTC's Metal video view.
/// Calls `onCreate(view)` exactly once with the created view so you can attach it in your ViewModel.
struct RTCVideoView: UIViewRepresentable {
    typealias UIViewType = RTCMTLVideoView

    /// Called once when the underlying RTCMTLVideoView is created.
    var onCreate: (RTCMTLVideoView) -> Void

    /// Optional configuration
    var contentMode: UIView.ContentMode = .scaleAspectFit
    var mirror: Bool = false
    var enableCornerRadius: CGFloat = 0

    func makeUIView(context: Context) -> RTCMTLVideoView {
        let v = RTCMTLVideoView()
        v.videoContentMode = .scaleAspectFit   // independent of UIKit contentMode
        v.contentMode = contentMode
       
        // Flips the image horizontally
        v.transform = mirror ? CGAffineTransform(scaleX: -1, y: 1) : .identity
        
        v.clipsToBounds = true
        if enableCornerRadius > 0 {
            v.layer.cornerRadius = enableCornerRadius
        }

        // Ensure we only call onCreate once
        if !context.coordinator.didCallOnCreate {
            context.coordinator.didCallOnCreate = true
            onCreate(v)
        }
        return v
    }

    func updateUIView(_ uiView: RTCMTLVideoView, context: Context) {
        // No-op; the VM drives track attachment/detachment.
        // If you want to toggle mirroring dynamically, you can pass it in and set uiView.mirror here.
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        var didCallOnCreate = false
    }
}




struct RoomsScreen: View {
    @StateObject private var vm = RoomsViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {

                // Controls
                GroupBox(label: Text("Controls")) {
                    HStack {
                        Button("Connect WS") { vm.connectWS() }
                            .padding()
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                            .disabled(vm.isWSOpen)

                        Button("Hang Up") { vm.hangupAll() }
                            .padding(8)
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                            .disabled(!vm.isWSOpen)

                        Button("Start/Update Call") { vm.startOrUpdateCall() }
                            .padding(8)
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                            .disabled(!(vm.isWSOpen && vm.hasRemotePeer))

                        Button(vm.cameraOn ? "Stop Camera" : "Start Camera") { vm.toggleCamera() }
                            .padding(8)
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                            .disabled(!vm.isWSOpen)
                    }
                }

                // Session
                GroupBox(label: Text("Session")) {
                    HStack {
                        LabeledField(label: "Room", text: $vm.roomId)
                        LabeledField(label: "Peer", text: $vm.peerId)
                    }
                    Picker("Role", selection: $vm.role) {
                        Text("Stage").tag(Role.stage)
                        Text("Viewer").tag(Role.viewer)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: vm.role) { r in vm.changeRole(r) }
                }

                // Roster
                GroupBox(label: Text("Roster")) {
                    TextEditor(text: $vm.rosterText)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 70, maxHeight: 200)
                        .disabled(true)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3)))
                }

                // Video grid
                GroupBox(label: Text("Video")) {
                    ResponsiveGrid {
                        VStack(alignment: .leading) {
                            Text("Local").font(.headline)
                            RTCVideoView { view in vm.bindLocalView(view) }
                                .frame(height: 220)
                                .background(Color.black)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        VStack(alignment: .leading) {
                            Text("Remote").font(.headline)
                            RTCVideoView { view in vm.bindRemoteView(view) }
                                .frame(height: 220)
                                .background(Color.black)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("WebRTC Rooms (SwiftUI)")
    }
}

// Small helpers
struct LabeledField: View {
    let label: String
    @Binding var text: String
    var body: some View {
        HStack {
            Text(label).fontWeight(.semibold)
            TextField(label, text: $text)
                .textFieldStyle(.roundedBorder)
                .disableAutocorrection(true)
                .autocapitalization(.none)
        }
    }
}

/// Simple 2-column responsive grid (1 column on narrow screens)
struct ResponsiveGrid<Content: View>: View {
    @ViewBuilder var content: () -> Content
    var body: some View {
        GeometryReader { geo in
            let twoCols = geo.size.width > 700
            if twoCols {
                HStack(spacing: 12) {
                    content()
                }
            } else {
                VStack(spacing: 12) {
                    content()
                }
            }
        }
        .frame(minHeight: 240)
    }
}
