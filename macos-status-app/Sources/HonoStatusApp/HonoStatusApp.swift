import AppKit
import SwiftUI

@main
struct HonoStatusApp: App {
  @StateObject private var model = HonoServerController()

  init() {
    NSApplication.shared.setActivationPolicy(.accessory)
  }

  var body: some Scene {
    MenuBarExtra {
      ContentView(model: model)
        .frame(width: 320)
    } label: {
      Label(model.menuBarTitle, systemImage: model.menuBarSymbol)
    }
    .menuBarExtraStyle(.window)
  }
}

struct ContentView: View {
  @ObservedObject var model: HonoServerController

  private var serverToggleBinding: Binding<Bool> {
    Binding(
      get: { model.isRunning || model.isStarting },
      set: { shouldRun in
        Task {
          if shouldRun {
            await model.startServerIfNeeded(forceRestart: true)
          } else {
            await model.stopServer()
          }
        }
      }
    )
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      VStack(alignment: .leading, spacing: 6) {
        Text("Hono API")
          .font(.headline)
        Text(model.statusDescription)
          .font(.subheadline)
          .foregroundStyle(model.statusColor)
        Text("地址: \(model.helloURL.absoluteString)")
          .font(.caption)
          .foregroundStyle(.secondary)
        Text("测试网站: \(model.testWebsiteURL.absoluteString)")
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      HStack(spacing: 10) {
        Toggle("API", isOn: serverToggleBinding)
          .toggleStyle(.switch)
          .disabled(model.isStarting || model.isStopping)

        Button("打开 /hello") {
          model.openHelloURL()
        }

        Button("打开 /files") {
          model.openFilesURL()
        }
      }

      Button("打开测试网站") {
        model.openTestWebsite()
      }

      if let errorMessage = model.errorMessage {
        Text(errorMessage)
          .font(.caption)
          .foregroundStyle(.red)
      }

      VStack(alignment: .leading, spacing: 6) {
        Text("最近日志")
          .font(.subheadline.weight(.semibold))

        ScrollView {
          Text(model.recentLogs)
            .font(.system(size: 11, design: .monospaced))
            .frame(maxWidth: .infinity, alignment: .leading)
            .textSelection(.enabled)
        }
        .frame(height: 140)
        .padding(10)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 12))
      }

      Divider()

      HStack {
        Text("项目路径: \(model.projectRoot.path)")
          .font(.caption2)
          .foregroundStyle(.secondary)

        Spacer()

        Button("退出") {
          Task {
            await model.quitApp()
          }
        }
      }
    }
    .padding(16)
  }
}
