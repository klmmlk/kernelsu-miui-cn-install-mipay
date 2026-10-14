# This script will be executed during uninstallation.
# 清理包管理器缓存，避免残留的旧签名被命中。
rm -rf /data/system/package_cache/* 2>/dev/null
