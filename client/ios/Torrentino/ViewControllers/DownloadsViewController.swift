import UIKit
import RxSwift
import RxCocoa
import Differ

final class DownloadsViewController: UIViewController {
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var noItemsLabel: UILabel!

    private var disposeBag = DisposeBag()
    private var cellData: [CellData] = []
    private var items: [TorrentItem] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.register(UINib(nibName: "Cell", bundle: .main), forCellWithReuseIdentifier: Cell.reuseIdentifier)
        setupStatusUpdate()
    }

    private func setupStatusUpdate() {
        API.shared.getRecurentStatus().subscribe(
            onNext: { [weak self] in
                self?.updateStatusItems(with: $0)
            },
            onError: { [weak self] in
                self?.alert(about: $0, onRetry: { [weak self] in
                    self?.setupStatusUpdate()
                })
            }
        ).disposed(by: disposeBag)
    }

    private func updateStatusItems(with items: [TorrentItem]) {
        items.isEmpty ? handleEmpty() : handleNonEmpty(items)
    }

    private func handleEmpty() {
        items.removeAll()
        cellData.removeAll()
        collectionView.reloadData()
        collectionView.isHidden = true
        noItemsLabel.isHidden = false
    }

    private func handleNonEmpty(_ items: [TorrentItem]) {
        noItemsLabel.isHidden = true
        collectionView.isHidden = false
        let diff = self.items.extendedDiff(items, isEqual: { $0.id == $1.id })
        self.items = items
        cellData = items.map { item in
            guard let data = cellData.first(where: { $0.id == item.id }) else {
                return CellData(item: item, onDownload: PublishRelay())
            }
            data.update(with: item)
            return data
        }
        if !diff.isEmpty { collectionView.reloadData() }
    }
}

extension DownloadsViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: collectionView.frame.width - 20, height: 102)
    }

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsets(top: 20, left: 10, bottom: 20, right: 10)
    }

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 20
    }

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 5
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let item = items[indexPath.row]
        guard item.status?.state == "Finished" else { return }
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let controllerID = "FilesViewController"
        let controller = storyboard.instantiateViewController(withIdentifier: controllerID) as! FilesViewController
        controller.loadView()
        controller.viewDidLoad()
        controller.setup(with: item.id)
        navigationController?.pushViewController(controller, animated: true)
    }
}

extension DownloadsViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return cellData.count
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: Cell.reuseIdentifier,
            for: indexPath
        ) as! Cell
        let data = cellData[indexPath.row]
        cell.populate(with: data)
        if let item = items.first(where: { $0.id == data.id }) { data.update(with: item) }
        return cell
    }
}
