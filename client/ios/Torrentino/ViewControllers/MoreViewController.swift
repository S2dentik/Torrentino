import UIKit
import RxSwift
import RxCocoa
import Differ

private extension Host {
    var segmentIndex: Int {
        switch self {
        case .ip: return 0
        case .name: return 1
        }
    }
}

private extension Scheme {
    var segmentIndex: Int {
        switch self {
        case .http: return 0
        case .https: return 1
        }
    }

    init?(_ index: Int) {
        switch index {
        case 0: self = .http
        case 1: self = .https
        default: return nil
        }
    }
}

final class MoreViewController: UIViewController, UITextFieldDelegate {
    @IBOutlet weak var schemeSegmentedControl: UISegmentedControl!
    @IBOutlet weak var segmentedControl: UISegmentedControl!
    @IBOutlet weak var ipTextField: UITextField!
    @IBOutlet weak var portTextField: UITextField!
    @IBOutlet weak var hostNameTextField: UITextField!

    @IBAction func hostChanged(_ sender: UISegmentedControl) {
        changeHost(to: sender.selectedSegmentIndex)
    }

    @IBAction func saveChanges(_ sender: UIButton) {
        switch segmentedControl.selectedSegmentIndex {
        case 0: saveIPHost()
        case 1: saveNameHost()
        default: return
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        ipTextField.delegate = self
        portTextField.delegate = self
        hostNameTextField.delegate = self
        setupKeyboardDismiss()
        populateUI()
    }

    func textField(_ textField: UITextField,
                   shouldChangeCharactersIn range: NSRange,
                   replacementString string: String) -> Bool {
        switch textField {
        case ipTextField:
            let ip: String = {
                guard let current = ipTextField.text else { return string }
                let lower = current.index(current.startIndex, offsetBy: range.location)
                let upper = current.index(lower, offsetBy: range.length)
                let range = Range<String.Index>(uncheckedBounds: (lower, upper))
                return current.replacingCharacters(in: range, with: string)
            }()
            if ip.isEmpty { return true }
            return verifyIP(ip)
        case portTextField:
            let result: String = {
                guard let current = portTextField.text else { return string }
                let lower = current.index(current.startIndex, offsetBy: range.location)
                let upper = current.index(lower, offsetBy: range.length)
                let range = Range<String.Index>(uncheckedBounds: (lower, upper))
                return current.replacingCharacters(in: range, with: string)
            }()
            if result.isEmpty { return true }
            guard let port = UInt(result), port <= 65535 else { return false }
            return true
        case hostNameTextField:
            return true
        default:
            return true
        }
    }

    private func verifyIP(_ value: String) -> Bool {
        let pattern = "^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])[.]){0,3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])?$"
        let regexText = NSPredicate(format: "SELF MATCHES %@", pattern)
        return regexText.evaluate(with: value)
    }

    private func populateUI() {
        segmentedControl.selectedSegmentIndex = API.shared.currentHost.segmentIndex
        schemeSegmentedControl.selectedSegmentIndex = API.shared.currentHost.scheme.segmentIndex
        switch API.shared.currentHost {
        case .ip(_, let ip, let port):
            changeUIToIPHost()
            ipTextField.text = ip.stringValue
            if let port = port {
                portTextField.text = String(port)
            } else {
                portTextField.text = nil
            }
        case .name(_, let url):
            changeUIToNameHost()
            hostNameTextField.text = url.absoluteString
        }
    }

    private func changeHost(to index: Int) {
        switch index {
        case 0: changeUIToIPHost()
        case 1: changeUIToNameHost()
        default: return
        }
    }

    private func changeUIToIPHost() {
        ipTextField.isHidden = false
        portTextField.isHidden = false
        hostNameTextField.isHidden = true
    }

    private func changeUIToNameHost() {
        ipTextField.isHidden = true
        portTextField.isHidden = true
        hostNameTextField.isHidden = false
    }

    private func saveIPHost() {
        guard let ipStringValue = ipTextField.text, let ip = IP(stringValue: ipStringValue) else {
            return informBadHost(ipTextField.text)
        }
        guard let scheme = Scheme(schemeSegmentedControl.selectedSegmentIndex) else {
            return informBadScheme(schemeSegmentedControl.selectedSegmentIndex)
        }
        if let portStringValue = portTextField.text, let port = UInt(portStringValue) {
            API.shared.set(host: .ip(scheme, ip, port))
        } else {
            API.shared.set(host: .ip(scheme, ip, nil))
        }
        let host: Host = {
            if let portStringValue = portTextField.text, let port = UInt(portStringValue) {
                return .ip(scheme, ip, port)
            } else {
                return .ip(scheme, ip, nil)
            }
        }()
        API.shared.set(host: host)
        informSaveSuccess(host)
    }

    private func saveNameHost() {
        guard let stringValue = hostNameTextField.text, let url = URL(string: stringValue) else {
            return informBadHost(hostNameTextField.text)
        }
        guard let scheme = Scheme(schemeSegmentedControl.selectedSegmentIndex) else {
            return informBadScheme(schemeSegmentedControl.selectedSegmentIndex)
        }
        let host = Host.name(scheme, url)
        API.shared.set(host: host)
        informSaveSuccess(host)
    }

    private func informBadHost(_ value: String?) {
        showAlert(
            title: "Ooops!",
            message: "Con't save \(value ?? "nil") as host!",
            actions: [UIAlertAction(title: "OK", style: .default, handler: { _ in })]
        )
    }

    private func informBadScheme(_ value: Int) {
        showAlert(
            title: "Ooops!",
            message: "Con't save \(value) as scheme!",
            actions: [UIAlertAction(title: "OK", style: .default, handler: { _ in })]
        )
    }

    private func informSaveSuccess(_ host: Host) {
        showAlert(
            title: "",
            message: "Saved \(host.url.absoluteString) as API host!",
            actions: [UIAlertAction(title: "OK", style: .default, handler: { _ in })]
        )
    }

    private func setupKeyboardDismiss() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tapGesture)
    }

    @objc private func dismissKeyboard() {
        ipTextField.resignFirstResponder()
        portTextField.resignFirstResponder()
        hostNameTextField.resignFirstResponder()
    }
}
