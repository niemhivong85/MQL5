# MQL5 FVG Indicator Project

## 📁 Files

### 1. **FVG_Indicator_Enhanced.mq5** ⭐ NEW!
Enhanced version với đầy đủ tính năng giao dịch:
- ✅ Fair Value Gap detection
- ✅ News filter by currency
- ✅ **Interactive Trading Zones (Drag & Drop)**
- ✅ **Sweep Pattern Detection**
- ✅ **Auto Position Sizing & Risk Management**
- ✅ **Dual Exit Strategy (EMA Trailing + Risk:Reward)**

**📖 Xem hướng dẫn chi tiết:** [README_Enhanced.md](README_Enhanced.md)

---

## 🚀 Quick Start

### Cài đặt:
```bash
# Copy file vào thư mục MT5
MT5/MQL5/Indicators/FVG_Indicator_Enhanced.mq5
```

### Sử dụng:
1. Kéo indicator vào chart
2. Bấm nút **MUA** hoặc **BÁN**
3. Kéo ô vuông đến vị trí mong muốn
4. Bấm **XÁC NHẬN**
5. Chờ tín hiệu Sweep + Pattern

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

- [README_Enhanced.md](README_Enhanced.md) - Hướng dẫn chi tiết
- [FVG_Indicator_Enhanced.mq5](FVG_Indicator_Enhanced.mq5) - Source code

---

## 🔄 Version History

### v2.00 (2025-11-28) - Enhanced Version
- ➕ Trading zone với drag & drop interface
- ➕ Sweep pattern detection
- ➕ Bottom/Top formation detection
- ➕ Auto position sizing
- ➕ Dual exit strategy (EMA + RR)
- ➕ Zone mitigation (như FVG)
- ➕ Visual trade levels

### v1.03 - Original Version
- Fair Value Gap detection
- News filter by currency
- Basic FVG management

---

**Happy Trading! 📈**
