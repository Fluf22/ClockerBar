import AppKit

protocol SetupWindowDelegate: AnyObject {
    func setupDidComplete()
}

class SetupWindowController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate {
    weak var delegate: SetupWindowDelegate?
    
    private var containerView: NSView!
    
    private var stepLabel: NSTextField!
    private var titleLabel: NSTextField!
    private var subtitleLabel: NSTextField!
    private var inputField: NSTextField!
    private var nextButton: NSButton!
    private var backButton: NSButton!
    private var loadingIndicator: NSProgressIndicator!
    private var errorLabel: NSTextField!
    
    private var employeeSearchField: NSTextField!
    private var employeeTableView: NSTableView!
    private var tableScrollView: NSScrollView!
    
    private var currentStep = 1
    private var apiKey = ""
    private var companyDomain = ""
    private var employees: [Employee] = []
    private var filteredEmployees: [Employee] = []
    private var selectedEmployee: Employee?
    
    private var existingEmployeeId: String?
    
    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Clocker Setup"
        window.center()
        
        self.init(window: window)
        loadExistingConfig()
        setupUI()
        showStep(1)
    }
    
    private func loadExistingConfig() {
        if let config = KeychainManager.getConfig() {
            apiKey = config.apiKey
            companyDomain = config.companyDomain
            existingEmployeeId = config.employeeId
        }
    }
    
    private func setupUI() {
        guard let contentView = window?.contentView else { return }
        contentView.wantsLayer = true
        
        containerView = NSView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(containerView)
        
        stepLabel = NSTextField(labelWithString: "Step 1 of 3")
        stepLabel.font = NSFont.systemFont(ofSize: 12)
        stepLabel.textColor = .secondaryLabelColor
        stepLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(stepLabel)
        
        titleLabel = NSTextField(labelWithString: "")
        titleLabel.font = NSFont.boldSystemFont(ofSize: 24)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(titleLabel)
        
        subtitleLabel = NSTextField(labelWithString: "")
        subtitleLabel.font = NSFont.systemFont(ofSize: 13)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(subtitleLabel)
        
        inputField = NSTextField()
        inputField.font = NSFont.systemFont(ofSize: 16)
        inputField.delegate = self
        inputField.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(inputField)
        
        loadingIndicator = NSProgressIndicator()
        loadingIndicator.style = .spinning
        loadingIndicator.controlSize = .large
        loadingIndicator.isHidden = true
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(loadingIndicator)
        
        errorLabel = NSTextField(labelWithString: "")
        errorLabel.font = NSFont.systemFont(ofSize: 12)
        errorLabel.textColor = .systemRed
        errorLabel.isHidden = true
        errorLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(errorLabel)
        
        employeeSearchField = NSTextField()
        employeeSearchField.font = NSFont.systemFont(ofSize: 16)
        employeeSearchField.placeholderString = "Type to search..."
        employeeSearchField.delegate = self
        employeeSearchField.isHidden = true
        employeeSearchField.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(employeeSearchField)
        
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        column.title = "Name"
        column.width = 420
        
        employeeTableView = NSTableView()
        employeeTableView.addTableColumn(column)
        employeeTableView.headerView = nil
        employeeTableView.dataSource = self
        employeeTableView.delegate = self
        employeeTableView.rowHeight = 32
        employeeTableView.style = .plain
        
        tableScrollView = NSScrollView()
        tableScrollView.documentView = employeeTableView
        tableScrollView.hasVerticalScroller = true
        tableScrollView.borderType = .bezelBorder
        tableScrollView.isHidden = true
        tableScrollView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(tableScrollView)
        
        nextButton = NSButton(title: "Continue", target: self, action: #selector(nextClicked))
        nextButton.bezelStyle = .rounded
        nextButton.font = NSFont.systemFont(ofSize: 14)
        nextButton.keyEquivalent = "\r"
        nextButton.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(nextButton)
        
        backButton = NSButton(title: "Back", target: self, action: #selector(backClicked))
        backButton.bezelStyle = .rounded
        backButton.font = NSFont.systemFont(ofSize: 14)
        backButton.isHidden = true
        backButton.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(backButton)
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            stepLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 30),
            stepLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 40),
            
            titleLabel.topAnchor.constraint(equalTo: stepLabel.bottomAnchor, constant: 8),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 40),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -40),
            
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subtitleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 40),
            subtitleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -40),
            
            inputField.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 30),
            inputField.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 40),
            inputField.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -40),
            inputField.heightAnchor.constraint(equalToConstant: 32),
            
            loadingIndicator.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            loadingIndicator.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 50),
            
            errorLabel.topAnchor.constraint(equalTo: inputField.bottomAnchor, constant: 10),
            errorLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 40),
            errorLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -40),
            
            employeeSearchField.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 30),
            employeeSearchField.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 40),
            employeeSearchField.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -40),
            employeeSearchField.heightAnchor.constraint(equalToConstant: 32),
            
            tableScrollView.topAnchor.constraint(equalTo: employeeSearchField.bottomAnchor, constant: 15),
            tableScrollView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 40),
            tableScrollView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -40),
            tableScrollView.heightAnchor.constraint(equalToConstant: 150),
            
            nextButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -30),
            nextButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -40),
            nextButton.widthAnchor.constraint(equalToConstant: 100),
            nextButton.heightAnchor.constraint(equalToConstant: 32),
            
            backButton.centerYAnchor.constraint(equalTo: nextButton.centerYAnchor),
            backButton.trailingAnchor.constraint(equalTo: nextButton.leadingAnchor, constant: -15),
            backButton.widthAnchor.constraint(equalToConstant: 80),
            backButton.heightAnchor.constraint(equalToConstant: 32)
        ])
    }
    
    private func showStep(_ step: Int) {
        currentStep = step
        errorLabel.isHidden = true
        inputField.isHidden = false
        loadingIndicator.isHidden = true
        employeeSearchField.isHidden = true
        tableScrollView.isHidden = true
        nextButton.isEnabled = false
        
        switch step {
        case 1:
            stepLabel.stringValue = "Step 1 of 3"
            titleLabel.stringValue = "Enter your API Key"
            subtitleLabel.stringValue = "You can find this in BambooHR under Account → API Keys"
            inputField.placeholderString = "API Key"
            inputField.stringValue = apiKey
            inputField.isHidden = false
            replaceInputWithSecureField()
            backButton.isHidden = true
            nextButton.title = "Continue"
            nextButton.isEnabled = !apiKey.isEmpty
            
        case 2:
            stepLabel.stringValue = "Step 2 of 3"
            titleLabel.stringValue = "Enter your company domain"
            subtitleLabel.stringValue = "The subdomain from your BambooHR URL (e.g., 'acme' from acme.bamboohr.com)"
            replaceInputWithRegularField()
            inputField.placeholderString = "Company domain"
            inputField.stringValue = companyDomain
            inputField.isHidden = false
            backButton.isHidden = false
            nextButton.title = "Continue"
            nextButton.isEnabled = !companyDomain.isEmpty
            
        case 3:
            stepLabel.stringValue = "Step 3 of 3"
            titleLabel.stringValue = "Select your name"
            subtitleLabel.stringValue = "Loading employees..."
            inputField.isHidden = true
            backButton.isHidden = false
            nextButton.title = "Finish"
            nextButton.isEnabled = false
            loadEmployees()
            
        default:
            break
        }
    }
    
    private func replaceInputWithSecureField() {
        let isSecure = inputField is NSSecureTextField
        if !isSecure {
            let newField = NSSecureTextField()
            newField.font = inputField.font
            newField.delegate = self
            newField.placeholderString = inputField.placeholderString
            newField.stringValue = inputField.stringValue
            newField.translatesAutoresizingMaskIntoConstraints = false
            
            let superviewConstraints = containerView.constraints.filter { 
                $0.firstItem as? NSView == inputField || $0.secondItem as? NSView == inputField 
            }
            
            containerView.removeConstraints(superviewConstraints)
            inputField.removeFromSuperview()
            containerView.addSubview(newField)
            inputField = newField
            
            NSLayoutConstraint.activate([
                inputField.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 30),
                inputField.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 40),
                inputField.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -40),
                inputField.heightAnchor.constraint(equalToConstant: 32)
            ])
        }
    }
    
    private func replaceInputWithRegularField() {
        let isSecure = inputField is NSSecureTextField
        if isSecure {
            let newField = NSTextField()
            newField.font = NSFont.systemFont(ofSize: 16)
            newField.delegate = self
            newField.placeholderString = inputField.placeholderString
            newField.stringValue = inputField.stringValue
            newField.translatesAutoresizingMaskIntoConstraints = false
            
            let superviewConstraints = containerView.constraints.filter { 
                $0.firstItem as? NSView == inputField || $0.secondItem as? NSView == inputField 
            }
            
            containerView.removeConstraints(superviewConstraints)
            inputField.removeFromSuperview()
            containerView.addSubview(newField)
            inputField = newField
            
            NSLayoutConstraint.activate([
                inputField.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 30),
                inputField.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 40),
                inputField.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -40),
                inputField.heightAnchor.constraint(equalToConstant: 32)
            ])
        }
    }
    
    private func loadEmployees() {
        loadingIndicator.isHidden = false
        loadingIndicator.startAnimation(nil)
        
        Task {
            do {
                let fetchedEmployees = try await EmployeeSearch.searchEmployees(apiKey: apiKey, companyDomain: companyDomain)
                await MainActor.run {
                    self.employees = fetchedEmployees.sorted { $0.displayName < $1.displayName }
                    self.filteredEmployees = self.employees
                    self.employeeTableView.reloadData()
                    self.loadingIndicator.stopAnimation(nil)
                    self.loadingIndicator.isHidden = true
                    self.subtitleLabel.stringValue = "Search and select your name from the list"
                    self.employeeSearchField.isHidden = false
                    self.tableScrollView.isHidden = false
                    
                    if let existingId = self.existingEmployeeId,
                       let index = self.filteredEmployees.firstIndex(where: { $0.id == existingId }) {
                        self.employeeTableView.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
                        self.employeeTableView.scrollRowToVisible(index)
                        self.selectedEmployee = self.filteredEmployees[index]
                        self.nextButton.isEnabled = true
                    }
                    
                    self.window?.makeFirstResponder(self.employeeSearchField)
                }
            } catch {
                await MainActor.run {
                    self.loadingIndicator.stopAnimation(nil)
                    self.loadingIndicator.isHidden = true
                    self.showError("Failed to load employees: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func controlTextDidChange(_ obj: Notification) {
        guard let field = obj.object as? NSTextField else { return }
        
        if field == inputField {
            switch currentStep {
            case 1:
                apiKey = field.stringValue.trimmingCharacters(in: .whitespaces)
                nextButton.isEnabled = !apiKey.isEmpty
            case 2:
                companyDomain = field.stringValue.trimmingCharacters(in: .whitespaces)
                nextButton.isEnabled = !companyDomain.isEmpty
            default:
                break
            }
        } else if field == employeeSearchField {
            let searchText = field.stringValue.lowercased()
            
            if searchText.isEmpty {
                filteredEmployees = employees
            } else {
                filteredEmployees = employees.filter {
                    $0.displayName.lowercased().contains(searchText)
                }
            }
            
            employeeTableView.reloadData()
        }
    }
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return filteredEmployees.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let employee = filteredEmployees[row]
        
        let cell = NSTextField(labelWithString: employee.displayName)
        cell.font = NSFont.systemFont(ofSize: 14)
        cell.lineBreakMode = .byTruncatingTail
        return cell
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        let selectedRow = employeeTableView.selectedRow
        if selectedRow >= 0 && selectedRow < filteredEmployees.count {
            selectedEmployee = filteredEmployees[selectedRow]
            nextButton.isEnabled = true
        } else {
            selectedEmployee = nil
            nextButton.isEnabled = false
        }
    }
    
    @objc private func nextClicked() {
        errorLabel.isHidden = true
        
        switch currentStep {
        case 1:
            showStep(2)
        case 2:
            showStep(3)
        case 3:
            saveAndFinish()
        default:
            break
        }
    }
    
    @objc private func backClicked() {
        if currentStep > 1 {
            showStep(currentStep - 1)
        }
    }
    
    private func saveAndFinish() {
        guard let employee = selectedEmployee else {
            showError("Please select your name")
            return
        }
        
        let config = BambooHRConfig(
            apiKey: apiKey,
            companyDomain: companyDomain,
            employeeId: employee.id
        )
        
        do {
            try KeychainManager.saveConfig(config)
            delegate?.setupDidComplete()
            close()
        } catch {
            showError("Failed to save: \(error.localizedDescription)")
        }
    }
    
    private func showError(_ message: String) {
        errorLabel.stringValue = message
        errorLabel.isHidden = false
    }
    
    func showWindow() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
