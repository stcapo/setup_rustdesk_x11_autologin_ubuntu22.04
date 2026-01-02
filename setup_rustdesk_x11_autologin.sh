#!/usr/bin/env bash
set -e

# =========================
# Config (可改)
# =========================
TARGET_USER="xc"
RUSTDESK_BIN="/usr/bin/rustdesk"
GDM_CONF="/etc/gdm3/custom.conf"

echo "=== RustDesk X11 Auto-Login Setup ==="

# =========================
# 0. 基础检查
# =========================
if [[ $EUID -ne 0 ]]; then
  echo "[ERROR] 请使用 root 运行该脚本"
  exit 1
fi

if ! id "$TARGET_USER" >/dev/null 2>&1; then
  echo "[ERROR] 用户 $TARGET_USER 不存在"
  exit 1
fi

if [[ ! -x "$RUSTDESK_BIN" ]]; then
  echo "[ERROR] 未找到 rustdesk 可执行文件: $RUSTDESK_BIN"
  exit 1
fi

# =========================
# 1. 禁用 Wayland
# =========================
echo "[1/5] 禁用 Wayland (启用 X11)"

mkdir -p "$(dirname "$GDM_CONF")"
touch "$GDM_CONF"

if grep -q '^#\?WaylandEnable=' "$GDM_CONF"; then
  sed -i 's/^#\?WaylandEnable=.*/WaylandEnable=false/' "$GDM_CONF"
else
  echo "WaylandEnable=false" >> "$GDM_CONF"
fi

# =========================
# 2. 启用 GDM 自动登录
# =========================
echo "[2/5] 配置 GDM 自动登录用户: $TARGET_USER"

if grep -q '^\[daemon\]' "$GDM_CONF"; then
  sed -i '/^\[daemon\]/a AutomaticLoginEnable=true\nAutomaticLogin='"$TARGET_USER" "$GDM_CONF"
else
  cat >> "$GDM_CONF" <<EOF

[daemon]
AutomaticLoginEnable=true
AutomaticLogin=$TARGET_USER
EOF
fi

# =========================
# 3. 配置 RustDesk 桌面自启
# =========================
echo "[3/5] 配置 RustDesk GNOME 桌面自启"

AUTOSTART_DIR="/home/$TARGET_USER/.config/autostart"
AUTOSTART_FILE="$AUTOSTART_DIR/rustdesk.desktop"

mkdir -p "$AUTOSTART_DIR"

cat > "$AUTOSTART_FILE" <<EOF
[Desktop Entry]
Type=Application
Name=RustDesk
Exec=$RUSTDESK_BIN
X-GNOME-Autostart-enabled=true
EOF

chown -R "$TARGET_USER:$TARGET_USER" "/home/$TARGET_USER/.config"

# =========================
# 4. 禁用 systemd rustdesk.service
# =========================
echo "[4/5] 禁用 systemd rustdesk.service (避免无桌面时退出)"

systemctl disable --now rustdesk 2>/dev/null || true
systemctl stop rustdesk 2>/dev/null || true

# =========================
# 5. 完成 & 提示重启
# =========================
echo "[5/5] 配置完成 ✅"

echo
echo "================= RESULT ================="
echo "✔ Wayland 已禁用 (X11)"
echo "✔ GDM 自动登录用户: $TARGET_USER"
echo "✔ RustDesk 将在 $TARGET_USER 桌面启动"
echo "✔ systemd rustdesk.service 已禁用"
echo "=========================================="
echo
echo "👉 请执行: sudo reboot"
echo "👉 重启后无需 VNC，Windows 端可直接 RustDesk 远控"
