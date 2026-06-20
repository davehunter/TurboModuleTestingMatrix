# Adding a React Native version to the matrix

This is the guide for adding a new RN version to the matrix — both the easy path (the new version "just works") and the harder one (RN changed something that requires a framework-side fix in `TurboModuleTesting` first).

The happy path is short. The not-happy path is where this document earns its keep — every RN minor we've added across the 0.80 → 0.86 range surfaced at least one regression that needed a coordinated framework + matrix change, and the patterns repeat.

## Prerequisites

- macOS — the framework is macOS-only.
- **Ruby 3.2 or 3.3.** CocoaPods 1.15.2 (pinned via the RN-template `Gemfile`) uses `kconv`, which was removed from the stdlib in Ruby 3.4. `brew install ruby@3.3` then prepend `/opt/homebrew/opt/ruby@3.3/bin` to your `PATH` for the local run. CI pins Ruby 3.2.
- Node 20+, CMake 3.22+, Ninja.
- `jq`, `rsync`, `gh` (for opening PRs).
- A local sibling checkout of `TurboModuleTesting` at `../TurboModuleTesting`. The matrix picks that up automatically as the framework source.

## The happy path

For a version that lies inside the range of RN we already support (currently 0.80.3 → 0.86.0), and where no RN-side breaking change has happened, the whole thing is one config edit.

1. **Add an entry to [`versions.json`](../versions.json).** Keep entries in ascending RN order — convention, not enforced.
   ```json
   {
     "rn": "0.84.3",
     "cli": "@react-native-community/cli@latest",
     "cliInitFlavor": "community",
     "node": ">=20",
     "ruby": "3.2",
     "notes": "Latest 0.84.x patch."
   }
   ```
   `cli` is whatever `npx <cli> init` should resolve to — `@latest` is fine for any reasonably recent RN; pin an explicit major (e.g. `@15`) only if `@latest` won't init that version.

2. **Validate locally — `run-matrix.sh` auto-generates the missing app.**
   ```sh
   PATH=/opt/homebrew/opt/ruby@3.3/bin:$PATH ./scripts/run-matrix.sh 0.84.3
   ```
   The `generate` phase runs first (it's the first column in the summary), invoking `scripts/generate.sh` under the hood. That runs `npx <cli> init` into `_generated/<rn>/HostApp/`, layers [`overlays/_shared/`](../overlays/_shared/) (and any per-version overrides under `overlays/<rn>/`), runs `npm install`, `bundle install`, and `bundle exec pod install`. Pod install triggers RN's codegen as part of `prepare_react_native_project!`, so by the time it returns there's a `NativeRTNTestableModuleJSI.h` under `ios/build/generated/ios/.../`. Subsequent phases (`npm-install` → `pod-install` → `codegen-check` → `cmake-configure` → `cmake-build` → `ctest`) then run against the materialized app.

   On a re-run with `_generated/<rn>/HostApp/` already on disk, the `generate` phase reports `skipped` and the rest runs against the existing tree. To force a clean regeneration: `rm -rf _generated/<rn>/HostApp` and re-run.

3. **Commit and PR.**
   ```sh
   git checkout -b add-rn-0.84.3
   git add versions.json
   git commit -m "Add RN 0.84.3 to the matrix"
   git push -u origin add-rn-0.84.3
   gh pr create
   ```
   Only `versions.json` changes — `_generated/` is not committed.

CI runs the same `scripts/run-matrix.sh` against `TurboModuleTesting@main` and a fresh macOS runner — one job per RN version in `versions.json`. Because nothing is committed under `_generated/`, the first CI run generates each app from scratch (~5–7 min per axis dominated by `pod install`). The strategy.matrix fan-out makes that real-time per RN version.

## When the happy path doesn't happen

Every RN minor we've added so far has tripped on at least one of these. The pattern is consistent enough that a single failed phase usually tells you which family of fix you need.

### `pod install` fails with "Unable to find a specification for X"

The vendored [`RTNTestableModule.podspec`](../RTNTestableModule/RTNTestableModule.podspec) lists `s.dependency "X"` and `X` doesn't exist as a pod in the new RN.

What's happened across versions so far:
- RN 0.84 consolidated `RCT-Folly`, `glog`, `boost`, `fmt`, `DoubleConversion`, `fast_float` into a single umbrella pod called `ReactNativeDependencies`. It also removed `React-Codegen` (the generated code now lives inside that umbrella).
- The podspec handles this with a runtime version check:
  ```ruby
  rn_minor = rn_version.split(".")[1].to_i
  if rn_minor >= 84
    s.dependency "ReactNativeDependencies"
  else
    s.dependency "React-Codegen"
    s.dependency "RCT-Folly"
  end
  ```

If a new RN version splits, removes, or renames a pod that we depend on, edit the podspec's `if` block to emit the right name for that version range. Include the podspec edit in the same PR as the version add — that's a single coherent change.

### `cmake-configure` fails with "include could not find requested file"

The framework's `cmake/TurboModuleHelpers.cmake` `include`s files from `node_modules/react-native/ReactCommon/cmake-utils/`. The structure of that tree has changed across versions:
- `cmake-utils/internal/react-native-platform-selector.cmake` was added in 0.81 (it didn't exist in 0.80).
- `cmake-utils/react-native-flags.cmake` has been there since 0.80.

The framework already wraps the platform-selector include in `if(EXISTS …)`. If a future include path drifts, **add the same existence-checked include pattern in the framework**.

### `cmake-configure` fails with "CMake can not determine linker language for target X"

An RN `OBJECT` library has no `.cpp` sources to infer a linker language from. This happened with `runtimeexecutor` on RN 0.80 (header-only at that time). The framework fix is one line after the `add_subdirectory`:
```cmake
if(TARGET runtimeexecutor)
  set_target_properties(runtimeexecutor PROPERTIES LINKER_LANGUAGE CXX)
endif()
```
A no-op for RN versions that have actual `.cpp` files.

### `cmake-build` fails with `'fbjni/fbjni.h' file not found` or `pthread_setname_np` errors

An RN target is compiling `platform/android/*.cpp` on macOS. RN 0.81 introduced `react_native_android_selector(...)` to gate those globs; pre-0.81 versions hard-code the android sources. The framework strips them for RN < 0.81:
```cmake
if(TMT_RN_VERSION_MINOR LESS 81)
  foreach(_tgt IN LISTS RN_TARGETS)
    if(TARGET ${_tgt})
      get_target_property(_srcs ${_tgt} SOURCES)
      list(FILTER _srcs EXCLUDE REGEX "platform/android/.*\\.cpp$")
      set_target_properties(${_tgt} PROPERTIES SOURCES "${_srcs}")
    endif()
  endforeach()
endif()
```
If a newer RN version introduces a similar leak (some other platform path gets hard-coded), extend the same pattern.

### `cmake-build` fails with `error: 'X' is deprecated` and `-Werror`

RN deprecated an API and the framework still uses it. This happened with `TurboModuleBinding::install`'s signature change in RN 0.84.

Two-step fix in the framework:
1. `cmake/TurboModuleHelpers.cmake` extracts `TMT_RN_VERSION_MINOR` from the host app's `node_modules/react-native/package.json` and publishes it as a compile definition on the `TurboModuleTesting` target.
2. The framework C++ (e.g. `cpp/TurboModuleTestingEnvironment.h`) uses `#if defined(TMT_RN_VERSION_MINOR) && TMT_RN_VERSION_MINOR >= 84` to pick the new API and falls back to the old one for older RN.

### `cmake-build` fails at link with `library 'X' not found`

An RN target's `target_link_libraries` references an android-only library (`fbjni`, `reactnativejni`, `log`). The framework already provides INTERFACE-library stubs for these. If a new RN version adds a new android-only link dep, add it to the stub list in `cmake/TurboModuleHelpers.cmake`:
```cmake
foreach(rn_stub_lib IN ITEMS folly_runtime glog glog_init boost jsi
                             fbjni reactnativejni log
                             new_android_only_lib)
  if(NOT TARGET ${rn_stub_lib})
    add_library(${rn_stub_lib} INTERFACE)
  endif()
endforeach()
```

### Codegen header not found after pod install

If the codegen check fails ("codegen header `NativeRTNTestableModuleJSI.h` not found at either…"), RN has moved the generated-code root. The framework currently looks at two locations:
- `ios/build/generated/ios/ReactCodegen/` (RN 0.84+)
- `ios/build/generated/ios/` (RN 0.80 – 0.83)

If a future RN moves it again, add the new path to the existence-check fallback in `cmake/TurboModuleHelpers.cmake`, and also to the codegen sanity check in `scripts/generate.sh`.

## When a framework-side change is needed

A matrix PR that needs a framework change is a two-PR dance:

1. **Open the framework PR first** on `TurboModuleTesting` with the CMake / C++ change. Verify locally against every existing matrix version (run `./scripts/run-matrix.sh` from the matrix root with `TURBO_MODULE_TESTING_SRC` pointing at the framework branch). The point of the matrix is to catch regressions in the framework; PRs that change the framework's CMake or C++ surface should pass for **every** tracked RN version, not just the new one. The framework's PR workflow exercises that automatically.

2. **Open the matrix PR second**, referencing the framework PR. Its CI will be red on the new axis until the framework PR merges and you re-trigger (push an empty commit, or close-and-reopen).

3. **Merge order: framework first, matrix second.** Reverse the order and the matrix's CI on `main` will start failing for the new version's axis the moment its PR lands.

## Verifying a release range locally

When in doubt or before merging the matrix PR, run the whole matrix end-to-end:
```sh
rm -rf build/
PATH=/opt/homebrew/opt/ruby@3.3/bin:$PATH ./scripts/run-matrix.sh
```
The build dir reset forces a clean configure for every version — useful because CMake caches are version-specific and a successful incremental build doesn't always mean a successful clean build.

`results/latest/summary.txt` is the table you want — overall pass means you're done.

## Failure-pattern quick reference

| Failing phase | Likely cause | Where to fix |
|---|---|---|
| `pod-install` `Unable to find specification` | RN consolidated/renamed/removed a pod | `RTNTestableModule/RTNTestableModule.podspec` (matrix) |
| `codegen-check` | RN changed the generated-code root path | `cmake/TurboModuleHelpers.cmake` + `scripts/generate.sh` (framework + matrix) |
| `cmake-configure` `include could not find` | RN moved or removed a CMake helper file | `cmake/TurboModuleHelpers.cmake` (framework) |
| `cmake-configure` `can not determine linker language` | RN-side OBJECT lib became header-only | `cmake/TurboModuleHelpers.cmake` (framework) |
| `cmake-build` missing fbjni header / pthread signature | Android-only source compiling on macOS | `cmake/TurboModuleHelpers.cmake` (framework) — strip pattern |
| `cmake-build` `'X' is deprecated -Werror` | RN deprecated an API the framework calls | Framework C++ + `TMT_RN_VERSION_MINOR` macro |
| `cmake-build` `library 'X' not found` | Android-only link dep | `cmake/TurboModuleHelpers.cmake` (framework) — INTERFACE stub |
| `ctest` fails | A real regression in the framework or the test module | The actual test output in `results/<run>/<rn>/logs/ctest.log` |

The framework is the right place for almost every fix that's not "a pod was renamed". Anything that needs to be conditional on the consuming app's RN version uses the `TMT_RN_VERSION_MAJOR/MINOR/PATCH` compile defs (C++) or the `TMT_RN_VERSION_MINOR` CMake variable (CMake).
