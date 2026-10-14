#!/usr/bin/env bash
#
# 从小米国行卡刷包（payload.bin）里提取本模块需要的 10 个 Pay app。
#
# 用法:
#   1. 下载 K60 Ultra 国行稳定版卡刷包（miui_COROT_*.zip）
#   2. 解出 payload.bin
#   3. 运行本脚本：bash scripts/extract_apks.sh path/to/payload.bin
#
# 前置依赖: pip install payload-dumper
# EROFS 解包工具: bin/erofsUnpack.exe（来自 erofs2ext4Converter-for-MIUI-Device）
#

set -euo pipefail

if [ $# -ne 1 ]; then
  echo "用法: $0 <payload.bin>"
  echo "  例: $0 ~/Downloads/miui_COROT_3.0.5.0/payload.bin"
  exit 1
fi

PAYLOAD="$1"
PAYLOAD_DIR="$(dirname "$PAYLOAD")"
EXTRACT_DIR="${PAYLOAD_DIR}/_extracted_modules"
MODULE_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if [ ! -f "$PAYLOAD" ]; then
  echo "错误: 找不到 $PAYLOAD" >&2
  exit 1
fi

echo "==> [1/4] 检查依赖"
if ! py -3 -c "import payload_dumper" 2>/dev/null; then
  echo "  安装 payload-dumper..."
  py -3 -m pip install --quiet payload-dumper
fi
if [ ! -x "D:\coding\Mipay\erofs2ext4Converter-for-MIUI-Device-main\bin\erofsUnpack.exe" ] && [ ! -x "./bin/erofsUnpack.exe" ]; then
  echo "  警告: 找不到 erofsUnpack.exe（需要从 https://github.com/ljc-fight/erofs2ext4Converter-for-MIUI-Device 放到 ./bin/）"
fi

echo "==> [2/4] 用 payload-dumper 提取 system/product/system_ext/vendor 4 个分区"
mkdir -p "$EXTRACT_DIR"
py -3 -m payload_dumper "$PAYLOAD" --output "$EXTRACT_DIR" \
  --partitions system,product,system_ext,vendor 2>&1 | tail -3

echo "==> [3/4] 用 erofsUnpack 解 EROFS 镜像"
EROFSPACK="$MODULE_ROOT/bin/erofsUnpack.exe"
if [ ! -f "$EROFSPACK" ]; then
  EROFSPACK="D:\coding\Mipay\erofs2ext4Converter-for-MIUI-Device-main\bin\erofsUnpack.exe"
fi
if [ ! -f "$EROFSPACK" ]; then
  echo "  错误: 找不到 erofsUnpack.exe" >&2
  exit 1
fi
UNPACK_DIR="$EXTRACT_DIR/unpacked"
mkdir -p "$UNPACK_DIR"
for img in product system_ext system; do
  if [ -f "$EXTRACT_DIR/${img}.img" ]; then
    echo "  解 ${img}.img..."
    (cd "$UNPACK_DIR" && "$EROFSPACK" "$EXTRACT_DIR/${img}.img" >/dev/null 2>&1) || true
  fi
done

echo "==> [4/4] 复制 10 个 Pay app 到 module/product/app/"
declare -A APPS=(
  [MIpay]="product/data-app/MIpay"
  [MipayService]="product/app/MipayService"
  [MINextpay]="product/app/MINextpay"
  [MITSMClient]="product/app/MITSMClient"
  [MiTrustService]="product/app/MiTrustService"
  [PaymentService]="product/app/PaymentService"
  [MIUISecurityInputMethod]="product/app/MIUISecurityInputMethod"
  [MIUISecurityAdd]="product/app/MIUISecurityAdd"
  [SecurityOnetrackService]="product/app/SecurityOnetrackService"
  [MIUIFrequentPhrase]="product/app/MIUIFrequentPhrase"
)

SRC="$UNPACK_DIR"
for app in "${!APPS[@]}"; do
  src="$SRC/${APPS[$app]}"
  dst="$MODULE_ROOT/module/product/app/$app"
  if [ -d "$src" ]; then
    mkdir -p "$dst"
    cp -r "$src/." "$dst/"
    echo "  ✅ $app ← ${APPS[$app]}"
  else
    echo "  ❌ $app 找不到 $src（国行包可能版本太老或新）"
  fi
done

# MITSMClient.apk 需要特殊处理：删除 sharedUserId（避免 UID_CHANGED）
TSM_APK="$MODULE_ROOT/module/product/app/MITSMClient/MITSMClient.apk"
if [ -f "$TSM_APK" ] && [ -f "tools/apktool.jar" ]; then
  echo ""
  echo "==> [bonus] 处理 MITSMClient.apk（apktool 删 sharedUserId + 重签）"
  bash scripts/strip_tsm_shared_userid.sh "$TSM_APK"
fi

echo ""
echo "==> 完成！"
echo "  现在可以: bash build.sh release"
