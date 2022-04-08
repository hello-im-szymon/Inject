import Foundation

/// Common protocol interface for classes that support observing injection events
/// This is automatically added to all NSObject subclasses like `ViewController`s or `Window`s
public protocol InjectListener {
    associatedtype InjectInstanceType = Self

    func enableInjection()
    func onInjection(callback: @escaping (InjectInstanceType) -> Void) -> Void
}

/// Public namespace for using Inject API
public enum Inject {
    public static let observer = injectionObserver
    public static let load: Void = loadInjectionImplementation
}

public extension InjectListener {
    /// Ensures injection is enabled
    @inlinable @inline(__always)
    func enableInjection() {
        _ = Inject.load
    }
}

#if DEBUG
private var loadInjectionImplementation: Void = {
#if os(macOS)
    let bundleName = "macOSInjection.bundle"
#elseif os(tvOS)
    let bundleName = "tvOSInjection.bundle"
#elseif targetEnvironment(simulator)
    let bundleName = "iOSInjection.bundle"
#else
    let bundleName = "maciOSInjection.bundle"
#endif // OS and environment conditions
    Bundle(path: "/Applications/InjectionIII.app/Contents/Resources/" + bundleName)?.load()
}()

public class InjectionObserver {
    public private(set) var injectionNumber = 0 {
        didSet {
            listeners.forEach { $0.handler() }
        }
    }
    private var token: NSObjectProtocol?
    private struct Listener {
        let id = UUID()
        let handler: () -> Void
    }
    private var listeners = [Listener]()
    fileprivate init() {
        token = NotificationCenter.default.addObserver(forName: Notification.Name("INJECTION_BUNDLE_NOTIFICATION"), object: nil, queue: nil) { [weak self] _ in
                self?.injectionNumber += 1
            }
    }
    deinit {
        NotificationCenter.default.removeObserver(token!)
    }

    fileprivate func addListener(_ handler: @escaping () -> Void) -> NSCancellable {
        let listener = Listener(handler: handler)
        listeners.append(listener)
        return NSCancellable { [weak self, id = listener.id] in
            self?.listeners.removeAll(where: { $0.id == id })
        }
    }
}

private let injectionObserver = InjectionObserver()
private var injectionObservationKey = arc4random()

public extension InjectListener where Self: NSObject {
    func onInjection(callback: @escaping (Self) -> Void) {
        let observation = injectionObserver.addListener { [weak self] in
            guard let self = self else { return }
            callback(self)
        }

        objc_setAssociatedObject(self, &injectionObservationKey, observation, .OBJC_ASSOCIATION_RETAIN)
    }
}

private final class NSCancellable: NSObject {
    private let cancelHandler: () -> Void
    init(_ cancelHandler: @escaping () -> Void) {
        self.cancelHandler = cancelHandler
        super.init()
    }
    deinit {
        cancelHandler()
    }
}

#else
public class InjectionObserver: ObservableObject {}
private let injectionObserver = InjectionObserver()
private var loadInjectionImplementation: Void = {}()

public extension InjectListener where Self: NSObject {
    @inlinable @inline(__always)
    func onInjection(callback: @escaping (Self) -> Void) {}
}
#endif // DEBUG
