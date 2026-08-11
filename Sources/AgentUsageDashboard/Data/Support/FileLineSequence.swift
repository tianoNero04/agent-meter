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
        private var reachedEOF = false

        init(url: URL, chunkSize: Int) {
            self.handle = try? FileHandle(forReadingFrom: url)
            self.chunkSize = chunkSize
        }

        func next() -> String? {
            guard let handle else { return nil }
            while true {
                if let newlineIndex = buffer.firstIndex(of: 0x0A) {
                    var line = buffer.prefix(upTo: newlineIndex)
                    // Data 切片后 startIndex 可能非零，必须按距离而不是绝对下标移除。
                    let consumed = buffer.distance(from: buffer.startIndex, to: newlineIndex) + 1
                    buffer.removeFirst(consumed)
                    if line.last == 0x0D { line = line.dropLast() }
                    return String(data: line, encoding: .utf8) ?? ""
                }
                if reachedEOF {
                    guard !buffer.isEmpty else { return nil }
                    var line = buffer
                    buffer = Data()
                    if line.last == 0x0D { line = line.dropLast() }
                    return String(data: line, encoding: .utf8) ?? ""
                }
                let chunk = handle.readData(ofLength: chunkSize)
                if chunk.isEmpty {
                    reachedEOF = true
                } else {
                    buffer.append(chunk)
                }
            }
        }
    }
}
