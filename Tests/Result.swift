/**
Used to represent whether a request was successful or encountered an error.

Success: The request and all post processing operations were successful resulting in the serialization of the
provided associated value.
Failure: The request encountered an error resulting in a failure. The associated values are the original data
provided by the server as well as the error that caused the failure.
*/
import Result

extension Result {

    /// Returns `true` if the result is a success, `false` otherwise.
    public var isSuccess: Bool {
        switch self {
        case .Success:
            return true
        case .Failure:
            return false
        }
    }

    /// Returns `true` if the result is a failure, `false` otherwise.
    public var isFailure: Bool {
        return !isSuccess
    }

    /// Returns the associated value if the result is a success, `nil` otherwise.
    public var value: Value? {
        switch self {
        case .Success(let value):
            return value
        case .Failure:
            return nil
        }
    }

    /// Returns the associated error value if the result is a failure, `nil` otherwise.
    public var error: ErrorType? {
        switch self {
        case .Success:
            return nil
        case .Failure(let error):
            return error
        }
    }
}

extension Result where Error: NSError {
    /// Returns the associated data value if the result is a failure, `nil` otherwise.
    public var data: NSData? {
        switch self {
        case .Success:
            return nil
        case .Failure(let error):
            return error.data
        }
    }
}