import Foundation
import CoreServices

// MARK: - FileSystemWatcher
// Watches directories for file system changes using FSEvents

final class FileSystemWatcher {
    var onEvent: ((NormalizedEvent) -> Void)?
    private var streamRef: FSEventStreamRef?
    private var watchedPaths: [String]

    init(paths: [String] = [
        NSHomeDirectory() + "/Downloads",
        NSHomeDirectory() + "/Documents",
        NSHomeDirectory() + "/Desktop"
    ]) {
        self.watchedPaths = paths
    }

    func start() {
        let selfPtr = Unmanaged.passRetained(self)
        var context = FSEventStreamContext(
            version: 0,
            info: selfPtr.toOpaque(),
            retain: nil, release: nil, copyDescription: nil
        )

        streamRef = FSEventStreamCreate(
            kCFAllocatorDefault,
            { _, info, numEvents, eventPaths, eventFlags, _ in
                guard let info = info else { return }
                let watcher = Unmanaged<FileSystemWatcher>.fromOpaque(info).takeUnretainedValue()
                let paths = Unmanaged<CFArray>.fromOpaque(eventPaths).takeUnretainedValue() as? [String] ?? []
                let flags = Array(UnsafeBufferPointer(start: eventFlags, count: numEvents))
                watcher.handleEvents(paths: paths, flags: flags)
            },
            &context,
            watchedPaths as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.3,
            FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagUseCFTypes)
        )

        if let stream = streamRef {
            FSEventStreamSetDispatchQueue(stream, DispatchQueue.global(qos: .utility))
            FSEventStreamStart(stream)
        }
    }

    func stop() {
        if let stream = streamRef {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            streamRef = nil
        }
    }

    private func handleEvents(paths: [String], flags: [FSEventStreamEventFlags]) {
        for (path, flag) in zip(paths, flags) {
            let f = flag
            if f & UInt32(kFSEventStreamEventFlagItemCreated) != 0 {
                emit(.fileCreated(path: path))
            } else if f & UInt32(kFSEventStreamEventFlagItemRemoved) != 0 {
                emit(.fileDeleted(path: path))
            } else if f & UInt32(kFSEventStreamEventFlagItemRenamed) != 0 {
                // FSEvents fired twice for rename: old path then new path
                emit(.fileRenamed(from: path, to: path))
            }
        }
    }

    private func emit(_ type: NormalizedEvent.EventType) {
        onEvent?(NormalizedEvent(type: type, timestamp: Date()))
    }
}
