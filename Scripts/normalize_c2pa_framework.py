#!/usr/bin/env python3
"""Align the embedded C2PA framework's deployment metadata with its Mach-O binary."""

import os
from pathlib import Path
import plistlib
import re
import subprocess


def minimum_os_version(executable: Path) -> str:
    result = subprocess.run(
        ["/usr/bin/xcrun", "vtool", "-show-build", str(executable)],
        check=True,
        capture_output=True,
        text=True,
    )
    versions = re.findall(r"^\s*minos\s+(\d+(?:\.\d+)*)\s*$", result.stdout, re.MULTILINE)

    if not versions:
        raise RuntimeError(f"Cannot determine the minimum OS version of {executable}")

    # A universal binary must advertise a minimum compatible with every architecture.
    return max(versions, key=lambda version: tuple(int(part) for part in version.split(".")))


def main() -> None:
    framework = Path(os.environ["TARGET_BUILD_DIR"]) / os.environ["FRAMEWORKS_FOLDER_PATH"] / "C2PAC.framework"

    if not framework.exists():
        return

    info_path = framework / "Info.plist"
    original_data = info_path.read_bytes()
    info = plistlib.loads(original_data)
    executable = framework / info["CFBundleExecutable"]
    minimum_version = minimum_os_version(executable)

    if info.get("MinimumOSVersion") == minimum_version:
        return

    signing_allowed = os.environ.get("CODE_SIGNING_ALLOWED", "YES") == "YES"
    identity = os.environ.get("EXPANDED_CODE_SIGN_IDENTITY", "")

    if signing_allowed and not identity:
        raise RuntimeError("A signing identity is required to update the embedded C2PA framework")

    # Xcode creates a stub executable when embedding this static framework. Its minimum
    # follows the app target, while the vendor's plist still declares iOS 16.0 (ITMS-90208).
    previous_version = info.get("MinimumOSVersion")
    info["MinimumOSVersion"] = minimum_version
    output_format = plistlib.FMT_BINARY if original_data.startswith(b"bplist") else plistlib.FMT_XML
    info_path.write_bytes(plistlib.dumps(info, fmt=output_format, sort_keys=False))

    # The framework was signed during embedding. Restore its signature after changing
    # metadata, before Xcode signs the enclosing app or exports the archive.
    if signing_allowed:
        subprocess.run(
            [
                "/usr/bin/codesign", "--force", "--sign", identity,
                "--preserve-metadata=identifier,entitlements,flags",
                "--timestamp=none", str(framework),
            ],
            check=True,
        )

    print(f"C2PAC MinimumOSVersion: {previous_version} -> {minimum_version}")


if __name__ == "__main__":
    main()
