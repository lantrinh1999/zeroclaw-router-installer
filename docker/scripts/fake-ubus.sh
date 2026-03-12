#!/bin/sh
# Fake ubus - đọc response từ /etc/device/ubus-board.json
case "$1" in
  call)
    case "$2" in
      system)
        case "$3" in
          board|'{"method":"board"}')
            cat /etc/device/ubus-board.json 2>/dev/null || echo "{}"
            ;;
          info|'{"method":"info"}')
            MEM_TOTAL=$(awk '/MemTotal/{print $2*1024}' /proc/meminfo)
            MEM_FREE=$(awk '/MemFree/{print $2*1024}' /proc/meminfo)
            cat <<EOF
{
	"uptime": $(cat /proc/uptime | cut -d. -f1),
	"localtime": $(date +%s),
	"load": [0, 0, 0],
	"memory": {
		"total": ${MEM_TOTAL:-524288000},
		"free": ${MEM_FREE:-262144000},
		"shared": 0,
		"buffered": 0
	}
}
EOF
            ;;
          *)
            echo "{}"
            ;;
        esac
        ;;
      service)
        echo "{}"
        ;;
      *)
        echo "{}"
        ;;
    esac
    ;;
  *)
    echo "Usage: ubus call <path> [<message>]"
    ;;
esac
exit 0
