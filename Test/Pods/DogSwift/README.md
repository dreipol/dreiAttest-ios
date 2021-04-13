<p align="center">
    <img src="https://raw.githubusercontent.com/dreipol/DogSwift/master/assets/ic_DogSwift.svg?sanitize=true">  
</p>
<h1 align="center">
    DogSwift
</h1> 

A lightweight and easy to use logging API to include in your mobile iOS application. 

DogSwift uses `os_log` on devices with iOS 10.0+ installed and falls back to `NSLog` for older iOS versions. DogSwift can print errors, messages and object descriptions to Xcode's debugging console. It's also possible to tag each logging statement with a category which will be utilized by Apple's `os_log` implementation, like `UI`, `Networking` et cetera.

## Instructions

Add the environment variable `LOG_LEVEL` along with the desired value:
- `error = 1`
- `warn = 2`
- `info = 3`
- `debug = 4`

### Log to Xcode's debugging console
```swift
// Log function name of current scope.
Log.info(#function)

// The message parameter can be of type `Any`.
Log.debug(view.bounds, tag: .ui)

// Log a warning.
Log.warn("Current device is running iOS 9.0, which doesn't support os_log.", tag: .location)

// Error logging.
let exampleError = NSError(domain: "ch.dreipol", code: -9999, userInfo: [
    NSLocalizedDescriptionKey: "Flying to the moon was not possible.",
    NSLocalizedFailureReasonErrorKey: "The operation timed out.",
    NSLocalizedRecoverySuggestionErrorKey: "Have you tried turning it off and on again?"
])
Log.error(exampleError, description: #function, tag: .system
```

### Logging with tags
Tags can help to group the logging output. Currently the folliwing tags are supported:
- `none`
- `database`
- `networking`
- `system`
- `ui`

### Define custom tags
It's possible to define your own tags and pass them to DogSwift:
```swift
import DogSwift

enum ExampleTag: String {
    case viewDidLoad
}

extension ExampleTag: TagProtocol {
    func makeString() -> String {
        return String(describing: self)
    }
}
```

The new Tag can now be passed to DogSwift:
```swift
[...]

override func viewDidLoad() {
    super.viewDidLoad()

    Log.debug(view.bounds, tag: ExampleTag.viewDidLoad)
}
    
[...]
```

## Requirements

Swift 5.0

## Installation with CocoaPods

DogSwift is available through CocoaPods. To install
it, simply add the following line to your Podfile:

```ruby
pod 'DogSwift'
```

# DogSwiftExample

To run the example project, open `DogSwiftExample.xcworkspace` which resides inside the DogSwiftExample directory. The demo app contains some examples on how to use DogSwift for Logging errors as well as various information to Xcode's debugging console.
