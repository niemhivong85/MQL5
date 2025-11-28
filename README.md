# MQL5 FVG Trading System

## 📁 Files

### 1. **FVG_Trading_EA.mq5** 🤖 EXPERT ADVISOR (TỰ ĐỘNG VÀO LỆNH)
Expert Advisor có khả năng giao dịch tự động:
- ✅ **TỰ ĐỘNG VÀO LỆNH** khi có tín hiệu
- ✅ **Quản lý lệnh tự động** (Partial close TP1/TP2/TP3)
- ✅ **EMA Trailing Exit**
- ✅ Fair Value Gap detection
- ✅ Interactive Trading Zones
- ✅ Sweep Pattern Detection
- ✅ Auto Position Sizing & Risk Management

**📖 Hướng dẫn EA:** [README_EA.md](README_EA.md) ⭐ RECOMMENDED

---

### 2. **FVG_Indicator_Enhanced.mq5** 📊 INDICATOR (CHỈ HIỂN THỊ)
Indicator version (không tự động vào lệnh):
- ✅ Phát hiện tín hiệu và alert
- ✅ Vẽ zones & levels
- ❌ Không vào lệnh tự động
- ❌ Không quản lý positions

**📖 Hướng dẫn Indicator:** [README_Enhanced.md](README_Enhanced.md)

---

## 🚀 Quick Start

### **Option 1: Expert Advisor (TỰ ĐỘNG VÀO LỆNH)** ⭐ RECOMMENDED

```bash
# Copy file vào thư mục MT5
MT5/MQL5/Experts/FVG_Trading_EA.mq5
```

**Sử dụng:**
1. Kéo EA vào chart
2. Bật "Allow Algo Trading"
3. Set `Auto_Trade = true`
4. Bấm nút **MUA** hoặc **BÁN**
5. Kéo ô vuông đến vị trí
6. Bấm **XÁC NHẬN**
7. **EA tự động vào lệnh** khi có tín hiệu! 🤖

---

### **Option 2: Indicator (CHỈ ALERT)**

```bash
# Copy file vào thư mục MT5
MT5/MQL5/Indicators/FVG_Indicator_Enhanced.mq5
```

**Sử dụng:**
1. Kéo indicator vào chart
2. Bấm nút **MUA** hoặc **BÁN**
3. Kéo ô vuông đến vị trí
4. Bấm **XÁC NHẬN**
5. Chờ alert, **vào lệnh thủ công**

---

## 🎯 Tính Năng Chính

### 🔹 Trading Zone Management
- Tạo vùng mua/bán bằng drag & drop
- Mitigation giống FVG (giảm dần khi giá chạm)
- Auto delete khi break hoặc fully mitigated

### 🔹 Pattern Detection
- **Sweep Candle:** Phát hiện nến hunt stop loss
- **Bottom/Top Formation:** Xác nhận đảo chiều trong N cây
- Linh hoạt điều chỉnh số cây để scan

### 🔹 Risk Management
- **Auto Stop Loss:** Dưới sweep candle hoặc zone edge + buffer
- **Position Sizing:** Tính lot tự động dựa vào rủi ro ($)
- **Take Profit:** 2 phương pháp (EMA trailing hoặc RR scaling)

### 🔹 Visual Feedback
- Vẽ Entry/SL/TP lines rõ ràng
- Alert với đầy đủ thông tin giao dịch
- Màu sắc tùy chỉnh

---

## 📊 Workflow

```
Create Zone → Confirm → Price Touch Zone → Sweep Detected → 
Pattern Found → Calculate SL/TP/Lot → Alert → Manual Entry
```

---

## ⚙️ Key Parameters

| Parameter | Default | Mô tả |
|-----------|---------|-------|
| `Sweep_Candles_Count` | 5 | Số cây để tìm pattern |
| `Risk_Amount_Per_Trade` | $100 | Số tiền rủi ro mỗi lệnh |
| `SL_Buffer_Points` | 5 | Buffer thêm cho SL |
| `EMA_Period` | 20 | EMA cho trailing exit |
| `RR_Level_1` | 1.0 | Target 1R |
| `RR_Close_Percent_1` | 50% | Đóng 50% ở 1R |

---

## 📚 Documentation

- [README_EA.md](README_EA.md) - **Expert Advisor (Auto Trading)** ⭐
- [README_Enhanced.md](README_Enhanced.md) - Indicator (Manual Trading)
- [FEATURES_SUMMARY.md](FEATURES_SUMMARY.md) - Technical Summary
- [FVG_Trading_EA.mq5](FVG_Trading_EA.mq5) - EA Source Code
- [FVG_Indicator_Enhanced.mq5](FVG_Indicator_Enhanced.mq5) - Indicator Source Code

---

## 🔄 Version History

### v2.00 (2025-11-28) - Expert Advisor Version 🤖
- ➕ **EXPERT ADVISOR: Tự động vào lệnh**
- ➕ **Auto trade execution với CTrade**
- ➕ **Partial close theo RR (TP1/TP2/TP3)**
- ➕ **Position management trong OnTick()**
- ➕ **EMA trailing exit**
- ➕ Trading zone với drag & drop interface
- ➕ Sweep pattern detection
- ➕ Bottom/Top formation detection
- ➕ Auto position sizing
- ➕ Zone mitigation (như FVG)
- ➕ Visual trade levels

### v1.03 - Original Version
- Fair Value Gap detection
- News filter by currency
- Basic FVG management

---

**Happy Trading! 📈**
