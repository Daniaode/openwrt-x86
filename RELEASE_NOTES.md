# v18 — 在线更新新增取消按钮，修复下载超时误判

**此版本取代全部历史版本。**

版本标识：`r8201-0185dc581`，baked tag `v18-20261101`，内核 `6.18.58`，575 包。

---

## 一、新增：取消更新按钮

### 需求

下载/校验过程中，界面一直显示进度条，无法打断。新增「取消更新」按钮。

### 实现

三处改动：

| 层 | 改动 |
|---|---|
| 后端 | `cmd_cancel`：杀掉下载进程组 + curl，清理锁、状态、临时分片 |
| rpcd | `ALLOWED` 增加 `cancel: { args: 0 }` |
| 前端 | 进度区在 CHECKING / DOWNLOADING / VERIFYING 阶段显示「取消更新」按钮 |

关键设计：

- **进程组 kill**：下载 worker 由 `setsid` 启动，是会话组长也是进程组组长，进度监控子 shell 和 curl 都继承该组。`kill -9 -- -$pid` 一次性终结整条下载链，而不是只杀 shell 外壳。
- **与 cleanup 区分**：`cleanup` 在有活锁时拒绝（保护活下载不被 unlink 输出文件），`cancel` 是用户明确的「停止」，必须强拆。
- **APPLYING 阶段不可取消**：镜像已开始写入，取消没有意义且危险。

### 实测

```
PASS  cancel 终止 worker（3 → 0）
PASS  cancel 终止 curl（0）
PASS  锁清理、job 清理
PASS  cancel 后可重新 start
```

---

## 二、修复：下载超时误判

### 问题

凌晨等非高峰时段，ghfast 代理连接建立超过 20 秒，`--connect-timeout 20` 直接把下载判成超时失败：

```
03:09:44 downloading v17-r8202/... (proxy=https://ghfast.top/)
03:10:05 job failed: the download stalled or timed out (timeout)
```

而实际上代理是通的，只是慢——1MB range 探测 3 秒就成功（341 KB/s）。

### 修复

`--connect-timeout 20` → `--connect-timeout 60`。

理由：`--connect-timeout` 只约束 TCP 连接建立阶段。繁忙代理在非高峰时段接受连接可能远超 20 秒，20 秒会误杀「只是慢」的正常下载。60 秒仍然约束无休止的握手，但不会切断慢连接。

真正的「卡住」检测由 `--speed-limit 1024 --speed-time 120` 承担（连接建立后 120 秒无数据才中断），这才是防止永久卡住的正确机制。

### 实测

```
t=4s  BYTES=131000    PCT=0  SPD=131000
t=6s  BYTES=30407280  PCT=15 SPD=15138140
t=30s BYTES=91486832  PCT=46 SPD=1856853
→ 进度递增，速度稳定 1.5~15 MB/s
```

---

## 三、验证

全新 VM（172.16.99.82）13 项全过：

```
PASS  镜像身份 R26.11.1 / v18-20261101 / 1.1.0-r2
PASS  cancel 三处就位（helper / rpcd / 前端）
PASS  前端进度条 + 详情代码就位
PASS  网络自检（网关 / DNS，nft 225 条）
PASS  check available（降 tag 触发真实更新）
PASS  start 正常
PASS  下载进度递增（0 → 91 MB，46%）
PASS  cancel 终止 worker + curl
PASS  锁清理、job 清理
PASS  cancel 后可重新 start

SUMMARY pass=*** fail=0   RESULT=PASS
```

---

## 四、镜像

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

---

## 五、升级

```sh
sysupgrade -v /tmp/openwrt-x86-64-generic-squashfs-combined.img.gz
```

或在本版固件内用 `系统 → 在线更新`。

> **注意**：v15 及更早版本升级到本版时，「在线更新」页面的进度条和取消按钮才会生效。v15 点「开始下载」会转圈是因为旧版 rpcd 白名单缺 `start` 动词，已在 v16 修复。

登录：`root` / `password`，**首启后立即 `passwd` 修改**。

---

## 六、已知限制

- `hk-gh-proxy` 通道在虚拟化环境下极慢（实测 0.09 MB/s），界面已标注
- 下载代理的完整性依赖 SHA256 校验，未加 GPG 签名
- 测试环境无运营商 IPv6 上游，IPv6 端到端连通性仍无法实测

---

## 七、许可

构建脚本与配置以 MIT 发布。固件内各软件包版权归原作者，LEDE 主源码遵循 GPL-2.0。
