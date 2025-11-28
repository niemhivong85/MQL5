//+------------------------------------------------------------------+
//|                                       FVG_Indicator_Enhanced.mq5 |
//|                    Fair Value Gap with Trading Zone & Sweep      |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025"
#property version   "2.00"
#property indicator_chart_window
#property indicator_plots 0

//--- Input parameters - FVG Settings
input int      FVG_LookBack = 500;
input color    Bullish_FVG_Color = clrGreen;
input color    Bearish_FVG_Color = clrRed;
input int      FVG_Transparency = 80;
input bool     Show_Bullish_FVG = true;
input bool     Show_Bearish_FVG = true;
input int      Min_FVG_Points = 10;
input bool     Fill_On_Touch = true;
input bool     Delete_On_Break = true;

//--- Input parameters - News Filter by Currency
input bool     Enable_News_Filter = true;
input bool     Filter_USD = true;
input bool     Filter_EUR = true;
input bool     Filter_GBP = true;
input bool     Filter_JPY = false;
input bool     Filter_AUD = false;
input bool     Filter_CAD = false;
input bool     Filter_CHF = false;
input bool     Filter_NZD = false;

//--- Input parameters - News Impact Level
input bool     Filter_High_Impact = true;
input bool     Filter_Medium_Impact = true;
input bool     Filter_Low_Impact = false;

input int      News_Minutes_Before = 30;
input int      News_Minutes_After = 30;
input bool     Show_News_Zone = true;
input color    News_Zone_Color = clrYellow;

//--- NEW: Trading Zone & Sweep Parameters
input group    "=== Trading Zone Settings ==="
input int      Sweep_Candles_Count = 5;        // N cây nến sau sweep để tìm đáy/đỉnh
input bool     Enable_Alert = true;             // Bật thông báo
input bool     Enable_Sound = true;             // Bật âm thanh
input string   Alert_Sound = "alert.wav";       // File âm thanh

input group    "=== Button & Zone Colors ==="
input color    Buy_Zone_Color = clrDodgerBlue;
input color    Sell_Zone_Color = clrOrangeRed;
input color    Button_Buy_Color = clrLimeGreen;
input color    Button_Sell_Color = clrRed;
input color    Button_Confirm_Color = clrGold;
input color    Button_Edit_Color = clrOrange;
input int      Zone_Transparency = 70;

//--- Structures
struct FVG_Structure
{
   datetime time_start;
   datetime time_end;
   double   top;
   double   bottom;
   double   original_top;
   double   original_bottom;
   bool     is_bullish;
   string   rect_name;
   int      start_bar;
   bool     is_active;
};

struct NewsTime
{
   string currency;
   int    day_of_week;
   int    hour;
   int    minute;
   int    impact;
   string name;
};

struct TradingZone
{
   double   top;
   double   bottom;
   bool     is_active;
   bool     is_locked;
   bool     is_buy_zone;
   string   rect_name;
   bool     signal_triggered;
   datetime last_check_time;
};

//--- Global variables
FVG_Structure FVG_Array[];
int FVG_Count = 0;
string indicator_prefix = "FVG_";
string news_prefix = "NEWS_";
string button_prefix = "BTN_";
string zone_prefix = "ZONE_";
NewsTime news_times[];

// Trading Zone variables
TradingZone buy_zone;
TradingZone sell_zone;
bool creating_buy_zone = false;
bool creating_sell_zone = false;
datetime last_chart_event = 0;

// Button names
string btn_buy = button_prefix + "BUY";
string btn_sell = button_prefix + "SELL";
string btn_confirm = button_prefix + "CONFIRM";
string btn_edit = button_prefix + "EDIT";

//--- Forward declarations
void DeleteAllObjects();
void LoadNewsSettings();
void AddNewsTime(int &count, string curr, int day, int hour, int min, int impact, string name);
bool IsNewsTime(datetime check_time);
void CreateFVG(datetime start_time, double top, double bottom, bool is_bullish, int bar_index);
void DrawFVGRectangle(int index);
void UpdateFVGStatus(const datetime &time[], const double &high[], const double &low[], const double &close[]);

// NEW: Trading Zone functions
void CreateButtons();
void CreateTradingZone(bool is_buy);
void DrawTradingZone(TradingZone &zone);
void LockTradingZones();
void UnlockTradingZones();
bool CheckSweepAndPattern(const datetime &time[], const double &open[], const double &high[], const double &low[], const double &close[], bool is_buy_signal);
bool IsSweepCandle(const double &open[], const double &high[], const double &low[], const double &close[], int index, bool check_for_buy);
bool IsBottomFormation(const double &open[], const double &high[], const double &low[], const double &close[], int sweep_index);
bool IsTopFormation(const double &open[], const double &high[], const double &low[], const double &close[], int sweep_index);
void SendAlert(string message);

//+------------------------------------------------------------------+
int OnInit()
{
   DeleteAllObjects();
   ArrayResize(FVG_Array, 0);
   FVG_Count = 0;
   
   if(Enable_News_Filter)
      LoadNewsSettings();
   
   // Initialize trading zones
   buy_zone.is_active = false;
   buy_zone.is_locked = false;
   buy_zone.is_buy_zone = true;
   buy_zone.rect_name = zone_prefix + "BUY";
   buy_zone.signal_triggered = false;
   buy_zone.top = 0;
   buy_zone.bottom = 0;
   
   sell_zone.is_active = false;
   sell_zone.is_locked = false;
   sell_zone.is_buy_zone = false;
   sell_zone.rect_name = zone_prefix + "SELL";
   sell_zone.signal_triggered = false;
   sell_zone.top = 0;
   sell_zone.bottom = 0;
   
   CreateButtons();
   ChartSetInteger(0, CHART_EVENT_MOUSE_MOVE, true);
   ChartSetInteger(0, CHART_EVENT_OBJECT_CREATE, true);
   ChartSetInteger(0, CHART_EVENT_OBJECT_DRAG, true);
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   DeleteAllObjects();
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
                const int &spread[])
{
   ArraySetAsSeries(time, true);
   ArraySetAsSeries(open, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);
   
   int start_bar = (prev_calculated == 0) ? MathMin(rates_total - 4, FVG_LookBack) : 3;
   
   // Detect FVGs
   for(int i = start_bar; i >= 3; i--)
   {
      if(Enable_News_Filter && IsNewsTime(time[i]))
         continue;
      
      if(Show_Bullish_FVG)
      {
         double gap_bottom = high[i+2];
         double gap_top = low[i];
         
         if(gap_top > gap_bottom)
         {
            double gap_size = gap_top - gap_bottom;
            if(gap_size >= Min_FVG_Points * _Point)
            {
               bool exists = false;
               for(int j = 0; j < FVG_Count; j++)
               {
                  if(FVG_Array[j].time_start == time[i+2] && 
                     MathAbs(FVG_Array[j].original_top - gap_top) < _Point * 2 &&
                     FVG_Array[j].is_bullish == true)
                  {
                     exists = true;
                     break;
                  }
               }
               if(!exists)
                  CreateFVG(time[i+2], gap_top, gap_bottom, true, i+2);
            }
         }
      }
      
      if(Show_Bearish_FVG)
      {
         double gap_top = low[i+2];
         double gap_bottom = high[i];
         
         if(gap_top > gap_bottom)
         {
            double gap_size = gap_top - gap_bottom;
            if(gap_size >= Min_FVG_Points * _Point)
            {
               bool exists = false;
               for(int j = 0; j < FVG_Count; j++)
               {
                  if(FVG_Array[j].time_start == time[i+2] && 
                     MathAbs(FVG_Array[j].original_top - gap_top) < _Point * 2 &&
                     FVG_Array[j].is_bullish == false)
                  {
                     exists = true;
                     break;
                  }
               }
               if(!exists)
                  CreateFVG(time[i+2], gap_top, gap_bottom, false, i+2);
            }
         }
      }
   }
   
   UpdateFVGStatus(time, high, low, close);
   
   // Check trading zones for sweep patterns
   if(buy_zone.is_active && buy_zone.is_locked && !buy_zone.signal_triggered)
   {
      if(CheckSweepAndPattern(time, open, high, low, close, true))
      {
         buy_zone.signal_triggered = true;
         SendAlert("BUY SIGNAL: Sweep + Bottom Formation detected!");
      }
   }
   
   if(sell_zone.is_active && sell_zone.is_locked && !sell_zone.signal_triggered)
   {
      if(CheckSweepAndPattern(time, open, high, low, close, false))
      {
         sell_zone.signal_triggered = true;
         SendAlert("SELL SIGNAL: Sweep + Top Formation detected!");
      }
   }
   
   return(rates_total);
}

//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
   if(id == CHARTEVENT_OBJECT_CLICK)
   {
      if(sparam == btn_buy)
      {
         creating_buy_zone = true;
         creating_sell_zone = false;
         CreateTradingZone(true);
         ObjectSetInteger(0, btn_buy, OBJPROP_STATE, false);
      }
      else if(sparam == btn_sell)
      {
         creating_sell_zone = true;
         creating_buy_zone = false;
         CreateTradingZone(false);
         ObjectSetInteger(0, btn_sell, OBJPROP_STATE, false);
      }
      else if(sparam == btn_confirm)
      {
         LockTradingZones();
         ObjectSetInteger(0, btn_confirm, OBJPROP_STATE, false);
      }
      else if(sparam == btn_edit)
      {
         UnlockTradingZones();
         ObjectSetInteger(0, btn_edit, OBJPROP_STATE, false);
      }
   }
   
   if(id == CHARTEVENT_OBJECT_DRAG)
   {
      if(sparam == buy_zone.rect_name && buy_zone.is_active && !buy_zone.is_locked)
      {
         buy_zone.top = ObjectGetDouble(0, buy_zone.rect_name, OBJPROP_PRICE, 0);
         buy_zone.bottom = ObjectGetDouble(0, buy_zone.rect_name, OBJPROP_PRICE, 1);
      }
      else if(sparam == sell_zone.rect_name && sell_zone.is_active && !sell_zone.is_locked)
      {
         sell_zone.top = ObjectGetDouble(0, sell_zone.rect_name, OBJPROP_PRICE, 0);
         sell_zone.bottom = ObjectGetDouble(0, sell_zone.rect_name, OBJPROP_PRICE, 1);
      }
   }
}

//+------------------------------------------------------------------+
void CreateButtons()
{
   int x_start = 20;
   int y_start = 30;
   int btn_width = 80;
   int btn_height = 30;
   int btn_spacing = 10;
   
   // Buy button
   if(ObjectCreate(0, btn_buy, OBJ_BUTTON, 0, 0, 0))
   {
      ObjectSetInteger(0, btn_buy, OBJPROP_XDISTANCE, x_start);
      ObjectSetInteger(0, btn_buy, OBJPROP_YDISTANCE, y_start);
      ObjectSetInteger(0, btn_buy, OBJPROP_XSIZE, btn_width);
      ObjectSetInteger(0, btn_buy, OBJPROP_YSIZE, btn_height);
      ObjectSetString(0, btn_buy, OBJPROP_TEXT, "MUA");
      ObjectSetInteger(0, btn_buy, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, btn_buy, OBJPROP_BGCOLOR, Button_Buy_Color);
      ObjectSetInteger(0, btn_buy, OBJPROP_BORDER_COLOR, clrBlack);
      ObjectSetInteger(0, btn_buy, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, btn_buy, OBJPROP_FONTSIZE, 10);
      ObjectSetString(0, btn_buy, OBJPROP_FONT, "Arial Bold");
   }
   
   // Sell button
   if(ObjectCreate(0, btn_sell, OBJ_BUTTON, 0, 0, 0))
   {
      ObjectSetInteger(0, btn_sell, OBJPROP_XDISTANCE, x_start + btn_width + btn_spacing);
      ObjectSetInteger(0, btn_sell, OBJPROP_YDISTANCE, y_start);
      ObjectSetInteger(0, btn_sell, OBJPROP_XSIZE, btn_width);
      ObjectSetInteger(0, btn_sell, OBJPROP_YSIZE, btn_height);
      ObjectSetString(0, btn_sell, OBJPROP_TEXT, "BÁN");
      ObjectSetInteger(0, btn_sell, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, btn_sell, OBJPROP_BGCOLOR, Button_Sell_Color);
      ObjectSetInteger(0, btn_sell, OBJPROP_BORDER_COLOR, clrBlack);
      ObjectSetInteger(0, btn_sell, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, btn_sell, OBJPROP_FONTSIZE, 10);
      ObjectSetString(0, btn_sell, OBJPROP_FONT, "Arial Bold");
   }
   
   // Confirm button
   if(ObjectCreate(0, btn_confirm, OBJ_BUTTON, 0, 0, 0))
   {
      ObjectSetInteger(0, btn_confirm, OBJPROP_XDISTANCE, x_start + (btn_width + btn_spacing) * 2);
      ObjectSetInteger(0, btn_confirm, OBJPROP_YDISTANCE, y_start);
      ObjectSetInteger(0, btn_confirm, OBJPROP_XSIZE, btn_width);
      ObjectSetInteger(0, btn_confirm, OBJPROP_YSIZE, btn_height);
      ObjectSetString(0, btn_confirm, OBJPROP_TEXT, "XÁC NHẬN");
      ObjectSetInteger(0, btn_confirm, OBJPROP_COLOR, clrBlack);
      ObjectSetInteger(0, btn_confirm, OBJPROP_BGCOLOR, Button_Confirm_Color);
      ObjectSetInteger(0, btn_confirm, OBJPROP_BORDER_COLOR, clrBlack);
      ObjectSetInteger(0, btn_confirm, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, btn_confirm, OBJPROP_FONTSIZE, 9);
      ObjectSetString(0, btn_confirm, OBJPROP_FONT, "Arial Bold");
   }
   
   // Edit button
   if(ObjectCreate(0, btn_edit, OBJ_BUTTON, 0, 0, 0))
   {
      ObjectSetInteger(0, btn_edit, OBJPROP_XDISTANCE, x_start + (btn_width + btn_spacing) * 3);
      ObjectSetInteger(0, btn_edit, OBJPROP_YDISTANCE, y_start);
      ObjectSetInteger(0, btn_edit, OBJPROP_XSIZE, btn_width);
      ObjectSetInteger(0, btn_edit, OBJPROP_YSIZE, btn_height);
      ObjectSetString(0, btn_edit, OBJPROP_TEXT, "SỬA");
      ObjectSetInteger(0, btn_edit, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, btn_edit, OBJPROP_BGCOLOR, Button_Edit_Color);
      ObjectSetInteger(0, btn_edit, OBJPROP_BORDER_COLOR, clrBlack);
      ObjectSetInteger(0, btn_edit, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, btn_edit, OBJPROP_FONTSIZE, 10);
      ObjectSetString(0, btn_edit, OBJPROP_FONT, "Arial Bold");
   }
}

//+------------------------------------------------------------------+
void CreateTradingZone(bool is_buy)
{
   TradingZone &zone = is_buy ? buy_zone : sell_zone;
   
   // Get current price and visible bars
   double current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   int visible_bars = (int)ChartGetInteger(0, CHART_VISIBLE_BARS);
   datetime first_visible = (datetime)ChartGetInteger(0, CHART_FIRST_VISIBLE_BAR);
   
   // Default zone size (about 50-100 points)
   double zone_size = 100 * _Point;
   
   if(is_buy)
   {
      zone.top = current_price - 50 * _Point;
      zone.bottom = current_price - 150 * _Point;
   }
   else
   {
      zone.top = current_price + 150 * _Point;
      zone.bottom = current_price + 50 * _Point;
   }
   
   zone.is_active = true;
   zone.is_locked = false;
   zone.signal_triggered = false;
   
   DrawTradingZone(zone);
}

//+------------------------------------------------------------------+
void DrawTradingZone(TradingZone &zone)
{
   string name = zone.rect_name;
   
   if(ObjectFind(0, name) >= 0)
      ObjectDelete(0, name);
   
   datetime time_start = iTime(_Symbol, PERIOD_CURRENT, 50);
   datetime time_end = TimeCurrent() + PeriodSeconds() * 500;
   
   if(ObjectCreate(0, name, OBJ_RECTANGLE, 0, time_start, zone.top, time_end, zone.bottom))
   {
      color zone_color = zone.is_buy_zone ? Buy_Zone_Color : Sell_Zone_Color;
      ObjectSetInteger(0, name, OBJPROP_COLOR, zone_color);
      ObjectSetInteger(0, name, OBJPROP_FILL, true);
      ObjectSetInteger(0, name, OBJPROP_BACK, false);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, !zone.is_locked);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, false);
      ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
      
      // Apply transparency
      int r = (zone_color & 0xFF);
      int g = ((zone_color >> 8) & 0xFF);
      int b = ((zone_color >> 16) & 0xFF);
      int alpha = (int)((100 - Zone_Transparency) * 2.55);
      r = r + (255 - r) * (255 - alpha) / 255;
      g = g + (255 - g) * (255 - alpha) / 255;
      b = b + (255 - b) * (255 - alpha) / 255;
      color bg_color = (color)((b << 16) | (g << 8) | r);
      
      ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg_color);
      
      // Add label
      string label_name = name + "_LABEL";
      if(ObjectFind(0, label_name) >= 0)
         ObjectDelete(0, label_name);
         
      if(ObjectCreate(0, label_name, OBJ_TEXT, 0, time_start, zone.top))
      {
         ObjectSetString(0, label_name, OBJPROP_TEXT, zone.is_buy_zone ? "  BUY ZONE" : "  SELL ZONE");
         ObjectSetInteger(0, label_name, OBJPROP_COLOR, zone_color);
         ObjectSetInteger(0, label_name, OBJPROP_FONTSIZE, 10);
         ObjectSetString(0, label_name, OBJPROP_FONT, "Arial Bold");
         ObjectSetInteger(0, label_name, OBJPROP_ANCHOR, ANCHOR_LEFT);
      }
   }
}

//+------------------------------------------------------------------+
void LockTradingZones()
{
   if(buy_zone.is_active)
   {
      buy_zone.is_locked = true;
      ObjectSetInteger(0, buy_zone.rect_name, OBJPROP_SELECTABLE, false);
      Print("Buy zone locked at: ", buy_zone.top, " - ", buy_zone.bottom);
   }
   
   if(sell_zone.is_active)
   {
      sell_zone.is_locked = true;
      ObjectSetInteger(0, sell_zone.rect_name, OBJPROP_SELECTABLE, false);
      Print("Sell zone locked at: ", sell_zone.top, " - ", sell_zone.bottom);
   }
   
   Alert("Trading zones confirmed and locked!");
}

//+------------------------------------------------------------------+
void UnlockTradingZones()
{
   if(buy_zone.is_active)
   {
      buy_zone.is_locked = false;
      buy_zone.signal_triggered = false;
      ObjectSetInteger(0, buy_zone.rect_name, OBJPROP_SELECTABLE, true);
   }
   
   if(sell_zone.is_active)
   {
      sell_zone.is_locked = false;
      sell_zone.signal_triggered = false;
      ObjectSetInteger(0, sell_zone.rect_name, OBJPROP_SELECTABLE, true);
   }
   
   Print("Trading zones unlocked for editing");
}

//+------------------------------------------------------------------+
bool CheckSweepAndPattern(const datetime &time[], const double &open[], const double &high[], 
                          const double &low[], const double &close[], bool is_buy_signal)
{
   TradingZone &zone = is_buy_signal ? buy_zone : sell_zone;
   
   // Check last 10 bars for sweep in the zone
   for(int i = 1; i < 10; i++)
   {
      // Check if price touched the zone
      bool price_in_zone = false;
      
      if(is_buy_signal)
      {
         // For buy: low must touch the zone
         if(low[i] <= zone.top && low[i] >= zone.bottom)
            price_in_zone = true;
      }
      else
      {
         // For sell: high must touch the zone
         if(high[i] >= zone.bottom && high[i] <= zone.top)
            price_in_zone = true;
      }
      
      if(!price_in_zone)
         continue;
      
      // Check for sweep candle
      if(IsSweepCandle(open, high, low, close, i, is_buy_signal))
      {
         // Check for bottom/top formation in next N candles
         if(is_buy_signal)
         {
            if(IsBottomFormation(open, high, low, close, i))
            {
               Print("BUY Signal: Sweep at bar ", i, " + Bottom formation detected!");
               return true;
            }
         }
         else
         {
            if(IsTopFormation(open, high, low, close, i))
            {
               Print("SELL Signal: Sweep at bar ", i, " + Top formation detected!");
               return true;
            }
         }
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
bool IsSweepCandle(const double &open[], const double &high[], const double &low[], 
                   const double &close[], int index, bool check_for_buy)
{
   if(index + 1 >= ArraySize(open))
      return false;
   
   if(check_for_buy)
   {
      // Sweep low: Low[i] < Low[i+1]
      if(low[index] >= low[index + 1])
         return false;
      
      // Check close condition
      bool is_bearish = close[index] < open[index];
      
      if(is_bearish)
      {
         // Nến đỏ: Close[i] >= Close[i+1]
         if(close[index] >= close[index + 1])
            return true;
      }
      else
      {
         // Nến xanh: Close[i] >= Open[i] (luôn đúng cho nến xanh)
         // Hoặc so với cây liền kề: Close[i] >= Open[i+1]
         if(close[index] >= open[index + 1])
            return true;
      }
   }
   else
   {
      // Sweep high: High[i] > High[i+1]
      if(high[index] <= high[index + 1])
         return false;
      
      // Check close condition (ngược lại với sweep low)
      bool is_bullish = close[index] > open[index];
      
      if(is_bullish)
      {
         // Nến xanh: Close[i] <= Close[i+1]
         if(close[index] <= close[index + 1])
            return true;
      }
      else
      {
         // Nến đỏ: Close[i] <= Open[i+1]
         if(close[index] <= open[index + 1])
            return true;
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
bool IsBottomFormation(const double &open[], const double &high[], const double &low[], 
                       const double &close[], int sweep_index)
{
   // Tìm cây tạo đáy trong N cây tiếp theo
   // Tạo đáy: Close[i] > High[i+1]
   
   int search_end = MathMax(0, sweep_index - Sweep_Candles_Count);
   
   for(int i = sweep_index - 1; i >= search_end; i--)
   {
      if(i + 1 >= ArraySize(close))
         continue;
         
      // Điều kiện tạo đáy: Close của cây hiện tại > High của cây liền kề
      if(close[i] > high[i + 1])
      {
         Print("Bottom formation found at bar ", i, " (Close=", close[i], " > High[i+1]=", high[i+1], ")");
         return true;
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
bool IsTopFormation(const double &open[], const double &high[], const double &low[], 
                    const double &close[], int sweep_index)
{
   // Tìm cây tạo đỉnh trong N cây tiếp theo
   // Tạo đỉnh: Close[i] < Low[i+1]
   
   int search_end = MathMax(0, sweep_index - Sweep_Candles_Count);
   
   for(int i = sweep_index - 1; i >= search_end; i--)
   {
      if(i + 1 >= ArraySize(close))
         continue;
         
      // Điều kiện tạo đỉnh: Close của cây hiện tại < Low của cây liền kề
      if(close[i] < low[i + 1])
      {
         Print("Top formation found at bar ", i, " (Close=", close[i], " < Low[i+1]=", low[i+1], ")");
         return true;
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
void SendAlert(string message)
{
   if(Enable_Alert)
   {
      Alert(message);
   }
   
   if(Enable_Sound)
   {
      PlaySound(Alert_Sound);
   }
   
   Print("SIGNAL: ", message);
}

//+------------------------------------------------------------------+
void CreateFVG(datetime start_time, double top, double bottom, bool is_bullish, int bar_index)
{
   FVG_Count++;
   ArrayResize(FVG_Array, FVG_Count);
   
   int index = FVG_Count - 1;
   
   FVG_Array[index].time_start = start_time;
   FVG_Array[index].time_end = TimeCurrent() + PeriodSeconds() * 500;
   FVG_Array[index].top = top;
   FVG_Array[index].bottom = bottom;
   FVG_Array[index].original_top = top;
   FVG_Array[index].original_bottom = bottom;
   FVG_Array[index].is_bullish = is_bullish;
   FVG_Array[index].start_bar = bar_index;
   FVG_Array[index].is_active = true;
   FVG_Array[index].rect_name = indicator_prefix + TimeToString(start_time, TIME_DATE|TIME_SECONDS) + "_" + (is_bullish ? "Bull" : "Bear");
   
   DrawFVGRectangle(index);
}

//+------------------------------------------------------------------+
void DrawFVGRectangle(int index)
{
   string name = FVG_Array[index].rect_name;
   
   if(ObjectFind(0, name) >= 0)
      ObjectDelete(0, name);
   
   if(ObjectCreate(0, name, OBJ_RECTANGLE, 0,
                   FVG_Array[index].time_start, FVG_Array[index].top,
                   FVG_Array[index].time_end, FVG_Array[index].bottom))
   {
      color fvg_color = FVG_Array[index].is_bullish ? Bullish_FVG_Color : Bearish_FVG_Color;
      ObjectSetInteger(0, name, OBJPROP_COLOR, fvg_color);
      ObjectSetInteger(0, name, OBJPROP_FILL, true);
      ObjectSetInteger(0, name, OBJPROP_BACK, true);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
      
      int r = (fvg_color & 0xFF);
      int g = ((fvg_color >> 8) & 0xFF);
      int b = ((fvg_color >> 16) & 0xFF);
      int alpha = (int)((100 - FVG_Transparency) * 2.55);
      r = r + (255 - r) * (255 - alpha) / 255;
      g = g + (255 - g) * (255 - alpha) / 255;
      b = b + (255 - b) * (255 - alpha) / 255;
      color bg_color = (color)((b << 16) | (g << 8) | r);
      
      ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg_color);
   }
}

//+------------------------------------------------------------------+
void UpdateFVGStatus(const datetime &time[], const double &high[], const double &low[], const double &close[])
{
   for(int i = 0; i < FVG_Count; i++)
   {
      if(!FVG_Array[i].is_active)
         continue;
         
      for(int bar = 0; bar < MathMin(100, ArraySize(time)); bar++)
      {
         if(time[bar] <= FVG_Array[i].time_start)
            continue;
            
         bool is_modified = false;
         
         if(FVG_Array[i].is_bullish)
         {
            double bar_low = low[bar];
            
            if(Delete_On_Break && close[bar] < FVG_Array[i].bottom)
            {
               FVG_Array[i].is_active = false;
               ObjectDelete(0, FVG_Array[i].rect_name);
               break;
            }
            
            if(Fill_On_Touch && bar_low < FVG_Array[i].top && bar_low > FVG_Array[i].bottom)
            {
               FVG_Array[i].top = bar_low;
               is_modified = true;
               
               if(FVG_Array[i].top - FVG_Array[i].bottom < Min_FVG_Points * _Point)
               {
                  FVG_Array[i].is_active = false;
                  ObjectDelete(0, FVG_Array[i].rect_name);
                  break;
               }
            }
         }
         else
         {
            double bar_high = high[bar];
            
            if(Delete_On_Break && close[bar] > FVG_Array[i].top)
            {
               FVG_Array[i].is_active = false;
               ObjectDelete(0, FVG_Array[i].rect_name);
               break;
            }
            
            if(Fill_On_Touch && bar_high > FVG_Array[i].bottom && bar_high < FVG_Array[i].top)
            {
               FVG_Array[i].bottom = bar_high;
               is_modified = true;
               
               if(FVG_Array[i].top - FVG_Array[i].bottom < Min_FVG_Points * _Point)
               {
                  FVG_Array[i].is_active = false;
                  ObjectDelete(0, FVG_Array[i].rect_name);
                  break;
               }
            }
         }
         
         if(is_modified)
            DrawFVGRectangle(i);
      }
      
      if(FVG_Array[i].is_active)
      {
         FVG_Array[i].time_end = TimeCurrent() + PeriodSeconds() * 500;
         ObjectSetInteger(0, FVG_Array[i].rect_name, OBJPROP_TIME, 1, FVG_Array[i].time_end);
      }
   }
}

//+------------------------------------------------------------------+
void DeleteAllObjects()
{
   int total = ObjectsTotal(0, 0, OBJ_RECTANGLE);
   for(int i = total - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i, 0, OBJ_RECTANGLE);
      if(StringFind(name, indicator_prefix) >= 0 || 
         StringFind(name, news_prefix) >= 0 ||
         StringFind(name, zone_prefix) >= 0)
         ObjectDelete(0, name);
   }
   
   total = ObjectsTotal(0, 0, OBJ_VLINE);
   for(int i = total - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i, 0, OBJ_VLINE);
      if(StringFind(name, news_prefix) >= 0)
         ObjectDelete(0, name);
   }
   
   total = ObjectsTotal(0, 0, OBJ_BUTTON);
   for(int i = total - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i, 0, OBJ_BUTTON);
      if(StringFind(name, button_prefix) >= 0)
         ObjectDelete(0, name);
   }
   
   total = ObjectsTotal(0, 0, OBJ_TEXT);
   for(int i = total - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i, 0, OBJ_TEXT);
      if(StringFind(name, zone_prefix) >= 0)
         ObjectDelete(0, name);
   }
}

//+------------------------------------------------------------------+
void LoadNewsSettings()
{
   ArrayResize(news_times, 0);
   int count = 0;
   
   if(Filter_USD)
   {
      AddNewsTime(count, "USD", 5, 13, 30, 3, "NFP");
      AddNewsTime(count, "USD", 3, 20, 0, 3, "FOMC Rate");
      AddNewsTime(count, "USD", 3, 20, 30, 3, "FOMC Press");
      AddNewsTime(count, "USD", 3, 13, 30, 2, "CPI");
      AddNewsTime(count, "USD", 2, 13, 30, 2, "Retail Sales");
      AddNewsTime(count, "USD", 4, 13, 30, 2, "PPI");
      AddNewsTime(count, "USD", 5, 15, 0, 2, "ISM Manufacturing");
      AddNewsTime(count, "USD", 4, 13, 30, 1, "Jobless Claims");
      AddNewsTime(count, "USD", 2, 15, 0, 1, "Consumer Conf");
   }
   
   if(Filter_EUR)
   {
      AddNewsTime(count, "EUR", 3, 12, 0, 3, "ECB Rate");
      AddNewsTime(count, "EUR", 3, 12, 30, 3, "ECB Press Conf");
      AddNewsTime(count, "EUR", 4, 10, 0, 3, "Eurozone GDP");
      AddNewsTime(count, "EUR", 2, 10, 0, 2, "German CPI");
      AddNewsTime(count, "EUR", 5, 9, 0, 2, "German PMI");
      AddNewsTime(count, "EUR", 1, 8, 0, 1, "German ZEW");
      AddNewsTime(count, "EUR", 2, 9, 0, 1, "German IFO");
   }
   
   if(Filter_GBP)
   {
      AddNewsTime(count, "GBP", 4, 12, 0, 3, "BOE Rate");
      AddNewsTime(count, "GBP", 3, 7, 0, 3, "UK GDP");
      AddNewsTime(count, "GBP", 2, 7, 0, 2, "UK CPI");
      AddNewsTime(count, "GBP", 5, 9, 30, 2, "UK Retail Sales");
      AddNewsTime(count, "GBP", 1, 9, 30, 2, "UK PMI");
      AddNewsTime(count, "GBP", 3, 9, 30, 1, "UK Manufacturing");
   }
   
   if(Filter_JPY)
   {
      AddNewsTime(count, "JPY", 4, 3, 0, 3, "BOJ Rate");
      AddNewsTime(count, "JPY", 5, 0, 30, 2, "Tankan Survey");
      AddNewsTime(count, "JPY", 1, 0, 0, 2, "Japan PMI");
      AddNewsTime(count, "JPY", 3, 23, 50, 1, "Japan CPI");
   }
   
   if(Filter_AUD)
   {
      AddNewsTime(count, "AUD", 1, 4, 30, 3, "RBA Rate");
      AddNewsTime(count, "AUD", 3, 0, 30, 3, "Australia GDP");
      AddNewsTime(count, "AUD", 4, 0, 30, 2, "Employment");
      AddNewsTime(count, "AUD", 2, 0, 0, 1, "RBA Minutes");
   }
   
   if(Filter_CAD)
   {
      AddNewsTime(count, "CAD", 3, 15, 0, 3, "BOC Rate");
      AddNewsTime(count, "CAD", 5, 13, 30, 3, "CAD Employment");
      AddNewsTime(count, "CAD", 2, 13, 30, 2, "CAD CPI");
      AddNewsTime(count, "CAD", 4, 14, 30, 1, "CAD Retail");
   }
   
   if(Filter_CHF)
   {
      AddNewsTime(count, "CHF", 4, 8, 30, 3, "SNB Rate");
      AddNewsTime(count, "CHF", 2, 8, 0, 2, "Swiss CPI");
   }
   
   if(Filter_NZD)
   {
      AddNewsTime(count, "NZD", 2, 21, 0, 3, "RBNZ Rate");
      AddNewsTime(count, "NZD", 3, 22, 45, 2, "NZ GDP");
      AddNewsTime(count, "NZD", 4, 22, 45, 1, "NZ Employment");
   }
   
   Print("News filter loaded: ", count, " events from selected currencies");
}

//+------------------------------------------------------------------+
void AddNewsTime(int &count, string curr, int day, int hour, int min, int impact, string name)
{
   bool should_add = false;
   if(impact == 3 && Filter_High_Impact) should_add = true;
   if(impact == 2 && Filter_Medium_Impact) should_add = true;
   if(impact == 1 && Filter_Low_Impact) should_add = true;
   
   if(!should_add)
      return;
   
   ArrayResize(news_times, count + 1);
   news_times[count].currency = curr;
   news_times[count].day_of_week = day;
   news_times[count].hour = hour;
   news_times[count].minute = min;
   news_times[count].impact = impact;
   news_times[count].name = name;
   count++;
}

//+------------------------------------------------------------------+
bool IsNewsTime(datetime check_time)
{
   if(!Enable_News_Filter)
      return false;
   
   MqlDateTime dt;
   TimeToStruct(check_time, dt);
   
   for(int i = 0; i < ArraySize(news_times); i++)
   {
      if(dt.day_of_week == news_times[i].day_of_week)
      {
         MqlDateTime news_dt = dt;
         news_dt.hour = news_times[i].hour;
         news_dt.min = news_times[i].minute;
         news_dt.sec = 0;
         
         datetime news_time = StructToTime(news_dt);
         datetime time_start = news_time - News_Minutes_Before * 60;
         datetime time_end = news_time + News_Minutes_After * 60;
         
         if(check_time >= time_start && check_time <= time_end)
            return true;
      }
   }
   
   return false;
}
//+------------------------------------------------------------------+
