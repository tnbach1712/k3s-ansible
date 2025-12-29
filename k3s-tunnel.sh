#!/bin/bash
# Script: k3s-tunnel.sh
# Mục đích: Tạo SSH tunnel từ máy local qua bastion tới VIP 192.168.0.50:6443
# Sử dụng: ./k3s-tunnel.sh start|stop|status

BASTION_USER=bachtn
BASTION_HOST=51.159.77.46
VIP=192.168.0.50
LOCAL_PORT=6443
REMOTE_PORT=6443

start_tunnel() {
  if lsof -iTCP:$LOCAL_PORT -sTCP:LISTEN | grep -q ssh; then
    echo "[INFO] Tunnel đã chạy trên port $LOCAL_PORT."
    exit 0
  fi
  echo "[INFO] Đang tạo SSH tunnel tới $VIP:$REMOTE_PORT qua $BASTION_HOST..."
  ssh -fN -L $LOCAL_PORT:$VIP:$REMOTE_PORT $BASTION_USER@$BASTION_HOST
  sleep 1
  if lsof -iTCP:$LOCAL_PORT -sTCP:LISTEN | grep -q ssh; then
    echo "[OK] Tunnel đã sẵn sàng trên localhost:$LOCAL_PORT"
  else
    echo "[ERROR] Không tạo được tunnel!"
    exit 1
  fi
}

stop_tunnel() {
  PID=$(lsof -t -iTCP:$LOCAL_PORT -sTCP:LISTEN -a -c ssh)
  if [ -n "$PID" ]; then
    kill $PID
    echo "[OK] Đã dừng tunnel (PID $PID)"
  else
    echo "[INFO] Không tìm thấy tunnel đang chạy."
  fi
}

status_tunnel() {
  if lsof -iTCP:$LOCAL_PORT -sTCP:LISTEN | grep -q ssh; then
    echo "[OK] Tunnel đang chạy trên localhost:$LOCAL_PORT"
  else
    echo "[INFO] Tunnel chưa chạy."
  fi
}

case "$1" in
  start)
    start_tunnel
    ;;
  stop)
    stop_tunnel
    ;;
  status)
    status_tunnel
    ;;
  *)
    echo "Usage: $0 {start|stop|status}"
    exit 1
    ;;
esac
