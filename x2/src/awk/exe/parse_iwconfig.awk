# Example iwconfig output:
# -----------------------
# $ iwconfig wlp3s0
# wlp3s0    IEEE 802.11  ESSID:"BPLUNWIRED"
#           Mode:Managed  Frequency:5.785 GHz  Access Point: E2:55:2D:C0:64:B8
#           Bit Rate=135 Mb/s   Tx-Power=15 dBm
#           Retry short limit:7   RTS thr:off   Fragment thr:off
#           Power Management:on
#           Link Quality=59/70  Signal level=-51 dBm
#           Rx invalid nwid:0  Rx invalid crypt:0  Rx invalid frag:0
#           Tx excessive retries:0  Invalid misc:0   Missed beacon:0
#
#
# USAGE: khatus_parse_iwconfig -v requested_interface="$wifi_interface"

/^[a-z0-9]+ +IEEE 802\.11 +ESSID:/ {
    interface = $1
    split($4, essid_parts, ":")
    essid[interface] = essid_parts[2]
    gsub("\"", "", essid[interface])
}

/^ +Link Quality=[0-9]+\/[0-9]+ +Signal level=/ {
    split($2, lq_parts_eq, "=")
    split(lq_parts_eq[2], lq_parts_slash, "/")
    cur = lq_parts_slash[1]
    max = lq_parts_slash[2]
    link[interface] = cur / max * 100
}

END {
    i = requested_interface
    print("status" Kfs i, link[i] ? sprintf("%s:%d%%", essid[i], link[i]) : "--")
    print("essid"  Kfs i, link[i] ? essid[i] : "--")
    print("link"   Kfs i, link[i] ? link[i] : "--")
}
