local e = require "nixio.fs"

m = Map("bridge", translate("Transparent bridge"),
	translate("Turns this router into a layer-2 bridge between its physical ports. " ..
		"Clients behind it keep the upstream router's subnet, gateway and NAT; " ..
		"no second layer of address translation is introduced."))

m:section(SimpleSection).template = "bridge/bridge_status"

s = m:section(TypedSection, "bridge", translate("Settings"))
s.anonymous = true

o = s:option(Flag, "enabled", translate("Enable transparent bridge"))
o.rmempty = false
o.default = "0"

o = s:option(Value, "gateway", translate("Upstream gateway"),
	translate("Address of the router that provides this network's gateway and DNS."))
o.rmempty = false
o.datatype = "ip4addr"

o = s:option(Value, "ipaddr", translate("Management address"),
	translate("Must sit in the upstream router's subnet and must not collide with another device. " ..
		"This is the address you use to reach this web interface once the bridge is on."))
o.rmempty = false
o.datatype = "ip4addr"

o = s:option(Value, "netmask", translate("Netmask"))
o.rmempty = false
o.datatype = "ip4addr"
o.default = "255.255.255.0"

o = s:option(Value, "network", translate("Number of physical ports"),
	translate("Leave empty to bridge every detected eth* port."))
o.datatype = "uinteger"
o.placeholder = "0"

o = m:section(TypedSection, "bridge", translate("What enabling does"))
o.anonymous = true
o.description = translate(
	"<li>The current network and DHCP configuration is saved once to /etc/bridge, so turning the switch off restores it.</li>" ..
	"<li>All physical ports are put into one bridge, which then carries the management address.</li>" ..
	"<li>Firewall rules are kept, not erased. Bridged traffic is switched at layer 2 and never reaches these zones.</li>" ..
	"<li>Some router-only features stop applying while the bridge is on, for example multi-dial and full-cone NAT.</li>" ..
	"<li>If the web interface becomes unreachable, connect to the management address shown above.</li>")

-- The CBI form only writes /etc/config/bridge. Something has to invoke
-- /etc/init.d/bridge afterwards, and the usual ucitrack route does not fire
-- here: procd config triggers listen for a config.change event, but a plain
-- `uci commit` never emits one, so saving the form changed nothing on disk
-- that mattered and the switch appeared dead.
--
-- on_after_commit runs inside LuCI's own apply path, so it works regardless of
-- how uci was driven. The script is detached because enabling renumbers the
-- management address and reloads the network: a synchronous call would hang
-- the HTTP request until the browser's connection dies underneath it.
function m.on_after_commit(self)
	luci.sys.call("/etc/init.d/bridge reload >/dev/null 2>&1 &")
end

return m
