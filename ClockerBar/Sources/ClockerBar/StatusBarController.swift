import AppKit

class StatusBarController: SetupWindowDelegate {
    private var statusItem: NSStatusItem
    private var menu: NSMenu
    private var clockerService: ClockerService?
    private var setupWindowController: SetupWindowController?
    
    private var statusMenuItem: NSMenuItem!
    private var timeMenuItem: NSMenuItem!
    private var hoursMenuItem: NSMenuItem!
    private var toggleMenuItem: NSMenuItem!
    private var refreshTimer: Timer?
    private var currentStatus: ClockStatus?
    
    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        menu = NSMenu()
        
        setupMenu()
        setupStatusItem()
        
        if KeychainManager.hasCredentials() {
            initializeService()
        } else {
            showSetupWindow()
        }
    }
    
    private func initializeService() {
        do {
            clockerService = try ClockerService()
            startRefreshTimer()
            Task {
                await refreshStatus()
            }
        } catch {
            Task { @MainActor in
                self.updateUIWithError(error)
            }
        }
    }
    
    private func setupStatusItem() {
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "clock", accessibilityDescription: "Clocker")
        }
        statusItem.menu = menu
    }
    
    private func setupMenu() {
        statusMenuItem = NSMenuItem(title: "Loading...", action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)
        
        timeMenuItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        timeMenuItem.isEnabled = false
        menu.addItem(timeMenuItem)
        
        hoursMenuItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        hoursMenuItem.isEnabled = false
        menu.addItem(hoursMenuItem)
        
        menu.addItem(NSMenuItem.separator())
        
        toggleMenuItem = NSMenuItem(title: "Toggle", action: #selector(toggleClock), keyEquivalent: "t")
        toggleMenuItem.target = self
        menu.addItem(toggleMenuItem)
        
        let refreshItem = NSMenuItem(title: "Refresh", action: #selector(manualRefresh), keyEquivalent: "r")
        refreshItem.target = self
        menu.addItem(refreshItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }
    
    private func startRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task {
                await self?.refreshStatus()
            }
        }
    }
    
    @MainActor
    private func refreshStatus() async {
        guard let service = clockerService else {
            statusMenuItem.title = "Not configured"
            return
        }
        do {
            let status = try await service.getStatus()
            currentStatus = status
            updateUI(with: status)
        } catch {
            updateUIWithError(error)
        }
    }
    
    @MainActor
    private func updateUI(with status: ClockStatus) {
        let symbolName = iconForStatus(status)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Clocker")
        }
        
        if status.isClockedIn {
            statusMenuItem.title = "Status: Clocked In"
            toggleMenuItem.title = "Clock Out"
        } else {
            statusMenuItem.title = "Status: Clocked Out"
            toggleMenuItem.title = "Clock In"
        }
        
        if status.isClockedIn, let since = status.clockedInSince {
            let duration = formatDuration(since: since)
            timeMenuItem.title = "Since: \(duration)"
            timeMenuItem.isHidden = false
        } else {
            timeMenuItem.isHidden = true
        }
        
        let hours = String(format: "%.1f", status.todayTotalHours)
        hoursMenuItem.title = "Today: \(hours) hours"
    }
    
    private func iconForStatus(_ status: ClockStatus) -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        
        if !status.isClockedIn && hour >= 8 && hour < 18 {
            return "clock.badge.questionmark"
        }
        
        if status.isClockedIn && hour >= 18 {
            return "clock.badge.questionmark.fill"
        }
        
        return status.isClockedIn ? "clock.fill" : "clock"
    }
    
    @MainActor
    private func updateUIWithError(_ error: Error) {
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "exclamationmark.triangle", accessibilityDescription: "Error")
        }
        statusMenuItem.title = "Error: \(error.localizedDescription)"
        timeMenuItem.isHidden = true
    }
    
    private func formatDuration(since isoString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        guard let date = formatter.date(from: isoString) ?? {
            formatter.formatOptions = [.withInternetDateTime]
            return formatter.date(from: isoString)
        }() else {
            return isoString
        }
        
        let elapsed = Date().timeIntervalSince(date)
        let hours = Int(elapsed) / 3600
        let minutes = (Int(elapsed) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    @objc private func toggleClock() {
        guard let service = clockerService else {
            showSetupWindow()
            return
        }
        Task {
            do {
                try await service.toggle()
                await refreshStatus()
            } catch {
                await MainActor.run {
                    showAlert(message: "Failed to toggle: \(error.localizedDescription)")
                }
            }
        }
    }
    
    @objc private func manualRefresh() {
        Task {
            await refreshStatus()
        }
    }
    
    @objc private func openSettings() {
        showSetupWindow()
    }
    
    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
    
    private func showSetupWindow() {
        if setupWindowController == nil {
            setupWindowController = SetupWindowController()
            setupWindowController?.delegate = self
        }
        setupWindowController?.showWindow()
    }
    
    private func showAlert(message: String) {
        let alert = NSAlert()
        alert.messageText = "Clocker Error"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    func setupDidComplete() {
        do {
            if clockerService == nil {
                clockerService = try ClockerService()
            } else {
                try clockerService?.reloadConfig()
            }
            startRefreshTimer()
            Task {
                await refreshStatus()
            }
        } catch {
            Task { @MainActor in
                self.updateUIWithError(error)
            }
        }
    }
}
