# FVG Indicator Enhanced - Hướng Dẫn Sử Dụng

## 📋 Tổng Quan

Indicator MQL5 nâng cao với các chức năng:
- ✅ Phát hiện Fair Value Gap (FVG)
- ✅ Lọc tin tức theo đồng tiền
- ✅ **TẠO VÀ QUẢN LÝ VÙNG GIAO DỊCH** (Trading Zones)
- ✅ **PHÁT HIỆN PATTERN SWEEP + ĐÁY/ĐỈNH**
- ✅ **TỰ ĐỘNG TÍNH STOP LOSS & POSITION SIZE**
- ✅ **CHỐT LỜI THEO EMA HOẶC RISK:REWARD**

---

## 🎯 Cách Sử Dụng

### **Bước 1: Tạo Vùng Giao Dịch**

1. **Bấm nút "MUA"** hoặc **"BÁN"** ở góc trên bên trái màn hình
2. Một **ô vuông màu** sẽ xuất hiện trên chart
3. **Kéo thả ô vuông** đến vị trí bạn muốn đặt vùng canh mua/bán
4. **Bấm "XÁC NHẬN"** để khóa vùng giao dịch

> **Lưu ý:** Sau khi xác nhận, ô vuông sẽ được cố định và bắt đầu theo dõi tín hiệu.

---

### **Bước 2: Indicator Tự Động Làm Gì?**

Khi giá chạm vào vùng giao dịch, indicator sẽ:

#### **1️⃣ Phát Hiện Nến Sweep**

**Với vùng MUA (Buy Zone):**
- Tìm nến có **Low thấp hơn Low** của cây trước
- Kiểm tra điều kiện đóng cửa:
  - Nến đỏ: `Close >= Close[trước]`
  - Nến xanh: `Close >= Open[trước]`

**Với vùng BÁN (Sell Zone):**
- Tìm nến có **High cao hơn High** của cây trước
- Kiểm tra điều kiện đóng cửa tương tự (ngược lại)

#### **2️⃣ Tìm Pattern Tạo Đáy/Đỉnh**

Sau khi phát hiện sweep, đếm **N cây nến** (có thể điều chỉnh):

**Tạo Đáy (cho Buy):**
- `Close[i] > High[i+1]`
- Xác nhận xu hướng tăng

**Tạo Đỉnh (cho Sell):**
- `Close[i] < Low[i+1]`
- Xác nhận xu hướng giảm

#### **3️⃣ Tính Toán Tự Động**

Khi có tín hiệu hợp lệ, indicator sẽ:

| Tính Toán | Cách Thức |
|-----------|-----------|
| **Entry** | Giá hiện tại (Ask/Bid) |
| **Stop Loss** | Dưới cây sweep + buffer (có thể chọn dưới zone) |
| **Lot Size** | Dựa vào số tiền rủi ro / khoảng cách SL |
| **TP1, TP2, TP3** | Dựa vào tỷ lệ Risk:Reward (1R, 2R, 3R) |

#### **4️⃣ Vẽ Các Đường Giá**

- 🟡 **Entry Line** (màu vàng)
- 🔴 **Stop Loss Line** (màu đỏ, đường chấm)
- 🟢 **TP1, TP2, TP3 Lines** (màu xanh, đường gạch)

#### **5️⃣ Hiển Thị Alert**

Một thông báo chi tiết sẽ xuất hiện:

```
BUY SIGNAL
Entry: 1.08450
SL: 1.08350 (100.0 pts)
Lot: 0.10
TP1: 1.08550 | TP2: 1.08650 | TP3: 1.08750
```

---

### **Bước 3: Quản Lý Vùng**

#### **Sửa Vùng:**
- Bấm nút **"SỬA"**
- Ô vuông có thể di chuyển lại
- Tín hiệu sẽ reset

#### **Mitigation (Giảm Vùng):**
Giống FVG, khi giá chạm vào:
- **Buy Zone:** Giá chạm từ dưới → giảm `top` xuống
- **Sell Zone:** Giá chạm từ trên → tăng `bottom` lên
- Nếu vùng quá nhỏ → **Tự động xóa**

#### **Delete Zone:**
Vùng sẽ bị xóa khi:
- Giá break qua vùng (đóng cửa bên ngoài)
- Vùng bị mitigate hoàn toàn

---

## ⚙️ Cài Đặt Input Parameters

### **📌 Trading Zone Settings**

```cpp
Sweep_Candles_Count = 5           // Số cây nến để tìm đáy/đỉnh (tính từ sweep)
Enable_Alert = true               // Bật thông báo
Enable_Sound = true               // Bật âm thanh
Zone_Mitigate_On_Touch = true     // Giảm zone khi giá chạm (như FVG)
Zone_Delete_On_Break = true       // Xóa zone khi giá break
```

### **📌 Stop Loss Settings**

```cpp
SL_Use_Sweep_Low = true           // SL dưới cây sweep (ưu tiên)
SL_Use_Zone_Edge = false          // SL dưới zone edge
SL_Buffer_Points = 5              // Thêm buffer cho SL (points)
```

### **📌 Position Sizing**

```cpp
Risk_Amount_Per_Trade = 100.0     // Số tiền rủi ro mỗi lệnh ($)
Auto_Calculate_Lot = true         // Tự động tính lot size
Manual_Lot_Size = 0.01            // Lot size thủ công (nếu tắt auto)
```

**Công thức tính Lot:**

```
Lot Size = Risk Amount / (SL Points × Point Value)
```

### **📌 Take Profit - EMA Trailing**

```cpp
Use_EMA_Exit = true               // Chốt lời theo EMA
EMA_Period = 20                   // Chu kỳ EMA
EMA_Timeframe = PERIOD_CURRENT    // Timeframe EMA
```

**Cách hoạt động:**
- **Buy:** Đóng cửa dưới EMA → Chốt lời
- **Sell:** Đóng cửa trên EMA → Chốt lời

### **📌 Take Profit - Risk Reward**

```cpp
Use_RR_Exit = true                // Chốt lời theo RR

// Level 1
RR_Level_1 = 1.0                  // 1R (1:1)
RR_Close_Percent_1 = 50.0         // Đóng 50%

// Level 2
RR_Level_2 = 2.0                  // 2R (1:2)
RR_Close_Percent_2 = 30.0         // Đóng thêm 30%

// Level 3
RR_Level_3 = 3.0                  // 3R (1:3)
RR_Close_Percent_3 = 20.0         // Đóng hết còn lại
```

**Ví dụ:**
- Lot gốc: 0.10
- TP1 (1R): Đóng 0.05 lot (50%)
- TP2 (2R): Đóng 0.03 lot (30%)
- TP3 (3R): Đóng 0.02 lot (20% còn lại)

---

## 📊 Workflow Hoàn Chỉnh

```
1. Bấm nút MUA/BÁN
   ↓
2. Kéo ô vuông đến vị trí mong muốn
   ↓
3. Bấm XÁC NHẬN
   ↓
4. Chờ giá chạm vào zone
   ↓
5. Indicator phát hiện Sweep
   ↓
6. Đếm N cây để tìm pattern đáy/đỉnh
   ↓
7. TÌM THẤY → Tính toán SL/TP/Lot
   ↓
8. Vẽ các đường giá + Alert
   ↓
9. Bạn đặt lệnh thủ công hoặc copy thông tin
   ↓
10. Theo dõi EMA hoặc RR để chốt lời
```

---

## 🎨 Màu Sắc Tùy Chỉnh

```cpp
Buy_Zone_Color = clrDodgerBlue    // Màu vùng mua
Sell_Zone_Color = clrOrangeRed    // Màu vùng bán
Button_Buy_Color = clrLimeGreen   // Màu nút mua
Button_Sell_Color = clrRed        // Màu nút bán
Button_Confirm_Color = clrGold    // Màu nút xác nhận
Button_Edit_Color = clrOrange     // Màu nút sửa
SL_Line_Color = clrRed            // Màu đường SL
TP_Line_Color = clrGreen          // Màu đường TP
Zone_Transparency = 70            // Độ trong suốt zone (%)
```

---

## 📝 Lưu Ý Quan Trọng

### ✅ **Ưu điểm:**
- Tự động phát hiện setup chất lượng cao
- Tính toán position sizing khoa học
- Quản lý rủi ro chặt chẽ
- Linh hoạt với 2 phương pháp chốt lời

### ⚠️ **Lưu ý:**
- Indicator **KHÔNG TỰ ĐỘNG ĐẶT LỆNH**
- Bạn phải đặt lệnh thủ công theo thông tin
- Nên backtest trước khi dùng live
- Điều chỉnh parameters cho phù hợp với style giao dịch

### 🔧 **Troubleshooting:**

| Vấn đề | Giải pháp |
|--------|-----------|
| Không có tín hiệu | Kiểm tra zone có đúng vị trí không |
| Lot size = 0 | Tăng Risk_Amount hoặc giảm SL_Buffer |
| Zone biến mất | Giá đã break hoặc mitigate xong |
| EMA không hoạt động | Kiểm tra EMA_Period và timeframe |

---

## 🚀 Cài Đặt

1. Copy file `FVG_Indicator_Enhanced.mq5` vào thư mục:
   ```
   MT5/MQL5/Indicators/
   ```

2. Compile trong MetaEditor (F7)

3. Kéo vào chart và thiết lập parameters

4. Sử dụng theo workflow ở trên

---

## 📞 Support

Nếu có thắc mắc về code hoặc cần thêm chức năng, hãy liên hệ!

**Version:** 2.00
**Ngày cập nhật:** 2025-11-28

---

## 🎓 Kiến Thức Bổ Sung

### **Sweep Pattern:**
- Là động thái "hunt stop loss" của thị trường
- Thường xảy ra trước khi đảo chiều mạnh
- Kết hợp với pattern đáy/đỉnh tăng độ tin cậy

### **Position Sizing:**
- Luôn rủi ro cố định mỗi lệnh
- Không nên vượt quá 1-2% tài khoản
- Điều chỉnh Risk_Amount phù hợp

### **Risk:Reward:**
- Tối thiểu 1:1, lý tưởng 1:2 hoặc cao hơn
- Scaling out giúp lock profit sớm
- Giữ một phần để target lớn hơn

---

**Chúc bạn giao dịch thành công! 📈**
