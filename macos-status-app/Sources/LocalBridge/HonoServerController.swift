import AppKit
import Combine
import Darwin
import Foundation
import SwiftUI

@MainActor
final class LocalBridgeController: ObservableObject {
  struct PortOccupant {
    let pid: Int32
    let command: String
  }

  enum ServerStatus {
    case stopped
    case starting
    case stopping
    case running
    case failed(String)
  }

  @Published private(set) var status: ServerStatus = .stopped
  @Published private(set) var recentLogs = "尚未启动服务。"
  @Published private(set) var errorMessage: String?

  let port = 3000
  let helloURL = URL(string: "http://127.0.0.1:3000/hello")!
  let filesURL = URL(string: "http://127.0.0.1:3000/files")!
  let testWebsiteURL: URL

  private let logLimit = 24
  private let healthCheckInterval: TimeInterval = 2
  private let startupGracePeriod: TimeInterval = 8
  private var process: Process?
  private var pollTask: Task<Void, Never>?
  private var logLines: [String] = []
  private var requestID: UInt = 0
  private var startupDeadline: Date?

  init() {
    let configuredURL = ProcessInfo.processInfo.environment["TEST_WEBSITE_URL"]
    self.testWebsiteURL = URL(string: configuredURL ?? Self.defaultTestWebsiteURLString())!

    Task { [weak self] in
      await self?.startServerIfNeeded()
    }
  }

  var projectRoot: URL {
    resolvedProjectRoot ?? sourceRootFallback
  }

  var devGoAPIRootURL: URL {
    projectRoot.appendingPathComponent("go-api", isDirectory: true)
  }

  var runtimeWorkingDirectoryURL: URL {
    bundledRuntimeRootURL ?? devGoAPIRootURL
  }

  var bundledGoBinaryURL: URL? {
    guard let runtimeRootURL = bundledRuntimeRootURL else {
      return nil
    }

    let binaryURL = runtimeRootURL.appendingPathComponent("go-api")
    guard FileManager.default.isExecutableFile(atPath: binaryURL.path) else {
      return nil
    }

    return binaryURL
  }

  var runtimeDisplayName: String {
    "Go"
  }

  var isRunning: Bool {
    if case .running = status {
      return true
    }
    return false
  }

  var isStarting: Bool {
    if case .starting = status {
      return true
    }
    return false
  }

  var isStopping: Bool {
    if case .stopping = status {
      return true
    }
    return false
  }

  var statusDescription: String {
    switch status {
    case .stopped:
      return "未运行"
    case .starting:
      return "启动中"
    case .stopping:
      return "停止中"
    case .running:
      return "运行中"
    case .failed:
      return "启动失败"
    }
  }

  var menuBarTitle: String {
    switch status {
    case .running:
      return "Bridge On"
    case .starting:
      return "Bridge ..."
    case .stopping:
      return "Bridge ..."
    case .stopped:
      return "Bridge Off"
    case .failed:
      return "Bridge Err"
    }
  }

  var menuBarSymbol: String {
    switch status {
    case .running:
      return "checkmark.circle.fill"
    case .starting:
      return "arrow.triangle.2.circlepath.circle.fill"
    case .stopping:
      return "stop.circle.fill"
    case .stopped:
      return "pause.circle.fill"
    case .failed:
      return "xmark.circle.fill"
    }
  }

  var statusColor: Color {
    switch status {
    case .running:
      return .green
    case .starting:
      return .orange
    case .stopping:
      return .orange
    case .stopped:
      return .secondary
    case .failed:
      return .red
    }
  }

  private var sourceRootFallback: URL {
    URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
  }

  private var bundledRuntimeRootURL: URL? {
    guard let resourceURL = Bundle.main.resourceURL else {
      return nil
    }

    let runtimeURL = resourceURL.appendingPathComponent("runtime", isDirectory: true)
    guard FileManager.default.fileExists(atPath: runtimeURL.path) else {
      return nil
    }

    return runtimeURL
  }

  private var resolvedProjectRoot: URL? {
    let candidates = [
      Bundle.main.bundleURL,
      URL(fileURLWithPath: FileManager.default.currentDirectoryPath),
      sourceRootFallback
    ]

    for candidate in candidates {
      if let root = findProjectRoot(startingAt: candidate) {
        return root
      }
    }

    return nil
  }

  func startServerIfNeeded(forceRestart: Bool = false) async {
    if forceRestart {
      await stopServer()
    } else if process?.isRunning == true || isRunning || isStarting {
      return
    }

    let executableURL: URL
    let arguments: [String]

    if let bundledGoBinaryURL {
      executableURL = bundledGoBinaryURL
      arguments = []
    } else {
      guard FileManager.default.fileExists(atPath: devGoAPIRootURL.path) else {
        setFailure("找不到 Go API 目录: \(devGoAPIRootURL.path)")
        return
      }
      guard let goBinaryURL = resolveGoBinaryURL() else {
        setFailure("找不到 Go。请先安装 Go，或通过 GO_BINARY_PATH 指向 go 可执行文件。")
        return
      }
      executableURL = goBinaryURL
      arguments = ["run", "-ldflags=-linkmode=external", "."]
    }

    if let occupant = await findPortOccupant() {
      let shouldTerminate = await promptToTerminatePortOccupant(occupant)
      if shouldTerminate {
        let terminated = await terminatePortOccupant(occupant)
        guard terminated else {
          setFailure("端口 \(port) 仍被占用，未能结束进程 \(occupant.pid)")
          return
        }
        appendLog("已结束占用端口 \(port) 的进程 \(occupant.pid)")
      } else {
        setFailure("端口 \(port) 已被 \(occupant.command)（PID \(occupant.pid)）占用")
        return
      }
    }

    requestID += 1
    let currentRequestID = requestID
    errorMessage = nil
    status = .starting
    startupDeadline = Date().addingTimeInterval(startupGracePeriod)
    appendLog("准备启动 \(runtimeDisplayName) 进程")

    let process = Process()
    let pipe = Pipe()

    process.executableURL = executableURL
    process.arguments = arguments
    process.currentDirectoryURL = runtimeWorkingDirectoryURL
    process.standardOutput = pipe
    process.standardError = pipe

    pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
      let data = handle.availableData
      guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else {
        return
      }

      Task { @MainActor [weak self] in
        text
          .split(whereSeparator: \.isNewline)
          .map(String.init)
          .forEach { self?.appendLog($0) }
      }
    }

    process.terminationHandler = { [weak self] terminatedProcess in
      Task { @MainActor [weak self] in
        guard let self else { return }
        self.pollTask?.cancel()
        self.pollTask = nil
        if self.process?.processIdentifier == terminatedProcess.processIdentifier {
          self.process = nil
        }

        let code = terminatedProcess.terminationStatus
        guard currentRequestID == self.requestID else {
          self.appendLog("忽略过期进程回调，PID \(terminatedProcess.processIdentifier)")
          return
        }

        if case .stopping = self.status {
          self.status = .stopped
          self.startupDeadline = nil
          self.appendLog("\(self.runtimeDisplayName) 进程已停止，退出码 \(code)")
        } else if case .running = self.status {
          self.status = .stopped
          self.startupDeadline = nil
          self.appendLog("\(self.runtimeDisplayName) 进程已停止，退出码 \(code)")
        } else {
          self.startupDeadline = nil
          self.setFailure("\(self.runtimeDisplayName) 进程退出，退出码 \(code)")
        }
      }
    }

    do {
      try process.run()
      self.process = process
      appendLog("\(runtimeDisplayName) 进程已启动，PID \(process.processIdentifier)")
      startPolling(requestID: currentRequestID)
    } catch {
      startupDeadline = nil
      setFailure("无法启动 \(runtimeDisplayName): \(error.localizedDescription)")
    }
  }

  func stopServer() async {
    requestID += 1
    let currentRequestID = requestID
    pollTask?.cancel()
    pollTask = nil
    startupDeadline = nil

    guard let process else {
      status = .stopped
      appendLog("没有可停止的 \(runtimeDisplayName) 进程")
      return
    }

    if !process.isRunning {
      self.process = nil
      status = .stopped
      appendLog("\(runtimeDisplayName) 进程已经停止")
      return
    }

    appendLog("正在停止 \(runtimeDisplayName) 进程")
    status = .stopping

    process.terminate()

    let terminated = await waitForProcessToExit(process, timeout: 3)
    guard currentRequestID == requestID else {
      appendLog("忽略过期停止请求")
      return
    }

    if terminated {
      self.process = nil
      status = .stopped
      appendLog("\(runtimeDisplayName) 进程已确认停止")
    } else {
      setFailure("停止超时，请稍后重试")
    }
  }

  func openHelloURL() {
    NSWorkspace.shared.open(helloURL)
  }

  func openFilesURL() {
    NSWorkspace.shared.open(filesURL)
  }

  func openTestWebsite() {
    NSWorkspace.shared.open(testWebsiteURL)
  }

  func quitApp() async {
    if process?.isRunning == true || isRunning || isStarting || isStopping {
      await stopServer()
    }

    NSApplication.shared.terminate(nil)
  }

  private func startPolling(requestID: UInt) {
    pollTask?.cancel()
    pollTask = Task { [weak self] in
      guard let self else { return }

      while !Task.isCancelled {
        await self.refreshStatus(requestID: requestID)
        try? await Task.sleep(for: .seconds(healthCheckInterval))
      }
    }
  }

  private func refreshStatus(requestID: UInt) async {
    guard requestID == self.requestID else {
      return
    }

    do {
      let (data, response) = try await URLSession.shared.data(from: helloURL)
      guard let httpResponse = response as? HTTPURLResponse else {
        if isStarting {
          appendLog("健康检查暂未拿到有效响应，继续等待")
          return
        }
        setFailure("健康检查没有拿到有效响应")
        return
      }

      let text = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
      if httpResponse.statusCode == 200 && text == "world" {
        errorMessage = nil
        if !isRunning {
          appendLog("健康检查成功")
        }
        startupDeadline = nil
        status = .running
      } else {
        if isStarting, let startupDeadline, Date() < startupDeadline {
          appendLog("接口尚未就绪，HTTP \(httpResponse.statusCode)，继续等待")
          return
        }
        startupDeadline = nil
        setFailure("健康检查失败，HTTP \(httpResponse.statusCode)")
      }
    } catch {
      if isStopping {
        return
      }
      if isStarting, let startupDeadline, Date() < startupDeadline {
        appendLog("启动等待中: \(error.localizedDescription)")
        return
      }
      startupDeadline = nil
      setFailure("健康检查失败: \(error.localizedDescription)")
    }
  }

  private func setFailure(_ message: String) {
    errorMessage = message
    status = .failed(message)
    appendLog(message)
  }

  private func appendLog(_ message: String) {
    logLines.append(message)
    if logLines.count > logLimit {
      logLines.removeFirst(logLines.count - logLimit)
    }
    recentLogs = logLines.joined(separator: "\n")
  }

  private func findPortOccupant() async -> PortOccupant? {
    let output = await runCommand(
      executableURL: URL(fileURLWithPath: "/usr/sbin/lsof"),
      arguments: ["-nP", "-iTCP:\(port)", "-sTCP:LISTEN", "-F", "pc"]
    )

    guard output.terminationStatus == 0 else {
      return nil
    }

    let lines = output.stdout
      .split(whereSeparator: \.isNewline)
      .map(String.init)

    var pid: Int32?
    var command: String?

    for line in lines {
      guard let prefix = line.first else { continue }
      let value = String(line.dropFirst())
      if prefix == "p" {
        pid = Int32(value)
      } else if prefix == "c" {
        command = value
      }

      if let pid, let command {
        if process?.processIdentifier == pid {
          return nil
        }
        return PortOccupant(pid: pid, command: command)
      }
    }

    return nil
  }

  private func promptToTerminatePortOccupant(_ occupant: PortOccupant) async -> Bool {
    let alert = NSAlert()
    alert.messageText = "端口 \(port) 已被占用"
    alert.informativeText = "\(occupant.command)（PID \(occupant.pid)）正在监听 \(port) 端口。是否帮你结束这个进程，然后继续启动 Local Bridge？"
    alert.alertStyle = .warning
    alert.addButton(withTitle: "结束并继续")
    alert.addButton(withTitle: "取消")

    return alert.runModal() == .alertFirstButtonReturn
  }

  private func terminatePortOccupant(_ occupant: PortOccupant) async -> Bool {
    appendLog("尝试结束占用端口的进程 \(occupant.pid)")

    if kill(occupant.pid, SIGTERM) != 0 {
      appendLog("发送 SIGTERM 失败，errno \(errno)")
      return false
    }

    let deadline = Date().addingTimeInterval(5)
    while Date() < deadline {
      if await findPortOccupant() == nil {
        return true
      }
      try? await Task.sleep(for: .milliseconds(200))
    }

    appendLog("占用端口的进程未在预期时间内退出")
    return false
  }

  private func waitForProcessToExit(_ process: Process, timeout: TimeInterval) async -> Bool {
    let deadline = Date().addingTimeInterval(timeout)

    while process.isRunning && Date() < deadline {
      try? await Task.sleep(for: .milliseconds(100))
    }

    return !process.isRunning
  }

  private func runCommand(executableURL: URL, arguments: [String]) async -> CommandResult {
    await withCheckedContinuation { continuation in
      let process = Process()
      let stdoutPipe = Pipe()
      let stderrPipe = Pipe()

      process.executableURL = executableURL
      process.arguments = arguments
      process.standardOutput = stdoutPipe
      process.standardError = stderrPipe

      do {
        try process.run()
        process.terminationHandler = { finishedProcess in
          let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
          let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

          continuation.resume(
            returning: CommandResult(
              terminationStatus: finishedProcess.terminationStatus,
              stdout: String(data: stdoutData, encoding: .utf8) ?? "",
              stderr: String(data: stderrData, encoding: .utf8) ?? ""
            )
          )
        }
      } catch {
        continuation.resume(
          returning: CommandResult(
            terminationStatus: -1,
            stdout: "",
            stderr: error.localizedDescription
          )
        )
      }
    }
  }

  private func resolveGoBinaryURL() -> URL? {
    for candidate in goBinaryCandidates() {
      if FileManager.default.isExecutableFile(atPath: candidate.path) {
        return candidate
      }
    }

    return nil
  }

  private func goBinaryCandidates() -> [URL] {
    var candidates: [URL] = []

    if let explicitGoPath = ProcessInfo.processInfo.environment["GO_BINARY_PATH"], !explicitGoPath.isEmpty {
      candidates.append(URL(fileURLWithPath: explicitGoPath))
    }

    let pathEntries = (ProcessInfo.processInfo.environment["PATH"] ?? "")
      .split(separator: ":")
      .map(String.init)

    for entry in pathEntries where !entry.isEmpty {
      candidates.append(URL(fileURLWithPath: entry).appendingPathComponent("go"))
    }

    let homeDirectoryPath = FileManager.default.homeDirectoryForCurrentUser.path
    candidates.append(URL(fileURLWithPath: homeDirectoryPath).appendingPathComponent("go/bin/go"))
    candidates.append(URL(fileURLWithPath: "/opt/homebrew/bin/go"))
    candidates.append(URL(fileURLWithPath: "/usr/local/bin/go"))

    var seen: Set<String> = []
    return candidates.filter { seen.insert($0.path).inserted }
  }

  private static func defaultTestWebsiteURLString() -> String {
    if let resourceURL = Bundle.main.resourceURL {
      let runtimeURL = resourceURL.appendingPathComponent("runtime", isDirectory: true)
      if FileManager.default.fileExists(atPath: runtimeURL.path) {
        return "https://localbridge.awayyao.workers.dev/"
      }
    }

    return "http://127.0.0.1:8787"
  }

  private func findProjectRoot(startingAt url: URL) -> URL? {
    var currentURL = url.standardizedFileURL
    let fileManager = FileManager.default

    if !currentURL.hasDirectoryPath {
      currentURL.deleteLastPathComponent()
    }

    while true {
      let goAPIPath = currentURL.appendingPathComponent("go-api/main.go").path
      if fileManager.fileExists(atPath: goAPIPath) {
        return currentURL
      }

      let parentURL = currentURL.deletingLastPathComponent()
      if parentURL.path == currentURL.path {
        return nil
      }
      currentURL = parentURL
    }
  }
}

private struct CommandResult {
  let terminationStatus: Int32
  let stdout: String
  let stderr: String
}
