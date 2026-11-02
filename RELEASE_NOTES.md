# v20 — 透明网桥界面汉化

**此版本取代全部历史版本。**

版本标识：`r8201-0185dc581`，baked tag `v20-20261103`，内核 `6.18.58`，575 包。

---

## 一、问题

透明网桥页面（网络 → 透明网桥）显示为**英文**，其余界面是中文。

## 二、根因

翻译文件落后于界面文字。

`luci-app-bridge` 的中文翻译在 `po/zh-cn/bridge.po`。v17 重写该界面时把英文文案全换了：

| 旧字符串 | v17 后的新字符串 |
|---|---|
| `GatewayIP` | `Upstream gateway` |
| `Bridge IP` | `Management address` |
| `Number of network ports` | `Number of physical ports` |
| `Setting instructions:` | `What enabling does` |
| (新增) | `Enable transparent bridge` |
| (新增) | 大段说明文字 |

但 `.po` 文件只保留了旧 msgid 的翻译，新字符串没有对应条目 → 没有翻译 → 回退到英文显示。

机制本身是正常的：`luci.mk` 里 `zh-cn` 就是 `zh_Hans` 的别名（`LUCI_PO_DIR_ALIAS.zh_Hans=zh-cn`），`bridge.zh-cn.lmo` 也确实编译并装进了固件——只是内容对不上。

## 三、修复

重写 `po/zh-cn/bridge.po`，msgid 与当前界面文案逐条对齐，涵盖：

- 设置项：透明网桥 / 启用透明网桥 / 上级网关 / 管理地址 / 网络掩码 / 物理网口数量
- 各项说明文字
- 「启用后会做什么」的 5 条要点
- 状态页：运行中 / 未运行 / 正在收集数据…

## 四、验证

**不是 grep 文件，而是真实浏览器点击**（headless Chrome，zh-CN 语言环境）登录 LuCI 打开透明网桥页，读取渲染文本：

```
透明网桥 / 把路由器变成物理网口之间的二层网桥…/ 未运行
设置 / 启用透明网桥 / 上级网关 / 管理地址 / 网络掩码 / 物理网口数量
提供本网络网关与 DNS 的上游路由器地址。
必须与上级路由器在同一网段… / 启用后会做什么 / 5 条说明全中文
无英文残留
```

（「网络掩码」是 luci-base 对 Netmask 的既有译法，同为中文）

五阶段验证全部通过：

| 阶段 | 结果 |
|---|---|
| ① QEMU | ✅ 无 panic，控制台登录正常 |
| ② ESXi 新建 VM | ✅ 健康 6/6，浏览器实测全中文 |
| ③ 升级 v19→v20 | ✅ 版本变化，配置保留，lmo 含中文 |
| ④ 恢复出厂 | ✅ preset=ghfast，nft 225 干净 |
| ⑤ 清理 | ✅ 测试 VM 与临时文件清理 |

## 五、镜像

| 文件 | 大小 |
|---|---|
| `openwrt-x86-64-generic-squashfs-combined-efi.vmdk` | 185 MB |
| `openwrt-x86-64-generic-squashfs-combined.vmdk` | 185 MB |
| `openwrt-x86-64-generic-squashfs-combined-efi.img.gz` | 186 MB |
| `openwrt-x86-64-generic-squashfs-combined.img.gz` | 186 MB |
| `openwrt-x86-64-generic-ext4-combined.img.gz` | 234 MB |
| `openwrt-x86-64-generic-ext4-combined-efi.img.gz` | 234 MB |
| `openwrt-x86-64-generic.manifest` | 15 KB |

校验：`sha256sum -c RELEASE_SHA256SUMS`

## 六、升级

```sh
sysupgrade -v /tmp/openwrt-x86-64-generic-squashfs-combined.img.gz
```

或在本版固件内用 `系统 → 在线更新`。

登录：`root` / `password`，**首启后立即 `passwd` 修改**。

## 七、许可

构建脚本与配置以 MIT 发布。固件内各软件包版权归原作者，LEDE 主源码遵循 GPL-2.0。
