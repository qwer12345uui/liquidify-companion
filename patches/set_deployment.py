#!/usr/bin/env python3
"""Set IPHONEOS_DEPLOYMENT_TARGET for a single Xcode target inside a .pbxproj.

Usage: set_deployment.py <Project.xcodeproj/project.pbxproj> <TargetName> <version>

Only the build configurations belonging to <TargetName> are modified, so the
app can stay on an older deployment target than one of its extensions.
"""
import re
import sys

# Object IDs in pbxproj files are not fixed length (E5FP00040, AA8A568A2F6...).
OID = r"[0-9A-Za-z]+"


def main() -> int:
    if len(sys.argv) != 4:
        print(__doc__)
        return 2
    path, target, version = sys.argv[1], sys.argv[2], sys.argv[3]
    text = open(path, encoding="utf-8").read()

    # 1. locate the native target block
    tm = re.search(
        r"\b(" + OID + r")\s*/\*\s*" + re.escape(target) + r"\s*\*/\s*=\s*\{\s*"
        r"isa\s*=\s*PBXNativeTarget;(.*?)\n\t\t\};",
        text,
        re.S,
    )
    if not tm:
        print(f"target {target!r} not found")
        return 1
    lm = re.search(r"buildConfigurationList\s*=\s*(" + OID + r")", tm.group(2))
    if not lm:
        print(f"no buildConfigurationList for {target!r}")
        return 1
    list_id = lm.group(1)

    # 2. resolve the configuration list to its Debug/Release configs
    cl = re.search(
        r"\b" + re.escape(list_id) + r"\s*/\*[^=]*=\s*\{\s*isa\s*=\s*XCConfigurationList;"
        r"(.*?)\n\t\t\};",
        text,
        re.S,
    )
    if not cl:
        print("configuration list not found")
        return 1
    configs = re.findall(r"(" + OID + r")\s*/\*\s*(Debug|Release)\s*\*/", cl.group(1))
    if not configs:
        print("no Debug/Release configs in list")
        return 1

    # 3. rewrite the setting inside just those configuration blocks
    total = 0
    for cid, name in configs:
        block = re.compile(
            r"(\b" + re.escape(cid) + r"\s*/\*\s*" + name + r"\s*\*/\s*=\s*\{)(.*?)(\n\t\t\};)",
            re.S,
        )

        def repl(mo: re.Match) -> str:
            nonlocal total
            new, n = re.subn(
                r"IPHONEOS_DEPLOYMENT_TARGET = [^;]*;",
                f"IPHONEOS_DEPLOYMENT_TARGET = {version};",
                mo.group(2),
            )
            total += n
            return mo.group(1) + new + mo.group(3)

        text = block.sub(repl, text, count=1)

    open(path, "w", encoding="utf-8").write(text)
    print(f"set {target} -> {version} in {total} build configuration(s)")
    return 0 if total else 1


if __name__ == "__main__":
    sys.exit(main())
