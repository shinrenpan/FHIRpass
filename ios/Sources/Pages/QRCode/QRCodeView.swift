import SwiftUI
import SwiftData
import CoreImage.CIFilterBuiltins

struct QRCodeView: View {
  let viewModel: QRCodeViewModel

  var body: some View {
    Group {
      if let profile = viewModel.state.profile,
         let payload = viewModel.state.qrPayload {
        qrCodeContent(profile: profile, payload: payload)
      } else {
        emptyState
      }
    }
    .navigationTitle("我的通行碼")
    .task {
      await viewModel.doAction(.view(.isFirstAppear))
    }
  }
}

// MARK: - Subviews

private extension QRCodeView {
  func qrCodeContent(profile: QRCodeViewModel.PatientSummary, payload: String) -> some View {
    ScrollView {
      VStack(spacing: 32) {
        if let image = makeQRImage(payload) {
          Image(uiImage: image)
            .interpolation(.none)
            .resizable()
            .scaledToFit()
            .frame(width: 260, height: 260)
            .padding(20)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
        }

        VStack(spacing: 6) {
          Text(profile.name)
            .font(.title2.bold())
          Text(profile.idNumber)
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }

        Text("出示此 QR Code 給醫院櫃檯掃描，完成現場初診建檔")
          .font(.footnote)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
          .padding(.horizontal)
      }
      .padding(.vertical, 40)
    }
  }

  var emptyState: some View {
    ContentUnavailableView {
      Label("尚未設定個人資料", systemImage: "person.badge.plus")
    } description: {
      Text("請先填寫個人基本資料，才能產生醫療通行 QR Code")
    } actions: {
      Button("前往設定") {
        Task { await viewModel.doAction(.view(.setupProfileTap)) }
      }
      .buttonStyle(.borderedProminent)
    }
  }

  func makeQRImage(_ payload: String) -> UIImage? {
    let context = CIContext()
    let filter = CIFilter.qrCodeGenerator()
    filter.message = Data(payload.utf8)
    filter.correctionLevel = "M"
    guard let output = filter.outputImage else { return nil }
    let scaled = output.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
    guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
    return UIImage(cgImage: cgImage)
  }
}

#if DEBUG
#Preview("有資料") {
  let vm: QRCodeViewModel = {
    let container = try! ModelContainer(for: PatientProfile.self)
    let vm = QRCodeViewModel(modelContext: container.mainContext)
    vm.state.profile = .init(name: "陳小明", idNumber: "A123456789", birthday: Date(), gender: "male", phone: "0912345678")
    vm.state.qrPayload = vm.state.profile?.qrPayload
    return vm
  }()
  NavigationStack { QRCodeView(viewModel: vm) }
}

#Preview("空狀態") {
  let vm: QRCodeViewModel = {
    let container = try! ModelContainer(for: PatientProfile.self)
    return QRCodeViewModel(modelContext: container.mainContext)
  }()
  NavigationStack { QRCodeView(viewModel: vm) }
}
#endif
