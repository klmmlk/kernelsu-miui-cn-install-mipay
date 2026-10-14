#!/usr/bin/env bash
#
# 用 apktool 删 MITSMClient.apk 的 android:sharedUserId="android.uid.nfc"
# 然后重新打包 + zipalign + apksigner 签名
#
# 为什么不直接装原版：国行版声明了 sharedUserId，系统会拒绝（UID_CHANGED）
#

set -euo pipefail

INPUT_APK="${1:-module/product/app/MITSMClient/MITSMClient.apk}"
WORK="$MODULE_ROOT/workdir"
MODULE_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$MODULE_ROOT/workdir"
APKTOOL="$MODULE_ROOT/tools/apktool.jar"
JAVA="${JAVA_HOME:-$(command -v java 2>/dev/null || echo /c/Program\ Files/Microsoft/jdk-17.0.13.11-hotspot/bin/java.exe)}"
ZIPALIGN="D:\AndroidSDK\build-tools\36.0.0\zipalign.exe"
APKSIGNER="D:\AndroidSDK\build-tools\36.0.0\apksigner.bat"

if [ ! -f "$INPUT_APK" ]; then
  echo "错误: 找不到 $INPUT_APK" >&2
  exit 1
fi

if [ ! -f "$APKTOOL" ]; then
  echo "错误: 找不到 $APKTOOL" >&2
  exit 1
fi

echo "==> [1/4] apktool 解包"
mkdir -p "$WORK"
rm -rf "$WORK/tsm"
"$JAVA" -jar "$APKTOOL" d -f -o "$WORK/tsm" "$INPUT_APK" 2>&1 | tail -2

echo "==> [2/4] 删 android:sharedUserId 属性"
# 只删 manifest 第一行的 android:sharedUserId="android.uid.nfc"
# 整个 manifest tag 在第一行（apktool 输出的格式）
sed -i 's/ android:sharedUserId="android.uid.nfc"//' "$WORK/tsm/AndroidManifest.xml"

echo "==> [3/4] apktool 重新打包"
"$JAVA" -jar "$APKTOOL" b "$WORK/tsm" -o "$WORK/MITSMClient-noshared.apk" 2>&1 | tail -2

echo "==> [4/4] zipalign + apksigner"
if [ -f "$ZIPALIGN" ]; then
  "$ZIPALIGN" -f -p 4 "$WORK/MITSMClient-noshared.apk" "$WORK/MITSMClient-aligned.apk" 2>&1
else
  echo "  警告: 找不到 zipalign，跳过"
  cp "$WORK/MITSMClient-noshared.apk" "$WORK/MITSMClient-aligned.apk"
fi
if [ -f "$APKSIGNER" ]; then
  "$APKSIGNER" sign --ks ~/.android/debug.keystore --ks-pass pass:android \
    --ks-key-alias androiddebugkey "$WORK/MITSMClient-aligned.apk" 2>&1
else
  echo "  警告: 找不到 apksigner，跳过签名"
fi

cp "$WORK/MITSMClient-aligned.apk" "$INPUT_APK"
echo "  ✅ $INPUT_APK 已替换为去 sharedUserId + 重签的版本"
