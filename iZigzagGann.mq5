//+------------------------------------------------------------------+
//|                                        © Tran Van Luc, 2022-2025 |
//|                                             https://t.me/vluc028 |
//+------------------------------------------------------------------+
#property copyright "© Tran Van Luc, 2022-2025"
#property link      "https://t.me/vluc028"
#property version   "1.10"

#property indicator_chart_window
#property indicator_buffers 2
#property indicator_plots   1

#property indicator_type1   DRAW_ZIGZAG

#property indicator_color1  clrRed
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

//--- Input parameters
input ENUM_TIMEFRAMES Timeframe = PERIOD_CURRENT;    // Khung thời gian (M1, M5, H1, H4, D1...)
input datetime Start_Time_VN = D'2024.01.01 09:00';  // Thời gian Việt Nam
input int      VN_GMT_Offset = 7;                    // Múi giờ Việt Nam (GMT+7)
input int      LookBack_Bars = 1000;                 // Số nến lùi lại về quá khứ
input bool     Auto_Find_Start = true;               // Tự động tìm điểm bắt đầu
input color    Line_Color_Close = clrYellow;         // Màu đường Close
input color    Line_Color_High = clrLime;            // Màu đường Highest
input color    Line_Color_Low = clrRed;              // Màu đường Lowest
input color    Start_Point_Color = clrYellow;        // Màu điểm bắt đầu
input bool     Show_Reference_Lines = true;          // Hiển thị đường tham chiếu (CLOSE/HIGHEST/LOWEST)
input bool     Show_Price_Labels = true;             // Hiển thị nhãn giá tại các điểm ZigZag
input bool     Show_Percent_Change = true;           // Hiển thị % thay đổi giữa các điểm
input bool     Enable_Alerts = false;                // Bật cảnh báo khi có điểm ZigZag mới
input int      Min_Percent_Alert = 0;                // % tối thiểu để cảnh báo (0 = cảnh báo tất cả)

double         Buffer_High[];
double         Buffer_Low[];
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int pending_index = -1;
int pending_HighLow = 1;
string sortNameIndi = "iZigzagGann";
int start_bar_index = -1;
string prefix = "ZZ_";
int last_zigzag_count = 0;                           // Đếm số điểm ZigZag để phát hiện điểm mới
double last_zigzag_price = 0;                        // Giá điểm ZigZag cuối cùng
bool last_zigzag_is_high = false;                    // Điểm cuối là đỉnh hay đáy

//--- Forward declarations
void DeleteOldObjects();
void MarkStartPoint(int bar_index, double price, datetime bar_time, bool is_high);
void DrawHorizontalLine(double price, datetime time_start, datetime time_end, string label, color line_color, int line_id);
void MarkZigZagPoint(int bar_index, double price, datetime bar_time, bool is_high, double prev_price, bool prev_is_high);
void SendZigZagAlert(double price, bool is_high, double percent_change);
int CountZigZagPoints();
//+------------------------------------------------------------------+
int OnInit() {
   pending_HighLow = 0;
   pending_index = -1;
   start_bar_index = -1;

   SetIndexBuffer(0, Buffer_High, INDICATOR_DATA);
   SetIndexBuffer(1, Buffer_Low, INDICATOR_DATA);
   PlotIndexSetString(0, PLOT_LABEL, "iZigzag High_Low");
   IndicatorSetString(INDICATOR_SHORTNAME, sortNameIndi);

   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, 0);
   
   // Xóa các object cũ
   DeleteOldObjects();
//---
   return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   DeleteOldObjects();
}
//+------------------------------------------------------------------+
void DeleteOldObjects() {
   int total = ObjectsTotal(0);
   for(int i = total - 1; i >= 0; i--) {
      string name = ObjectName(0, i);
      if(StringFind(name, prefix) >= 0)
         ObjectDelete(0, name);
   }
}
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[]) {

//---
   int start = 1;
   
   // ======= PHẦN MỚI: TÌM ĐIỂM START (CHỈ CHẠY 1 LẦN) =======
   static bool already_found = false;
   
   if(Auto_Find_Start && !already_found && rates_total > LookBack_Bars + 2) {
      Print("═══════════════════════════════════");
      Print("📍 BẮT ĐẦU TÌM ĐIỂM THAM CHIẾU");
      
      // Chuyển đổi thời gian VN sang Server
      datetime time_vn = Start_Time_VN;
      
      MqlDateTime dt_server, dt_gmt;
      TimeToStruct(TimeCurrent(), dt_server);
      TimeToStruct(TimeGMT(), dt_gmt);
      
      int server_offset = dt_server.hour - dt_gmt.hour;
      if(server_offset < -12) server_offset += 24;
      if(server_offset > 12) server_offset -= 24;
      
      int hour_diff = VN_GMT_Offset - server_offset;
      datetime time_server = time_vn - hour_diff * 3600;
      
      Print("Thời gian VN: ", TimeToString(time_vn, TIME_DATE|TIME_MINUTES));
      Print("Thời gian Server: ", TimeToString(time_server, TIME_DATE|TIME_MINUTES));
      
      // Tìm cây nến
      int bar_reference = iBarShift(_Symbol, Timeframe, time_server, false);
      if(bar_reference < 0 || bar_reference == 0) {
         bar_reference = 1;
      }
      
      datetime ref_time = iTime(_Symbol, Timeframe, bar_reference);
      double ref_close = iClose(_Symbol, Timeframe, bar_reference);
      
      Print("📌 CÂY THAM CHIẾU: Bar ", bar_reference, " | CLOSE: ", DoubleToString(ref_close, _Digits));
      
      // Quét 1000 cây lùi lại
      int start_bar = bar_reference;
      int end_bar = bar_reference + LookBack_Bars;
      
      if(end_bar >= iBars(_Symbol, Timeframe)) {
         end_bar = iBars(_Symbol, Timeframe) - 1;
      }
      
      Print("🔍 QUÉT: bar ", start_bar, " → bar ", end_bar);
      
      // Tìm HIGHEST và LOWEST
      double highest_price = iHigh(_Symbol, Timeframe, start_bar);
      int highest_index = start_bar;
      double lowest_price = iLow(_Symbol, Timeframe, start_bar);
      int lowest_index = start_bar;
      
      for(int i = start_bar; i <= end_bar; i++) {
         double bar_high = iHigh(_Symbol, Timeframe, i);
         double bar_low = iLow(_Symbol, Timeframe, i);
         
         if(bar_high > highest_price) {
            highest_price = bar_high;
            highest_index = i;
         }
         if(bar_low < lowest_price) {
            lowest_price = bar_low;
            lowest_index = i;
         }
      }
      
      // Vẽ 3 đường ngang
      datetime time_from = iTime(_Symbol, Timeframe, end_bar);
      datetime time_to = iTime(_Symbol, Timeframe, start_bar);
      
      // Đảm bảo thời gian đúng thứ tự
      if(time_from > time_to) {
         datetime temp = time_from;
         time_from = time_to;
         time_to = temp;
      }
      
      if(Show_Reference_Lines) {
         DrawHorizontalLine(ref_close, time_from, time_to, "CLOSE", Line_Color_Close, 1);
         DrawHorizontalLine(highest_price, time_from, time_to, "HIGHEST", Line_Color_High, 2);
         DrawHorizontalLine(lowest_price, time_from, time_to, "LOWEST", Line_Color_Low, 3);
      }
      
      // So sánh khoảng cách
      double distance_to_high = MathAbs(ref_close - highest_price);
      double distance_to_low = MathAbs(ref_close - lowest_price);
      
      Print("Khoảng cách đến HIGHEST: ", distance_to_high);
      Print("Khoảng cách đến LOWEST: ", distance_to_low);
      
      // Chọn điểm START
      if(distance_to_high > distance_to_low) {
         // Bắt đầu từ ĐỈNH
         start_bar_index = highest_index;
         pending_index = highest_index;
         pending_HighLow = -1;
         
         datetime high_time = iTime(_Symbol, Timeframe, highest_index);
         MarkStartPoint(highest_index, highest_price, high_time, true);
         Print("✅ BẮT ĐẦU TỪ ĐỈNH: Bar ", highest_index, " | Giá: ", DoubleToString(highest_price, _Digits));
      } else {
         // Bắt đầu từ ĐÁY
         start_bar_index = lowest_index;
         pending_index = lowest_index;
         pending_HighLow = 1;
         
         datetime low_time = iTime(_Symbol, Timeframe, lowest_index);
         MarkStartPoint(lowest_index, lowest_price, low_time, false);
         Print("✅ BẮT ĐẦU TỪ ĐÁY: Bar ", lowest_index, " | Giá: ", DoubleToString(lowest_price, _Digits));
      }
      Print("═══════════════════════════════════");
      
      already_found = true;
      ChartRedraw();
   }
   // ======= HẾT PHẦN MỚI =======
   
   if(prev_calculated != 0)
      start = prev_calculated - 1;

   for(int i = start; i < rates_total; i++) {
      Buffer_High[i] = 0;
      Buffer_Low[i] = 0;

      if(pending_HighLow == 0) {
         if(high[i] > high[i - 1] && low[i] > low[i - 1]) {
            pending_index = i;
            pending_HighLow = 1;

            Buffer_High[i] = high[pending_index];
            Buffer_Low[0] = low[0];
            continue;
         }
         if(high[i] < high[i - 1] && low[i] < low[i - 1]) {
            pending_index = i;
            pending_HighLow = -1;

            Buffer_High[0] = high[0];
            Buffer_Low[i] = low[pending_index];
            continue;
         }
      }

      else if(pending_HighLow == 1) {
         if(high[i] > high[pending_index] && low[i] < low[pending_index]) {
            // Đánh dấu điểm đỉnh cũ
            if(Show_Price_Labels && Buffer_High[pending_index] > 0) {
               datetime prev_time = iTime(_Symbol, Timeframe, pending_index);
               MarkZigZagPoint(pending_index, high[pending_index], prev_time, true, last_zigzag_price, last_zigzag_is_high);
               last_zigzag_price = high[pending_index];
               last_zigzag_is_high = true;
            }
            
            Buffer_High[pending_index] = high[pending_index];

            Buffer_Low[i] = low[i];
            Buffer_High[i] = high[i];
            if(i < rates_total - 1) {
               pending_index = i;
               pending_HighLow = 1;
            }
            
            // Cảnh báo điểm mới
            if(Enable_Alerts && i == rates_total - 1) {
               double percent_change = 0;
               if(last_zigzag_price > 0) {
                  percent_change = MathAbs((high[i] - last_zigzag_price) / last_zigzag_price) * 100;
               }
               if(percent_change >= Min_Percent_Alert) {
                  SendZigZagAlert(high[i], true, percent_change);
               }
            }
            continue;
         }

         else if(high[i] > high[pending_index] && low[i] > low[pending_index]) {
            Buffer_High[pending_index] = 0;
            if(i < rates_total - 1) {
               pending_index = i;
               pending_HighLow = 1;
            }

            Buffer_High[i] = high[i];
            continue;
         }

         else if(high[i] < high[pending_index] && low[i] < low[pending_index]) { 
            // Đánh dấu điểm đáy mới
            if(Show_Price_Labels) {
               datetime low_time = iTime(_Symbol, Timeframe, i);
               MarkZigZagPoint(i, low[i], low_time, false, last_zigzag_price, last_zigzag_is_high);
               double percent_change = 0;
               if(last_zigzag_price > 0) {
                  percent_change = MathAbs((low[i] - last_zigzag_price) / last_zigzag_price) * 100;
               }
               last_zigzag_price = low[i];
               last_zigzag_is_high = false;
               
               // Cảnh báo điểm mới
               if(Enable_Alerts && i == rates_total - 1 && percent_change >= Min_Percent_Alert) {
                  SendZigZagAlert(low[i], false, percent_change);
               }
            }
            
            if(i < rates_total - 1) {
               pending_index = i;
               pending_HighLow = -1;
            }

            Buffer_Low[i] = low[i];
            continue;
         }
      }
      else  if(pending_HighLow == -1) {
         if(high[i] > high[pending_index] && low[i] < low[pending_index]) { 
            // Đánh dấu điểm đáy cũ
            if(Show_Price_Labels && Buffer_Low[pending_index] > 0) {
               datetime prev_time = iTime(_Symbol, Timeframe, pending_index);
               MarkZigZagPoint(pending_index, low[pending_index], prev_time, false, last_zigzag_price, last_zigzag_is_high);
               last_zigzag_price = low[pending_index];
               last_zigzag_is_high = false;
            }
            
            Buffer_Low[pending_index] = low[pending_index];
            Buffer_High[i] = high[i];
            Buffer_Low[i] = low[i];
            if(i < rates_total - 1) {
               pending_index = i;
               pending_HighLow = -1;
            }
            
            // Cảnh báo điểm mới
            if(Enable_Alerts && i == rates_total - 1) {
               double percent_change = 0;
               if(last_zigzag_price > 0) {
                  percent_change = MathAbs((high[i] - last_zigzag_price) / last_zigzag_price) * 100;
               }
               if(percent_change >= Min_Percent_Alert) {
                  SendZigZagAlert(high[i], true, percent_change);
               }
            }
            continue;
         }

         else if(low[i] < low[pending_index] && high[i] < high[pending_index]) { 
            Buffer_Low[pending_index] = 0;
            if(i < rates_total - 1) {
               pending_index = i;
               pending_HighLow = -1;
            }
            Buffer_Low[i] = low[i];
            continue;
         }

         else if(high[i] > high[pending_index] && low[i] > low[pending_index]) { 
            // Đánh dấu điểm đỉnh mới
            if(Show_Price_Labels) {
               datetime high_time = iTime(_Symbol, Timeframe, i);
               MarkZigZagPoint(i, high[i], high_time, true, last_zigzag_price, last_zigzag_is_high);
               double percent_change = 0;
               if(last_zigzag_price > 0) {
                  percent_change = MathAbs((high[i] - last_zigzag_price) / last_zigzag_price) * 100;
               }
               last_zigzag_price = high[i];
               last_zigzag_is_high = true;
               
               // Cảnh báo điểm mới
               if(Enable_Alerts && i == rates_total - 1 && percent_change >= Min_Percent_Alert) {
                  SendZigZagAlert(high[i], true, percent_change);
               }
            }
            
            if(i < rates_total - 1) {
               pending_index = i;
               pending_HighLow = 1;
            }
            Buffer_High[i] = high[i];
            continue;
         }
      }
   }
//---
   return(rates_total);
}
//+------------------------------------------------------------------+
//| Đánh dấu điểm bắt đầu ZigZag                                     |
//+------------------------------------------------------------------+
void MarkStartPoint(int bar_index, double price, datetime bar_time, bool is_high) {
   string name = prefix + "Point";
   
   if(ObjectFind(0, name) >= 0)
      ObjectDelete(0, name);
   
   if(ObjectCreate(0, name, OBJ_ARROW, 0, bar_time, price)) {
      ObjectSetInteger(0, name, OBJPROP_COLOR, Start_Point_Color);
      ObjectSetInteger(0, name, OBJPROP_ARROWCODE, is_high ? 234 : 233);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, 3);
      ObjectSetInteger(0, name, OBJPROP_BACK, false);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   }
   
   string text_name = prefix + "Text";
   if(ObjectFind(0, text_name) >= 0)
      ObjectDelete(0, text_name);
      
   if(ObjectCreate(0, text_name, OBJ_TEXT, 0, bar_time, price)) {
      string label = is_high ? "START (ĐỈNH)" : "START (ĐÁY)";
      ObjectSetString(0, text_name, OBJPROP_TEXT, label);
      ObjectSetInteger(0, text_name, OBJPROP_COLOR, Start_Point_Color);
      ObjectSetInteger(0, text_name, OBJPROP_FONTSIZE, 10);
      ObjectSetInteger(0, text_name, OBJPROP_ANCHOR, is_high ? ANCHOR_LOWER : ANCHOR_UPPER);
      ObjectSetInteger(0, text_name, OBJPROP_BACK, false);
      ObjectSetInteger(0, text_name, OBJPROP_SELECTABLE, false);
   }
}
//+------------------------------------------------------------------+
//| Vẽ đường ngang cố định                                           |
//+------------------------------------------------------------------+
void DrawHorizontalLine(double price, datetime time_start, datetime time_end, string label, color line_color, int line_id) {
   string name = prefix + "Line_" + IntegerToString(line_id);
   
   if(ObjectFind(0, name) >= 0)
      ObjectDelete(0, name);
   
   if(ObjectCreate(0, name, OBJ_TREND, 0, time_start, price, time_end, price)) {
      ObjectSetInteger(0, name, OBJPROP_COLOR, line_color);
      ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, name, OBJPROP_BACK, true);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, name, OBJPROP_RAY_LEFT, false);
   }
   
   string text_name = name + "_Label";
   if(ObjectFind(0, text_name) >= 0)
      ObjectDelete(0, text_name);
      
   if(ObjectCreate(0, text_name, OBJ_TEXT, 0, time_end, price)) {
      string full_label = label + " (" + DoubleToString(price, _Digits) + ")";
      ObjectSetString(0, text_name, OBJPROP_TEXT, "  " + full_label);
      ObjectSetInteger(0, text_name, OBJPROP_COLOR, line_color);
      ObjectSetInteger(0, text_name, OBJPROP_FONTSIZE, 9);
      ObjectSetInteger(0, text_name, OBJPROP_ANCHOR, ANCHOR_LEFT);
      ObjectSetInteger(0, text_name, OBJPROP_BACK, false);
      ObjectSetInteger(0, text_name, OBJPROP_SELECTABLE, false);
   }
}
//+------------------------------------------------------------------+
