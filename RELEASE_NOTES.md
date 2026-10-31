# v17 — 修复透明网桥在页面开启后不生效

**此版本取代全部历史版本。**

版本标识：`r8201-0185dc581`，baked tag `v17-20261031`，内核 `6.18.58`，575 包。

---

## 一、问题

在 LuCI 的 `网络 → 透明网桥` 页面勾选启用、保存应用后，配置写进去了，但**网桥从未建立**。页面看不到任何报错，开关看起来"开了"，实际什么也没发生。

---

## 二、三个根因，缺一不可

### 1. init 脚本没有执行位

```
-rw-r--r--  /etc/init.d/bridge
$ /etc/init.d/bridge start
→ Permission denied
```

页面只负责把 `enabled` 写入 `/etc/config/bridge`，真正干活的是这个 init 脚本。脚本不可执行，触发时直接被拒绝。

`luci.mk` 用 `cp -pR ./root` 安装，权限位原样保留，所以源文件是 644，装进固件还是 644。

### 2. 触发机制用错了

这个固件用**新版 ucitrack**：`/usr/share/ucitrack/*.json`。原包的 `uci-defaults` 写的是老式 `/etc/config/ucitrack` 条目——这个系统**根本不维护那个文件**，写进去毫无作用。

对照：`/usr/share/ucitrack/` 下已有 14 个 json（firewall、upnp、openclash 等），没有 bridge 的那一份。

`register_init` 的条件是「可执行 + enabled + 非 procd」，三条都满足，只缺这个 json。

### 3. CBI 表单缺少保存回调

即使前两条修好，还有一个时机问题：`uci commit` 本身**不会**发出 `config.change` 事件，只有 LuCI 的 apply 路径才会。原页面没有任何 `on_after_commit`，所以保存后没人去调用 init 脚本。

---

## 三、修复

| 项 | 改动 |
|---|---|
| 权限位 | `chmod 755`，并在 Makefile 里加解析期 `$(error)` 守卫 |
| 触发机制 | 新增 `root/usr/share/ucitrack/luci-app-bridge.json` |
| 保存回调 | CBI 增加 `on_after_commit`，后台调用 `init.d/bridge reload` |

`on_after_commit` 里用后台调用而非同步：启用会重编管理地址并 reload 网络，同步调用会把 HTTP 请求挂到浏览器连接断掉为止。

守卫为什么放在**解析期**而不是 `Build/Compile`：实测 `Build/Compile` 对这个包根本不执行（插入探针，编译成功但命中 0 次），放那里等于装饰。`$(error)` 在 Makefile 解析时必定触发。

实测拦截：

```
正常状态                      → 可解析，编译继续
chmod 644 init.d/bridge       → ERROR: ... is not executable
移走 ucitrack json            → ERROR: missing ... json
```

---

## 四、顺带修掉 3 个副作用缺陷

### 1. 清空防火墙配置

原脚本：

```sh
cat /dev/null > /etc/config/firewall
```

然后只重建一个 zone。实测把 **183 行 / 2 个 zone 的防火墙配置删成 10 行 / 1 个 zone**，用户的端口转发、自定义规则全部丢失。

现在保留原配置，只在缺失时补一个 bridge zone。理由：网桥流量是二层转发，由内核 bridge 处理，**根本不经过这些 zone**，清空没有任何收益。

### 2. `break` 用在循环外

```sh
if [ ... ]; then
	break;      # 不在 for/while 内，ash 下是无效语句
```

这使"防重复配置"的判断完全失效，每次 reload 都重写 network/firewall 并重启网络。改用 `param` 文件记录上次应用的参数做幂等判断。

### 3. 状态指示灯判据过时

原代码：

```lua
e.running = luci.sys.call("iptables -L INPUT | grep zone_.*input | grep bridge")==0
```

本固件是 **fw4 / nftables**（`nft list ruleset` 有 `table inet fw4`），没有那种 iptables 规则名。即使网桥完全正常，页面也一直显示"未运行"。

改为查 `/sys/class/net/br-bridge/brif` 的成员数——直接问内核，与防火墙后端无关。

---

## 五、另一处连带修复：改写 network 导致 DNS 失效

原脚本清空 `/etc/config/network` 后只重建 bridge 接口，但不碰 `/etc/config/dhcp`。结果 dnsmasq 仍然绑定已删除的 `lan` / `wan`：

```
dhcp.lan.interface='lan'   → network.lan 已不存在
dhcp.wan.interface='wan'   → network.wan 已不存在
```

实测现象：网桥建起来了，`172.16.99.25/24` 也拿到了，但**域名解析全部失败**——因为 dnsmasq 的上游来自 `wan` 接口的 `resolv.conf.auto`，而那个接口没了。

现在同步清理 dhcp 里指向已删接口的段，新增 `dhcp.bridge`（`ignore='1'`，客户端仍由上游路由器分配地址），并显式指定上游 DNS。

---

## 六、验证：全新烧写，走页面保存路径

在全新 v17 镜像的 VM 上，模拟"页面保存"（写 uci + commit + `config.change` 事件）：

```
PASS  init.d/bridge 可执行（原为 644）
PASS  ucitrack json 存在（触发机制）
PASS  cbi 有 on_after_commit

PASS  页面保存后建出网桥
PASS  init 脚本确实被执行（0 → 1 次）
PASS  网桥成员口 [eth0 eth1]
PASS  管理 IP 在网桥上（172.16.99.25）
PASS  上游网关可达
PASS  DNS 正常
PASS  防火墙 zone 未被删除（2 → 3）
PASS  防火墙规则未被清空（184 → 191）

PASS  关闭后网桥移除
PASS  LAN 已还原
PASS  还原后 DNS 正常

SUMMARY pass=15 fail=0   RESULT=PASS
```

另在既有设备上跑了三段验证（禁用 → 启用 → 禁用），同样 14/14 通过。

---

## 七、镜像

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

## 八、升级

```sh
sysupgrade -v /tmp/openwrt-x86-64-generic-squashfs-combined.img.gz
```

或在本版固件内用 `系统 → 在线更新`。

登录：`root` / `password`，**首启后立即 `passwd` 修改**。

---

## 九、已知限制

- 启用透明网桥后，路由器的多拨、全锥 NAT 等功能不再适用（网桥是二层设备，不做三层处理）
- 管理地址必须与上游同网段且不冲突；填错会导致 Web 界面失联，需通过控制台改回
- `hk-gh-proxy` 下载通道在虚拟化环境下极慢（实测 0.09 MB/s），界面已标注
- 测试环境无运营商 IPv6 上游，IPv6 端到端连通性仍无法实测

---

## 十、许可

构建脚本与配置以 MIT 发布。固件内各软件包版权归原作者，LEDE 主源码遵循 GPL-2.0。
