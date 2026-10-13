import Foundation

/// 按行流式读取文本文件，避免把整个日志文件一次性载入内存。
/// 以 `\n` 分行并去掉行尾 `\r`，空行与无法解码的行同样产出（由解析方跳过）。
struct FileLineSequence: Sequence {
    let url: URL
    var chunkSize: Int = 64 * 1024
    var startOffset: UInt64 = 0
    var readLimit: UInt64?

    func makeIterator() -> Iterator {
        Iterator(url: url, chunkSize: chunkSize, startOffset: startOffset, readLimit: readLimit)
    }

    final class Iterator: IteratorProtocol {
        private let handle: FileHandle?
        private let chunkSize: Int
        private var buffer = Data()
        /// buffer 中已消费的位置：用偏移游标代替 removeFirst，
        /// 避免大缓冲下每行都整体搬移剩余字节（O(n²)）。
        private var offset = 0
        private var scanOffset = 0
        private var reachedEOF = false
        private var remainingBytes: UInt64?
        private(set) var bytesRead: UInt64 = 0
        private(set) var lastLineTerminated = true

        init(url: URL, chunkSize: Int, startOffset: UInt64, readLimit: UInt64?) {
            self.handle = try? FileHandle(forReadingFrom: url)
            self.chunkSize = Swift.max(1, chunkSize)
            self.remainingBytes = readLimit
            if startOffset > 0 { try? handle?.seek(toOffset: startOffset) }
        }

        deinit { try? handle?.close() }

        func next() -> String? {
            guard let data = nextData() else { return nil }
            return String(data: data, encoding: .utf8) ?? ""
        }

        /// 原始字节行：调用方可以在解码前做字节级粗筛，避免超大行无谓的 UTF-8 解码。
        func nextData() -> Data? {
            guard let handle else { return nil }
            while true {
                if offset < buffer.count, let newlineIndex = indexOfNewline() {
                    var line = buffer[offset..<newlineIndex]
                    offset = newlineIndex + 1
                    scanOffset = offset
                    lastLineTerminated = true
                    if line.last == 0x0D { line = line.dropLast() }
                    compactIfNeeded()
                    return Data(line)
                }
                if reachedEOF {
                    guard offset < buffer.count else { return nil }
                    var line = buffer[offset...]
                    offset = buffer.count
                    lastLineTerminated = false
                    if line.last == 0x0D { line = line.dropLast() }
                    return Data(line)
                }
                let length = Int(Swift.min(UInt64(chunkSize), remainingBytes ?? UInt64(chunkSize)))
                // FileHandle 的 Foundation 缓冲会进入 autorelease pool；逐块释放，
                // 避免后台扫描数 GB 日志时把全部读取缓冲滞留到采集结束。
                let chunk = autoreleasepool { handle.readData(ofLength: length) }
                bytesRead += UInt64(chunk.count)
                if let remaining = remainingBytes { remainingBytes = remaining - UInt64(chunk.count) }
                if chunk.isEmpty {
                    reachedEOF = true
                } else {
                    buffer.append(chunk)
                }
            }
        }

        /// 仅扫描新增字节；长行跨 chunk 时不再反复扫描已检查的前缀。
        private func indexOfNewline() -> Int? {
            buffer.withUnsafeBytes { pointer -> Int? in
                guard let base = pointer.baseAddress else { return nil }
                let found = memchr(base.advanced(by: scanOffset), 0x0A, buffer.count - scanOffset)
                if found == nil { scanOffset = buffer.count }
                return found.map { base.distance(to: $0) }
            }
        }

        /// 已消费前缀超过阈值时在行边界压缩缓冲，控制内存占用。
        /// 显式拷贝重建 Data 保证 startIndex 归零（removeFirst 会产生非零起始下标的切片）。
        private func compactIfNeeded() {
            guard offset >= 1024 * 1024 else { return }
            buffer = Data(buffer[offset...])
            scanOffset -= offset
            offset = 0
        }
    }
}
