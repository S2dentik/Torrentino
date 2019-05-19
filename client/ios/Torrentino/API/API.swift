import RxSwift
import RxRelay

struct TorrentItem: Equatable, Decodable {
    struct Status: Equatable, Decodable {
        let state: String
        let speed: Double
        let progress: Double
        let peers: Int
        let isFinished: Bool
        let eta: Double

        enum CodingKeys: String, CodingKey {
            case state
            case speed = "download_speed"
            case progress
            case peers = "num_peers"
            case isFinished = "is_finished"
            case eta
        }
    }

    let id: String
    let title: String
    let size: String
    let category: String
    let subCategory: String
    let seeders: Int
    let status: Status?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case size
        case category
        case subCategory = "sub_category"
        case seeders
        case status
    }
}

final class FileNode: Decodable {
    enum Kind: String, Decodable {
        case file
        case folder
    }

    let id: Int
    let name: String
    let type: Kind
    let children: [FileNode]

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case type
        case children
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        type = try container.decode(Kind.self, forKey: .type)
        children = try container.decode([FileNode].self, forKey: .children)
    }
}

struct VideoURL: Decodable {
    let port: Port
    let url: String
}

struct IP: Codable {
    let part1: UInt8
    let part2: UInt8
    let part3: UInt8
    let part4: UInt8

    var stringValue: String {
        return "\(part1).\(part2).\(part3).\(part4)"
    }

    init(part1: UInt8, part2: UInt8, part3: UInt8, part4: UInt8) {
        self.part1 = part1
        self.part2 = part2
        self.part3 = part3
        self.part4 = part4
    }

    init?(stringValue: String) {
        let components = stringValue.components(separatedBy: ".")
        guard components.count == 4 else { return nil }
        guard let part1 = UInt8(components[0]),
            let part2 = UInt8(components[1]),
            let part3 = UInt8(components[2]),
            let part4 = UInt8(components[3]) else { return nil }
        self.init(part1: part1, part2: part2, part3: part3, part4: part4)
    }
}

typealias Port = UInt

enum Scheme: String, Codable {
    case http
    case https
}

enum Host: Codable {
    case ip(Scheme, IP, Port?)
    case name(Scheme, URL)

    var scheme: Scheme {
        switch self {
        case .ip(let scheme, _, _):
            return scheme
        case .name(let scheme, _):
            return scheme
        }
    }

    var url: URL {
        switch self {
        case .ip(let scheme, let ip, .some(let port)):
            return URL(string: "\(scheme.rawValue)://\(ip.stringValue):\(port)")!
        case .ip(let scheme, let ip, .none):
            return URL(string: "\(scheme.rawValue)://\(ip.stringValue)")!
        case .name(let scheme, let url):
            return URL(string: "\(scheme.rawValue)://\(url.absoluteString)")!
        }
    }

    func url(with port: Port) -> URL {
        switch self {
        case .ip(let scheme, let ip, _):
            return URL(string: "\(scheme.rawValue)://\(ip.stringValue):\(port)")!
        case .name(let scheme, let url):
            return URL(string: "\(scheme.rawValue)://\(url.absoluteString):\(port)")!
        }
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: "com.torrentino.host")
    }

    static func load() -> Host {
        guard let data = UserDefaults.standard.data(forKey: "com.torrentino.host") else { return .defaultHost }
        guard let host = try? JSONDecoder().decode(Host.self, from: data) else { return .defaultHost }
        return host
    }

    static var defaultHost: Host {
        return .ip(.http, IP(part1: 178, part2: 168, part3: 48, part4: 164), 10000)
    }

    enum CodingKeys: String, CodingKey {
        case type
        case url
        case ip
        case port
        case scheme
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .ip(let scheme, let ip, let port):
            try container.encode("ip", forKey: .type)
            try container.encode(ip, forKey: .ip)
            try container.encode(scheme, forKey: .scheme)
            try container.encodeIfPresent(port, forKey: .port)
        case .name(let scheme, let url):
            try container.encode("url", forKey: .type)
            try container.encode(scheme, forKey: .scheme)
            try container.encode(url, forKey: .url)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "url":
            let url = try container.decode(URL.self, forKey: .url)
            let scheme = try container.decode(Scheme.self, forKey: .scheme)
            self = .name(scheme, url)
        case "ip":
            let ip = try container.decode(IP.self, forKey: .ip)
            let scheme = try container.decode(Scheme.self, forKey: .scheme)
            let port = try container.decodeIfPresent(Port.self, forKey: .port)
            self = .ip(scheme, ip, port)
        default:
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: [CodingKeys.type], debugDescription: "Wrong type")
            )
        }
    }
}

final class API {
    static let shared = API()

    private var recurentStatusTimer: Timer?
    private var recurentStatus = PublishRelay<[TorrentItem]>()
    private var host: Host = .load()
    private var disposeBag = DisposeBag()

    var currentHost: Host {
        return host
    }

    init() {
        setupRecurentStatus()
    }

    deinit {
        recurentStatusTimer?.invalidate()
    }

    func set(host: Host) {
        self.host = host
        self.host.save()
    }

    func download(id: String) {
        let url = host.url.appendingPathComponent("/download")
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "id", value: id)]
        let finalURL = components.url!
        let request = URLRequest(url: finalURL)
        URLSession.shared.dataTask(with: request) { _, _, _ in }.resume()
    }

    func getItems(for query: String) -> Observable<[TorrentItem]> {
        let url = host.url.appendingPathComponent("/search")
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "query", value: query)]
        let finalURL = components.url!
        let request = URLRequest(url: finalURL)
        return Observable<[TorrentItem]>.create { observer in
            let task = URLSession.shared.dataTask(with: request) { data, _, error in
                if let error = error {
                    observer.onError(error)
                } else if let data = data {
                    do {
                        let models = try JSONDecoder().decode([TorrentItem].self, from: data)
                        observer.onNext(models)
                        observer.onCompleted()
                    } catch {
                        observer.onError(error)
                    }
                } else {
                    observer.onCompleted()
                }
            }
            task.resume()
            return Disposables.create(with: task.cancel)
        }.observeOn(MainScheduler.instance)
    }

    func getFiles(for id: String) -> Observable<[FileNode]> {
        let url = host.url.appendingPathComponent("/files")
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "id", value: id)]
        let finalURL = components.url!
        let request = URLRequest(url: finalURL)
        return Observable<[FileNode]>.create { observer in
            let task = URLSession.shared.dataTask(with: request) { data, _, error in
                if let error = error {
                    observer.onError(error)
                } else if let data = data {
                    do {
                        let models = try JSONDecoder().decode([FileNode].self, from: data)
                        observer.onNext(models)
                        observer.onCompleted()
                    } catch {
                        observer.onError(error)
                    }
                } else {
                    observer.onCompleted()
                }
            }
            task.resume()
            return Disposables.create(with: task.cancel)
        }.observeOn(MainScheduler.instance)
    }

    func getVideoURL(for id: Int) -> Observable<VideoURL> {
        let url = host.url.appendingPathComponent("/video_url")
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "id", value: String(id))]
        let finalURL = components.url!
        let request = URLRequest(url: finalURL)
        return Observable<VideoURL>.create { observer in
            let task = URLSession.shared.dataTask(with: request) { data, _, error in
                if let error = error {
                    observer.onError(error)
                } else if let data = data {
                    do {
                        let url = try JSONDecoder().decode(VideoURL.self, from: data)
                        observer.onNext(url)
                        observer.onCompleted()
                    } catch {
                        observer.onError(error)
                    }
                } else {
                    observer.onCompleted()
                }
            }
            task.resume()
            return Disposables.create(with: task.cancel)
        }.observeOn(MainScheduler.instance)
    }

    func convertVideo(with id: Int) {
        let url = host.url.appendingPathComponent("/convert_video")
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "id", value: String(id))]
        let finalURL = components.url!
        let request = URLRequest(url: finalURL)
        URLSession.shared.dataTask(with: request) { _, _, _ in }.resume()
    }

    func getRecurentStatus() -> Observable<[TorrentItem]> {
        return recurentStatus.asObservable()
    }

    private func setupRecurentStatus() {
        recurentStatusTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true, block: { _ in
            self.getStatus()
                .catchErrorJustReturn([])
                .bind(to: self.recurentStatus)
                .disposed(by: self.disposeBag)
        })
        recurentStatusTimer?.fire()
    }

    private func getStatus() -> Observable<[TorrentItem]> {
        let url = host.url.appendingPathComponent("/status")
        let request = URLRequest(url: url)
        return Observable<[TorrentItem]>.create { observer in
            let task = URLSession.shared.dataTask(with: request) { data, _, error in
                if let error = error {
                    observer.onError(error)
                    print("STATUS POLLING ERROR: \(error.localizedDescription)")
                } else if let data = data {
                    do {
                        let models = try JSONDecoder().decode([TorrentItem].self, from: data)
                        observer.onNext(models)
                        observer.onCompleted()
                        print("STATUS POLLED")
                    } catch {
                        observer.onError(error)
                        print("STATUS POLLING ERROR: \(error.localizedDescription)")
                    }
                } else {
                    observer.onCompleted()
                }
            }
            task.resume()
            return Disposables.create(with: task.cancel)
        }.observeOn(MainScheduler.instance)
    }
}
