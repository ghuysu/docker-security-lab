# Quick Start Guide

Hướng dẫn nhanh test pipeline: Attack → Suricata → Loki → Grafana

## 1. Khởi động Lab

```bash
# Start containers
docker compose up -d

# Kiểm tra trạng thái (phải có 6 containers)
docker compose ps

# Verify Suricata loaded rules
docker logs suricata 2>&1 | grep "rules loaded"
```

## 2. Truy cập Grafana

1. Mở browser: **http://localhost:3000**
2. Login: `admin` / `admin`
3. Dashboards → **Suricata IDS - Real Attack Monitoring**
4. Set auto-refresh: **5s**

**Dashboard panels:**
- Real-time Attack Detection (7 attack types)
- Attack Distribution (pie chart)
- Tool Gauges (SQLMap, NMAP, Hydra, LFI)
- Live Logs (real-time alerts)
- Top 10 Attacks
- Severity Timeline

## 3. Chạy Attack Script

```bash
# Vào Kali container
docker compose exec kali bash
cd /tools

# Setup tools (lần đầu)
bash setup.sh

# Launch attack menu
./interactive_attack.sh
```

**Menu options:**
1. Port Scanning (NMAP)
2. SQL Injection (SQLMap)
3. Brute Force (Hydra)
4. LFI - Local File Inclusion
5. File Upload
6. XSS - Cross-Site Scripting
7. CSRF
8. **Run All Attacks** ← Test tổng hợp

## 4. Test Attacks

### Test đơn lẻ - SQL Injection

```bash
# Trong Kali menu
Select: 2

# Quan sát Grafana (5-10s):
# - SQLMap gauge: 0 → 50-200 (màu đỏ)
# - SQL Injection line spike
# - Logs flood với SQL alerts
```

### Test tổng hợp - All Attacks

```bash
# Trong Kali menu
Select: 8
Confirm: y

# Dashboard sẽ "bùng nổ":
# - Tất cả 7 lines spike đồng thời
# - Gauges chuyển đỏ/cam
# - Logs scroll cực nhanh
# - 300-500 alerts trong 5 phút
```

## 5. Xem Kết Quả

### Dashboard Real-time

**Trước attack:**
- All gauges: 0 (xanh)
- Logs: 0 lines
- Pie chart: trống

**Sau attack:**
- SQLMap gauge: 200+ (đỏ)
- NMAP gauge: 50+ (cam)
- Hydra gauge: 10+ (vàng)
- LFI gauge: 5+ (đỏ)
- Logs: 300-500 lines
- Pie chart: SQL 60%, XSS 15%, NMAP 10%, others 15%

### Explore Logs

Grafana → Explore → Datasource: Loki

**Useful queries:**

```logql
# Tất cả alerts
{job="suricata"}

# Chỉ SQL Injection
{job="suricata"} |~ "(?i)sql"

# Chỉ Critical severity
{job="suricata"} |~ "Priority: 1"

# Count by type
sum by (attack) (count_over_time({job="suricata"} [10m]))
```

### Check Alert Rules

Grafana → Alerting → Alert rules

**8 rules:**
- SQL Injection Alert (threshold >5)
- XSS Attack Alert (threshold >3)
- LFI Attack Alert (threshold >0)
- NMAP Scan Alert (threshold >0)
- Brute Force Alert (threshold >3)
- File Upload Alert (threshold >0)
- CSRF Alert (threshold >0)
- High Volume Alert (threshold >100)

**Status:**
- 🔴 Firing: Đang có attack
- 🟢 Normal: Không có attack
- ⏸️ Pending: Chờ threshold

## 6. Email Alerts (Optional)

### Setup Gmail

1. Google Account → Security → 2-Step Verification (enable)
2. App passwords → Create → Mail → Copy password (16 chars)
3. Edit `grafana/grafana.ini`:

```ini
[smtp]
user = your-email@gmail.com
password = abcd efgh ijkl mnop  # App password
from_address = your-email@gmail.com
```

4. Edit `grafana/provisioning/alerting/contact-points.yml`:

```yaml
settings:
  addresses: your-email@gmail.com
```

5. Restart Grafana:

```bash
docker compose restart grafana
```

### Test Email

Grafana → Alerting → Contact points → email-alerts → **Test**

**Expected alerts khi run all attacks:**
- `[FIRING] SQL Injection Detected` (Critical)
- `[FIRING] NMAP Port Scan Detected` (High)
- `[FIRING] Brute Force Attack` (High)
- `[FIRING] LFI - /etc/passwd Access` (Critical)
- `[FIRING] High Volume Attack` (Critical)

## 7. Troubleshooting

### Không thấy logs trong Grafana

```bash
# Check Promtail
docker logs promtail --tail 20

# Check Loki labels
curl http://localhost:3100/loki/api/v1/labels

# Test query
curl -G http://localhost:3100/loki/api/v1/query \
  --data-urlencode 'query={job="suricata"}' \
  --data-urlencode 'limit=5'
```

### Suricata không detect

```bash
# Validate config
docker exec suricata suricata -T -c /etc/suricata/suricata.conf

# Check logs
docker logs suricata --tail 50

# Verify rules
docker exec suricata cat /etc/suricata/rules/local.rules | grep -c "alert"
# Phải thấy: 39
```

### Dashboard không update

```bash
# Restart Grafana
docker compose restart grafana

# Check time range (góc phải dashboard)
# Set: Last 15 minutes

# Verify auto-refresh enabled
# Dropdown: 5s
```

## Quick Test Script

```bash
# Terminal 1: Start lab
docker compose up -d
docker logs suricata 2>&1 | grep "rules loaded"

# Terminal 2: Run attacks
docker compose exec kali bash -c 'cd /tools && ./interactive_attack.sh'
# Select: 8 (Run All)

# Terminal 3: Monitor
docker logs -f suricata | grep -i "alert"

# Browser: Watch dashboard explode!
# http://localhost:3000/d/suricata-realtime-attacks
```

## Expected Results

| Metric | Before | After All Attacks |
|--------|--------|------------------|
| Total Alerts | 0 | 300-500 |
| SQL Injection | 0 | 150-300 |
| XSS | 0 | 30-50 |
| NMAP Scan | 0 | 50-100 |
| Brute Force | 0 | 10-20 |
| LFI | 0 | 5-10 |
| Detection Time | - | 5-10 seconds |
| Alert Rules Firing | 0/8 | 6-8/8 |

## Next Steps

- Fine-tune thresholds in `suricata/rules/local.rules`
- Customize dashboard panels
- Add more attack scenarios
- Export logs to CSV for analysis
- Setup Slack/Discord notifications

**Lab fully working khi tất cả attacks được detect và hiển thị trong Grafana!** 🎯
