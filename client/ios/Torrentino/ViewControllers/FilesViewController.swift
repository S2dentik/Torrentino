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
    override func layoutSubviews() {
        super.layoutSubviews();
        guard var imageFrame = imageView?.frame else { return }
        let offset = CGFloat(indentationLevel) * indentationWidth
        imageFrame.origin.x += offset
        imageView?.frame = imageFrame
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
        )
        cell.contentView.backgroundColor = #colorLiteral(red: 0.176448822, green: 0.1764850318, blue: 0.1547711492, alpha: 1)
        cell.backgroundColor = #colorLiteral(red: 0.176448822, green: 0.1764850318, blue: 0.1547711492, alpha: 1)
        cell.textLabel?.lineBreakMode = .byTruncatingMiddle
        cell.textLabel?.textColor = #colorLiteral(red: 0.6666666865, green: 0.6666666865, blue: 0.6666666865, alpha: 1)
        cell.detailTextLabel?.textColor = #colorLiteral(red: 0.6666666865, green: 0.6666666865, blue: 0.6666666865, alpha: 1)
        if node.type == .folder {
            cell.imageView?.image = #imageLiteral(resourceName: "folder").withRenderingMode(.alwaysTemplate)
            cell.imageView?.tintColor = #colorLiteral(red: 0, green: 0.7543834448, blue: 0.7387440801, alpha: 1)
        } else {
            cell.imageView?.image = #imageLiteral(resourceName: "file").withRenderingMode(.alwaysTemplate)
            cell.imageView?.tintColor = #colorLiteral(red: 0.6666666865, green: 0.6666666865, blue: 0.6666666865, alpha: 1)
        }
        cell.textLabel?.text = node.name
        if node.isExpandable {
            cell.detailTextLabel?.text = "\(node.children.count) files"
        }

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
        let node: FileNode = {
            if let parent = parentNode as? FileNode {
                return parent.children[indexPath.row]
            } else {
                return nodes[indexPath.row]
            }
        }()
        play(node: node)
    }

    private func play(node: FileNode) {
        guard node.type == .file else { return }
        API.shared.getVideoURL(for: node.id).subscribe(onNext: { [weak self] url in
            let controller = PlayerViewController()
            controller.loadView()
            controller.viewDidLoad()
            self?.present(controller, animated: true, completion: nil)
            controller.setup(with: url.url)
        }, onError: { [weak self] error in
            self?.alert(about: error, onRetry: { [weak self] in self?.play(node: node) })
        }).disposed(by: disposeBag)
    }
}
