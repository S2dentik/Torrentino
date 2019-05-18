import UIKit
import RxSwift
import RxRelay

struct CellData {
    enum Seeds {
        case all(Int)
        case peers(Int)
    }

    struct Status {
        let seeds: Seeds
        let eta: TimeInterval?
        let status: String
        let speed: Double
        let progress: Float
        let downloadEnabled: Bool

        init(item: TorrentItem) {
            if let state = item.status {
                seeds = .peers(state.peers)
                eta = state.eta
                status = state.state
                speed = state.speed
                progress = Float(state.progress)
                downloadEnabled = false
            } else {
                seeds = .all(item.seeders)
                eta = nil
                status = "N/A"
                speed = 0
                progress = 0
                downloadEnabled = true
            }
        }
    }

    let id: String
    let title: String
    let size: String
    let category: String
    let status: BehaviorRelay<Status>
    let onDownload: PublishRelay<String>

    init(id: String,
         title: String,
         size: String,
         category: String,
         status: BehaviorRelay<Status>,
         onDownload: PublishRelay<String>) {
        self.id = id
        self.title = title
        self.size = size
        self.category = category
        self.status = status
        self.onDownload = onDownload
    }

    init(item: TorrentItem, onDownload: PublishRelay<String>) {
        self.init(
            id: item.id,
            title: item.title,
            size: item.size,
            category: item.category + " | " + item.subCategory,
            status: BehaviorRelay<Status>(value: Status(item: item)),
            onDownload: onDownload
        )
    }
}

extension CellData {
    func update(with item: TorrentItem) {
        status.accept(Status(item: item))
    }
}

final class Cell: UICollectionViewCell {
    static let reuseIdentifier = "Cell"

    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var sizeLabel: UILabel!
    @IBOutlet weak var etaLabel: UILabel!
    @IBOutlet weak var speedLabel: UILabel!
    @IBOutlet weak var categoryLabel: UILabel!
    @IBOutlet weak var seedsLabel: UILabel!
    @IBOutlet weak var downloadButton: UIButton!
    @IBOutlet weak var progressView: UIProgressView!

    @IBAction func download(_ sender: Any) {
        guard let id = data?.id else { return }
        data?.onDownload.accept(id)
    }

    private var disposeBag = DisposeBag()
    private var data: CellData?

    override func awakeFromNib() {
        super.awakeFromNib()
        downloadButton.setImage(#imageLiteral(resourceName: "download").withRenderingMode(.alwaysTemplate), for: UIControl.State())
        downloadButton.imageView?.tintColor = #colorLiteral(red: 0.7999204993, green: 0.8000556827, blue: 0.7999026775, alpha: 1)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        data = nil
        statusLabel.text = ""
        titleLabel.text = ""
        sizeLabel.text = ""
        etaLabel.text = ""
        speedLabel.text = ""
        categoryLabel.text = ""
        seedsLabel.text = ""
        downloadButton.isEnabled = true
        progressView.progress = 0
        disposeBag = DisposeBag()
    }

    func populate(with data: CellData) {
        self.data = data
        titleLabel.text = data.title
        sizeLabel.text = data.size
        categoryLabel.text = data.category
        data.status.subscribe(onNext: { [weak self] status in
            switch status.seeds {
            case .all(let total): self?.seedsLabel.text = "\(total) \(total == 1 ? "seed" : "seeds")"
            case .peers(let total): self?.seedsLabel.text = "\(total) \(total == 1 ? "peer" : "peers")"
            }
            self?.progressView.progress = status.progress
            self?.downloadButton.isEnabled = status.downloadEnabled
            self?.downloadButton.isHidden = !status.downloadEnabled
            self?.statusLabel.text = status.status
            if status.status == "Finished" {
                self?.progressView.tintColor = #colorLiteral(red: 0.3411764801, green: 0.6235294342, blue: 0.1686274558, alpha: 1)
                self?.statusLabel.textColor = #colorLiteral(red: 0.3411764801, green: 0.6235294342, blue: 0.1686274558, alpha: 1)
                self?.etaLabel.text = nil
                self?.speedLabel.text = nil
            } else {
                self?.progressView.tintColor = #colorLiteral(red: 1, green: 0.6800974607, blue: 0, alpha: 1)
                self?.statusLabel.textColor = #colorLiteral(red: 1, green: 0.6800974607, blue: 0, alpha: 1)
                self?.etaLabel.text = self?.formatEta(from: status.eta)
                self?.speedLabel.text = self?.formatSpeed(from: status.speed)
            }
        }).disposed(by: disposeBag)
    }

    private func formatEta(from time: Double?) -> String? {
        guard let time = time, time > 0 else { return nil }
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.day, .hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        formatter.zeroFormattingBehavior = .dropAll
        return formatter.string(from: time) ?? "-:-"
    }

    private func formatSpeed(from speed: Double) -> String? {
        guard speed > 0 else { return nil }
        let byteCount = speed * 1024
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useTB, .useGB, .useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(byteCount)) + "/s"
    }
}
