# 🤖 FVG Trading EA - Expert Advisor

## 📋 Tổng Quan

Expert Advisor (EA) MQL5 có khả năng **TỰ ĐỘNG VÀO LỆNH** dựa trên:
- ✅ Pattern Sweep + Bottom/Top Formation
- ✅ Trading Zones (vùng mua/bán)
- ✅ Auto Position Sizing (tính lot tự động)
- ✅ Auto Stop Loss placement
- ✅ Partial close theo Risk:Reward (1R, 2R, 3R)
- ✅ EMA Trailing Exit

---

## 🚀 Sự Khác Biệt So Với Indicator

| Feature | Indicator | EA |
|---------|-----------|-----|
| **Phát hiện tín hiệu** | ✅ | ✅ |
| **Vẽ zones & levels** | ✅ | ✅ |
| **Alert** | ✅ | ✅ |
| **Tự động vào lệnh** | ❌ | ✅ |
| **Quản lý lệnh** | ❌ | ✅ |
| **Partial close TP** | ❌ | ✅ |
| **EMA exit** | ❌ | ✅ |
| **Trailing stop** | ❌ | ✅ |

---

## 🎯 Cách Sử Dụng

### **Bước 1: Cài Đặt**

```bash
# Copy file vào thư mục MT5
MT5/MQL5/Experts/FVG_Trading_EA.mq5
```

Compile trong MetaEditor (F7)

### **Bước 2: Attach EA Vào Chart**

1. Mở chart (ví dụ: EURUSD M15)
2. Kéo EA vào chart
3. Trong tab "Common":
   - ✅ Bật "Allow Algo Trading"
   - ✅ Bật "Allow DLL imports" (nếu cần)
4. Trong tab "Inputs":
   - Thiết lập parameters (xem bên dưới)
   - **Quan trọng:** `Auto_Trade = true` để EA thực sự vào lệnh

### **Bước 3: Tạo Trading Zone**

1. Bấm nút **"MUA"** hoặc **"BÁN"**
2. Kéo ô vuông đến vị trí mong muốn
3. Bấm **"XÁC NHẬN"**
4. EA sẽ tự động:
   - Theo dõi giá
   - Phát hiện Sweep + Pattern
   - Vào lệnh khi có tín hiệu
   - Quản lý TP/SL

---

## ⚙️ Parameters Quan Trọng

### **📌 EA Settings (Quan Trọng Nhất)**

```cpp
Magic_Number = 123456           // Mã nhận diện lệnh của EA
Auto_Trade = true               // ⚠️ BẬT/TẮT tự động vào lệnh
Trade_Comment = "FVG_EA"        // Comment trên lệnh
```

⚠️ **Lưu ý:** Nếu `Auto_Trade = false`, EA chỉ alert, không vào lệnh!

### **📌 Position Sizing**

```cpp
Risk_Amount_Per_Trade = 100.0   // Số tiền rủi ro mỗi lệnh ($)
Auto_Calculate_Lot = true       // Tự động tính lot
Manual_Lot_Size = 0.01          // Lot cố định (nếu tắt auto)
Max_Slippage = 10               // Slippage tối đa (points)
```

**Công thức tính lot:**
```
Lot = Risk Amount / (SL Points × Point Value)
```

### **📌 Stop Loss**

```cpp
SL_Use_Sweep_Low = true         // SL dưới sweep (ưu tiên)
SL_Use_Zone_Edge = false        // SL dưới zone edge
SL_Buffer_Points = 5            // Buffer thêm cho SL
```

### **📌 Take Profit - Risk:Reward**

```cpp
Use_RR_Exit = true              // Bật chốt lời theo RR

// Level 1: Chốt 50% ở 1R
RR_Level_1 = 1.0
RR_Close_Percent_1 = 50.0

// Level 2: Chốt 30% ở 2R  
RR_Level_2 = 2.0
RR_Close_Percent_2 = 30.0

// Level 3: Chốt 20% còn lại ở 3R
RR_Level_3 = 3.0
RR_Close_Percent_3 = 20.0
```

**Ví dụ với lot 0.10:**
- TP1 (1R): Đóng 0.05 lot
- TP2 (2R): Đóng 0.03 lot
- TP3 (3R): Đóng 0.02 lot còn lại

### **📌 Take Profit - EMA Trailing**

```cpp
Use_EMA_Exit = true             // Bật EMA exit
EMA_Period = 20                 // Chu kỳ EMA
EMA_Timeframe = PERIOD_CURRENT  // Timeframe
```

**Logic:**
- Buy: Nến đóng cửa dưới EMA → Close position
- Sell: Nến đóng cửa trên EMA → Close position

### **📌 Pattern Detection**

```cpp
Sweep_Candles_Count = 5         // N cây để tìm pattern
```

---

## 📊 Workflow Tự Động

```
1. User tạo Trading Zone (Mua/Bán)
   ↓
2. User bấm XÁC NHẬN
   ↓
3. EA theo dõi giá mỗi tick (OnTick)
   ↓
4. Giá chạm vào zone
   ↓
5. EA phát hiện Sweep Candle
   ↓
6. EA tìm Bottom/Top Formation trong N cây
   ↓
7. ✅ TÌM THẤY PATTERN
   ↓
8. EA tính toán:
   - Entry price (Ask/Bid)
   - Stop Loss (dưới sweep + buffer)
   - Lot Size (dựa trên risk)
   - TP1, TP2, TP3 (theo RR)
   ↓
9. EA GỬI LỆNH (nếu Auto_Trade = true)
   ↓
10. EA quản lý lệnh:
   - Theo dõi giá mỗi tick
   - Partial close khi chạm TP1, TP2, TP3
   - Hoặc close theo EMA
   - Stop Loss tự động bởi broker
```

---

## 🔍 Theo Dõi Lệnh

### **Trong Terminal:**

```
Experts > [Your Account] 
```

Bạn sẽ thấy log:
```
✅ Order placed successfully!
  Type: BUY
  Ticket: 123456789
  Lot: 0.10
  Entry: 1.08450
  SL: 1.08350

✅ Partial close success: 0.05 lots at TP1
✅ Partial close success: 0.03 lots at TP2
✅ Partial close success: 0.02 lots at TP3
```

### **Trong Toolbox > Trade:**

Bạn sẽ thấy position với:
- Symbol
- Volume (giảm dần khi partial close)
- Entry price
- Current P/L
- SL level

---

## 🎨 Visual Feedback

EA vẽ các đường:

| Đường | Màu | Style | Mô tả |
|-------|-----|-------|-------|
| **Entry** | Vàng | Solid | Giá vào lệnh |
| **SL** | Đỏ | Dotted | Stop Loss |
| **TP1** | Xanh | Dashed | Target 1R (50%) |
| **TP2** | Xanh | Dashed | Target 2R (30%) |
| **TP3** | Xanh | Dashed | Target 3R (20%) |

---

## ⚠️ Lưu Ý Quan Trọng

### ✅ **Ưu điểm:**

- Tự động vào lệnh 24/7
- Quản lý rủi ro chặt chẽ
- Partial close giúp lock profit sớm
- Không bỏ lỡ tín hiệu

### ⚠️ **Rủi ro:**

- EA chỉ tốt nếu strategy đúng
- Cần backtest kỹ trước
- Theo dõi thường xuyên
- Không để chạy không giám sát

### 🔧 **Checklist Trước Khi Chạy Live:**

- [ ] Backtest trên demo ít nhất 1-2 tuần
- [ ] Test với tài khoản demo trước
- [ ] Kiểm tra `Auto_Trade = true`
- [ ] Kiểm tra `Risk_Amount` hợp lý
- [ ] Kiểm tra broker cho phép EA
- [ ] Kiểm tra spread và commission
- [ ] Có plan quản lý vốn
- [ ] Hiểu rõ pattern Sweep

---

## 🔧 Troubleshooting

### **EA không vào lệnh:**

✅ Check:
- `Auto_Trade = true`?
- "Allow Algo Trading" enabled?
- Có tín hiệu hợp lệ chưa?
- Tài khoản đủ margin?
- Broker cho phép trading?

### **Lot size = 0:**

✅ Fix:
- Tăng `Risk_Amount_Per_Trade`
- Giảm `SL_Buffer_Points`
- Hoặc dùng `Manual_Lot_Size`

### **Position không close tại TP:**

✅ Check:
- `Use_RR_Exit = true`?
- Giá đã chạm TP chưa?
- EA vẫn đang chạy?
- Check log trong Experts

### **Error khi compile:**

✅ Fix:
- Cần MQL5 build 3000 trở lên
- Include <Trade\Trade.mqh> phải có
- Check syntax errors

---

## 📈 Best Practices

### **1. Position Sizing:**
- Risk 1-2% mỗi lệnh
- Không quá 5% total exposure
- Adjust `Risk_Amount` theo tài khoản

### **2. Timeframes:**
- M15-H1: Tốt nhất
- M5: Nhiều noise
- H4+: Ít setup

### **3. Symbols:**
- Major pairs: EUR/USD, GBP/USD, etc.
- Low spread
- High liquidity

### **4. Sessions:**
- London + New York: Tốt nhất
- Asian: Ít biến động
- News time: Cẩn thận

---

## 🔄 Updates & Maintenance

### **Backup Settings:**
Lưu file `.set` với parameters của bạn:
- Right-click EA on chart
- Properties > Inputs > Save

### **Monitor Performance:**
Check hàng ngày:
- Win rate
- Average RR
- Drawdown
- Sharpe ratio

---

## 📞 Support & FAQ

### **Q: EA có giao dịch tự động 100%?**
A: Có, nhưng bạn vẫn phải tạo zones bằng tay và xác nhận.

### **Q: Có thể chạy trên nhiều chart?**
A: Có, dùng `Magic_Number` khác nhau cho mỗi chart.

### **Q: Tôi có thể manual close lệnh không?**
A: Có, nhưng EA sẽ không quản lý nữa.

### **Q: EA có tự động tạo zone không?**
A: Không, bạn phải tạo zone manually.

### **Q: Cần VPS không?**
A: Nên dùng VPS để EA chạy 24/7.

---

## 📚 Files

- `FVG_Trading_EA.mq5` - File EA chính
- `README_EA.md` - Hướng dẫn này
- `FVG_Indicator_Enhanced.mq5` - Version indicator (không giao dịch)

---

## ⚡ Quick Setup (TL;DR)

```
1. Copy FVG_Trading_EA.mq5 vào MT5/MQL5/Experts/
2. Compile (F7)
3. Kéo vào chart
4. Set Auto_Trade = true
5. Set Risk_Amount = 100
6. Bấm OK
7. Bấm nút MUA/BÁN để tạo zone
8. Kéo zone đến vị trí
9. Bấm XÁC NHẬN
10. EA tự động vào lệnh khi có setup!
```

---

**Version:** 2.00  
**Type:** Expert Advisor  
**Platform:** MetaTrader 5  
**Language:** MQL5  

**⚠️ DISCLAIMER:** Trading có rủi ro. Backtest kỹ trước khi dùng live. Không chịu trách nhiệm về lỗ lãi.

**Happy Auto Trading! 🤖📈**
