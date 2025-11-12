# Docker Security Lab - README

## 📋 Kiến trúc hệ thống

Lab thực hành về **Network Security Monitoring** với stack hiện đại:

```
┌─────────────────────────────────────────────────────────┐
│                    Docker Security Lab                  │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  ┌──────────┐      ┌──────────┐      ┌──────────┐       │
│  │   Kali   │─────▶│   DVWA   │◀─────│  Snort   │       │
│  │  Linux   │      │   App    │      │   IDS    │       │
│  └──────────┘      └──────────┘      └────┬─────┘       │
│                                           │             │
│                                           │  logs       │
│                                           ▼             │
│  ┌──────────────────────────────────────────────────┐   │
│  │         Logging & Monitoring Stack               │   │
│  │                                                  │   │
│  │  Snort ──▶ Promtail ──▶ Loki ──▶ Grafana         │   │
│  │   (IDS)    (Shipper)   (Store)   (Visualize)     │   │
│  └──────────────────────────────────────────────────┘   │
│                                                         │
│  Access Points:                                         │
│  • Grafana: http://localhost:3000                       │
│  • Loki API: http://localhost:3100                      │
│  • DVWA: http://localhost:8081                          │
└─────────────────────────────────────────────────────────┘
```

## 🎯 Chiến lược và mục tiêu Lab

### **Phase 1: Observability Foundation (HIỆN TẠI)**
**Mục tiêu**: Xây dựng hệ thống logging tập trung với Grafana Loki Stack

**Stack hiện tại**:
- **Loki 2.9.0**: Log aggregation system (nhẹ hơn Elasticsearch)
- **Promtail 3.0.0**: Log shipper (đọc logs từ Snort)
- **Grafana 11.2.0**: Visualization dashboard


### **Phase 2: Attack & Detection (SẮP TỚI)**
- **Kali Linux**: Máy attacker
- **DVWA**: Target application với nhiều lỗ hổng
- **Snort IDS**: Phát hiện các cuộc tấn công real-time
- **Loki & Grafana**: Snort logs sẽ được Promtail thu thập và gửi lên Loki để phân tích trong Grafana

## 🚀 Setup từng bước

### **Bước 1: Kiểm tra prerequisites**
```bash
# Kiểm tra Docker
docker --version  # Cần >= 20.10
docker compose version  # Cần >= 2.0

# Kiểm tra port conflicts
lsof -i :3000  # Grafana
lsof -i :3100  # Loki
```

### **Bước 2: Chuẩn bị cấu trúc thư mục**
```bash
# Directory structure đã có sẵn
docker-security-lab/
├── docker-compose.yml
├── loki/
│   └── config.yml
├── promtail/
│   └── config.yml
└── snort/
    ├── rules/
    │   ├── local.
    │   ├── white_list.rules
    │   └── black_list.rules
    ├── log/                # Snort sẽ ghi logs vào đây
    └── snort.conf
```

### **Bước 3: Khởi động Logging Stack**
```bash
# Start Loki + Promtail + Grafana
docker compose up -d

# Kiểm tra status
docker compose ps

# Xem logs nếu có vấn đề
docker compose logs -f
```

### **Bước 4: Cấu hình Grafana**

1. **Truy cập Grafana**: http://localhost:3000
   - Username: `admin`
   - Password: `admin` (sẽ yêu cầu đổi lần đầu)

2. **Add Loki Data Source**:
   ```
   Configuration (⚙️) → Data Sources → Add data source
   → Chọn "Loki"
   → URL: http://loki:3100
   → Save & Test
   ```

3. **Import Snort Dashboard**:
   ```
   Create (+) → Import
   → Upload JSON file hoặc paste Dashboard ID
   → Chọn Loki data source
   → Import
   ```

### **Bước 5: Test Logging Pipeline**

```bash
docker compose up -d snort

# Tạo test traffic
docker exec snort ping -c 5 8.8.8.8

# Kiểm tra logs được tạo
ls -lh snort/log/

# Query logs trong Grafana
# Explore → Loki → Query: {job="snort"}
```

### **Bước 6: Enable Attack Scenario (Optional)**

Khi muốn test attack scenarios:

```bash
# 1. Uncomment DVWA và Kali trong docker-compose.yml
# 2. Restart stack
docker compose up -d

# 3. Setup DVWA
# Truy cập http://localhost:8081
# Click "Create/Reset Database"

# 4. Exec vào Kali
docker exec -it kali bash

# Install tools trong Kali
apt update && apt install -y nmap sqlmap

# 5. Test attack từ Kali → DVWA
# Snort sẽ detect và log
```

## 📊 Monitoring & Troubleshooting

### **Kiểm tra health của services**

```bash
# Loki health
curl http://localhost:3100/ready

# Promtail metrics
curl http://localhost:9080/metrics

# Container status
docker compose ps
docker compose logs <service-name>
```
## 🎓 Kịch bản thực hành

### **Scenario 1: Basic Log Collection**
1. Khởi động stack cơ bản (Loki + Promtail + Grafana)
2. Enable Snort
3. Tạo traffic và quan sát logs trong Grafana
4. Tạo dashboard đơn giản

### **Scenario 2: Attack Detection**
1. Enable DVWA và Kali
2. Thực hiện SQL Injection từ Kali
3. Quan sát Snort alerts trong Grafana
4. Phân tích patterns

### **Scenario 3: Custom Rules**
1. Thêm custom Snort rules
2. Test rules với specific payloads
3. Verify detection trong logs
4. Fine-tune để giảm false positives

## 📁 File quan trọng

| File | Mục đích | Chỉnh sửa |
|------|----------|-----------|
| `docker-compose.yml` | Định nghĩa services | Enable/disable services |
| `loki/config.yml` | Loki configuration | Retention, limits |
| `promtail/config.yml` | Log scraping config | Log paths, labels |
| `snort/snort.conf` | Snort IDS config | Network variables |
| `snort/rules/*.rules` | Detection rules | Add/modify signatures |

## 🔐 Security Notes

- ⚠️ **KHÔNG** dùng setup này cho production
- ⚠️ DVWA chứa lỗ hổng cố ý - chỉ dùng trong isolated network
- ⚠️ Grafana default credentials phải đổi ngay
- ⚠️ Snort chạy với NET_ADMIN capabilities - cần thiết cho packet capture

## 📚 Tài liệu tham khảo

- [Grafana Loki Documentation](https://grafana.com/docs/loki/latest/)
- [Promtail Configuration](https://grafana.com/docs/loki/latest/clients/promtail/)
- [Snort Rules Writing](https://docs.snort.org/rules/)
- [DVWA Documentation](https://github.com/digininja/DVWA)
