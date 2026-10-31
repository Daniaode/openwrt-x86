#
# Copyright (C) 2016 Openwrt.org
#
# This is free software, licensed under the Apache License, Version 2.0 .
#

include $(TOPDIR)/rules.mk

LUCI_TITLE:=LuCI support for transparent bridge
LUCI_DESCRIPTION:=Turns the router into a layer-2 bridge between its physical \
 ports while keeping one management address on the bridge.
LUCI_DEPENDS:=+ip-bridge +kmod-nft-bridge

define Package/luci-app-bridge/conffiles
/etc/config/bridge
endef

# Guards for the two faults that made the switch silently do nothing.
#
# These run when this Makefile is parsed, not inside Build/Compile. A check
# inside Build/Compile did not execute for this package at all (verified with a
# probe: zero hits while the package compiled fine), so it would have been
# decoration. A parse-time $(error) cannot be skipped.
#
# 1. The init script shipped as mode 644, so ucitrack's trigger invoked it and
#    got "Permission denied". The form wrote /etc/config/bridge and nothing
#    else happened, with no error surfaced anywhere. luci.mk installs ./root
#    with `cp -pR`, which preserves the mode, so the bit must be right here.
#
# 2. The trigger comes from /usr/share/ucitrack/luci-app-bridge.json on this
#    firmware generation. It reads that JSON and no longer maintains the
#    legacy /etc/config/ucitrack entries, where registering did nothing.
ifeq ($(wildcard ./root/usr/share/ucitrack/luci-app-bridge.json),)
  $(error luci-app-bridge: missing root/usr/share/ucitrack/luci-app-bridge.json - without it nothing runs the init script after a form save)
endif
ifeq ($(shell test -x ./root/etc/init.d/bridge && echo yes),)
  $(error luci-app-bridge: root/etc/init.d/bridge is not executable - ucitrack cannot run it and the bridge will never come up)
endif

include $(TOPDIR)/feeds/luci/luci.mk

# Required for this package to be picked up at all: include/scan.mk selects
# packages by grepping each Makefile for 'call (BuildPackage|...)' and skips
# everything else. Without this line the build reports
# "No rule to make target 'package/custom/luci-app-bridge/compile'", which
# looks like a broken Makefile rather than an unregistered package.
# call BuildPackage - OpenWrt buildroot signature
