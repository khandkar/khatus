#! /bin/bash

MSG_FS='|'

set -e

executable_name_of_cmd() {
    basename "$(echo $1 | awk '{print $1; exit}')"
}

run_producer() {
    pipe="$1"
    bin="$2"
    cmd="$3"
    executable_name="$4"
    perf_log="$5"

    if [ ! "$perf_log" = '' ]
    then
        # %S system  time in seconds
        # %U user    time in seconds
        # %e elapsed time in seconds
        # %c context switches involuntary
        # %w context switches voluntary
        # %x exit code
        time_fmt='%S %U %e %c %w %x'
        time="/usr/bin/time -ao ${perf_log} -f "
        time_sep=' '
    else
        time_fmt=''
        time=''
        time_sep=''
    fi

    ${time}"${time_fmt}"${time_sep}$bin/$cmd \
    2> >(
        while read line
        do
            echo "${NODE}${MSG_FS}${executable_name}${MSG_FS}error${MSG_FS}$line" > "$pipe"
        done \
    ) \
    | while read line
        do
            echo "${NODE}${MSG_FS}${executable_name}${MSG_FS}data${MSG_FS}$line" > "$pipe"
        done
    cmd_exit_code=${PIPESTATUS[0]}
    if [ "$cmd_exit_code" -ne 0 ]
    then
        echo
            "${NODE}${MSG_FS}${executable_name}${MSG_FS}error${MSG_FS}NON_ZERO_EXIT_CODE${MSG_FS}$cmd_exit_code" \
            > "$pipe"
    fi
}

fork_watcher() {
    pipe="$1"
    bin="$2"
    cmd="$3"
    executable_name=$(executable_name_of_cmd "$cmd")
    run_producer "$pipe" "$bin" "$cmd" "$executable_name" &
}

fork_poller() {
    interval="$1"
    perf_log_dir="$2"
    shift 2
    pipe="$1"
    bin="$2"
    cmd="$3"

    executable_name=$(basename "$(echo $cmd | awk '{print $1; exit}')")

    if [ ! "$perf_log_dir" = '' ]
    then
        cmd="$3"
        perf_log_file=${executable_name}.log
        mkdir -p "$perf_log_dir"
        perf_log_path="$perf_log_dir/$perf_log_file"
    fi

    while :
    do
        run_producer "$pipe" "$bin" "$cmd" "$executable_name" "$perf_log_path"
        sleep "$interval"
    done &
}

find_thermal_zone() {
    local -r _type="$1"
    awk \
        -v _type="$_type" \
        '
        $0 ~ ("^" _type "$") {
            split(FILENAME, f, "thermal_zone");
            split(f[2], f2, "/");
            print f2[1]}
        ' \
        /sys/class/thermal/thermal_zone*/type
}

main() {
    declare -A opts=(
        ["--node"]=$(hostname)
        ["--dir_bin"]="$HOME/bin"
        ["--dir_perf_logs"]=''
        ["--file_pipe"]=$(mktemp)
        ["--weather_station_id"]='KJFK'
        ["--screen_brightness_device_name"]='acpi_video0'
        ["--wifi_interface"]=''
        ["--disk_space_device"]='/'
        ["--disk_io_device"]='sda'
        ["--thermal_zone"]="$(find_thermal_zone x86_pkg_temp)"
        ["--fan_path"]='/proc/acpi/ibm/fan'
        ["--pulseaudio_sink"]='0'
        ["--interval_datetime"]=1
        ["--interval_procs"]=1
        ["--interval_brightness"]=1
        ["--interval_weather"]=$(( 30 * 60))  # 30 minutes
        ["--interval_mpd"]=1
        ["--interval_volume"]=1
        ["--interval_bluetooth"]=1
        ["--interval_net_wifi"]=1
        ["--interval_net_io"]=1
        ["--interval_net_carrier"]=1
        ["--interval_disk_space"]=1
        ["--interval_disk_io"]=1
        ["--interval_loadavg"]=1
        ["--interval_temp"]=1
        ["--interval_fan"]=1
        ["--interval_mem"]=1
    )
    while :
    do
        key="$1"
        val="$2"
        case "$key" in
            '')
                break
                ;;
            * )
                if [ -v opts["$key"] ]
                then
                    if [ "$val" != "" ]
                    then
                        opts["$key"]="$val"
                        shift
                        shift
                    else
                        echo "Option $key requires an argument" >&2
                        exit 1
                    fi
                else
                    echo "Unknown option: $key" >&2
                    exit 1
                fi
        esac
    done

    if [ "${opts['--wifi_interface']}" = ''  ]
    then
        echo 'Please provide the required parameter: --wifi_interface' >&2
        exit 1
    fi

    (
        echo '=============================================='
        echo "Khatus starting with the following parameters:"
        echo '=============================================='
        for param in ${!opts[@]}
        do
            echo "$param := ${opts[$param]}"
        done \
        | column -ts: \
        | sort
        echo '----------------------------------------------'
    ) >&2

    NODE="${opts['--node']}"

    screen_brightness_device_path='/sys/class/backlight'
    screen_brightness_device_path+="/${opts['--screen_brightness_device_name']}"

    # Just shorthand
    pipe="${opts['--file_pipe']}"
    bin="${opts['--dir_bin']}"
    perf="${opts['--dir_perf_logs']}"

    rm -f "$pipe"
    mkfifo "$pipe"

    cmd_sens_screen_brightness='khatus_sensor_screen_brightness'
    cmd_sens_screen_brightness+=" $screen_brightness_device_path"

    cmd_sens_weather="khatus_sensor_weather $bin ${opts['--weather_station_id']}"
    cmd_sens_disk_space="khatus_sensor_disk_space $bin ${opts['--disk_space_device']}"
    cmd_sens_disk_io="khatus_sensor_disk_io $bin ${opts['--disk_io_device']}"
    cmd_sens_temperature="khatus_sensor_temperature ${opts['--thermal_zone']}"
    cmd_sens_fan="khatus_sensor_fan $bin ${opts['--fan_path']}"
    cmd_sens_bluetooth="khatus_sensor_bluetooth_power $bin"
    cmd_sens_mpd="khatus_sensor_mpd $bin"
    cmd_sens_net_addr_io="khatus_sensor_net_addr_io $bin"
    cmd_sens_volume="khatus_sensor_volume $bin"
    cmd_sens_wifi="khatus_sensor_net_wifi_status $bin ${opts['--wifi_interface']}"
    cmd_sens_loadavg="khatus_sensor_loadavg $bin"
    cmd_sens_memory="khatus_sensor_memory $bin"

    fork_watcher                                           "$pipe" "$bin" "khatus_sensor_energy $bin"
    fork_watcher                                           "$pipe" "$bin" "khatus_sensor_devices $bin"
    fork_poller "${opts['--interval_datetime']}"   "$perf" "$pipe" "$bin" khatus_sensor_datetime
    fork_poller "${opts['--interval_procs']}"      "$perf" "$pipe" "$bin" "khatus_sensor_procs $bin"
    fork_poller "${opts['--interval_brightness']}" "$perf" "$pipe" "$bin" "$cmd_sens_screen_brightness"
    fork_poller "${opts['--interval_weather']}"    "$perf" "$pipe" "$bin" "$cmd_sens_weather"
    fork_poller "${opts['--interval_mpd']}"        "$perf" "$pipe" "$bin" "$cmd_sens_mpd"
    fork_poller "${opts['--interval_volume']}"     "$perf" "$pipe" "$bin" "$cmd_sens_volume"
    fork_poller "${opts['--interval_bluetooth']}"  "$perf" "$pipe" "$bin" "$cmd_sens_bluetooth"
    fork_poller "${opts['--interval_bluetooth']}"  "$perf" "$pipe" "$bin" 'khatus_sensor_bluetooth'
    fork_poller "${opts['--interval_net_wifi']}"   "$perf" "$pipe" "$bin" "$cmd_sens_wifi"
    fork_poller "${opts['--interval_net_io']}"     "$perf" "$pipe" "$bin" "$cmd_sens_net_addr_io"
    fork_poller "${opts['--interval_disk_space']}" "$perf" "$pipe" "$bin" "$cmd_sens_disk_space"
    fork_poller "${opts['--interval_disk_io']}"    "$perf" "$pipe" "$bin" "$cmd_sens_disk_io"
    fork_poller "${opts['--interval_loadavg']}"    "$perf" "$pipe" "$bin" "$cmd_sens_loadavg"
    fork_poller "${opts['--interval_temp']}"       "$perf" "$pipe" "$bin" "$cmd_sens_temperature"
    fork_poller "${opts['--interval_fan']}"        "$perf" "$pipe" "$bin" "$cmd_sens_fan"
    fork_poller "${opts['--interval_mem']}"        "$perf" "$pipe" "$bin" "$cmd_sens_memory"
    fork_poller "${opts['--interval_net_carrier']}" "$perf" "$pipe" "$bin" khatus_sensor_net_carrier

    stdbuf -o L tail -f "$pipe"
}

main $@
