#!/bin/bash
# EasePi A2 OLED 128x32 diagnostic and configuration tool (Go)
# Usage: sudo bash /usr/local/oled/oled_init.sh

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

SCRIPT_DIR="/usr/local/oled"
OLED_BIN="${SCRIPT_DIR}/oled"
FONT_FILE="${SCRIPT_DIR}/DejaVuSansMono.ttf"
SERVICE_FILE="/etc/systemd/system/oled.service"

check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}[ERROR]${NC} Please run with root privileges (sudo bash ${SCRIPT_DIR}/oled_init.sh)"
        exit 1
    fi
}

check_files() {
    echo -e "${GREEN}[INFO]${NC} Checking OLED related files..."
    if [ ! -f "${OLED_BIN}" ]; then
        echo -e "${RED}[ERROR]${NC} Binary missing: ${OLED_BIN}"
        exit 1
    fi
    if [ ! -x "${OLED_BIN}" ]; then
        echo -e "${GREEN}[INFO]${NC} Adding execute permission for oled"
        chmod +x "${OLED_BIN}"
    fi
    if [ ! -f "${FONT_FILE}" ]; then
        echo -e "${RED}[ERROR]${NC} Font missing: ${FONT_FILE}"
        exit 1
    fi
    if [ ! -f "${SERVICE_FILE}" ]; then
        echo -e "${RED}[ERROR]${NC} Service file missing: ${SERVICE_FILE}"
        exit 1
    fi
    echo -e "${GREEN}[INFO]${NC} File check passed"
}

check_deps() {
    echo -e "${GREEN}[INFO]${NC} Checking system dependencies..."
    if ! command -v i2cdetect &>/dev/null; then
        echo -e "${YELLOW}[WARN]${NC} i2c-tools missing, installing..."
        apt-get update -y -qq
        apt-get install -y --no-install-recommends i2c-tools
    else
        echo -e "${GREEN}[INFO]${NC} i2c-tools already installed"
    fi
}

check_i2c() {
    echo -e "${GREEN}[INFO]${NC} Checking I2C bus and OLED device..."
    if ! lsmod | grep -q "i2c_dev"; then
        echo -e "${GREEN}[INFO]${NC} Loading i2c-dev module"
        modprobe i2c-dev 2>/dev/null
    fi
    if [ -e "/dev/i2c-3" ]; then
        echo -e "${GREEN}[INFO]${NC} i2c-3 device node exists"
        chmod 666 /dev/i2c-3 2>/dev/null
    else
        echo -e "${RED}[ERROR]${NC} i2c-3 device node not found"
        exit 1
    fi
    if i2cdetect -y 3 2>/dev/null | grep -q "3c\|3d"; then
        echo -e "${GREEN}[INFO]${NC} OLED device found on i2c-3"
    else
        echo -e "${YELLOW}[WARN]${NC} OLED device not detected, please check hardware connection"
        i2cdetect -y 3
    fi
}

check_service() {
    echo -e "${GREEN}[INFO]${NC} Checking OLED service status..."
    if systemctl is-active --quiet oled.service; then
        echo -e "${GREEN}[INFO]${NC} oled.service is running"
    else
        echo -e "${YELLOW}[WARN]${NC} oled.service is not running"
        echo -e "${GREEN}[INFO]${NC} Starting service..."
        systemctl start oled.service
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}[INFO]${NC} Service started successfully"
        else
            echo -e "${RED}[ERROR]${NC} Service start failed"
            journalctl -u oled.service -n 20 --no-pager
        fi
    fi
    if systemctl is-enabled --quiet oled.service 2>/dev/null; then
        echo -e "${GREEN}[INFO]${NC} oled.service enabled for auto-start"
    else
        echo -e "${YELLOW}[WARN]${NC} oled.service not enabled for auto-start"
        systemctl enable oled.service
    fi
}

restart_service() {
    echo -e "${GREEN}[INFO]${NC} Restarting OLED service..."
    systemctl restart oled.service
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}[INFO]${NC} Service restarted successfully"
        sleep 2
        if systemctl is-active --quiet oled.service; then
            echo -e "${GREEN}[INFO]${NC} Service running normally"
        else
            echo -e "${RED}[ERROR]${NC} Service running abnormally"
        fi
    else
        echo -e "${RED}[ERROR]${NC} Service restart failed"
    fi
}

show_usage() {
    local cpu_usage cpu_temp rx tx
    cpu_usage=$(grep 'cpu ' /proc/stat 2>/dev/null | awk '{usage=($2+$4)*100/($2+$4+$5)} END {printf "%.0f", usage}' 2>/dev/null || echo "N/A")
    cpu_temp=$(awk '{printf "%.0f", $1/1000}' /sys/class/thermal/thermal_zone0/temp 2>/dev/null || echo "N/A")
    local ip
    ip=$(ip -4 addr show scope global 2>/dev/null | grep -oP 'inet \K[\d.]+' | head -1 || echo "N/A")

    echo -e "\n${GREEN}=== EasePi A2 OLED Diagnostic Tool (Go) ===${NC}"
    echo -e "${YELLOW}Current status:${NC}"
    echo -e "  CPU: ${cpu_usage}%  Temp: ${cpu_temp}C   IP: ${ip}"
    echo -e "\n${YELLOW}Management commands:${NC}"
    echo -e "  View status:  systemctl status oled.service"
    echo -e "  Restart svc:  systemctl restart oled.service"
    echo -e "  Stop svc:     systemctl stop oled.service"
    echo -e "  Run foreground: ${OLED_BIN}"
    echo -e "  Detect device:  i2cdetect -y 3"
    echo -e "\n${YELLOW}Display modes:${NC}"
    echo -e "  Idle(1 line): IP only, bottom-aligned"
    echo -e "  CPU high(2 lines): CPU+temp top, IP bottom"
    echo -e "  NET high(2 lines): net speed top, IP bottom"
    echo -e "  Heavy load(3 lines): CPU | NET | IP"
    echo -e "\n${YELLOW}Thresholds:${NC}"
    echo -e "  CPU > 30% or Temp > 60C → CPU mode"
    echo -e "  NET > 100KB/s → NET mode"
    echo -e "  Both triggered → 3-line mode"
}

main() {
    clear
    show_usage
    echo -e "\n${GREEN}Starting diagnostics...${NC}\n"

    check_root
    check_files
    check_deps
    check_i2c
    check_service

    echo -e "\n${GREEN}=== Diagnostics Complete ===${NC}"
    echo -e "${YELLOW}Restart OLED service? (y/n)${NC}"
    read -r response
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        restart_service
    fi
}

main