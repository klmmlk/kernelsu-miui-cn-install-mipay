##########################################################################################
#
# KernelSU / Magisk Module Installer Script
#
# 为 MIUI EU / 国际版 HyperOS 安装国行小米钱包组件。
#
# 注意：本模块对应的是 K60 Ultra 国行包里的 Pay 应用，
# 这些应用在 ROM 里的路径是 /product/app/（动态分区），而不是 /system/app/。
#
# 关键点：com.miui.tsmclient 在国际版里已预装为 MITSMClientGlobal.apk
# （小文件 2MB，没有 ContentProvider "com.miui.tsmclient.provider.feature"）。
# 国行版的同包 APK 是 31MB 带这个 ContentProvider。
# 我们用 mount bind 在开机早期覆盖国际版，让 PackageManager 扫描到国行版。
#
##########################################################################################

# 跳过默认解压流程，改为手动控制
SKIPUNZIP=1

# 使用独立 ash
ASH_STANDALONE=1

##########################################################################################
# Replace list
##########################################################################################

REPLACE="
/product/app/MIpay
/product/app/MipayService
/product/app/MINextpay
/product/app/MITSMClient
"

##########################################################################################
# Install
##########################################################################################

ui_print "- 解压模块文件..."
unzip -o "$ZIPFILE" -x 'META-INF/*' -d "$MODPATH" >&2

ui_print "- 检查 Android 版本（API=$API）..."
case $API in
  30|31|33|34|35|36) ;;
  *) abort "不支持的 Android 版本（API=$API）。本模块仅支持 API 30/31/33/34/35/36（Android 11-16）。";;
esac

# 关键步骤：用 mount bind 覆盖国际版的 MITSMClientGlobal.apk 为国行版
# 必须放在前面，因为这是 install 阶段最后一次能改文件系统映射的机会
ui_print "- 覆盖国际版 MITSMClientGlobal.apk..."
if [ -f "$MODPATH/product/app/MITSMClient/MITSMClient.apk" ] && [ -f /product/app/MITSMClientGlobal/MITSMClientGlobal.apk ]; then
  mount --bind "$MODPATH/product/app/MITSMClient/MITSMClient.apk" /product/app/MITSMClientGlobal/MITSMClientGlobal.apk
  if [ $? -eq 0 ]; then
    ui_print "  - mount bind 成功"
  else
    ui_print "  - mount bind 失败（可能 selinux 或只读限制）"
  fi
fi

# 验证 4 个 Pay 应用都已就位
ui_print "- 验证 Pay 应用..."
for app in MIpay MipayService MINextpay MITSMClient; do
  if [ ! -d "$MODPATH/product/app/$app" ]; then
    abort "缺失目录：$MODPATH/product/app/$app"
  fi
  if ! find "$MODPATH/product/app/$app" -maxdepth 1 -name '*.apk' -print -quit | grep -q .; then
    abort "缺失 APK：$MODPATH/product/app/$app"
  fi
  ui_print "  - $app OK"
done

# 注入安全元件相关 system property
ui_print "- 注入安全元件属性..."
{
  echo ""
  echo "# Enable Secure Element for MiPay / 公交卡 / 门禁卡"
  echo "ro.se.type=eSE,HCE,UICC"
  echo "persist.sys.nfc_unlock=1"
} >> "$MODPATH/system.prop"

# 清理包管理器缓存
ui_print "- 清理包管理器缓存..."
rm -rf /data/system/package_cache/* 2>/dev/null

# 删除开发/构建残留
ui_print "- 清理构建残留..."
rm -rf \
  "$MODPATH/system/placeholder" \
  "$MODPATH/customize.sh" \
  "$MODPATH/README.md" \
  "$MODPATH/.git"* \
  "$MODPATH/LICENSE" \
  "$MODPATH/tools" 2>/dev/null

# 应用默认权限
ui_print "- 设置文件权限..."
set_perm_recursive "$MODPATH" 0 0 0755 0644
set_perm_recursive "$MODPATH/product/app" 0 0 0755 0644

ui_print "- 安装完成！重启后生效。"
ui_print "- 重要：首次重启后钱包 App 需要先在「我的」页面等几秒加载 TSM 服务"
