import UIKit
import RxSwift
import RxCocoa

final class SearchViewController: UIViewController {
    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var noResultsLabel: UILabel!

    private var disposeBag = DisposeBag()
    private var cellData: [CellData] = []
    private var items: [TorrentItem] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        activityIndicator.stopAnimating()
        searchBar.delegate = self
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.register(UINib(nibName: "Cell", bundle: .main), forCellWithReuseIdentifier: Cell.reuseIdentifier)
        setupSearch()
        setupStatusUpdate()
        setupKeyboardDismiss()
    }

    private func handleSearchText(_ text: String?) {
        guard let text = text, !text.isEmpty else {
            return handleEmptyResults(showEmptyLabel: false)
        }
        noResultsLabel.isHidden = true
        activityIndicator.startAnimating()
        search(by: text).subscribe(onNext: { [weak self] items, cellData in
            items.isEmpty ? self?.handleEmptyResults() : self?.handleNonEmptyResults(items: items, cellData: cellData)
        }, onError: { [weak self] error in
            self?.alert(about: error, onRetry: { [weak self] in self?.handleSearchText(text) })
        }, onDisposed: { [weak self] in
            self?.activityIndicator.stopAnimating()
        }).disposed(by: disposeBag)
    }

    private func search(by query: String) -> Observable<([TorrentItem], [CellData])> {
        return API.shared.getItems(for: query).map { (items: [TorrentItem]) -> ([TorrentItem], [CellData]) in
            let download = PublishRelay<String>()
            download.subscribe(onNext: self.downloadItem).disposed(by: self.disposeBag)
            let cellData = items.map { CellData(item: $0, onDownload: download) }
            return (items, cellData)
        }
    }

    private func handleEmptyResults(showEmptyLabel: Bool = true) {
        noResultsLabel.isHidden = !showEmptyLabel
        collectionView.isHidden = true
        items.removeAll()
        cellData.removeAll()
        collectionView.reloadData()
    }

    private func handleNonEmptyResults(items: [TorrentItem], cellData: [CellData]) {
        noResultsLabel.isHidden = true
        collectionView.isHidden = false
        self.items = items
        self.cellData = cellData
        collectionView.reloadData()
    }

    private func downloadItem(with id: String) {
        API.shared.download(id: id)
    }

    private func setupStatusUpdate() {
        API.shared.getRecurentStatus().subscribe(onNext: updateStatusItems).disposed(by: disposeBag)
    }

    private func setupSearch() {
        searchBar.rx.text
            .distinctUntilChanged()
            .debounce(.seconds(1), scheduler: MainScheduler.instance)
            .subscribe(onNext: { [weak self] text in self?.handleSearchText(text) })
            .disposed(by: disposeBag)
    }

    private func updateStatusItems(with items: [TorrentItem]) {
        self.items = items
        self.items.forEach { item in
            guard let data = cellData.first(where: { $0.id == item.id }) else { return }
            data.update(with: item)
        }
    }

    private func setupKeyboardDismiss() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tapGesture)
    }

    @objc private func dismissKeyboard() {
        searchBar.resignFirstResponder()
    }
}

extension SearchViewController: UISearchBarDelegate {
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        dismissKeyboard()
    }
}

extension SearchViewController: UICollectionViewDelegateFlowLayout {
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
}

extension SearchViewController: UICollectionViewDataSource {
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
        if let status = items.first(where: { $0.id == data.id }) { data.update(with: status) }
        return cell
    }
}


extension UIViewController {
    func alert(about error: Error, onRetry: @escaping () -> Void) {
        showAlert(title: "Whoops!", message: error.localizedDescription, actions: [
            UIAlertAction(title: "OK", style: .cancel, handler: { _ in }),
            UIAlertAction(title: "Retry", style: .default, handler: { _ in onRetry() }),
        ])
    }

    func showAlert(title: String, message: String, actions: [UIAlertAction], style: UIAlertController.Style = .alert) {
        let controller = UIAlertController.init(title: title, message: message, preferredStyle: style)
        actions.forEach(controller.addAction)
        present(controller, animated: true, completion: nil)
    }
}
