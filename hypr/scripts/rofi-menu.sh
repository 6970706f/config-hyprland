#!/bin/bash

ROFI="rofi -dmenu -i -no-custom -config $HOME/.config/rofi/utility.rasi"

menu() {
    printf '%s\n' "$@" | $ROFI
}

wifi() {
    local wifi_device
    local state
    local connection
    local choice
    local selected
    local index
    local ssid
    local password
    local loading_pid
    local scan_done

    wifi_device=$(nmcli -t -f DEVICE,TYPE device status |
        awk -F: '$2 == "wifi" {print $1; exit}')

    while true; do
        if [ -z "$wifi_device" ]; then
            state="Unavailable"
            connection="No Wi-Fi adapter"
        else
            state=$(nmcli -t -f GENERAL.STATE device show "$wifi_device" 2>/dev/null |
                cut -d: -f2- |
                sed 's/ (.*//')

            connection=$(nmcli -t -f GENERAL.CONNECTION device show "$wifi_device" 2>/dev/null |
                cut -d: -f2-)

            [ -z "$connection" ] && connection="Not connected"
        fi

        choice=$(menu \
            "󰤨  Wi-Fi: ${connection}" \
            "󰤭  Enable Wi-Fi" \
            "󰤮  Disable Wi-Fi" \
            "󰤯  Available Networks" \
            "󰖩  Disconnect") || return

        case "$choice" in
            *"Enable Wi-Fi")
                nmcli radio wifi on
                ;;

            *"Disable Wi-Fi")
                nmcli radio wifi off
                ;;

            *"Available Networks")
                nmcli radio wifi on >/dev/null 2>&1

                scan_done=$(mktemp)

                (
                    nmcli device wifi rescan ifname "$wifi_device" >/dev/null 2>&1
                    touch "$scan_done"
                ) &

                loading_pid=$!

                while [ ! -f "$scan_done" ]; do
                    printf '%s\n' "󰤨  Scanning Wi-Fi..." |
                        $ROFI -dmenu -no-custom \
                        -config "$HOME/.config/rofi/utility.rasi" \
                        -p "Wi-Fi" &
                    
                    rofi_pid=$!

                    while [ ! -f "$scan_done" ] && kill -0 "$rofi_pid" 2>/dev/null; do
                        sleep 0.05
                    done

                    kill "$rofi_pid" 2>/dev/null
                    wait "$rofi_pid" 2>/dev/null
                done

                wait "$loading_pid" 2>/dev/null
                rm -f "$scan_done"

                mapfile -t networks < <(
                    nmcli -t -e no \
                        -f SSID,SIGNAL,SECURITY \
                        device wifi list 2>/dev/null |
                    awk -F: '
                        $1 != "" {
                            if (!best[$1] || $2 > best[$1]) {
                                best[$1] = $2
                                security[$1] = $3
                            }
                        }
                        END {
                            for (ssid in best)
                                printf "%s\t%s\t%s\n", ssid, best[ssid], security[ssid]
                    }
                    ' |
                    sort -t $'\t' -k2,2nr
                )

                [ "${#networks[@]}" -gt 0 ] || {
                    rofi -e "No Wi-Fi networks found"
                    continue
                }

                mapfile -t ssids < <(
                    printf '%s\n' "${networks[@]}" |
                    cut -f1
                )

                display=()

                for line in "${networks[@]}"; do
                    IFS=$'\t' read -r ssid signal security <<< "$line"

                    if [ "$security" = "--" ] || [ -z "$security" ]; then
                        display+=("󰤨  $ssid  ${signal}%")
                    else
                        display+=("󰤨  $ssid  ${signal}%  󰌾 $security")
                    fi
                done

                selected=$(
                    printf '%s\n' "${display[@]}" |
                    $ROFI -p "Wi-Fi" -format i
                ) || continue

                index="$selected"

                [[ "$index" =~ ^[0-9]+$ ]] || continue
                [ -n "${ssids[$index]}" ] || continue

                ssid="${ssids[$index]}"

                if nmcli device wifi connect "$ssid" >/dev/null 2>&1; then
                    rofi -e "Connected to $ssid"
                    continue
                fi

                password=$(rofi -dmenu -password -i \
                    -config "$HOME/.config/rofi/config.rasi" \
                    -p "Password") || continue

                [ -n "$password" ] || continue

                if nmcli device wifi connect "$ssid" password "$password" >/dev/null 2>&1; then
                    rofi -e "Connected to $ssid"
                else
                    rofi -e "Failed to connect to $ssid"
                fi
                ;;

            *"Disconnect")
                [ -n "$wifi_device" ] &&
                    nmcli device disconnect "$wifi_device"
                ;;
        esac
    done
}

bluetooth() {
    while true; do
        power=$(bluetoothctl show 2>/dev/null | awk -F': ' '/Powered:/{print $2}')

        choice=$(menu \
            "󰂯  Bluetooth: ${power:-unknown}" \
            "󰂰  Enable Bluetooth" \
            "󰂲  Disable Bluetooth" \
            "󰋋  Paired Devices" \
            "󰂱  Scan for Devices") || return

        case "$choice" in
            *"Enable Bluetooth")
                bluetoothctl power on
                ;;
            *"Disable Bluetooth")
                bluetoothctl power off
                ;;
            *"Paired Devices")
                devices=$(bluetoothctl devices Paired 2>/dev/null)
                selected=$(printf '%s\n' "$devices" | $ROFI -p "Bluetooth") || continue

                mac=$(printf '%s\n' "$selected" | awk '{print $2}')
                [ -n "$mac" ] || continue

                action=$(menu "Connect" "Disconnect" "Remove" "Back") || continue

                case "$action" in
                    Connect)
                        bluetoothctl connect "$mac"
                        ;;
                    Disconnect)
                        bluetoothctl disconnect "$mac"
                        ;;
                    Remove)
                        bluetoothctl remove "$mac"
                        ;;
                esac
                ;;
            *"Scan for Devices")
                bluetoothctl scan on >/dev/null 2>&1 &
                sleep 5
                bluetoothctl scan off >/dev/null 2>&1

                devices=$(bluetoothctl devices 2>/dev/null)
                selected=$(printf '%s\n' "$devices" | $ROFI -p "Found Devices") || continue

                mac=$(printf '%s\n' "$selected" | awk '{print $2}')
                [ -n "$mac" ] && bluetoothctl pair "$mac"
                ;;
        esac
    done
}

power() {
    choice=$(menu \
        "󰐥  Lock" \
        "󰒲  Suspend" \
        "󰍃  Log Out" \
        "󰜉  Reboot" \
        "󰐥  Power Off") || return

    case "$choice" in
        *"Lock")
            hyprlock
            ;;
        *"Suspend")
            systemctl suspend
            ;;
        *"Log Out")
            hyprctl dispatch exit
            ;;
        *"Reboot")
            systemctl reboot
            ;;
        *"Power Off")
            systemctl poweroff
            ;;
    esac
}

disks() {
    root_partition=$(findmnt -n -o SOURCE /)
    root_disk=$(lsblk -no PKNAME "$root_partition" 2>/dev/null)

    if [ -n "$root_disk" ]; then
        root_disk="/dev/$root_disk"
    else
        root_disk="$root_partition"
    fi

    while true; do
        devices=$(
            lsblk -e7 -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINTS -p 2>/dev/null |
            while IFS= read -r line; do
                device=$(printf '%s\n' "$line" |
                    sed -nE 's/.*(\/dev\/[^[:space:]]+).*/\1/p')

                [ -n "$device" ] || {
                    printf '%s\n' "$line"
                    continue
                }

                parent_disk=$(lsblk -no PKNAME "$device" 2>/dev/null)

                if [ "$device" = "$root_disk" ] ||
                   [ -n "$parent_disk" ] && [ "/dev/$parent_disk" = "$root_disk" ]; then
                    continue
                fi

                if findmnt -rn -S "$device" >/dev/null 2>&1; then
                    status="Mounted"
                else
                    status="Unmounted"
                fi

                printf '%-80s [%s]\n' "$line" "$status"
            done
        )

        selected=$(printf '%s\n' "$devices" | $ROFI -p "Disks") || return
        [ -n "$selected" ] || return

        device=$(printf '%s\n' "$selected" |
            sed -nE 's/.*(\/dev\/[^[:space:]]+).*/\1/p')

        [ -b "$device" ] || continue

        if findmnt -rn -S "$device" >/dev/null 2>&1; then
            udisksctl unmount -b "$device" >/dev/null 2>&1
        else
            udisksctl mount -b "$device" >/dev/null 2>&1
        fi
    done
}

scripts() {
    dir="$HOME/.config/hypr/scripts"

    while true; do
        mapfile -t files < <(
            find "$dir" -maxdepth 1 -type f -name '*.sh' -printf '%f\n' | sort
        )

        [ "${#files[@]}" -gt 0 ] || return

        selected=$(printf '%s\n' "${files[@]}" | $ROFI -p "Scripts") || return
        [ -n "$selected" ] || return

        case "$selected" in
            rofi-menu.sh)
                continue
                ;;
            *)
                "$dir/$selected"
                ;;
        esac

        return
    done
}

while true; do
    choice=$(menu \
        "󰤨  Wi-Fi" \
        "󰂯  Bluetooth" \
        "󰋊  Disks" \
        "󰒓  Scripts" \
        "󰐥  Power") || exit 0

    case "$choice" in
        *"Wi-Fi")
            wifi
            ;;
        *"Bluetooth")
            bluetooth
            ;;
        *"Power")
            power
            ;;
        *"Disks")
            disks
            ;;
        *"Scripts")
            scripts
            ;;
    esac
done