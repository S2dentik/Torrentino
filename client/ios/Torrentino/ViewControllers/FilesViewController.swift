import UIKit
import LNZTreeView
import RxSwift

extension FileNode: TreeNodeProtocol {
    var identifier: String {
        return name
    }

    var isExpandable: Bool {
        return !children.isEmpty
    }
}

final class FileNodeTableViewCell: UITableViewCell {
    private var node: FileNode?

    override func layoutSubviews() {
        super.layoutSubviews();
        guard var imageFrame = imageView?.frame else { return }
        let offset = CGFloat(indentationLevel) * indentationWidth
        imageFrame.origin.x += offset
        imageView?.frame = imageFrame
    }

    func configure(with node: FileNode) {
        self.node = node
        backgroundColor = #colorLiteral(red: 0.176448822, green: 0.1764850318, blue: 0.1547711492, alpha: 1)
        contentView.backgroundColor = #colorLiteral(red: 0.176448822, green: 0.1764850318, blue: 0.1547711492, alpha: 1)
        textLabel?.lineBreakMode = .byTruncatingMiddle
        textLabel?.textColor = #colorLiteral(red: 0.6666666865, green: 0.6666666865, blue: 0.6666666865, alpha: 1)
        if node.type == .folder {
            imageView?.image = #imageLiteral(resourceName: "folder").withRenderingMode(.alwaysTemplate)
            imageView?.tintColor = #colorLiteral(red: 0, green: 0.7543834448, blue: 0.7387440801, alpha: 1)
        } else {
            imageView?.image = #imageLiteral(resourceName: "file").withRenderingMode(.alwaysTemplate)
            imageView?.tintColor = #colorLiteral(red: 0.6666666865, green: 0.6666666865, blue: 0.6666666865, alpha: 1)
        }
        textLabel?.text = node.name
        let convertibleExtensions = ["webm", "mkv", "avi", "flv", "mov", "mpeg", "3gp"]
        if let fileExtension = node.name.components(separatedBy: ".").last,
            convertibleExtensions.contains(fileExtension) {
            let button = UIButton(type: .custom)
            button.setImage(#imageLiteral(resourceName: "m4p-file").withRenderingMode(.alwaysTemplate), for: UIControl.State())
            button.tintColor = #colorLiteral(red: 0.1764705926, green: 0.4980392158, blue: 0.7568627596, alpha: 1)
            button.addTarget(self, action: #selector(convertFile), for: .touchUpInside)
            button.frame.size = CGSize(width: 30, height: 30)
            accessoryView = button
        }
    }

    @objc private func convertFile(_ sender: UIButton) {
        guard let id = node?.id else { return }
        API.shared.convertVideo(with: id)
    }
}

final class FilesViewController: UIViewController, LNZTreeViewDataSource, LNZTreeViewDelegate {
    @IBOutlet weak var treeView: LNZTreeView!

    private var id: String?
    private var nodes: [FileNode] = []
    private let disposeBag = DisposeBag()

    override func viewDidLoad() {
        super.viewDidLoad()
        treeView.register(FileNodeTableViewCell.self, forCellReuseIdentifier: "FileNodeTableViewCell")
        treeView.tableViewRowAnimation = .right
        treeView.dataSource = self
        treeView.delegate = self
        treeView.backgroundColor = #colorLiteral(red: 0.176448822, green: 0.1764850318, blue: 0.1547711492, alpha: 1)
        treeView.subviews.forEach { $0.backgroundColor = #colorLiteral(red: 0.176448822, green: 0.1764850318, blue: 0.1547711492, alpha: 1) }
    }

    func setup(with id: String) {
        self.id = id
        API.shared.getFiles(for: id).subscribe(onNext: { [weak self] nodes in
            self?.nodes = nodes
            self?.treeView.resetTree()
        }, onError: { [weak self] error in
            self?.alert(about: error, onRetry: { [weak self] in self?.setup(with: id) })
        }).disposed(by: disposeBag)
    }

    func numberOfSections(in treeView: LNZTreeView) -> Int {
        return 1
    }

    func treeView(_ treeView: LNZTreeView,
                  numberOfRowsInSection section: Int,
                  forParentNode parentNode: TreeNodeProtocol?) -> Int {
        guard let parent = parentNode as? FileNode else { return nodes.count }
        return parent.children.count
    }

    func treeView(_ treeView: LNZTreeView,
                  nodeForRowAt indexPath: IndexPath,
                  forParentNode parentNode: TreeNodeProtocol?) -> TreeNodeProtocol {
        guard let parent = parentNode as? FileNode else { return nodes[indexPath.row] }
        return parent.children[indexPath.row]
    }

    func treeView(_ treeView: LNZTreeView,
                  cellForRowAt indexPath: IndexPath,
                  forParentNode parentNode: TreeNodeProtocol?,
                  isExpanded: Bool) -> UITableViewCell {
        let node: FileNode = {
            if let parent = parentNode as? FileNode {
                return parent.children[indexPath.row]
            } else {
                return nodes[indexPath.row]
            }
        }()
        let cell = treeView.dequeueReusableCell(
            withIdentifier: "FileNodeTableViewCell",
            for: node,
            inSection: indexPath.section
        ) as! FileNodeTableViewCell
        cell.configure(with: node)
        return cell
    }

    func treeView(_ treeView: LNZTreeView,
                  heightForNodeAt indexPath: IndexPath,
                  forParentNode parentNode: TreeNodeProtocol?) -> CGFloat {
        return 45
    }

    func treeView(_ treeView: LNZTreeView,
                  didSelectNodeAt indexPath: IndexPath,
                  forParentNode parentNode: TreeNodeProtocol?) {
        let tableView =  treeView.subviews.compactMap { $0 as? UITableView }.first
        tableView?.indexPathsForSelectedRows?.forEach { indexPath in
            tableView?.deselectRow(at: indexPath, animated: true)
        }
        play(node: {
            if let parent = parentNode as? FileNode {
                return parent.children[indexPath.row]
            } else {
                return nodes[indexPath.row]
            }
        }())
    }

    private func play(node: FileNode) {
        guard node.type == .file else { return }
        API.shared.getVideoURL(for: node.id).subscribe(onNext: { [weak self] url in
            let controller = PlayerViewController()
            controller.loadView()
            controller.viewDidLoad()
            self?.present(controller, animated: true, completion: nil)
            let fullURL = API.shared.currentHost.url(with: url.port).appendingPathComponent(url.url)
            controller.setup(with: fullURL)
        }, onError: { [weak self] error in
            self?.alert(about: error, onRetry: { [weak self] in self?.play(node: node) })
        }).disposed(by: disposeBag)
    }
}
