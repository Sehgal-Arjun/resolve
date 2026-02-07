import SwiftUI

struct ChatPaletteView: View {
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.10))
                )

            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .foregroundStyle(.secondary)

                TextField("Ask Resolve…", text: $text)
                    .textFieldStyle(.plain)
                    .font(.system(size: 18, weight: .medium))
                    .focused($focused)
            }
            .padding(18)
        }
        .frame(width: 620, height: 140)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                focused = true
            }
        }
    }
}

#Preview {
    ChatPaletteView()
}
