#!/usr/bin/env bash
# Build script for the MiuiCNInstallMiPay KernelSU/Magisk module.
#
# Usage:
#   bash build.sh                # build a dev zip (skips missing-APK checks)
#   bash build.sh release        # build and verify a release zip (requires all APKs)
#
# APK 提取流程：
#   1. 下载 K60 Ultra 国行卡刷包
#   2. 解出 payload.bin
#   3. 运行 bash scripts/extract_apks.sh <payload.bin>
#   4. 再运行 bash build.sh release
#
# Uses Python's zipfile module for cross-platform support (works on
# Windows Git Bash, macOS, and Linux; no `zip` binary required).

set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
MODULE_DIR="$ROOT/module"
OUT_DIR="$ROOT/out"
MODE="${1:-dev}"

if [ ! -f "$MODULE_DIR/module.prop" ]; then
  echo "ERROR: $MODULE_DIR/module.prop not found" >&2
  exit 1
fi

VERSION="$(grep '^version=' "$MODULE_DIR/module.prop" | cut -d= -f2)"
VERSION_CODE="$(grep '^versionCode=' "$MODULE_DIR/module.prop" | cut -d= -f2)"
ID="$(grep '^id=' "$MODULE_DIR/module.prop" | cut -d= -f2)"
OUT_NAME="${ID}.${VERSION}"
OUT_ZIP="$OUT_DIR/${OUT_NAME}.zip"

rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"

echo "==> Building $ID $VERSION (versionCode=$VERSION_CODE) [$MODE]"

# Pre-flight checks
for d in META-INF product product/app; do
  if [ ! -d "$MODULE_DIR/$d" ]; then
    echo "ERROR: missing $MODULE_DIR/$d" >&2
    exit 1
  fi
done

# For release builds: require all Pay-chain apps to have APKs
if [ "$MODE" = "release" ]; then
  for app in MIpay MipayService MINextpay MITSMClient \
             MiTrustService PaymentService MIUISecurityInputMethod \
             MIUISecurityAdd SecurityOnetrackService MIUIFrequentPhrase; do
    dir="$MODULE_DIR/product/app/$app"
    if [ ! -d "$dir" ]; then
      echo "ERROR: missing $dir" >&2
      echo "  → 请先运行: bash scripts/extract_apks.sh <payload.bin>" >&2
      exit 1
    fi
    if ! find "$dir" -maxdepth 1 -name '*.apk' -print -quit | grep -q .; then
      echo "ERROR: $dir has no APK. 请先运行 scripts/extract_apks.sh 提取。" >&2
      exit 1
    fi
  done
fi

# Find a Python interpreter (Windows py launcher, python3, or python)
PYTHON=""
if command -v py >/dev/null 2>&1; then
  PYTHON="py -3"
elif command -v python3 >/dev/null 2>&1 && python3 -c "import sys" >/dev/null 2>&1; then
  PYTHON="python3"
elif command -v python >/dev/null 2>&1 && python -c "import sys" >/dev/null 2>&1; then
  PYTHON="python"
else
  echo "ERROR: no working Python interpreter found. Install Python 3 or ensure 'py -3' is on PATH." >&2
  exit 1
fi

# Build the zip with Python
$PYTHON - "$MODULE_DIR" "$OUT_ZIP" <<'PY'
import os
import sys
import zipfile

src, out = sys.argv[1], sys.argv[2]
exclude_names = {".DS_Store", "placeholder"}
exclude_suffixes = (".gitkeep",)

count = 0
with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as zf:
    for root, dirs, files in os.walk(src):
        # Prune .git
        dirs[:] = [d for d in dirs if d != ".git"]
        for name in files:
            if name in exclude_names or name.endswith(exclude_suffixes):
                continue
            fp = os.path.join(root, name)
            arc = os.path.relpath(fp, src).replace(os.sep, "/")
            zf.write(fp, arc)
            count += 1
print(f"==> Packed {count} files into {out}")
PY

# Compute sha256
sha256sum "$OUT_ZIP" | tee "$OUT_DIR/${OUT_NAME}.zip.sha256"

echo ""
echo "==> Built:    $OUT_ZIP"
echo "==> SHA-256:  $(awk '{print $1}' "$OUT_DIR/${OUT_NAME}.zip.sha256")"
echo "==> Mode:     $MODE"
echo ""
echo "下一步："
echo "  - 把这个 zip 传到手机，通过 KernelSU App → 模块 → 从本地安装"
echo "  - 或推送 tag 触发 GitHub Actions 自动发布到 Releases"
