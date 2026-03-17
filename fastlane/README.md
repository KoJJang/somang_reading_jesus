fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

### bump_version

```sh
[bundle exec] fastlane bump_version
```



----


## Android

### android beta

```sh
[bundle exec] fastlane android beta
```

Android 내부 테스트(internal) 트랙에 업로드

### android prod

```sh
[bundle exec] fastlane android prod
```

내부 테스트 트랙 → 프로덕션으로 승격

----


## iOS

### ios beta

```sh
[bundle exec] fastlane ios beta
```

TestFlight에 업로드

### ios prod

```sh
[bundle exec] fastlane ios prod
```

App Store에 제출

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
