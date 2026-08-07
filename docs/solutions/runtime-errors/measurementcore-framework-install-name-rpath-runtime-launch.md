---
title: "MeasurementCore framework install name caused dyld launch failure"
date: "2026-07-26"
category: "runtime-errors"
module: "iOS/ColorMatchingLPS.xcodeproj"
problem_type: "runtime_error"
component: "tooling"
symptoms:
  - "XcodeBuildMCP reported build-and-run success, but the app did not launch cleanly"
  - "Runtime logs showed dyld looking for MeasurementCore.framework at /Library/Frameworks/MeasurementCore.framework/MeasurementCore"
root_cause: "config_error"
resolution_type: "config_change"
severity: "high"
related_components:
  - "iOS simulator launch"
  - "local framework targets"
  - "dynamic linker runtime paths"
tags:
  - "xcode"
  - "dyld"
  - "frameworks"
  - "rpath"
  - "measurementcore"
  - "simulator-launch"
---

# MeasurementCore framework install name caused dyld launch failure

## Problem

The SwiftUI app built successfully and, in the observed session, XcodeBuildMCP appeared to report simulator build-and-run success, but the launched process failed at dyld time because a local framework had an absolute install name. The observed runtime log showed the loader looking for `MeasurementCore.framework` at `/Library/Frameworks/MeasurementCore.framework/MeasurementCore` instead of resolving it from the app bundle's embedded frameworks.

The evidence pointed to an install-name configuration issue for local dynamic framework targets in [project.pbxproj](../../../iOS/ColorMatchingLPS.xcodeproj/project.pbxproj), rather than SwiftUI app entry.

## Symptoms

- The observed runtime log contained a dyld launch failure for `MeasurementCore.framework`, with lookup at `/Library/Frameworks/MeasurementCore.framework/MeasurementCore`.
- The app target already embedded local frameworks, which made the failure misleading: `MeasurementCore.framework` and `ColorMatchingLPSAppCore.framework` are both present in the app target's Embed Frameworks phase in [project.pbxproj](../../../iOS/ColorMatchingLPS.xcodeproj/project.pbxproj).
- After the fix, the generated simulator binaries contained `@rpath` install names and load commands for the local frameworks.

## What Didn't Work

- Treating XcodeBuildMCP's build-and-run summary as sufficient did not catch the actual failure mode in the observed session. The build completed, but runtime logs still showed dyld failing before the app could launch normally.
- Focusing only on the app target's embed phase did not explain the problem. The framework was copied into the app bundle, but the dynamic library install name recorded inside the framework binary still pointed dyld at `/Library/Frameworks`.

## Solution

Set `DYLIB_INSTALL_NAME_BASE = "@rpath"` on the local framework targets in [project.pbxproj](../../../iOS/ColorMatchingLPS.xcodeproj/project.pbxproj).

For `MeasurementCore`, both Debug and Release set the install-name base to `@rpath`:

```text
DYLIB_INSTALL_NAME_BASE = "@rpath";
```

The current tree defines those settings in the `MeasurementCore` Debug and Release build configurations at [project.pbxproj](../../../iOS/ColorMatchingLPS.xcodeproj/project.pbxproj).

For `ColorMatchingLPSAppCore`, both Debug and Release also set the install-name base to `@rpath`:

```text
DYLIB_INSTALL_NAME_BASE = "@rpath";
```

The current tree defines those settings in the `ColorMatchingLPSAppCore` Debug and Release build configurations at [project.pbxproj](../../../iOS/ColorMatchingLPS.xcodeproj/project.pbxproj).

Then verify the generated binaries, not just the project file:

```bash
otool -D "$DERIVED_DATA/Build/Products/Debug-iphonesimulator/MeasurementCore.framework/MeasurementCore"
otool -D "$DERIVED_DATA/Build/Products/Debug-iphonesimulator/ColorMatchingLPSAppCore.framework/ColorMatchingLPSAppCore"
otool -L "$DERIVED_DATA/Build/Products/Debug-iphonesimulator/ColorMatchingLPS.app/ColorMatchingLPS"
```

The fixed simulator artifacts showed install names and load commands like:

```text
@rpath/MeasurementCore.framework/MeasurementCore
@rpath/ColorMatchingLPSAppCore.framework/ColorMatchingLPSAppCore
```

## Why This Works

For embedded iOS frameworks, dyld needs to resolve dependencies through the app's runtime search paths and the app bundle's `Frameworks` directory. `@rpath` install names let the loader combine a binary's runtime search paths with framework-relative paths such as `@rpath/MeasurementCore.framework/MeasurementCore`.

An absolute install name such as `/Library/Frameworks/MeasurementCore.framework/MeasurementCore` bypasses that embedded-framework lookup model. Even when the framework is copied into the app bundle, dyld follows the absolute path encoded in the binary and fails if that path does not exist on the simulator or device.

The app/framework settings support the `@rpath` model: the app target includes `@executable_path/Frameworks` in `LD_RUNPATH_SEARCH_PATHS`, and the `ColorMatchingLPSAppCore` framework target includes `@executable_path/Frameworks` and `@loader_path/Frameworks` in its runpath search paths in [project.pbxproj](../../../iOS/ColorMatchingLPS.xcodeproj/project.pbxproj). With local framework install names also based at `@rpath`, dyld can resolve the embedded copies instead of probing `/Library/Frameworks`.

## Prevention

- When adding or reconfiguring local dynamic framework targets in this project, confirm all configurations use `DYLIB_INSTALL_NAME_BASE = "@rpath"`.
- Do not rely on build success alone for launchability. For runtime-linker issues, check the actual binary metadata with `otool -D` and `otool -L`, then confirm launch through simulator and device when the change affects shared framework packaging.
- Keep the prevention scoped narrowly: this guards against local embedded framework install names being encoded as absolute `/Library/Frameworks/...` paths. It does not prove that every future simulator or device launch problem is fixed.

A focused regression check for this class of issue is:

```bash
otool -D "$BUILT_PRODUCTS_DIR/MeasurementCore.framework/MeasurementCore" | grep '@rpath/MeasurementCore.framework/MeasurementCore'
otool -D "$BUILT_PRODUCTS_DIR/ColorMatchingLPSAppCore.framework/ColorMatchingLPSAppCore" | grep '@rpath/ColorMatchingLPSAppCore.framework/ColorMatchingLPSAppCore'
otool -L "$BUILT_PRODUCTS_DIR/ColorMatchingLPS.app/ColorMatchingLPS" | grep '@rpath/MeasurementCore.framework/MeasurementCore'
```

## Related Issues

No existing `docs/solutions/` learning was found for this specific failure. The related pattern to search for in future is a launch failure where build-and-run appears successful but dyld logs show a local embedded framework being searched via `/Library/Frameworks/...` instead of an install name beginning with `@rpath`.
