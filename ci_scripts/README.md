# ci_scripts

Build hooks for **Xcode Cloud**. Xcode Cloud automatically runs scripts in this
folder at fixed points in a build, by filename:

- `ci_post_clone.sh` — after the repo is cloned. We use it to install and run
  **SwiftLint** (`swiftlint lint --strict --baseline swiftlint-baseline.json`);
  lint failures fail the build.

These scripts only run on Xcode Cloud, not on local builds. To reproduce the
lint step locally:

```sh
swiftlint lint --config .swiftlint.yml --baseline swiftlint-baseline.json
```

The SwiftLint configuration lives in `.swiftlint.yml` at the repo root.

## Baseline

`swiftlint-baseline.json` (repo root) snapshots the project's pre-existing
violations so CI only fails on **new** ones — useful because the codebase
predates the lint rules (e.g. ~400 `foregroundColor` uses to migrate over time).

Regenerate it after a deliberate cleanup so the snapshot shrinks:

```sh
swiftlint lint --config .swiftlint.yml --write-baseline swiftlint-baseline.json
```

> Note: the GitHub Actions workflows under `.github/workflows/` are unrelated —
> they run Python data-sync jobs, not app builds.
