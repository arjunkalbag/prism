import Foundation

/// A fixed-capacity float ring buffer that hands audio samples from the
/// capture thread to the analysis thread.
///
/// Storage is preallocated up front; `write` performs no heap allocation,
/// keeping the capture callback tight. A small spin-free `NSLock` guards the
/// indices — capture (single producer) and analysis (single consumer) run on
/// different queues, and the critical sections are a handful of integer ops.
public final class RingBuffer: @unchecked Sendable {
    private var storage: [Float]
    private let capacity: Int
    private var writeIndex = 0
    private var available = 0
    private var written = 0
    private let lock = NSLock()

    public init(capacity: Int) {
        precondition(capacity > 0, "RingBuffer capacity must be positive")
        self.capacity = capacity
        self.storage = [Float](repeating: 0, count: capacity)
    }

    /// Append samples, overwriting the oldest data once full. Allocation-free.
    public func write(_ samples: UnsafeBufferPointer<Float>) {
        guard !samples.isEmpty else { return }
        lock.lock()
        defer { lock.unlock() }
        for s in samples {
            storage[writeIndex] = s
            writeIndex = (writeIndex + 1) % capacity
        }
        available = min(available + samples.count, capacity)
        written &+= samples.count
    }

    /// Monotonic count of all samples ever written. A consumer can diff this
    /// across reads to learn how many new samples arrived (for ordered, gap-free
    /// streaming, e.g. the tempo onset envelope).
    public var totalWritten: Int {
        lock.lock()
        defer { lock.unlock() }
        return written
    }

    /// Convenience array overload (does not allocate beyond the borrow).
    public func write(_ samples: [Float]) {
        samples.withUnsafeBufferPointer { write($0) }
    }

    /// Copy the most recent `count` samples into `out` (oldest → newest).
    /// `out` must already have at least `count` elements (preallocate it).
    /// Returns `false` if fewer than `count` samples are available yet.
    @discardableResult
    public func latest(_ count: Int, into out: inout [Float]) -> Bool {
        guard count > 0, count <= capacity, out.count >= count else { return false }
        lock.lock()
        defer { lock.unlock() }
        guard available >= count else { return false }
        var idx = (((writeIndex - count) % capacity) + capacity) % capacity
        for i in 0..<count {
            out[i] = storage[idx]
            idx = (idx + 1) % capacity
        }
        return true
    }

    /// Number of valid samples currently buffered.
    public var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return available
    }

    /// Drop all buffered samples (e.g. on stream restart).
    public func reset() {
        lock.lock()
        defer { lock.unlock() }
        writeIndex = 0
        available = 0
        written = 0
    }
}
