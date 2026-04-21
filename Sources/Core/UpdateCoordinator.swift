import Foundation
import AppKit
import os.log

class UpdateCoordinator: NSObject, URLSessionDownloadDelegate {
    
    static let shared = UpdateCoordinator()
    
    // 状态回调：通知上层（如 AppDelegate）当前更新状态以刷新菜单
    var onUpdateStateChanged: ((UpdateState) -> Void)?
    
    // 记录最新版本号
    private var latestVersionString: String = ""
    
    // 内部状态
    private var updateDownloadURL: URL?
    private var downloadedAppPath: String?
    private var downloadTask: URLSessionDownloadTask?
    
    enum UpdateState {
        case checking
        case downloading(progress: Int) // 0-100
        case readyToInstall(version: String)
        case error(String)
    }
    
    func checkForUpdates() {
        guard let url = URL(string: "https://api.github.com/repos/litiantaos/AwakeDisplay/releases/latest") else { return }
        
        let task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self, let data = data, error == nil else { return }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let tagName = json["tag_name"] as? String,
                   let assets = json["assets"] as? [[String: Any]],
                   let firstAsset = assets.first(where: { ($0["name"] as? String)?.hasSuffix(".zip") == true }),
                   let downloadURLString = firstAsset["browser_download_url"] as? String,
                   let downloadURL = URL(string: downloadURLString) {
                    
                    let latestVersion = tagName.replacingOccurrences(of: "v", with: "")
                    self.latestVersionString = latestVersion
                    let currentVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
                    
                    // 如果存在新版本，自动开始下载
                    if latestVersion.compare(currentVersion, options: .numeric) == .orderedDescending {
                        self.updateDownloadURL = downloadURL
                        DispatchQueue.main.async {
                            self.startDownload()
                        }
                    }
                }
            } catch {
                os_log("解析更新数据失败: %{public}@", type: .error, error.localizedDescription)
            }
        }
        task.resume()
    }
    
    private func startDownload() {
        guard let url = updateDownloadURL else { return }
        
        // 触发下载状态通知，初始进度 0
        onUpdateStateChanged?(.downloading(progress: 0))
        
        let config = URLSessionConfiguration.default
        let session = URLSession(configuration: config, delegate: self, delegateQueue: .main)
        
        downloadTask = session.downloadTask(with: url)
        downloadTask?.resume()
    }
    
    func installAndRestart() {
        guard let currentAppPath = Bundle.main.bundlePath as String?,
              let newAppPath = downloadedAppPath else { return }
        
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent("AwakeDisplayUpdate")
        
        do {
            try? fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
            
            // 准备更新脚本 (替换后重启并清理临时文件)
            let script = """
            #!/bin/bash
            sleep 2
            rm -rf "\(currentAppPath)"
            cp -R "\(newAppPath)" "\(currentAppPath)"
            xattr -rd com.apple.quarantine "\(currentAppPath)" || true
            open "\(currentAppPath)"
            rm -rf "\(tempDir.path)"
            """
            
            let scriptPath = tempDir.appendingPathComponent("update.sh").path
            try script.write(toFile: scriptPath, atomically: true, encoding: .utf8)
            try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptPath)
            
            let scriptProcess = Process()
            scriptProcess.executableURL = URL(fileURLWithPath: "/bin/bash")
            scriptProcess.arguments = [scriptPath]
            try scriptProcess.run()
            
            NSApplication.shared.terminate(nil)
            
        } catch {
            let alert = NSAlert()
            alert.messageText = "Update Failed".localized
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .critical
            alert.runModal()
            
            onUpdateStateChanged?(.error(error.localizedDescription))
        }
    }
    
    // MARK: - URLSessionDownloadDelegate
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let progress = Int((Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)) * 100)
        
        DispatchQueue.main.async {
            self.onUpdateStateChanged?(.downloading(progress: progress))
        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent("AwakeDisplayUpdate")
        
        // 如果之前有残留的更新文件夹，先清理掉
        if fileManager.fileExists(atPath: tempDir.path) {
            try? fileManager.removeItem(at: tempDir)
        }
        
        do {
            try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
            
            // 解压 zip
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
            process.arguments = ["-q", location.path, "-d", tempDir.path]
            try process.run()
            process.waitUntilExit()
            
            // 删除系统下载的 zip 临时文件
            try? fileManager.removeItem(at: location)
            
            // 查找解压后的 .app
            let newAppPath = tempDir.appendingPathComponent("AwakeDisplay.app").path
            
            guard fileManager.fileExists(atPath: newAppPath) else {
                throw NSError(domain: "UpdateError", code: 1, userInfo: [NSLocalizedDescriptionKey: "未找到解压后的应用"])
            }
            
            DispatchQueue.main.async {
                self.downloadedAppPath = newAppPath
                self.onUpdateStateChanged?(.readyToInstall(version: self.latestVersionString))
            }
            
        } catch {
            DispatchQueue.main.async {
                self.onUpdateStateChanged?(.error("解压失败: \(error.localizedDescription)"))
            }
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            DispatchQueue.main.async {
                self.onUpdateStateChanged?(.error("下载失败: \(error.localizedDescription)"))
            }
        }
    }
}
