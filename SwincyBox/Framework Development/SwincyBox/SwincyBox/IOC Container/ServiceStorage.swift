//
//  Services.swift
//  SwincyBox
//
//  Created by Matthew Paul Harding on 17/06/2022.
//

import Foundation

// MARK: - Protocol
/// This protocol declares an interface to retrieve a registered service from a storage wrapper, which either generates, instantiates or provides single access to the service it encapsulates or generates. A method is simply called to return the associated service. How the service is stored or instantiated is of no importance here.
protocol ServiceStoring {
    /// Interface for retrieving an instance of the service stored
    /// - Returns: An instance of the service stored
    func service(_ resolver: Resolver) -> Any
}

// MARK: - Permanent
/// A wrapper encapsulating the single instance of a registered type. This class will simply store the already instantiated type and return it when requested.
final class PermanentStore<Service>: ServiceStoring {
    /// The stored instance of the service which will be returned when requested.
    private var service: Service?
    /// The factory method used to create an instance of the service
    private let factory: ((Resolver) -> Service)
    
    /// Initialiser for a permanent store of a registered service.
    /// - Parameter factory: The factory method used to create an instance of the service.
    init(_ factory: @escaping ((Resolver) -> Service)) {
        self.factory = factory
    }
    
    /// This function returns the single stored instance of the service
    /// - Parameter resolver: The resolver object to be used when resolving dependencies
    /// - Returns: A newly created service with each function call.
    func service(_ resolver: Resolver) -> Any {
        if let service = self.service {
            return service
        }
        let newService = factory(resolver)
        self.service = newService
        return newService
    }
}

// MARK: - Transient
/// A wrapper encapsulating and storing a factory method used to generate new instances (known as a service) of a registered type. The stored function accepts no arguments and simply returns a newly instantiated type per each request.
final class TransientStore<Service>: ServiceStoring {
    /// The factory method used to create an instance of the service each time it is requested.
    private let factory: ((Resolver) -> Service)
    
    /// Initialiser for a transient store of a registered service.
    /// - Parameter factory: The factory method used to create an instance of the service each time it is requested.
    init(_ factory: @escaping ((Resolver) -> Service)) {
        self.factory = factory
    }
    
    /// This function returns a newly created service with each function call.
    /// - Parameter resolver: The resolver object to be used when resolving dependencies.
    /// - Returns: A newly created service with each function call.
    func service(_ resolver: Resolver) -> Any {
        return factory(resolver)
    }
}
