# TurboModuleTestingMatrix

Note, this is a very AI generated testsuite by claude 2.1.181 (Opus 4.8)

Tests to verify that [TurboModuleTesting](https://github.com/davehunter/TurboModuleTesting) works across multiple React Native versions.

The matrix holds one fully-locked host app per RN version under `apps/<rn>/HostApp/`, a shared `RTNTestableModule/` exercised by every version, and a driver that compiles + runs the framework's tests against each.

## Add a new RN version

1. Add an entry to [`versions.json`](./versions.json):
   ```json
   { "rn": "0.84.0", "cli": "@react-native-community/cli@latest", "cliInitFlavor": "community", "node": ">=20", "ruby": "3.2", "notes": "" }
   ```
2. Generate the host app:
   ```sh
   scripts/generate.sh 0.84.0
   ```
3. Commit:
   ```sh
   git add versions.json apps/0.84.0/
   ```

The generator runs `npx <cli> init`, layers [`overlays/_shared/`](./overlays/_shared/) (and any per-version overrides in `overlays/<rn>/`), then runs `npm install`, `bundle install`, and `pod install` — leaving committable lock files and a gitignored `node_modules/`, `Pods/`, `vendor/bundle/`.

## Run the matrix

```sh
scripts/run-matrix.sh             # all versions
scripts/run-matrix.sh 0.83.1      # a single version
```

Phases per version: `npm-install` → `pod-install` → `codegen-check` → `cmake-configure` → `cmake-build` → `ctest`. A failure in any phase short-circuits subsequent phases *for that version* but doesn't stop the matrix. Results land in `results/<run-id>/` and a `results/latest` symlink is updated.

### Choosing the TurboModuleTesting source

The matrix resolves the framework in this order:

1. `TURBO_MODULE_TESTING_SRC=<path>` — a local checkout (best for active framework development).
2. `TURBO_MODULE_TESTING_TAG=<tag>` — a GitHub tag (best for verifying a release).
3. `../TurboModuleTesting` sibling — automatic fallback when neither env var is set.

```sh
TURBO_MODULE_TESTING_TAG=v0.0.3 scripts/run-matrix.sh
```

## What's where

| Path | Purpose |
| --- | --- |
| `apps/<rn>/HostApp/` | Generated, committed host app per RN version. Lock files committed; `node_modules/`, `Pods/`, `vendor/bundle/` gitignored. |
| `RTNTestableModule/` | The C++ TurboModule under test. Vendored from `TurboModuleTestingExample/RTNTestableModule/`; owned by the matrix from that point. |
| `versions.json` | Authoritative list of supported RN versions. |
| `overlays/_shared/` | Files rsynced onto every freshly-init'd HostApp. `package.json.patch.json` is applied as a JSON Merge Patch. |
| `overlays/<rn>/` | Per-version overrides applied after the shared overlay. Create only when a version genuinely needs a difference. |
| `CMakeLists.txt`, `CMake/` | Per-version configure (driver invokes once per version with `-DEXAMPLE_APP_PATH=...`). |
| `scripts/generate.sh` | Generates or refreshes `apps/<rn>/HostApp/`. |
| `scripts/run-matrix.sh` | Drives every (or one) version through the phases and writes `results/<run-id>/`. |

## CI

The framework's [`pr.yml` workflow](../TurboModuleTesting/.github/workflows/pr.yml) checks out this repo and runs `scripts/run-matrix.sh` against the PR's framework checkout. One CI job per RN version (`strategy.matrix`), with caching keyed on the committed lock files.

## Requirements (local)

- macOS (the framework is macOS-only)
- **Ruby 3.2 or 3.3** — CocoaPods 1.15.2 (pinned via the RN-template `Gemfile`) uses `kconv`, which was removed from the stdlib in Ruby 3.4 / 4.0. CI pins Ruby 3.2 via `ruby/setup-ruby@v1`; for local runs use `brew install ruby@3.3` or `rbenv install 3.3.x`.
- Node 20+
- CMake 3.22+, Ninja
- Xcode + Command Line Tools
- `jq`, `rsync`

See [`PLAN.md`](./PLAN.md) for the full design rationale, open risks, and verification checklist.
