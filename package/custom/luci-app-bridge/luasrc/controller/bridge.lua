module("luci.controller.bridge", package.seeall)

function index()
	if not nixio.fs.access("/etc/config/bridge") then
		return
	end

	local page

	page = entry({"admin", "network", "bridge"}, cbi("bridge"), _("Transparent bridge"), 60)
	page.dependent = true
	entry({"admin","network","bridge","status"},call("act_status")).leaf=true
end

function act_status()
	local e = {}
	-- Ask the kernel what is actually bridged. The old check grepped iptables
	-- for a zone name, which reports "not running" on fw4/nftables images even
	-- when the bridge is up, and would also stay green if the zone existed but
	-- the bridge did not.
	local n = tonumber(luci.sys.exec("ls /sys/class/net/br-bridge/brif 2>/dev/null | wc -l")) or 0
	e.running = (n > 0)
	e.ports = n
	luci.http.prepare_content("application/json")
	luci.http.write_json(e)
end
