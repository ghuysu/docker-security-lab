# Docker Security Lab

Lab thực hành **Network Security Monitoring** với Suricata IDS, Loki, và Grafana.

## Kiến trúc

```
┌─────────────────────────────────────────────────────┐
│  Kali Linux  ──(attacks)──▶  DVWA Web App          │
│                                  │                  │
│                                  ▼                  │
│                          Suricata IDS               │
│                                  │                  │
│                                  ▼                  │
│              Promtail ──▶ Loki ──▶ Grafana          │
└─────────────────────────────────────────────────────┘
```

**Components:**
- **Kali Linux**: Máy tấn công với tools (nmap, sqlmap, hydra)
- **DVWA**: Ứng dụng web có lỗ hổng (target)
- **Suricata 8.0**: IDS phát hiện tấn công real-time
- **Loki 2.9**: Log storage
- **Promtail 3.0**: Log shipper
- **Grafana 11.2**: Dashboard & alerts

## Quick Start

```bash
# 1. Khởi động tất cả services
docker compose up -d

# 2. Setup tools trong Kali (lần đầu)
docker compose exec kali bash -c 'cd /tools && bash setup.sh'

# 3. Truy cập Grafana
# URL: http://localhost:3000
# Login: admin/admin

# 4. Chạy attack script
docker compose exec kali bash
cd /tools
./interactive_attack.sh
```

## Attack Scenarios

Script `interactive_attack.sh` hỗ trợ 7 loại tấn công:

1. **Port Scan** - nmap reconnaissance
2. **SQL Injection** - database attacks  
3. **XSS** - cross-site scripting
4. **LFI** - local file inclusion
5. **Brute Force** - password guessing
6. **File Upload** - malicious file upload
7. **CSRF** - cross-site request forgery

Mỗi attack sẽ trigger alert trong Grafana sau 1-2 phút.

## Dashboards & Alerts

**Access Points:**
- Grafana: http://localhost:3000
- DVWA: http://localhost:8081
- Loki API: http://localhost:3100

**Dashboards:**
- **Suricata IDS - Real Attack Monitoring**: Overview tất cả attacks
- **Suricata IDS - Simple Monitor**: View logs real-time

**Alert Rules (8 rules):**
- SQL Injection, XSS, LFI (Critical/High)
- Port Scan, Brute Force, File Upload (High)
- CSRF (Medium)
- High Volume Attack (Critical)

## Kiểm tra hoạt động

```bash
# Container status
docker compose ps

# Suricata logs
tail -f suricata/logs/fast.log
grep "NMAP\|SQL\|XSS" suricata/logs/fast.log

# Loki có nhận logs không
curl 'http://localhost:3100/loki/api/v1/label/job/values'
# Kết quả: {"data":["suricata"]}

# Alert rules health
# Grafana → Alerting → Alert rules
```

## Cấu trúc thư mục

```
.
├── docker-compose.yml
├── kali/
│   ├── interactive_attack.sh    # Attack script
│   └── setup.sh                 # Install tools
├── suricata/
│   ├── suricata.yaml           # Suricata config
│   ├── rules/local.rules       # Detection rules (39 rules)
│   └── logs/
│       ├── eve.json            # JSON logs → Loki
│       └── fast.log            # Text alerts
├── grafana/provisioning/
│   ├── dashboards/             # 2 dashboards
│   ├── alerting/alert-rules.yml # 8 alert rules
│   └── datasources/loki.yml
├── promtail/config.yml
└── loki/config.yml
```

## Troubleshooting

**Suricata không detect:**
- Kiểm tra bridge interface: `docker network inspect docker-security-lab_lab-net`
- Xem log: `docker compose logs suricata`
- NMAP scan cần >= 10 ports để trigger threshold

**Alert rules error:**
- Check datasource UID: `uid: loki` trong `loki.yml`
- Restart Grafana: `docker compose restart grafana`

**DVWA không resolve:**
- Network alias đã được set, restart containers
- Test: `docker compose exec kali getent hosts dvwa`

## Security Warning

⚠️ Lab này chỉ dùng cho mục đích học tập:
- DVWA chứa lỗ hổng cố ý
- Không expose ports ra internet
- Chỉ chạy trong môi trường isolated

## Làm sạch

```bash
# Dừng tất cả
docker compose down

# Xóa volumes (data sẽ mất)
docker compose down -v

# Xóa orphaned containers
docker compose down --remove-orphans
```
