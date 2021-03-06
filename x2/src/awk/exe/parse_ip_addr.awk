/^[0-9]+:/ {
    sub(":$", "", $1)
    sub(":$", "", $2)
    sequence = $1
    interface = $2
    Interfaces[sequence] = interface
}

/^ +inet [0-9]/ {
    sub("/[0-9]+", "", $2)
    addr = $2
    Addrs[interface] = addr
}

/^ +RX: / {transfer_direction = "r"}
/^ +TX: / {transfer_direction = "w"}

/^ +[0-9]+ +[0-9]+ +[0-9]+ +[0-9]+ +[0-9]+ +[0-9]+ *$/ {
    io[interface, transfer_direction] = $1;
}

END {
    for (seq=1; seq<=sequence; seq++) {
        interface = Interfaces[seq]
        label = substr(interface, 1, 1)
        addr = Addrs[interface]
        if (addr) {
            bytes_read    = io[interface, "r"]
            bytes_written = io[interface, "w"]
        } else {
            bytes_read    = ""
            bytes_written = ""
        }
        output["addr"          Kfs interface] = addr
        output["bytes_read"    Kfs interface] = bytes_read
        output["bytes_written" Kfs interface] = bytes_written
    }
    for (key in output) {
        print(key, output[key])
    }
}
