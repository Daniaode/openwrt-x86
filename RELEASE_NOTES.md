# v19 — 修复「更新」按钮弹不出确认框

**此版本取代全部历史版本。**

版本标识：`r8201-0185dc581`，baked tag `v19-20261101`，内核 `6.18.58`，575 包。

---

## 一、问题

在线更新页点「更新」按钮，**确认框（含「开始下载」按钮）弹不出来**，等于「更新」按钮是死的。

## 二、根因

LuCI 26.x 的 `createHandlerFn(ctx, fn, ...args)` 调用约定是**额外参数在前、event 在最后**：

```js
// LuCI 26.x 实际调用：fn(...args, event)
return L.bind(function() {
    const t = arguments[args.length].currentTarget;  // event 在 args 之后
    fn.apply(ctx, arguments);                        // fn 收到 [...args, event]
}, ctx, ...args);
```

而 v16 引入的 handler 参数顺序写反了：

```js
// 错误（v16–v18）：
handleDownload: function(ev, check) {
    ev.preventDefault();   // ev 实际是 check 对象 → 报错
    ...
}
```

点击按钮时 `handleDownload` 的第一个参数实际是 `check` 对象，`ev.preventDefault()` 抛 `ev.preventDefault is not a function`，modal 弹不出来，浏览器 console 报错但用户看不到。

## 三、修复

三个带参数的 handler 参数顺序反转：

```
handleDownload(ev, check)  → handleDownload(check, ev)
handleIgnore(ev, tag)       → handleIgnore(tag, ev)
handleUnignore(ev, tag)     → handleUnignore(tag, ev)
```

`handleApply`/`handleDiscard`/`handleCancel`/`handleRecheck` 无额外参数，不受影响。

## 四、验证（headless Chrome 模拟真人操作）

这次用 puppeteer 驱动真实浏览器（而非脚本直接调后端）做端到端验证，这正是之前缺失的一层：

```
登录 LuCI                    ✅ root/password
点击「更新」按钮 → modal 弹出  ✅（修复前弹不出）
点击「开始下载」→ 下载开始    ✅
进度条实时显示               ✅ Downloading firmware… 0% · 80.0 KB / 186.1 MB · 80.0 KB/s · 39m 42s left
点击「取消更新」→ 成功        ✅
透明网桥页配置读取            ✅ enabled=false, gateway/ipaddr/netmask 正确
```

## 五、为什么之前没发现

之前所有验证都是脚本直接调后端（uci/init.d/ubus），绕过了 LuCI 前端 UI 层。只有浏览器自动化（模拟真实点击）才能暴露这个前端参数顺序 bug。

## 六、镜像

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

## 七、升级

```sh
sysupgrade -v /tmp/openwrt-x86-64-generic-squashfs-combined.img.gz
```

或在本版固件内用 `系统 → 在线更新`。

登录：`root` / `password`，**首启后立即 `passwd` 修改**。

## 八、许可

构建脚本与配置以 MIT 发布。固件内各软件包版权归原作者，LEDE 主源码遵循 GPL-2.0。
