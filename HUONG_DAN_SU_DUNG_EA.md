# 🤖 HƯỚNG DẪN SỬ DỤNG EA - NHANH

## ⚠️ QUAN TRỌNG: Đây là EXPERT ADVISOR, không phải Indicator!

### 🔍 Kiểm Tra Bạn Đang Dùng File Nào?

**Nếu bạn đang dùng INDICATOR (sai):**
```
- File: FVG_Indicator_Enhanced.mq5
- Vị trí: MT5/MQL5/Indicators/
- Không tự động vào lệnh
- Chỉ alert
```

**Nếu bạn đang dùng EA (đúng):**
```
- File: FVG_Trading_EA.mq5  ⭐
- Vị trí: MT5/MQL5/Experts/
- TỰ ĐỘNG vào lệnh
- Có CTrade, position management
```

---

## 📦 CÁCH CÀI ĐẶT ĐÚNG

### **Bước 1: Copy File Đúng**
```bash
Copy file: FVG_Trading_EA.mq5
Vào thư mục: C:\Users\[YourName]\AppData\Roaming\MetaQuotes\Terminal\[ID]\MQL5\Experts\
```

### **Bước 2: Compile**
1. Mở MetaEditor (F4 trong MT5)
2. Navigator → Experts → FVG_Trading_EA.mq5
3. Bấm Compile (F7)
4. Phải thấy: "0 error(s), 0 warning(s)"

### **Bước 3: Kiểm Tra**
Trong Navigator của MT5, bạn phải thấy:
```
📁 Experts
  └─ 🤖 FVG_Trading_EA
```

**KHÔNG phải:**
```
📁 Indicators
  └─ 📊 FVG_Indicator_Enhanced
```

---

## 🎯 CÁCH SỬ DỤNG

### **Bước 1: Attach EA**
1. Kéo **FVG_Trading_EA** từ Navigator vào chart
2. Tab "Common":
   - ✅ Allow Algo Trading
   - ✅ Allow DLL imports
3. Tab "Inputs":
   - **Auto_Trade = true** ⚠️ (BẮT BUỘC để EA vào lệnh)
   - Buy_Zone_Color = Chọn màu bạn thích cho vùng MUA
   - Sell_Zone_Color = Chọn màu bạn thích cho vùng BÁN
   - Zone_Border_Width = 3 (viền dày = dễ kéo)
4. Bấm OK

### **Bước 2: Tạo Vùng Mua/Bán**

#### **📘 Tạo Vùng MUA:**
1. Bấm nút **"MUA"** (xanh lá, góc trên trái)
2. Sẽ xuất hiện **ô vuông màu xanh dương** (lớn, 200 points)
3. Label hiện: "🔵 BUY ZONE (Kéo để di chuyển)"

#### **📕 Tạo Vùng BÁN:**
1. Bấm nút **"BÁN"** (đỏ)
2. Sẽ xuất hiện **ô vuông màu cam đỏ** (lớn, 200 points)
3. Label hiện: "🔴 SELL ZONE (Kéo để di chuyển)"

### **Bước 3: Kéo Vùng**

#### **🖱️ CÁCH KÉO:**
1. **Click vào VIỀN** của ô vuông (viền dày 3px)
2. Giữ chuột
3. Kéo lên/xuống đến vị trí mong muốn
4. Nhả chuột

#### **💡 TIP để kéo dễ hơn:**
- Zoom chart ra (Ctrl + Scroll xuống)
- Click chính xác vào **VIỀN TRÊN** hoặc **VIỀN DƯỚI**
- Kéo theo chiều dọc (lên/xuống)

#### **🔧 Nếu vẫn khó kéo:**
- Right-click chart → Objects → Objects List
- Tìm "ZONE_BUY" hoặc "ZONE_SELL"
- Double-click để edit
- Thay đổi tọa độ giá (Price 1, Price 2)

### **Bước 4: Xác Nhận**
1. Khi đã đặt đúng vị trí
2. Bấm nút **"XÁC NHẬN"** (màu vàng)
3. Label thay đổi: "🔵 BUY ZONE [LOCKED]"
4. Không thể kéo nữa

### **Bước 5: EA Tự Động Làm Việc**
```
✅ EA theo dõi giá mỗi tick
✅ Phát hiện sweep candle
✅ Tìm bottom/top formation
✅ TỰ ĐỘNG VÀO LỆNH khi có tín hiệu
✅ Quản lý lệnh (partial close TP1/TP2/TP3)
✅ EMA exit
```

---

## 🎨 ĐỔI MÀU VÙNG

### **Trong EA Settings:**
1. Right-click chart → Expert Advisors → FVG_Trading_EA → Properties
2. Tab "Inputs"
3. Tìm:
   - **Buy_Zone_Color** → Chọn màu cho vùng MUA
   - **Sell_Zone_Color** → Chọn màu cho vùng BÁN
4. Bấm OK

### **Gợi ý màu:**
```
Buy Zone:
- clrDodgerBlue (mặc định)
- clrLimeGreen
- clrAqua
- clrCyan

Sell Zone:
- clrOrangeRed (mặc định)
- clrRed
- clrCrimson
- clrPink
```

---

## 🔧 TROUBLESHOOTING

### **❌ "EA không tự động vào lệnh"**

✅ **Check:**
1. Bạn đang dùng **FVG_Trading_EA.mq5** (EA), không phải Indicator?
2. Tab "Common" → "Allow Algo Trading" đã bật?
3. Tab "Inputs" → `Auto_Trade = true`?
4. Nút "Algo Trading" trên toolbar MT5 có màu xanh?
5. Check log: Tools → Options → Expert Advisors → Allow automated trading

### **❌ "Zone khó kéo"**

✅ **Giải pháp:**

**Cách 1: Tăng độ dày viền**
- EA Properties → Inputs
- `Zone_Border_Width = 5` (hoặc 10)

**Cách 2: Kéo thủ công**
- Right-click chart → Objects → Objects List
- Double-click "ZONE_BUY" hoặc "ZONE_SELL"
- Edit Price 1 và Price 2

**Cách 3: Zoom chart**
- Zoom out (Ctrl + Scroll xuống)
- Zone sẽ nhỏ hơn trên screen = dễ click

**Cách 4: Click chính xác**
- Click vào **VIỀN**, không click vào bên trong zone
- Viền dày 3-5px dễ click hơn

### **❌ "Zone không hiện"**

✅ **Check:**
1. Đã bấm nút MUA hoặc BÁN chưa?
2. Check log (Experts tab) có message "Buy zone created" không?
3. Zone có thể nằm ngoài khung nhìn → Zoom out hoặc scroll

---

## 📊 KẾT QUẢ MONG ĐỢI

### **Khi Setup Đúng:**

```
1. Bấm MUA → Zone màu XANH DƯƠNG xuất hiện
2. Kéo zone → Di chuyển được
3. Bấm XÁC NHẬN → Label đổi thành [LOCKED]
4. Giá chạm zone + có sweep → Alert "BUY SIGNAL"
5. EA tự động gửi lệnh → Check Terminal → Trade tab
6. Lệnh xuất hiện với:
   - Magic Number: 123456
   - Comment: FVG_EA
   - SL đã set
   - Volume theo Risk_Amount
```

### **Log Trong Experts Tab:**
```
✅ FVG Trading EA initialized successfully
✅ Auto Trade: ENABLED
✅ Buy zone created: 1.08450 - 1.08250
✅ Buy zone locked
💡 Zone có thể kéo. Click và drag viền để di chuyển!
BUY Signal: Sweep + Bottom formation detected!
Stop Loss calculated: 1.08200
Calculated Lot Size: 0.10
✅ Order placed successfully!
  Type: BUY
  Ticket: 123456789
  Lot: 0.10
  Entry: 1.08450
  SL: 1.08200
```

---

## 🆚 SO SÁNH EA vs INDICATOR

| | Indicator | EA |
|---|---|---|
| **File** | FVG_Indicator_Enhanced.mq5 | FVG_Trading_EA.mq5 |
| **Folder** | MQL5/Indicators/ | MQL5/Experts/ |
| **Icon** | 📊 | 🤖 |
| **Vào lệnh** | ❌ Thủ công | ✅ Tự động |
| **Quản lý lệnh** | ❌ | ✅ |
| **CTrade** | ❌ | ✅ |
| **OnTick** | OnCalculate | OnTick |

**→ Đảm bảo bạn đang dùng EA, không phải Indicator!**

---

## 📋 CHECKLIST TRƯỚC KHI SỬ DỤNG

- [ ] File đúng: FVG_Trading_EA.mq5 (không phải Indicator)
- [ ] Compile thành công (0 errors)
- [ ] Attach vào chart từ folder Experts
- [ ] Allow Algo Trading ✅
- [ ] Auto_Trade = true ✅
- [ ] Chọn màu zone theo ý thích
- [ ] Zone_Border_Width = 3 hoặc cao hơn
- [ ] Tạo zone thành công
- [ ] Kéo zone được
- [ ] Xác nhận zone
- [ ] Có log "EA initialized successfully"
- [ ] Test trên demo trước

---

## 💡 TIPS

### **Để Zone Dễ Kéo Nhất:**
```
1. Zone_Border_Width = 10
2. Zoom chart out
3. Click chính xác vào viền
4. Kéo theo chiều dọc (không kéo ngang)
5. Hoặc dùng Objects List để edit thủ công
```

### **Để Màu Đẹp:**
```
Buy Zone:
- clrDodgerBlue + Zone_Transparency = 70

Sell Zone:
- clrOrangeRed + Zone_Transparency = 70

Hoặc thử:
- Buy: clrLimeGreen
- Sell: clrCrimson
```

---

## 📞 HỖ TRỢ

Nếu vẫn gặp vấn đề:

1. Check file: `FVG_Trading_EA.mq5` (EA) hay `FVG_Indicator_Enhanced.mq5` (Indicator)?
2. Check log trong Experts tab
3. Screenshot và check setup
4. Đọc README_EA.md để biết thêm chi tiết

---

**File này:** HUONG_DAN_SU_DUNG_EA.md  
**Mục đích:** Hướng dẫn nhanh sử dụng EA và kéo zones  
**Version:** 2.0  

**Chúc bạn giao dịch thành công với EA! 🤖📈**
