import UIKit
import AVKit

final class PlayerViewController: UIViewController {
    private var playerViewController: AVPlayerViewController! {
        didSet {
            addChild(playerViewController)
            view.addSubview(playerViewController.view)
            view.bringSubviewToFront(playerViewController.view)
            playerViewController.view.frame = view.frame
        }
    }

    deinit {
        playerViewController.player = nil
    }

    func setup(with url: URL) {
        playerViewController.player = AVPlayer(url: url)
        playerViewController.player?.play()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        playerViewController = AVPlayerViewController()
    }
}
