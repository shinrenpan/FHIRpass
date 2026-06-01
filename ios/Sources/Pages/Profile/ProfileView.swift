import SwiftUI
import SwiftData

struct ProfileView: View {
  let viewModel: ProfileViewModel

  var body: some View {
    Form {
      Section("基本資料") {
        TextField("姓名", text: binding(\.name, action: { .nameChanged($0) }))
          .disabled(!viewModel.state.isEditing)

        TextField("身分證字號", text: binding(\.idNumber, action: { .idNumberChanged($0) }))
          .textInputAutocapitalization(.characters)
          .disabled(!viewModel.state.isEditing)

        if viewModel.state.isEditing {
          DatePicker("生日", selection: bindingDate(), displayedComponents: .date)
        } else {
          LabeledContent("生日", value: viewModel.state.birthday.formatted(date: .abbreviated, time: .omitted))
        }

        if viewModel.state.isEditing {
          Picker("性別", selection: bindingGender()) {
            ForEach(ProfileViewModel.Gender.allCases, id: \.self) { gender in
              Text(gender.displayName).tag(gender)
            }
          }
        } else {
          LabeledContent("性別", value: viewModel.state.gender.displayName)
        }

        TextField("手機號碼", text: binding(\.phone, action: { .phoneChanged($0) }))
          .keyboardType(.phonePad)
          .disabled(!viewModel.state.isEditing)
      }

      if viewModel.state.isEditing {
        Section {
          Button("儲存") {
            Task { await viewModel.doAction(.view(.saveTap)) }
          }
          .disabled(viewModel.state.saveStatus.isLoading || viewModel.state.name.isEmpty || viewModel.state.idNumber.isEmpty)
          .frame(maxWidth: .infinity)

          if viewModel.state.hasExistingProfile {
            Button("取消", role: .cancel) {
              Task { await viewModel.doAction(.view(.cancelTap)) }
            }
            .frame(maxWidth: .infinity)
          }
        }
      }

      if case let .error(message) = viewModel.state.saveStatus {
        Section {
          Text(message)
            .foregroundStyle(.red)
            .font(.footnote)
        }
      }
    }
    .navigationTitle("個人資料")
    .toolbar {
      if !viewModel.state.isEditing {
        ToolbarItem(placement: .topBarTrailing) {
          Button("編輯") {
            Task { await viewModel.doAction(.view(.editTap)) }
          }
        }
      }
    }
    .task {
      await viewModel.doAction(.view(.isFirstAppear))
    }
  }
}

// MARK: - Binding Helpers

private extension ProfileView {
  func binding<T>(_ keyPath: KeyPath<ProfileViewModel.State, T>, action: @escaping (T) -> ProfileViewModel.ViewAction) -> Binding<T> {
    Binding(
      get: { viewModel.state[keyPath: keyPath] },
      set: { newValue in Task { await viewModel.doAction(.view(action(newValue))) } }
    )
  }

  func bindingDate() -> Binding<Date> {
    Binding(
      get: { viewModel.state.birthday },
      set: { newValue in Task { await viewModel.doAction(.view(.birthdayChanged(newValue))) } }
    )
  }

  func bindingGender() -> Binding<ProfileViewModel.Gender> {
    Binding(
      get: { viewModel.state.gender },
      set: { newValue in Task { await viewModel.doAction(.view(.genderChanged(newValue))) } }
    )
  }
}

#if DEBUG
#Preview("有資料") {
  let vm: ProfileViewModel = {
    let container = try! ModelContainer(for: PatientProfile.self)
    let vm = ProfileViewModel(modelContext: container.mainContext)
    vm.state.name = "陳小明"
    vm.state.idNumber = "A123456789"
    vm.state.phone = "0912345678"
    vm.state.hasExistingProfile = true
    return vm
  }()
  NavigationStack { ProfileView(viewModel: vm) }
}

#Preview("新建") {
  let vm: ProfileViewModel = {
    let container = try! ModelContainer(for: PatientProfile.self)
    let vm = ProfileViewModel(modelContext: container.mainContext)
    vm.state.isEditing = true
    return vm
  }()
  NavigationStack { ProfileView(viewModel: vm) }
}
#endif
