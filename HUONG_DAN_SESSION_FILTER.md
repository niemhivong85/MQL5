# 🌍 HƯỚNG DẪN SESSION FILTER (Lọc Phiên Giao Dịch)

## 📋 Tổng Quan

Session Filter giúp EA **CHỈ VÀO LỆNH** trong phiên giao dịch bạn chọn.

**Ví dụ:**
- Chọn **London Session** → EA chỉ vào lệnh từ 8:00-17:00 GMT
- Chọn **New York Session** → EA chỉ vào lệnh từ 13:00-22:00 GMT
- Ngoài phiên đó → EA **KHÔNG vào lệnh mới** (nhưng vẫn quản lý lệnh cũ)

---

## 🕐 CÁC PHIÊN GIAO DỊCH

### **1. Asian Session (Phiên Á - Tokyo)**
```
Thời gian GMT: 00:00 - 09:00
Đặc điểm:
- Biến động thấp
- Spread thấp
- Phù hợp: Range trading
- Pairs: USD/JPY, AUD/JPY, NZD/JPY
```

### **2. London Session (Phiên Âu)**
```
Thời gian GMT: 08:00 - 17:00
Đặc điểm:
- Biến động cao nhất
- Volume lớn
- Phù hợp: Breakout, Trend
- Pairs: EUR/USD, GBP/USD, EUR/GBP
```

### **3. New York Session (Phiên Mỹ)**
```
Thời gian GMT: 13:00 - 22:00
Đặc điểm:
- Biến động cao
- Overlap với London (13:00-17:00 = tốt nhất)
- Phù hợp: Trend, News trading
- Pairs: EUR/USD, GBP/USD, USD/JPY
```

### **4. Sydney Session (Phiên Úc)**
```
Thời gian GMT: 22:00 - 07:00
Đặc điểm:
- Biến động thấp
- Volume nhỏ
- Phù hợp: Range trading
- Pairs: AUD/USD, NZD/USD
```

---

## ⚙️ CẤU HÌNH TRONG EA

### **Bật Session Filter:**

```cpp
Enable_Session_Filter = true   // Bật lọc phiên

// Chọn phiên nào để trade:
Trade_Asian_Session = false    // Phiên Á
Trade_London_Session = true    // Phiên Âu ✅
Trade_NY_Session = true        // Phiên Mỹ ✅
Trade_Sydney_Session = false   // Phiên Úc

Allow_Weekend_Trading = false  // Không trade cuối tuần
```

### **Tắt Session Filter (Trade 24/7):**

```cpp
Enable_Session_Filter = false  // EA trade mọi lúc
```

---

## 🎯 CÁC CHIẾN LƯỢC PHIÊN PHỔ BIẾN

### **Strategy 1: London + New York**
```
✅ Trade_London_Session = true
✅ Trade_NY_Session = true
❌ Trade_Asian_Session = false
❌ Trade_Sydney_Session = false

Lý do:
- Biến động cao
- Volume lớn
- Overlap 13:00-17:00 GMT = tốt nhất
- Phù hợp: Breakout, Trend following
```

### **Strategy 2: Chỉ London**
```
❌ Trade_Asian_Session = false
✅ Trade_London_Session = true
❌ Trade_NY_Session = false
❌ Trade_Sydney_Session = false

Lý do:
- Biến động cao nhất trong ngày
- Spread tốt
- Phù hợp: Major EUR, GBP pairs
```

### **Strategy 3: Chỉ New York**
```
❌ Trade_Asian_Session = false
❌ Trade_London_Session = false
✅ Trade_NY_Session = true
❌ Trade_Sydney_Session = false

Lý do:
- News từ Mỹ
- Phù hợp: USD pairs
- Tránh Asian & London volatility
```

### **Strategy 4: Asian + Sydney (Range Trading)**
```
✅ Trade_Asian_Session = true
❌ Trade_London_Session = false
❌ Trade_NY_Session = false
✅ Trade_Sydney_Session = true

Lý do:
- Biến động thấp
- Phù hợp: Range, mean reversion
- Pairs: AUD, NZD, JPY
```

---

## 🌐 CHUYỂN ĐỔI GIỮA GMT VÀ GIỜ ĐỊA PHƯƠNG

### **GMT là gì?**
GMT (Greenwich Mean Time) = UTC = Giờ chuẩn thế giới

### **Giờ Việt Nam:**
```
Việt Nam = GMT + 7

Ví dụ:
- London Session: 08:00-17:00 GMT
- Giờ Việt Nam: 15:00-00:00 (chiều tới nửa đêm)

- New York Session: 13:00-22:00 GMT  
- Giờ Việt Nam: 20:00-05:00 (tối tới sáng)
```

### **Công Thức:**
```
Giờ Việt Nam = GMT + 7
Giờ GMT = Giờ Việt Nam - 7
```

### **Bảng Chuyển Đổi Nhanh:**

| Session | GMT | Giờ Việt Nam |
|---------|-----|--------------|
| **Asian** | 00:00-09:00 | 07:00-16:00 |
| **London** | 08:00-17:00 | 15:00-00:00 |
| **NY** | 13:00-22:00 | 20:00-05:00 |
| **Sydney** | 22:00-07:00 | 05:00-14:00 |

---

## 📊 OVERLAP (CHỒNG LẤP PHIÊN)

### **London + New York Overlap:**
```
Thời gian GMT: 13:00-17:00 (4 giờ)
Thời gian VN: 20:00-00:00 (8pm-12am)

Đặc điểm:
✅ Biến động CAO NHẤT
✅ Volume LỚN NHẤT
✅ Spread TỐT NHẤT
✅ Best time to trade!

Phù hợp: EUR/USD, GBP/USD
```

### **Sydney + Asian Overlap:**
```
Thời gian GMT: 00:00-07:00
Thời gian VN: 07:00-14:00 (sáng)

Đặc điểm:
- Biến động thấp
- Phù hợp: Range trading
- Pairs: AUD, NZD
```

---

## 🔧 CÁCH THIẾT LẬP

### **Bước 1: Xác Định Mục Tiêu**

**Câu hỏi:**
- Bạn muốn trade phiên nào?
- Pairs nào?
- Style: Breakout hay Range?
- Timezone của bạn?

### **Bước 2: Cấu Hình EA**

```
1. Right-click chart → Expert Advisors → FVG_Trading_EA → Properties

2. Tab "Inputs" → "Trading Session Filter"

3. Thiết lập:
   ✅ Enable_Session_Filter = true
   
   Chọn phiên:
   ✅/❌ Trade_Asian_Session
   ✅/❌ Trade_London_Session
   ✅/❌ Trade_NY_Session
   ✅/❌ Trade_Sydney_Session
   
   ❌ Allow_Weekend_Trading = false

4. OK
```

### **Bước 3: Check Log**

Khi EA khởi động, check Experts tab:
```
==============================================
FVG Trading EA initialized successfully
Auto Trade: ENABLED
Session Filter: ENABLED
  Asian Session: NO
  London Session: YES
  New York Session: YES
  Sydney Session: NO
  Current Session(s): London NewYork
  In Trading Hours: YES ✅
==============================================
```

---

## 📝 LOGIC HOẠT ĐỘNG

### **Trong Phiên Được Chọn:**
```
✅ EA theo dõi zones
✅ Phát hiện sweep patterns
✅ VÀO LỆNH tự động
✅ Quản lý positions
```

### **Ngoài Phiên Được Chọn:**
```
⏸️ EA KHÔNG vào lệnh mới
✅ VẪN quản lý lệnh cũ
✅ VẪN chốt lời theo TP/EMA
✅ VẪN di chuyển SL nếu có
```

### **Log Khi Ngoài Phiên:**
```
⏸️ Outside trading session. Current: Asian
   Allowed sessions: London NewYork
```

---

## 💡 TIPS & BEST PRACTICES

### **1. Chọn Phiên Theo Pairs:**

```
EUR/USD, GBP/USD → London + NY
USD/JPY → Asian + NY
AUD/USD → Sydney + Asian
```

### **2. Avoid Low Liquidity:**

```
❌ Tránh: Sunday evening, Friday night
❌ Tránh: Major holidays
✅ Best: Tuesday-Thursday, London+NY overlap
```

### **3. Backtest Theo Phiên:**

```
- Backtest TỪNG phiên riêng
- So sánh win rate
- Chọn phiên tốt nhất cho strategy
```

### **4. Timezone Awareness:**

```
- Biết broker GMT offset
- Biết timezone của bạn
- Tính toán chính xác
```

### **5. Weekend Trading:**

```
❌ Allow_Weekend_Trading = false
- Spread cao vào cuối tuần
- Liquidity thấp
- Rủi ro gap
```

---

## 🔍 EXAMPLES

### **Example 1: Trader Việt Nam muốn trade buổi tối**

```
Mục tiêu: Trade 8pm-12am (giờ VN)

Setup:
✅ Enable_Session_Filter = true
❌ Trade_Asian_Session = false
✅ Trade_London_Session = true
✅ Trade_NY_Session = true
❌ Trade_Sydney_Session = false

Lý do:
- 8pm-12am VN = 13:00-17:00 GMT
- Đúng London + NY overlap
- Biến động cao
```

### **Example 2: Trader muốn trade buổi sáng**

```
Mục tiêu: Trade 7am-2pm (giờ VN)

Setup:
✅ Enable_Session_Filter = true
✅ Trade_Asian_Session = true
❌ Trade_London_Session = false
❌ Trade_NY_Session = false
✅ Trade_Sydney_Session = true

Lý do:
- 7am-2pm VN = 00:00-07:00 GMT
- Sydney + Asian overlap
- Phù hợp range trading
```

### **Example 3: Trade 24/7 (không lọc)**

```
Mục tiêu: Trade mọi setup

Setup:
❌ Enable_Session_Filter = false

Kết quả:
- EA trade mọi lúc
- Không quan tâm phiên
- Risk: Trade cả lúc spread cao
```

---

## ⚠️ CHÚ Ý

### **1. Broker GMT Offset:**

Mỗi broker có GMT offset khác nhau:
```
- ICMarkets: GMT+2/+3 (DST)
- XM: GMT+2/+3
- Exness: GMT+0
```

**Tầm quan trọng:**
- EA dùng `TimeGMT()` để tính phiên
- Không phụ thuộc broker offset
- Luôn chuẩn GMT

### **2. Daylight Saving Time (DST):**

```
- London: +1 giờ vào mùa hè
- New York: +1 giờ vào mùa hè
- GMT không thay đổi

→ Phiên có thể shift 1 giờ theo mùa
```

### **3. Spread Widening:**

```
Spread tăng khi:
- Chuyển phiên (gap)
- Cuối tuần
- Major news

→ Cẩn thận với lệnh vào lúc chuyển phiên
```

---

## 📊 PERFORMANCE BY SESSION

### **Thống Kê Chung (Major Pairs):**

```
London Session:
- Win rate: 55-60%
- Average RR: 1.8
- Best pairs: EUR/USD, GBP/USD

New York Session:
- Win rate: 50-55%
- Average RR: 1.6
- Best pairs: USD pairs

Asian Session:
- Win rate: 45-50%
- Average RR: 1.2
- Best pairs: JPY, AUD

London + NY Overlap:
- Win rate: 60-65% ⭐
- Average RR: 2.0
- Best time overall
```

---

## 🔧 TROUBLESHOOTING

### **"EA không vào lệnh"**

Check:
1. Enable_Session_Filter = true?
2. Ít nhất 1 phiên = true?
3. Hiện tại có trong phiên không?
4. Check log: "In Trading Hours: YES ✅"

### **"Không biết đang phiên nào"**

Check log:
```
Current Session(s): London NewYork
```

Hoặc dùng:
```cpp
GetCurrentSession()  // Trả về phiên hiện tại
```

### **"Muốn trade cả ngày"**

```
Enable_Session_Filter = false
```

---

## 📚 TÓM TẮT

### **Session Filter là gì?**
Lọc thời gian EA được phép vào lệnh

### **Tại sao cần?**
- Tránh phiên có spread cao
- Trade chỉ khi biến động tốt
- Tối ưu theo timezone
- Cải thiện win rate

### **Cách dùng?**
```
1. Enable_Session_Filter = true
2. Chọn phiên phù hợp
3. Check log khi khởi động
4. Backtest và optimize
```

### **Best Practice:**
```
✅ London + NY cho trend
✅ Asian + Sydney cho range
✅ Avoid weekends
✅ Backtest theo phiên
```

---

**File:** HUONG_DAN_SESSION_FILTER.md  
**Version:** 2.01  
**Tính năng:** Session Filter cho EA

**Happy Trading trong phiên yêu thích! 🌍📈**
