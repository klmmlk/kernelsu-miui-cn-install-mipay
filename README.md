# kernelsu-miui-cn-install-mipay

一个 **KernelSU / Magisk 模块**，在小米/红米**国际版**（MIUI EU / HyperOS Global）上**安装国行小米钱包**的完整组件链，让钱包 App 显示出**交通卡、门卡·钥匙、Mi Pay、车钥匙**等国际版没有的入口。

> ⚠️ **重要结论**：本模块在小米 13T（Android 16 + HyperOS 3.0.5.0）上**完整跑通了**——钱包 App 装上、TSM 服务跑起来、eSE 路由配置正确、4 个国行入口**全部显示**。但**点开后服务端拒绝**（`errorCode: 1090001 syncEse 失败`）。这是小米服务端策略问题，**模块无法解决**——只有刷国行 ROM 才能真正用上公交卡/门禁卡。

---

## 项目目标

让 MIUI EU / HyperOS Global（国际版）的**小米 13T**（也适用于 K60 Ultra 等同款硬件机型）能：

| 功能 | 国际版 | 装本模块后 |
|---|---|---|
| 钱包 App 登录国行账号 | ❌ 无 App | ✅ 可以 |
| 借钱、外卖红包、福利中心、车主服务 | ❌ | ✅ 可用 |
| 主页显示"交通卡""门卡·钥匙""Mi Pay""车钥匙"入口 | ❌ 全无 | ✅ **全部显示** |
| 点击交通卡→开京津冀互联互通卡 | ❌ | ❌ 服务端拒绝（1090001）|
| 复制/创建门禁卡 | ❌ | ❌ 服务端拒绝（1090001）|

---

## 硬件要求

- **小米 13T** (aristotle)、**红米 K60 Ultra** (corot) 或同款硬件（Dimensity 9200+）
- 任意系统：**HyperOS 3.0.5.0 + Android 16**（API 36）测试通过
- 已 root：**KernelSU 3.3.1**（也兼容 Magisk 24+）
- 至少 **1.5GB** 模块空间（137MB zip 装好后约 250MB）

---

## 文件来源

所有 APK 都从**红米 K60 Ultra 国行稳定版**（`miui_COROT_3.0.x.x_xxx_xxx.zip`）的 `payload.bin` 提取：

| APK | 来源 | 真实包名 | versionCode |
|---|---|---|---|
| MIpay.apk | `product/data-app/MIpay/` | `com.mipay.wallet` | 20577659 |
| MipayService.apk | `product/app/MipayService/` | `org.mipay.android.manager` | 221024 |
| MINextpay.apk | `product/app/MINextpay/` | `com.miui.nextpay` | 1870 |
| MITSMClient.apk | `product/app/MITSMClient/` | `com.miui.tsmclient` | 1950 |
| MiTrustService.apk | `product/app/MiTrustService/` | `com.xiaomi.trustservice` | 12260710 |
| PaymentService.apk | `product/app/PaymentService/` | `com.xiaomi.payment` | 2003069 |
| MIUISecurityInputMethod.apk | `product/app/MIUISecurityInputMethod/` | `com.miui.securityinputmethod` | 389 |
| MIUISecurityAdd.apk | `product/app/MIUISecurityAdd/` | `com.miui.securityadd` | 91209 |
| SecurityOnetrackService.apk | `product/app/SecurityOnetrackService/` | `com.xiaomi.security.onetrack` | 250813 |
| MIUIFrequentPhrase.apk | `product/app/MIUIFrequentPhrase/` | `com.miui.phrase` | 10180 |

> ⚠️ **不要从任何渠道直接分发这些 APK**——它们是小米公司的财产。模块仅供个人学习研究，下载/使用前请确认你所在司法管辖区允许此类用途。

---

## 安装

### 1. 准备 KernelSU / Magisk

确认已 root 并安装 KernelSU（或 Magisk 24+）。

### 2. 通过 KernelSU App 安装

1. 下载最新 release 的 zip：`cc.klmmlk.MiuiCNInstallMiPay.vX.Y.Z.zip`
2. KernelSU App → 模块 → 从本地安装 → 选择 zip
3. 等待安装完成，**重启手机**
4. 重启后桌面会多出"钱包" App（com.mipay.wallet）

### 3. 验证

```bash
# 钱包 App 是否装上
adb shell su -c "cmd package list packages | grep com.mipay.wallet"

# 是否 enabled（如果不是，手动 enable）
adb shell su -c "dumpsys package com.mipay.wallet | grep enabled="

# TSM 客户端是否被识别为国行版
adb shell su -c "dumpsys package com.miui.tsmclient | grep versionCode"
# 期待: versionCode=1950 (国行版)
# 如果还是 1738 = 国际版没替换成功
```

---

## 完整链路：模块做了什么

模块由 `customize.sh`（install 阶段）+ `service.sh`（late_start 阶段）组成，**两个关键动作**：

### 1. `customize.sh` 里做 `mount --bind`（**最关键**）

```bash
mount --bind $MODPATH/product/app/MITSMClient/MITSMClient.apk \
              /product/app/MITSMClientGlobal/MITSMClientGlobal.apk
```

为什么需要这一步：
- 国际版预装 `com.miui.tsmclient` 在 `/product/app/MITSMClientGlobal/`（**只有 2MB**，**没有** `com.miui.tsmclient.provider.feature` ContentProvider）
- 国行版同名 APK（**31.5MB**）才有这个 ContentProvider——它告诉钱包 App "TSM 客户端可用"
- 不替换的话，钱包 App 一调 TSM 就报"ContentProvider 找不到"，**直接隐藏**公交卡/门禁卡入口
- 替换后，国际版 tsmclient 的 ContentProvider 列表里多了 `com.miui.tsmclient.provider.feature`，钱包 App 看到它就显示入口

### 2. `service.sh` 自动安装 10 个 Pay app 并启用

```
org.mipay.android.manager/.MipayService  ← TSM 服务的 binder
com.miui.nextpay                          ← 下个支付
com.miui.tsmclient                        ← TSM 客户端（虽然 mount bind 改了 APK，但 PackageManager 不知道，要装一遍）
com.xiaomi.trustservice                   ← **设备信任评估**（关键）
com.xiaomi.payment                        ← 支付框架
com.miui.securityinputmethod              ← 安全输入键盘
com.miui.securityadd                      ← 安全插件
com.xiaomi.security.onetrack               ← 安全追踪
com.miui.phrase                            ← 词库
com.mipay.wallet                          ← 钱包主 App
```

---

## 完整链路：遇到并解决的技术障碍

为了不让你/未来的你重复踩坑，记录所有坑。

### 坑 1：EROFS 文件系统不能直接读

K60 Ultra 国行包 `system.img` 是 **EROFS**（Linux 5.x+ 的只读压缩 FS），不是 ext4。

**解决**：用 `ljc-fight/erofs2ext4Converter-for-MIUI-Device` 仓库的 `bin/erofsUnpack.exe`：

```bash
# 解出 system.img → 目录树
bin/erofsUnpack.exe system.img
# 输出 system/ 目录，含 system/app/、system/priv-app/、product/app/...
```

### 坑 2：pay apps 在 `product/app/` 不是 `system/app/`

MIUI 13 时代所有 Pay app 都在 `system/app/`。Android 12+ 引入 dynamic partitions 后，Pay app 移到了 **`product/app/`**（独立动态分区）。

**解决**：模块结构改为 `module/product/app/*`，让 Magisk/KernelSU 把文件挂到 `/product/app/*`。

### 坑 3：KernelSU 3.x 不自动 magic-mount `product` 分区

KernelSU 3.3.1 的 magic-mount 对 `system/` 工作正常，但对 `product/`、`vendor/` 等动态分区不工作（`mount | grep` 里看不到 KSU mount）。

**解决**：放弃 magic-mount 路径，改用 `pm install` 把所有 APK 装成普通 user app。

### 坑 4：`MipayService.apk` 包名不是 `com.miui.mipayservice`

MIUI 13 时代叫 `com.miui.mipayservice`，HyperOS 改成了 **`org.mipay.android.manager`**。

**解决**：用 `androguard` 读 APK manifest 拿真实包名，不要猜：

```python
from androguard.core.apk import APK
ap = APK('MipayService.apk')
print(ap.get_package())  # 'org.mipay.android.manager'
```

### 坑 5：4 个 Pay app 装上后都 `enabled=0`（disabled）

PackageManager 检测到 APK 签名/版本/依赖异常，**默认禁用**所有 Pay app。

**解决**：`pm enable <pkg>` 一个个手动启用。`service.sh` 里自动做。

### 坑 6：钱包 App 找不到 TSM ContentProvider，公交卡入口消失

Logcat 关键错误：

```
E TSMClient: TSM_FeatureManager: check tsm client type errorUnknown authority com.miui.tsmclient.provider.feature
WALLET_LOG-Tsm: canOpenNfcTrafficCard : false
WALLET_LOG-Tsm: canOpenNfcBankCard : false
```

**原因**：国行版 tsmclient 才有 `com.miui.tsmclient.provider.feature` 这个 ContentProvider（提供"TSM 客户端类型"信息给钱包 App）。国际版没有这个 provider，钱包 App 就以为没 TSM 客户端，**直接隐藏所有公交卡/门禁卡/银联云闪付入口**。

**解决**：`mount --bind` 把国行 APK 覆盖到 `/product/app/MITSMClientGlobal/MITSMClientGlobal.apk`（mount 在 `customize.sh` 跑，早于 PackageManager 首次扫描）。重启后 PackageManager 启动时读到的是国行版 APK，**ContentProvider 出现**。

### 坑 7：`pm install` 国行 tsmclient 报 `INSTALL_FAILED_UID_CHANGED`

```
INSTALL_FAILED_UID_CHANGED: Package com.miui.tsmclient shared user changed from <nothing> to android.uid.nfc
```

**原因**：国行版 tsmclient 声明了 `sharedUserId="android.uid.nfc"`，国际版没有。PackageManager 拒绝共享用户 ID 变化。

**解决**：用 apktool 解包国行 APK，删 manifest 里的 `sharedUserId` 属性，重新打包签名：

```bash
apktool d MITSMClient.apk -o workdir/mitm
sed -i 's/ android:sharedUserId="android.uid.nfc"//' workdir/mitm/AndroidManifest.xml
apktool b workdir/mitm -o MITSMClient-noshared.apk
zipalign -f -p 4 MITSMClient-noshared.apk MITSMClient-aligned.apk
apksigner sign --ks ~/.android/debug.keystore --ks-pass pass:android \
        --ks-key-alias androiddebugkey MITSMClient-aligned.apk
```

### 坑 8：`pm install` 报 `INSTALL_FAILED_UPDATE_INCOMPATIBLE`（签名不匹配）

```
INSTALL_FAILED_UPDATE_INCOMPATIBLE: Existing package com.miui.tsmclient signatures do not match newer version
```

**原因**：debug key 签名 ≠ 系统原本的 Xiaomi key 签名。PackageManager 把我们当作 update，签名校验失败。

**解决**：`pm uninstall --user 0 com.miui.tsmclient`（之前会失败 DELETE_FAILED_INTERNAL_ERROR，**指定 --user 0** 就成功）：

```bash
pm uninstall --user 0 com.miui.tsmclient  # Success
pm install -r -t -d /data/local/tmp/MITSMClient-aligned.apk  # Success
```

### 坑 9：`adb push` 在 Git Bash 下报 `secure_mkdirs failed`

Git Bash 调 adb.exe 时路径解析错乱（`C:/Program Files/Git/data/local/tmp/...`），但 adb 客户端显示推送"成功"实际上没传上去。

**解决**：用 **PowerShell** 调 adb push，绕开 Git Bash 路径解析 bug：

```powershell
& adb.exe -s <device> push <local> /data/local/tmp/<name>
```

### 坑 10：`svc prop` 写错

`system.prop` 里写的是 `ro.se.type=eSE,HCE,UICC`，但 0xclover 的参考文档（[0xclover.com](https://0xclover.com/2023/05/miui-wallet-in-global-roms/)）说要写 **`ro.vendor.se.type=HCE,UICC,eSE`**。

**解决**：两个都写，更保险。

### 坑 11：安装到 `/data/app/` 的 tsmclient 没 privileged 权限，ContentProvider 不注册

如果只把 4 个 Pay app 装到 `/data/app/`，tsmclient 的 ContentProvider **不会注册**——因为它的 `provider.feature` 用了 `signature|privileged` 权限保护。

**解决**：mount bind 后让 PackageManager 重新从 `/product/app/` 扫描到国行 tsmclient，作为 system app 注册。**这才是 mount bind 真正起的作用**。

### 坑 12：TSM 后端返回 `errorCode: 1090001 syncEse 失败`

装完所有 10 个 Pay app 后，**整条链路打通了**——钱包 App 能正常调到 TSM 后端，但服务端返回 `errorCode: 1090001`。

```
D TSMClient: syncEse result:1090001, 服务器异常，请稍后再试
```

**含义**：小米 TSM 后端不认你 13T 的 eSE（安全元件）ID——国际版设备的 eSE 没在国行服务端白名单里。

**结论**：**模块无法修复**。这是小米服务端的安全策略。唯一真正解决办法是**刷 K60 Ultra 国行 ROM**（同款硬件，13T = K60 Ultra 国际版）。

---

## 限制 / 已知问题

| 问题 | 原因 | 能否修复 |
|---|---|---|
| 公交卡开卡失败 `1090001` | 服务端不认国际版 eSE | ❌ 刷国行 ROM |
| 门禁卡复制失败 `1090001` | 同上 | ❌ 刷国行 ROM |
| 装上后偶尔有少量 SELinux avc 拒绝 | migt/mcd_data_file 访问 | ⚠️ 已知但不影响功能 |
| 公交卡刷卡 NFC 走的是 eSE1 路由 | 由 KernelSU + 系统决定 | ✅ 已自动配置 |
| 部分机型没 eSE 硬件 | 硬件限制 | ❌ 13T 有 eSE 没问题 |

---

## 完整卸载

```bash
# 1. KernelSU App → 模块 → 卸载

# 2. 手动卸 10 个 app（用 --user 0 才能卸 system app）
adb shell su -c "pm uninstall --user 0 com.mipay.wallet"
adb shell su -c "pm uninstall --user 0 org.mipay.android.manager"
adb shell su -c "pm uninstall --user 0 com.miui.nextpay"
adb shell su -c "pm uninstall --user 0 com.miui.tsmclient"
adb shell su -c "pm uninstall --user 0 com.xiaomi.trustservice"
adb shell su -c "pm uninstall --user 0 com.xiaomi.payment"
adb shell su -c "pm uninstall --user 0 com.miui.securityinputmethod"
adb shell su -c "pm uninstall --user 0 com.miui.securityadd"
adb shell su -c "pm uninstall --user 0 com.miui.phrase"

# 3. 重启让模块目录 + mount bind 自动消失
adb reboot
```

卸载后 `/product/app/MITSMClientGlobal/MITSMClientGlobal.apk` 会**自动恢复**成 2MB 国际版（mount bind 是 f2fs overlay，重启消失，原始块设备内容自动回来）。

---

## 从卡刷包提取 system.img → 解 EROFS → 找 Pay app

```bash
# 1. 解 payload.bin（最新卡刷包都是这个格式）
pip install payload-dumper
payload-dumper payload.bin --output ./extracted --partitions product,system,system_ext,vendor

# 2. 解 EROFS（用 erofs2ext4Converter 工具）
bin/erofsUnpack.exe extracted/product.img
bin/erofsUnpack.exe extracted/system.img
bin/erofsUnpack.exe extracted/system_ext.img

# 3. 找 Pay app
find extracted/product/app -maxdepth 1 -type d | grep -iE "MIpay|MIpayService|MINextpay|MITSMClient|MiTrustService|PaymentService|SoterService|MIUISecurityInputMethod|MIUISecurityAdd|SecurityOnetrackService|MIUIFrequentPhrase"

# 4. 复制到模块目录
cp -r extracted/product/app/MIpay module/product/app/
cp -r extracted/product/app/MipayService module/product/app/
# ... 等等
```

---

## 构建模块

```bash
bash build.sh dev       # 开发构建（不校验 APK）
bash build.sh release   # 完整 release 构建（校验所有 10 个 APK 存在）
```

构建产物：`out/cc.klmmlk.MiuiCNInstallMiPay.v0.1.0.zip` (约 137MB)

---

## 发布到 GitHub

```bash
git init
git add .
git commit -m "Initial: 完整 Pay 链路模块（10 app）"
git tag v0.1.0
git remote add origin https://github.com/<your-username>/kernelsu-miui-cn-install-mipay.git
git push -u origin main --tags
```

CI 会自动用 `.github/workflows/release.yml` 构建并发布 zip 到 Releases。

---

## 致谢

- **[mrchi/magisk-miui-eu-install-mipay](https://github.com/mrchi/magisk-miui-eu-install-mipay)** — 原版 Magisk 模块，本项目的起点。MIUI 13 时代的简洁方案。
- **[ljc-fight/erofs2ext4Converter-for-MIUI-Device](https://github.com/ljc-fight/erofs2ext4Converter-for-MIUI-Device)** — `erofsUnpack.exe` 工具（Windows 上读 EROFS 镜像）
- **[0xclover.com](https://0xclover.com/2023/05/miui-wallet-in-global-roms/)** — `ro.vendor.se.type` 这个 prop 的正确名称
- **[MinaMichita](https://blog.minamigo.moe/archives/184)** — MIUI EU 本地化模块原作者
- **[少数派：MIUI 国际版/EU 版本地化教程 - 小米钱包篇](https://sspai.com/post/60065)** — 教程参考
- **[KernelSU 文档](https://developers.kernelsu.org/docs/zh-CN/)** — 模块系统文档

---

## 许可证

Apache 2.0

**免责声明**：
- 本模块仅供个人学习与研究使用，**请勿用于任何商业用途**
- 安装本模块可能违反小米钱包服务协议，使用 MiPay 等支付功能时存在账号风险
- 公交卡/门禁卡功能需要小米服务端认证，国际版设备无法通过（详见上文）
- 作者不对因使用本模块导致的任何账户封禁、支付异常、设备故障负责
