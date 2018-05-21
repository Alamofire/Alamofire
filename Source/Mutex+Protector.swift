//
//  Mutex+Protector.swift
//
//  Copyright (c) 2014-2018 Alamofire Software Foundation (http://alamofire.org/)
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

import Foundation

// MARK: -

/// An `os_unfair_lock` wrapper.
final class UnfairLock {
    private var unfairLock = os_unfair_lock()

    fileprivate func lock() {
        os_unfair_lock_lock(&unfairLock)
    }

    fileprivate func unlock() {
        os_unfair_lock_unlock(&unfairLock)
    }

    ///
    /// - Parameter closure: The closure to run.
    /// - Returns:           The value the closure generated.
    func around<T>(_ closure: () -> T) -> T {
        lock(); defer { unlock() }
        return closure()
    }

    /// Execute a closure while aquiring the lock.
    ///
    /// - Parameter closure: The closure to run.
    func around(_ closure: () -> Void) {
        lock(); defer { unlock() }
        return closure()
    }
}

/// A thread-safe wrapper around a value.
final class Protector<T> {
    private let lock = UnfairLock()
    private var value: T

    init(_ value: T) {
        self.value = value
    }

    /// The contained value. Unsafe for anything more than direct read or write.
    var directValue: T {
        get { return lock.around { value } }
        set { lock.around { value = newValue } }
    }

    /// Synchronously read or transform the contained value.
    ///
    /// - Parameter closure: The closure to execute.
    /// - Returns:           The return value of the closure passed.
    func read<U>(_ closure: (T) -> U) -> U {
        return lock.around { closure(self.value) }
    }

    /// Synchronously modify the protected value.
    ///
    /// - Parameter closure: The closure to execute.
    /// - Returns:           The modified value.
    @discardableResult
    func write<U>(_ closure: (inout T) -> U) -> U {
        return lock.around { closure(&self.value) }
    }
}

extension Protector where T: RangeReplaceableCollection {
    func append(_ newElement: T.Iterator.Element) {
        write { (ward: inout T) in
            ward.append(newElement)
        }
    }

    func append<S: Sequence>(contentsOf newElements: S) where S.Iterator.Element == T.Iterator.Element {
        write { (ward: inout T) in
            ward.append(contentsOf: newElements)
        }
    }

    func append<C: Collection>(contentsOf newElements: C) where C.Iterator.Element == T.Iterator.Element {
        write { (ward: inout T) in
            ward.append(contentsOf: newElements)
        }
    }
}

extension Protector where T: Strideable {
    func advance(by stride: T.Stride) {
        write { (ward: inout T) in
            ward = ward.advanced(by: stride)
        }
    }
}
