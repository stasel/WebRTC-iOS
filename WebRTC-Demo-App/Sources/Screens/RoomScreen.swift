import SwiftUI
import WebRTC

struct RoomsScreen: View {
    @StateObject private var vm = RoomsViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {

                // Controls
                GroupBox(label: Text("Controls")) {
                    HStack {
                        Button("Connect WS") { vm.connectWS() }
                            .buttonStyle(.borderedProminent)
                            .disabled(vm.isWSOpen)

                        Button("Hang Up") { vm.hangupAll() }
                            .buttonStyle(.bordered)
                            .tint(.red)
                            .disabled(!vm.isWSOpen)

                        Button("Start/Update Call") { vm.startOrUpdateCall() }
                            .buttonStyle(.bordered)
                            .disabled(!(vm.isWSOpen && vm.hasRemotePeer))

                        Button(vm.cameraOn ? "Stop Camera" : "Start Camera") { vm.toggleCamera() }
                            .buttonStyle(.bordered)
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
