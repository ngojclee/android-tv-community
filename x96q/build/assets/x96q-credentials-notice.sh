# Show the first-boot credentials once per boot, for root shells only.
if [ "$(id -u)" = 0 ] && [ -r /root/.x96q-credentials ] && [ ! -f /run/x96q-creds-shown ]; then
    echo
    /usr/local/sbin/x96q-creds 2>/dev/null || true
    : >/run/x96q-creds-shown 2>/dev/null || true
fi
