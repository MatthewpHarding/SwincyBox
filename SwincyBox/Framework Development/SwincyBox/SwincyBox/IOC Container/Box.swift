//
//  Container.swift
//  SwincyBox
//
//  Created by Matthew Paul Harding on 15/06/2022.
//

import Foundation

/// Resolver typealias has been used to aid the documentation and readability of the code by using standardised IOC Framework terminology
public typealias Resolver = Box

/// A box represents what's known as a container, using terminology often used when discussing the Inversion Of Control principle. Each box is used to register and store dependencies, which are known as services and are either stored or created by the box used during registration. A typical usage of SwincyBox would be accessing one box throughout the application lifecycle. However, multiple boxes can be created with an option to even chain them together as children boxes. Please note that when calling the resolve function on a box it becomes a first responder, cascading up through the parent chain until either a dependency is returned or the end of the chain is found and a fatalError() will be thrown.
public final class Box {
    // MARK: - Properties
    /// A store of each registered service, or rather the wrapper type that encapsulates it.
    private var services: [String : ServiceStorage] = [:]
    /// A weak referenced property linking to the box which created it or nil if it wasn't created by a parent. Parent boxes are used to recursively search upwards to resolve a service.
    private weak var parentBox: Box? = nil
    /// An array of all child boxes created by calling the addChildBox() function.
    private var childBoxes: [String: Box] = [:]
    
    // MARK: - Exposed Public API
    public var registeredServiceCount: Int { return services.count }
    
    /// The constructor used to instantiate an instance of a box. After the class has been initialised the class will then be ready to register each service creation factory.
    public init () { }
    
    // MARK: - Clear Registered Services
    /// Calling this function will remove all of the services registered with this current box including all child boxes too.
    public func clear() {
        services.removeAll()
        childBoxes.forEach { $0.value.clear() }
    }
    
    // MARK: - Register Dependecy (without a resolver)
    /// Call register to add a closure which creates a specific type known as a service. The factory method that creates it will be stored for use each time resolve() is called. Specifying the LifeType will dictate if the returned instance is kept and stored for the lifetime of the box. A transient LifeType will create a new instance with each call to resolve(). A permanent type will store the first created instance returned with each subsequent call.
    public func register<Service>(_ type: Service.Type = Service.self, key: String? = nil, life: LifeType = .transient, _ factory: @escaping (() -> Service)) {
        registerServiceStore(wrapServiceFactory(factory, life: life), type, key)
    }
    
    // MARK: - Register Dependecy (using a resolver)
    /// Call register to add a closure which creates a specific type known as a service. The factory method that creates it will be stored for use each time resolve() is called. Specifying the LifeType will dictate if the returned instance is kept and stored for the lifetime of the box. A transient LifeType will create a new instance with each call to resolve(). A permanent type will store the first created instance returned with each subsequent call. This particular overload of the register function accepts a resolver type as an argument to the factory method which can be used to resolve any dependencies on the type registered.
    public func register<Service>(_ type: Service.Type = Service.self, key: String? = nil, life: LifeType = .transient, _ factory: @escaping ((Resolver) -> Service)) {
        registerServiceStore(wrapServiceFactory(factory, life: life), type, key)
    }
    
    /// Call this function to store the wrapped service within the dictionary of registered services.
    private func registerServiceStore<Service>(_ serviceStore: ServiceStorage, _ type: Service.Type, _ key: String?) {
        let serviceKey = serviceKey(for: type, key: key)
        if let _ = services[serviceKey] {
            logWarning("Already registerd '\(type)' for key '\(String(describing: key))'")
        }
        services[serviceKey] = serviceStore
    }
    
    // MARK: - Resolve Dependency
    /// Call this function to resolve (generate or retrieve) an instance of a type of a registered service. If the service has not yet been registered a fatalError() will be thrown. All services must be registered before the first call to resolve for the matching type with a matching key (or nil). Call this method once only within the application lifecycle.
    /// - Returns: An instance of the service requested. The type of the instance returned may only be different from the typecast it was registered for, either through inheritance or protocol adherence. However, it must match the type it was registered with otherwise a fatalError() is thrown.
    public func resolve<Service>(_ type: Service.Type = Service.self, key: String? = nil) -> Service {
        return resolveUsingParentIfNeeded(type, key: key)
    }
    
    // MARK: - Childbox
    /// Calling this function creates and embeds a new child box, which can then be used as a first responder for all calls to resolve cascading upwards through parent boxes until the dependency is resolved.
    /// - Parameter key: A unique string key identifier to be used when retrieving each specific box.
    /// - Returns: A newly created child box stored and retrieved by passed in key identifier.
    public func addChildBox(forKey key: String) -> Box {
        let box = Box()
        box.parentBox = self
        box.services = services // copies a snapshot of the existing dictionary. instances remain the same
        if let _ = childBoxes[key] {
            logWarning("Already registerd childBox for key '\(key)'")
        }
        childBoxes[key] = box
        return box
    }
    
    /// Calling this function returns an optional Box for the unique key used to create the box.
    /// - Parameter key: A unique string key identifier to be used when retrieving each specific box.
    /// - Returns: A child box associated and stored with the passed in key.
    public func childBox(forKey key: String) -> Box? {
        guard let childBox = childBoxes[key] else {
            logWarning("Child box not found for key '\(key)'")
            return nil
        }
        return childBox
    }
    
    // MARK: - Internally Resolve Dependency
    /// The first method to be called within the lightly recursive approach of cascading upwards through the chain of parent boxes. Similar to becoming a first responder, each child box is given an opportunity to return the service requested using this method attempToResolve().
    /// - Returns: An optional value representing the registered service. Nil if no such service could be resolved by this box.
    private func attempToResolve<Service>(_ type: Service.Type = Service.self, key: String? = nil) -> Service? {
        guard let storage = services[serviceKey(for: type, key: key)] else { return nil }
        return storage.returnService(self) as? Service
    }
    
    /// The root method for resolving a registered service. If the box cannot resolve the service then we recursively search each parent box until the type is resolved or we reach the end of the parent chain, in which case a fatalError() is thrown.
    /// - Returns: an instance of the registered type associated with both the generically assigned type (using Swift Generics) and the supplied key identifier.
    private func resolveUsingParentIfNeeded<Service>(_ type: Service.Type = Service.self, key: String? = nil) -> Service {
        guard let service = attempToResolve(type, key: key) ?? parentBox?.resolveUsingParentIfNeeded(type, key: key) else {
            fatalError("SwincyBox: Dependency not registered for type '\(type)'")
        }
        return service
    }
    
    // MARK: - Service Storage
    /// A centralised location used to generate a unique key from both the service type and associated key used for service retrieval. The returned key will then be used to store and retrieve the associated service.
    /// - Returns: A unique key generated from both the service type and associated key used for service retrieval.
    private func serviceKey<Service>(for type: Service, key: String?) -> String {
        guard let key = key else { return "\(type)" }
        return "\(type) - \(key)"
    }
    
    /// A function to encapsulate a factory method used to generate some instance of a service. This method will return a different type of wrapper for each different life cycle supported by SwincyBox. The passed in factory method accepts a resolver object as an argument, which should be used to resolve any dependencies before returning the service itself.
    /// - Returns: An type adhering to the service storage protocol which can then be asked to return the service it encapsulates.
    private func wrapServiceFactory<Service>(_ factory: @escaping ((Resolver) -> Service), life: LifeType) -> ServiceStorage {
        switch life {
        case .transient: return TransientStoreWithResolver(factory)
        case .permanent: return PermanentStore(factory(self))
        }
    }
    
    /// A function to encapsulate a factory method used to generate some instance of a service. This method will return a different type of wrapper for each different life cycle supported by SwincyBox. The passed in factory method accepts no arguments and simply returns an instance of the service.
    /// - Returns: An type adhering to the service storage protocol which can then be asked to return the service it encapsulates.
    private func wrapServiceFactory<Service>(_ factory: @escaping (() -> Service), life: LifeType) -> ServiceStorage {
        switch life {
        case .transient: return TransientStore(factory)
        case .permanent: return PermanentStore(factory())
        }
    }
}

// MARK: - Logging
/// Logging will only occur during a development build and not within a release build to ensure the performance of client apps is maintained and supported
extension Box {
    /// A wrapper for the Swift print() command adding a SwincyBox title to each message, whilst also ensuring that no logging occurs during a live release build. Messages will only be logged during a DEBUG Xcode build.
    /// - Parameter string: The string printed to the console. Each call to log prints the framework name first followed by the string parameter on a new line.
    private func log(_ string: String) {
        // NOTE: Printing to the console slows down performance of the app and device. We never want to negatively affect the performance of our client apps even for logging warnings
        #if DEBUG
        print("Swincy Framework")
        print(string)
        #endif
    }
    
    /// A method to print the passed in string message to the console log (within a DEBUG build) also prefixing the text, "Warning: ".
    /// - Parameter string: The string printed to the console with the added warning prefix.
    private func logWarning(_ string: String) {
        log("Warning: " + string)
    }
}
