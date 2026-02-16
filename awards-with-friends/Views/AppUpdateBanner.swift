import SwiftUI

struct AppUpdateBanner: View {
    private var updateService: AppUpdateService { AppUpdateService.shared }

    var body: some View {
        if updateService.updateAvailable, let url = updateService.appStoreURL {
            HStack(spacing: 10) {
                Image(systemName: "arrow.down.circle.fill")
                    .foregroundStyle(.white)

                Text("New app update available")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)

                Spacer()

                Link(destination: url) {
                    Text("Update")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.blue)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(.white)
                        .cornerRadius(14)
                }

                Button {
                    withAnimation(.easeOut(duration: 0.2)) {
                        updateService.dismiss()
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.blue)
            .cornerRadius(25)
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }
}
