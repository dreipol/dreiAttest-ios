# dreiAttest

[![Maintainability](https://api.codeclimate.com/v1/badges/739700599784ebf30814/maintainability)](https://codeclimate.com/repos/6037772f371217014d007062/maintainability)

dreiAttest implements Apple's [DeviceCheck Framework](https://developer.apple.com/documentation/devicecheck) to allow you to verify that request made to your server come from an actual device. [Android and Kotlin Multiplatform versions](https://github.com/dreipol/dreiAttest-android) are also available. To use dreiAttest you need to run [dreiAttest on your server](https://github.com/dreipol/dreiAttest-django).

Typically only certain endpoints over which sensitive data can be accessed are protected by dreiAttest. For this reason you define a base URL: requests starting with this base URL are handled by dreiAttest, while requests to other endpoints are simply forwarded to your server. For example if you define the base URL `https://example.com/attested`:
- Requests to `https://example.com/login` are **not** handled by dreiAttest
- Requests to `https://example.com/attested/profile-info` are handle by dreiAttest

You should only create a an `AttestService` after the user has logged in and pass in your service's user id. dreiAttest will generate a new key every time a user logs in with a different account. Apple counts these keys for you and allows you to identify suspicious login behavior.

For more information on how dreiAttest works read the [whitepaper]() or our [blog post]().

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
If your app doesn't use login you can also omit the `uid`. In that case dreiAttest will generate an identifier that uniquely identifies the current installation for you.

You can now use the [Alamofire session](https://github.com/Alamofire/Alamofire) as you normally would.

### Development
DeviceCheck is not supported by the iOS Simulator. During development it may be useful to [setup a shared secret](https://github.com/dreipol/dreiattest-django#usage) on the server to bypass dreiAttest. You can pass this shared secret to the iOS library using the `DREIATTEST_BYPASS_SECRET`environment variable or by passing it to the `AttestServie` in its initializer.

## Discussion
To use dreiAttest toghether with other interceptors create an `Interceptor` like
```swift
let interceptor = Interceptor(adapters: [], retriers: [], interceptors: [attestService, authenticationInterceptor, ...])
let session = Session(interceptor: interceptor)
```
