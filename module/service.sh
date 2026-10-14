#!/system/bin/sh
# Do NOT assume where your module will be located.
# ALWAYS use $MODDIR if you need to know where this script
# and module is placed. This will make sure your module will still work
# if KernelSU / Magisk change its mount point in the future.
MODDIR=${0%/*}

# This script runs in late_start service mode (after boot).
#
# 任务：解决 Android 16 + KernelSU 3.x + 动态分区的两个关键问题：
#   1. 模块的 product/ 不会被 KernelSU 自动 mount 到 /product/app/
#   2. 即使通过 pm install 装上了，包也可能因依赖问题被 disabled
#
# 所以我们手动：
#   a) 用 pm install 把每个 APK 装成普通 user app
#   b) 启用所有 Pay 相关包
#   c) 启动 MipayService 服务（不启动的话钱包 App 不显示公交卡/门禁卡）
#   d) 触发桌面 launcher 重扫

# 等待系统就绪
i=0
while [ "$i" -lt 90 ]; do
  if [ "$(getprop sys.boot_completed)" = "1" ]; then
    break
  fi
  sleep 2
  i=$((i + 1))
done
sleep 5

log() {
  echo "miui_cn_install_mipay: $*" >> /dev/kmsg 2>/dev/null
}

log "service started"

PMROOT="$MODDIR/product/app"

# 真实包名映射（从各 APK 的 AndroidManifest 中解析得到）：
#   MipayService.apk   → org.mipay.android.manager
#   MIpay.apk          → com.mipay.wallet
#   MINextpay.apk      → com.miui.nextpay
#   MITSMClient.apk    → com.miui.tsmclient

install_one() {
  local label="$1"
  local apk_path="$2"
  local pkg="$3"

  if [ ! -f "$apk_path" ]; then
    log "$label: APK not found at $apk_path"
    return 1
  fi

  # 已启用就跳过
  if dumpsys package "$pkg" 2>/dev/null | grep -qE "User 0:.*enabled=1"; then
    log "$label ($pkg): already enabled"
    return 0
  fi

  log "$label: installing $apk_path"
  # 后台安装避免卡住
  pm install -r -t -d "$apk_path" >/dev/null 2>&1 &
  local pid=$!
  local waited=0
  while kill -0 "$pid" 2>/dev/null && [ "$waited" -lt 90 ]; do
    sleep 2
    waited=$((waited + 2))
  done
  if kill -0 "$pid" 2>/dev/null; then
    log "$label: pm install timed out"
    kill -9 "$pid" 2>/dev/null
    return 1
  fi

  # 启用
  pm enable "$pkg" >/dev/null 2>&1
  if dumpsys package "$pkg" 2>/dev/null | grep -qE "User 0:.*enabled=1"; then
    log "$label: installed and enabled"
    return 0
  fi
  return 1
}

# 按依赖顺序安装：底层服务先
install_one "MipayService"  "$PMROOT/MipayService/MipayService.apk" "org.mipay.android.manager"
install_one "MITSMClient"   "$PMROOT/MITSMClient/MITSMClient.apk"   "com.miui.tsmclient"
install_one "MINextpay"     "$PMROOT/MINextpay/MINextpay.apk"       "com.miui.nextpay"
install_one "MIpay"         "$PMROOT/MIpay/MIpay.apk"               "com.mipay.wallet"

# 关键步骤：启动 MipayService 子服务
# 不启动这个的话，钱包 App 里"钱包"页不显示公交卡/门禁卡入口
log "starting MipayService"
am start-service -n org.mipay.android.manager/org.mipay.android.manager.MipayService >/dev/null 2>&1
sleep 3

# 触发桌面 launcher 重扫
log "refreshing launcher"
am force-stop com.miui.home >/dev/null 2>&1
am start -n com.miui.home/com.miui.home.launcher.Launcher >/dev/null 2>&1

# 清理缓存让 App 重新扫描
pm trim-caches 9999999999999999 >/dev/null 2>&1

log "service done"
