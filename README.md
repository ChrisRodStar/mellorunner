<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="assets/banner-dark.svg">
    <source media="(prefers-color-scheme: light)" srcset="assets/banner-light.svg">
    <img alt="MelloRunner — a running golden dog and the project name" src="assets/banner-dark.svg" width="100%">
  </picture>
</p>

# MelloRunner

An independent source-runner project for Melloku on iOS 27 and macOS 27, using Swift 6.4.

The package contains a Swift library, Swift Testing tests, and independently generated fixtures. It checks the WebAssembly magic, binary version, and configured input-size limit. It does not execute modules, validate their sections, or run Aidoku-compatible sources yet.

## Build and use

```sh
swift build
swift test
```

## Layout

- `Sources/MelloRunner`: runtime library; currently header inspection.
- `Tests/MelloRunnerTests`: contract tests and generated fixtures.
- `docs`: scope, architecture, compatibility, provenance, and next work.
- `Reference/AidokuRunner`: local upstream checkout, ignored by Git and excluded from package targets.

The first execution milestone is to invoke the fixture's `answer` export and receive 42 through an independently implemented runtime adapter.

[Scope](docs/PRODUCT.md) · [Architecture](docs/ARCHITECTURE.md) · [Compatibility](docs/COMPATIBILITY.md) · [Provenance](docs/PROVENANCE.md) · [Next work](docs/TODO.md)

Restore the optional local reference with `git clone https://github.com/Aidoku/AidokuRunner.git Reference/AidokuRunner`.
