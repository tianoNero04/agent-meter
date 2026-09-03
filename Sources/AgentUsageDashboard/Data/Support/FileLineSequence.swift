import Foundation

/// 按行流式读取文本文件，避免把整个日志文件一次性载入内存。
/// 以 `\n` 分行并去掉行尾 `\r`，空行与无法解码的行同样产出（由解析方跳过）。
struct FileLineSequence: Sequence {
    let url: URL
    var chunkSize: Int = 64 * 1024

    func makeIterator() -> Iterator {
        Iterator(url: url, chunkSize: chunkSize)
    }

    final class Iterator: IteratorProtocol {
        private let handle: FileHandle?
        private let chunkSize: Int
        private var buffer = Data()
        /// buffer 中已消费的位置：用偏移游标代替 removeFirst，
        /// 避免大缓冲下每行都整体搬移剩余字节（O(n²)）。
        private var offset = 0
        private var reachedEOF = false

        init(url: URL, chunkSize: Int) {
            self.handle = try? FileHandle(forReadingFrom: url)
            self.chunkSize = chunkSize
        }

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
                    if line.last == 0x0D { line = line.dropLast() }
                    compactIfNeeded()
                    return Data(line)
                }
                if reachedEOF {
                    guard offset < buffer.count else { return nil }
                    var line = buffer[offset...]
                    offset = buffer.count
                    if line.last == 0x0D { line = line.dropLast() }
                    return Data(line)
                }
                let chunk = handle.readData(ofLength: chunkSize)
                if chunk.isEmpty {
                    reachedEOF = true
                } else {
                    buffer.append(chunk)
                }
            }
        }

        /// 从 offset 起用 memchr 找换行，避免 Data 切片下标的边界陷阱。
        private func indexOfNewline() -> Int? {
            buffer.withUnsafeBytes { pointer -> Int? in
                guard let base = pointer.baseAddress else { return nil }
                let found = memchr(base.advanced(by: offset), 0x0A, buffer.count - offset)
                return found.map { base.distance(to: $0) }
            }
        }

        /// 已消费前缀超过阈值时在行边界压缩缓冲，控制内存占用。
        /// 显式拷贝重建 Data 保证 startIndex 归零（removeFirst 会产生非零起始下标的切片）。
        private func compactIfNeeded() {
            guard offset >= 1024 * 1024 else { return }
            buffer = Data(buffer[offset...])
            offset = 0
        }
    }
}
