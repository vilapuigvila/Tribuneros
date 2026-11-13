fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios tests

```sh
[bundle exec] fastlane ios tests
```

Run the unit tests (skips the two live-network tests)

### ios beta

```sh
[bundle exec] fastlane ios beta
```

Optionally ask a new version (empty skips), bump the build past App Store Connect's latest, commit, archive and upload to TestFlight

### ios beta_external

```sh
[bundle exec] fastlane ios beta_external
```

Like beta (optional new version, empty skips), then send it to the External-alfys testers with a What to Test you type first

### ios latest_build

```sh
[bundle exec] fastlane ios latest_build
```

Print the latest build number on App Store Connect

### ios new_version

```sh
[bundle exec] fastlane ios new_version
```

From a clean development branch: ask the new version and its What's New (English, Catalan), archive the .ipa with that version, and upload binary and texts to App Store Connect: new_version version:1.1 whats_new:"..." whats_new_ca:"..."

### ios submit_review

```sh
[bundle exec] fastlane ios submit_review
```

Attach an already processed build to the editable App Store version and submit it for App Review (no archive, no upload): submit_review [version:1.3] [build:32] [confirm:yes]; defaults are the editable version and its newest processed build

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
