import Foundation
import CoreServices

final class FSEventsDirectoryWatcher: DirectoryWatcher {
    private let rootURL: URL
    private let handler: () -> Void
    private var stream: FSEventStreamRef?

    init(rootURL: URL, handler: @escaping () -> Void) {
        self.rootURL = rootURL
        self.handler = handler
    }

    func start() {
        guard stream == nil else { return }

        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )
        let callback: FSEventStreamCallback = { _, info, _, _, _, _ in
            guard let info else { return }
            Unmanaged<FSEventsDirectoryWatcher>.fromOpaque(info).takeUnretainedValue().handler()
        }

        stream = FSEventStreamCreate(
            nil,
            callback,
            &context,
            [rootURL.path] as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.5,
            FSEventStreamCreateFlags(
                // SQLite 的 WAL/SHM 维护与本机缓存写入不能反过来触发自己采集。
                // 其他进程（Codex/Kimi CLI）的日志写入仍正常通知。
                kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagNoDefer
                    | kFSEventStreamCreateFlagIgnoreSelf
            )
        )

        guard let stream else { return }
        FSEventStreamSetDispatchQueue(stream, DispatchQueue.global(qos: .utility))
        FSEventStreamStart(stream)
    }

    func stop() {
        guard let stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
    }

    deinit { stop() }
}
