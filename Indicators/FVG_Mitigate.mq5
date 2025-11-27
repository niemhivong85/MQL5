//+------------------------------------------------------------------+
//|                                                FVG_Mitigate.mq5 |
//|                                                                  |
//|                                Fair Value Gap with Mitigation   |
//+------------------------------------------------------------------+
#property copyright "FVG Indicator"
#property link      ""
#property version   "1.00"
#property indicator_chart_window
#property indicator_plots 0

//--- Input parameters
input int      FVG_LookBack = 500;           // Số nến quét lại để tìm FVG
input color    BullishFVG_Color = clrBlue;   // Màu Bullish FVG
input color    BearishFVG_Color = clrRed;    // Màu Bearish FVG
input int      FVG_Transparency = 85;        // Độ trong suốt (0-255)
input bool     Show_Bullish = true;          // Hiển thị Bullish FVG
input bool     Show_Bearish = true;          // Hiển thị Bearish FVG

//--- Structure để lưu thông tin FVG
struct FVG_Info
{
   datetime time_start;      // Thời gian bắt đầu
   datetime time_end;        // Thời gian kết thúc (cập nhật theo time hiện tại)
   double   top;             // Mức giá trên
   double   bottom;          // Mức giá dưới
   bool     is_bullish;      // true = Bullish, false = Bearish
   string   rect_name;       // Tên rectangle object
   bool     is_active;       // FVG còn active không
};

FVG_Info fvg_list[];        // Mảng lưu các FVG
int fvg_count = 0;          // Số lượng FVG hiện tại

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   ArrayResize(fvg_list, 0);
   fvg_count = 0;

   // Xóa tất cả objects cũ
   DeleteAllFVGObjects();

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   DeleteAllFVGObjects();
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
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
                const int &spread[])
{
   // Set array as series
   ArraySetAsSeries(time, true);
   ArraySetAsSeries(open, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);

   // Quét và phát hiện FVG mới
   int start_bar = 3;
   int end_bar = MathMin(FVG_LookBack, rates_total - 3);

   if(prev_calculated == 0)
   {
      // Lần đầu chạy, quét toàn bộ
      for(int i = start_bar; i < end_bar; i++)
      {
         DetectFVG(i, time, high, low);
      }
   }
   else
   {
      // Chỉ kiểm tra nến mới
      DetectFVG(1, time, high, low);
   }

   // Cập nhật tất cả FVG (kiểm tra mitigation và phá vỡ)
   UpdateAllFVG(high, low, time);

   return(rates_total);
}

//+------------------------------------------------------------------+
//| Phát hiện FVG tại vị trí bar                                     |
//+------------------------------------------------------------------+
void DetectFVG(int bar, const datetime &time[], const double &high[], const double &low[])
{
   // Bullish FVG: Low[bar] > High[bar+2]
   // (Có khoảng trống giữa nến bar và bar+2)
   if(Show_Bullish && low[bar] > high[bar+2])
   {
      double fvg_top = low[bar];
      double fvg_bottom = high[bar+2];

      // Kiểm tra xem đã tồn tại FVG này chưa
      if(!IsFVGExists(time[bar+1], fvg_top, fvg_bottom, true))
      {
         CreateFVG(time[bar+1], fvg_top, fvg_bottom, true);
      }
   }

   // Bearish FVG: High[bar] < Low[bar+2]
   // (Có khoảng trống giữa nến bar và bar+2)
   if(Show_Bearish && high[bar] < low[bar+2])
   {
      double fvg_top = low[bar+2];
      double fvg_bottom = high[bar];

      // Kiểm tra xem đã tồn tại FVG này chưa
      if(!IsFVGExists(time[bar+1], fvg_top, fvg_bottom, false))
      {
         CreateFVG(time[bar+1], fvg_top, fvg_bottom, false);
      }
   }
}

//+------------------------------------------------------------------+
//| Kiểm tra FVG đã tồn tại chưa                                     |
//+------------------------------------------------------------------+
bool IsFVGExists(datetime check_time, double top, double bottom, bool is_bullish)
{
   for(int i = 0; i < fvg_count; i++)
   {
      if(fvg_list[i].is_active &&
         fvg_list[i].time_start == check_time &&
         fvg_list[i].is_bullish == is_bullish &&
         MathAbs(fvg_list[i].top - top) < Point() * 10 &&
         MathAbs(fvg_list[i].bottom - bottom) < Point() * 10)
      {
         return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Tạo FVG mới                                                      |
//+------------------------------------------------------------------+
void CreateFVG(datetime start_time, double top, double bottom, bool is_bullish)
{
   // Tăng kích thước mảng
   fvg_count++;
   ArrayResize(fvg_list, fvg_count);

   int index = fvg_count - 1;

   // Lưu thông tin FVG
   fvg_list[index].time_start = start_time;
   fvg_list[index].time_end = TimeCurrent() + PeriodSeconds() * 50; // Kéo dài về bên phải
   fvg_list[index].top = top;
   fvg_list[index].bottom = bottom;
   fvg_list[index].is_bullish = is_bullish;
   fvg_list[index].is_active = true;
   fvg_list[index].rect_name = "FVG_" + IntegerToString(start_time) + "_" + (is_bullish ? "Bull" : "Bear");

   // Vẽ rectangle
   DrawFVG(index);
}

//+------------------------------------------------------------------+
//| Vẽ FVG rectangle                                                 |
//+------------------------------------------------------------------+
void DrawFVG(int index)
{
   string name = fvg_list[index].rect_name;

   // Xóa object cũ nếu có
   if(ObjectFind(0, name) >= 0)
      ObjectDelete(0, name);

   // Tạo rectangle mới
   ObjectCreate(0, name, OBJ_RECTANGLE, 0,
                fvg_list[index].time_start, fvg_list[index].top,
                fvg_list[index].time_end, fvg_list[index].bottom);

   // Set màu sắc
   color fvg_color = fvg_list[index].is_bullish ? BullishFVG_Color : BearishFVG_Color;
   ObjectSetInteger(0, name, OBJPROP_COLOR, fvg_color);
   ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, name, OBJPROP_FILL, true);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);

   // Set độ trong suốt
   color bg_color = fvg_color;
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg_color);
   ObjectSetInteger(0, name, OBJPROP_COLOR, bg_color);

   // Làm mờ background
   long chart_id = ChartID();
   ObjectSetInteger(chart_id, name, OBJPROP_BACK, true);
}

//+------------------------------------------------------------------+
//| Cập nhật tất cả FVG                                              |
//+------------------------------------------------------------------+
void UpdateAllFVG(const double &high[], const double &low[], const datetime &time[])
{
   double current_high = high[0];
   double current_low = low[0];
   datetime current_time = time[0];

   for(int i = 0; i < fvg_count; i++)
   {
      if(!fvg_list[i].is_active)
         continue;

      bool need_update = false;
      bool need_delete = false;

      if(fvg_list[i].is_bullish)
      {
         // Bullish FVG
         // Kiểm tra mitigation: giá đi xuống vào vùng FVG
         if(current_low <= fvg_list[i].top && current_low >= fvg_list[i].bottom)
         {
            // Thu nhỏ FVG từ dưới lên
            fvg_list[i].bottom = current_low;
            need_update = true;
         }

         // Kiểm tra phá vỡ: giá phá qua dưới FVG
         if(current_low < fvg_list[i].bottom)
         {
            need_delete = true;
         }
      }
      else
      {
         // Bearish FVG
         // Kiểm tra mitigation: giá đi lên vào vùng FVG
         if(current_high >= fvg_list[i].bottom && current_high <= fvg_list[i].top)
         {
            // Thu nhỏ FVG từ trên xuống
            fvg_list[i].top = current_high;
            need_update = true;
         }

         // Kiểm tra phá vỡ: giá phá qua trên FVG
         if(current_high > fvg_list[i].top)
         {
            need_delete = true;
         }
      }

      // Cập nhật time_end để kéo dài rectangle
      fvg_list[i].time_end = current_time + PeriodSeconds() * 50;

      if(need_delete)
      {
         // Xóa FVG
         DeleteFVG(i);
      }
      else if(need_update || true) // Luôn cập nhật để kéo dài time_end
      {
         // Cập nhật FVG
         DrawFVG(i);
      }
   }
}

//+------------------------------------------------------------------+
//| Xóa FVG                                                          |
//+------------------------------------------------------------------+
void DeleteFVG(int index)
{
   if(ObjectFind(0, fvg_list[index].rect_name) >= 0)
   {
      ObjectDelete(0, fvg_list[index].rect_name);
   }
   fvg_list[index].is_active = false;
}

//+------------------------------------------------------------------+
//| Xóa tất cả FVG objects                                           |
//+------------------------------------------------------------------+
void DeleteAllFVGObjects()
{
   int obj_total = ObjectsTotal(0, 0, -1);

   for(int i = obj_total - 1; i >= 0; i--)
   {
      string obj_name = ObjectName(0, i, 0, -1);

      if(StringFind(obj_name, "FVG_") == 0)
      {
         ObjectDelete(0, obj_name);
      }
   }

   ArrayResize(fvg_list, 0);
   fvg_count = 0;
}
//+------------------------------------------------------------------+
