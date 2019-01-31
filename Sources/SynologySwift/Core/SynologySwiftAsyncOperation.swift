//
//  SynologySwiftAsyncOperation.swift
//  SynologySwift
//
//  Created by Thomas le Gravier on 18/12/2018.
//  Copyright © 2018 Thomas Le Gravier. All rights reserved.
//

import Foundation


class SynologySwiftAsyncOperation<T: Decodable>: Operation {
    
    override var isAsynchronous: Bool { return true }
    override var isExecuting: Bool { return state == .executing }
    override var isFinished: Bool { return state == .finished }
    
    private(set) var result: SynologySwift.Result<T>? {
        didSet {
            guard result != nil else {return}
            state = .finished
        }
    }
    
    private var state = State.ready {
        willSet {
            willChangeValue(forKey: state.keyPath)
            willChangeValue(forKey: newValue.keyPath)
        }
        didSet {
            didChangeValue(forKey: state.keyPath)
            didChangeValue(forKey: oldValue.keyPath)
        }
    }
    
    enum State: String {
        case ready = "Ready"
        case executing = "Executing"
        case finished = "Finished"
        fileprivate var keyPath: String { return "is" + self.rawValue }
    }
    
    override func start() {
        if isCancelled {
            state = .finished
        } else {
            state = .ready
            main()
        }
    }
    
    override func main() {
        if isCancelled {
            state = .finished
        } else {
            state = .executing
            blockOperation?({
                self.result = $0
            })
        }
    }
    
    func setBlockOperation(_ operation: @escaping (_ endHandler: @escaping (_ result: SynologySwift.Result<T>?)->Void)->()) {
        blockOperation = operation
    }
    
    /* Mark: Private */
    
    private var blockOperation: ((_ endHandler: @escaping (_ result: SynologySwift.Result<T>?)->Void)->())? = nil

}
