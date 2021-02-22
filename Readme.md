# dreiAttest

## Installation
### Using CocoaPods

Add the following to your Podfile:
```ruby
pod 'dreiAttest', :git => 'https://github.com/dreipol/dreiAttest-ios'
```
Run `pod install`.

## Usage

Import `dreiAttest` and `Alamofire`:
```swift
import dreiAttest
import Alamofire
```

Once the user has logged in to your app setup the attest service:
```swift
do {
    let attestService = try AttestService(baseAddress: URL(string: "https://example.com/attested")!, uid: "hello@example.com", validationLevel: .signOnly)
    let session = Session(interceptor: attestService)
    // ...
} catch {
    switch error {
    case AttestError.notSupported:
        // Running in a simulator, in an app extension, or on an Apple Silicon Mac.
    default:
        // Handle other errors
    }
}
```
If your app doesn't use login you can also omit the `uid`. In that case dreiAttest will generate an identifier that uniquely identifies the current device for you.

You can now use the [Alamofire session](https://github.com/Alamofire/Alamofire) as you normally would.

## Discussion
To use dreiAttest toghether with other interceptors create an `Interceptor` like
```swift
let interceptor = Interceptor(adapters: [], retriers: [], interceptors: [attestService, authenticationInterceptor, ...])
let session = Session(interceptor: interceptor)
```