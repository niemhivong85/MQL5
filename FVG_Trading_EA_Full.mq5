//+------------------------------------------------------------------+
//|                                       FVG_Trading_EA_Full.mq5    |
//|                    Fair Value Gap EA with Manual Zone Creation   |
//|                    + Automatic Trading                           |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025"
#property version   "2.00"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\AccountInfo.mqh>

//--- Trading objects
CTrade trade;
CPositionInfo position;
CAccountInfo account;

//--- Input parameters - FVG Settings
input group    "=== FVG Settings ==="
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
input group    "=== News Filter ==="
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
input int      Sweep_Candles_Count = 5;
input bool     Enable_Alert = true;
input bool     Enable_Sound = true;
input string   Alert_Sound = "alert.wav";
input bool     Zone_Mitigate_On_Touch = true;
input bool     Zone_Delete_On_Break = true;

input group    "=== Sweep Detection Display ==="
input bool     Show_Historical_Sweeps = true;     // Hiển thị sweep lịch sử
input int      Historical_Sweep_Bars = 500;       // Số nến quét lại
input bool     Mark_Sweep_With_Formation = true;  // Đánh dấu sweep CÓ formation
input bool     Mark_Sweep_Without_Formation = false; // Đánh dấu sweep CHƯA có formation
input color    Sweep_Buy_Color = clrLime;         // Màu mũi tên BUY (sweep low)
input color    Sweep_Sell_Color = clrRed;         // Màu mũi tên SELL (sweep high)
input int      Sweep_Arrow_Size = 2;              // Kích thước mũi tên

input group    "=== Stop Loss Settings ==="
input bool     SL_Use_Sweep_Low = true;
input bool     SL_Use_Zone_Edge = false;
input int      SL_Buffer_Points = 5;
input int      Min_SL_Points = 50;
input int      Max_SL_Points = 500;

input group    "=== Position Sizing ==="
input double   Risk_Percent_Per_Trade = 1.0;
input double   Risk_Amount_Per_Trade = 0;
input bool     Auto_Calculate_Lot = true;
input double   Manual_Lot_Size = 0.01;
input double   Max_Lot_Size = 10.0;

input group    "=== Take Profit - EMA Trailing ==="
input bool     Use_EMA_Exit = true;
input int      EMA_Period = 20;
input ENUM_TIMEFRAMES EMA_Timeframe = PERIOD_CURRENT;

input group    "=== Take Profit - Risk Reward ==="
input bool     Use_RR_Exit = true;
input double   RR_Level_1 = 1.0;
input double   RR_Close_Percent_1 = 50.0;
input double   RR_Level_2 = 2.0;
input double   RR_Close_Percent_2 = 30.0;
input double   RR_Level_3 = 3.0;
input double   RR_Close_Percent_3 = 20.0;

input group    "=== EA Control ==="
input bool     EA_Enabled = true;
input bool     Auto_Trade_On_Signal = true;  // TỰ ĐỘNG VÀO LỆNH khi có tín hiệu
input bool     Trade_Buy_Signals = true;
input bool     Trade_Sell_Signals = true;
input bool     One_Trade_At_Time = true;
input int      Magic_Number = 123456;
input string   Trade_Comment = "FVG_EA";

input group    "=== Button & Zone Colors ==="
input color    Buy_Zone_Color = clrDodgerBlue;
input color    Sell_Zone_Color = clrOrangeRed;
input color    Button_Buy_Color = clrLimeGreen;
input color    Button_Sell_Color = clrRed;
input color    Button_Confirm_Color = clrGold;
input color    Button_Edit_Color = clrOrange;
input color    SL_Line_Color = clrRed;
input color    TP_Line_Color = clrGreen;
input int      Zone_Transparency = 70;
input int      Zone_Border_Width = 3;

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
   double   original_top;
   double   original_bottom;
   bool     is_active;
   bool     is_locked;
   bool     is_buy_zone;
   string   rect_name;
   string   btn_lock_name;
   string   btn_edit_name;
   string   btn_delete_name;
   string   sweep_marker_names[];  // Danh sách các sweep markers của zone này
   int      sweep_count;
   bool     signal_triggered;
   datetime last_check_time;
   int      sweep_bar_index;
   double   sweep_low;
   double   sweep_high;
   double   stop_loss_price;
   double   entry_price;
   double   lot_size;
   double   tp1_price;
   double   tp2_price;
   double   tp3_price;
   bool     order_placed;
   ulong    ticket;
   double   initial_lot;
   double   remaining_lot;
};

//--- Global variables
FVG_Structure FVG_Array[];
int FVG_Count = 0;
string indicator_prefix = "FVG_";
string news_prefix = "NEWS_";
string button_prefix = "BTN_";
string zone_prefix = "ZONE_";
string sweep_prefix = "SWEEP_";
NewsTime news_times[];

// Trading Zone variables
TradingZone buy_zone;
TradingZone sell_zone;
bool creating_buy_zone = false;
bool creating_sell_zone = false;
datetime last_chart_event = 0;

// EMA Handle
int ema_handle = INVALID_HANDLE;
double ema_buffer[];

// Button names (chỉ dùng cho buttons MUA/BÁN chính)
string btn_buy = button_prefix + "BUY";
string btn_sell = button_prefix + "SELL";

// Last bar time for new bar detection
datetime last_bar_time = 0;

//--- Forward declarations
void DeleteAllObjects();
void LoadNewsSettings();
void AddNewsTime(int &count, string curr, int day, int hour, int min, int impact, string name);
bool IsNewsTime(datetime check_time);
void CreateFVG(datetime start_time, double top, double bottom, bool is_bullish, int bar_index);
void DrawFVGRectangle(int index);
void UpdateFVGStatus(const datetime &time[], const double &high[], const double &low[], const double &close[]);
void CreateButtons();
void UpdateZoneButtons(TradingZone &zone);
void CreateTradingZone(bool is_buy);
void DrawTradingZone(TradingZone &zone);
void LockZone(TradingZone &zone);
void UnlockZone(TradingZone &zone);
void DeleteZone(TradingZone &zone);
bool CheckSweepAndPattern(const datetime &time[], const double &open[], const double &high[], const double &low[], const double &close[], bool is_buy_signal);
bool IsSweepCandle(const double &open[], const double &high[], const double &low[], const double &close[], int index, bool check_for_buy);
bool IsBottomFormation(const double &open[], const double &high[], const double &low[], const double &close[], int sweep_index);
bool IsTopFormation(const double &open[], const double &high[], const double &low[], const double &close[], int sweep_index);
void SendAlert(string message);
void MarkSweepCandle(datetime time, double price, bool is_sweep_low);
void UpdateZoneMitigation(TradingZone &zone, const double &high[], const double &low[], const double &close[]);
void CalculateStopLoss(TradingZone &zone, const double &high[], const double &low[]);
double CalculateLotSize(double stop_loss_points);
void DrawTradeLevels(TradingZone &zone);
void ExecuteTrade(TradingZone &zone);
bool CheckEMAExit(bool is_buy_position);
void UpdateTrailingStop(TradingZone &zone);
void ManageOpenPositions();
void ClosePartialPosition(ulong ticket, double lot_to_close, string reason);
bool HasOpenPosition(bool is_buy);
double NormalizeLot(double lot);
void DisplayInfo();
void DetectFVGs(const datetime &time[], const double &open[], const double &high[], const double &low[], const double &close[]);

//+------------------------------------------------------------------+
int OnInit()
{
   // Setup trade object
   trade.SetExpertMagicNumber(Magic_Number);
   trade.SetDeviationInPoints(10);
   trade.SetTypeFilling(ORDER_FILLING_FOK);
   trade.SetAsyncMode(false);
   
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
   buy_zone.btn_lock_name = button_prefix + "BUY_LOCK";
   buy_zone.btn_edit_name = button_prefix + "BUY_EDIT";
   buy_zone.btn_delete_name = button_prefix + "BUY_DELETE";
   ArrayResize(buy_zone.sweep_marker_names, 0);
   buy_zone.sweep_count = 0;
   buy_zone.signal_triggered = false;
   buy_zone.order_placed = false;
   buy_zone.top = 0;
   buy_zone.bottom = 0;
   buy_zone.original_top = 0;
   buy_zone.original_bottom = 0;
   buy_zone.sweep_bar_index = -1;
   buy_zone.sweep_low = 0;
   buy_zone.sweep_high = 0;
   buy_zone.stop_loss_price = 0;
   buy_zone.entry_price = 0;
   buy_zone.lot_size = 0;
   buy_zone.ticket = 0;
   buy_zone.initial_lot = 0;
   buy_zone.remaining_lot = 0;
   
   sell_zone.is_active = false;
   sell_zone.is_locked = false;
   sell_zone.is_buy_zone = false;
   sell_zone.rect_name = zone_prefix + "SELL";
   sell_zone.btn_lock_name = button_prefix + "SELL_LOCK";
   sell_zone.btn_edit_name = button_prefix + "SELL_EDIT";
   sell_zone.btn_delete_name = button_prefix + "SELL_DELETE";
   sell_zone.signal_triggered = false;
   sell_zone.order_placed = false;
   sell_zone.top = 0;
   sell_zone.bottom = 0;
   sell_zone.original_top = 0;
   sell_zone.original_bottom = 0;
   sell_zone.sweep_bar_index = -1;
   sell_zone.sweep_low = 0;
   sell_zone.sweep_high = 0;
   sell_zone.stop_loss_price = 0;
   sell_zone.entry_price = 0;
   sell_zone.lot_size = 0;
   sell_zone.ticket = 0;
   sell_zone.initial_lot = 0;
   sell_zone.remaining_lot = 0;
   
   // Initialize EMA
   if(Use_EMA_Exit)
   {
      ema_handle = iMA(_Symbol, EMA_Timeframe, EMA_Period, 0, MODE_EMA, PRICE_CLOSE);
      if(ema_handle == INVALID_HANDLE)
      {
         Print("Failed to create EMA indicator handle");
         return(INIT_FAILED);
      }
      ArraySetAsSeries(ema_buffer, true);
   }
   
   // Validate TP percentages
   double total_percent = RR_Close_Percent_1 + RR_Close_Percent_2 + RR_Close_Percent_3;
   if(MathAbs(total_percent - 100.0) > 0.01)
   {
      Print("⚠️ Warning: TP percentages don't sum to 100% (Total: ", total_percent, "%). Please adjust settings.");
      Print("   RR_Close_Percent_1 + RR_Close_Percent_2 + RR_Close_Percent_3 should equal 100%");
   }
   
   CreateButtons();
   
   ChartRedraw();
   
   Print("✅ FVG Trading EA initialized successfully");
   Print("   Manual Zone Creation: ENABLED (Use buttons)");
   Print("   Auto Trade: ", Auto_Trade_On_Signal ? "ENABLED" : "DISABLED");
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(ema_handle != INVALID_HANDLE)
      IndicatorRelease(ema_handle);
   
   DeleteAllObjects();
   Comment("");
}

//+------------------------------------------------------------------+
void OnTick()
{
   if(!EA_Enabled)
      return;
   
   // Check for new bar
   datetime current_bar_time = iTime(_Symbol, PERIOD_CURRENT, 0);
   bool is_new_bar = (current_bar_time != last_bar_time);
   
   if(is_new_bar)
   {
      last_bar_time = current_bar_time;
      
      // Get price data
      datetime time[];
      double open[], high[], low[], close[];
      
      ArraySetAsSeries(time, true);
      ArraySetAsSeries(open, true);
      ArraySetAsSeries(high, true);
      ArraySetAsSeries(low, true);
      ArraySetAsSeries(close, true);
      
      int copied = CopyTime(_Symbol, PERIOD_CURRENT, 0, MathMin(FVG_LookBack + 10, 1000), time);
      if(copied <= 0) return;
      
      CopyOpen(_Symbol, PERIOD_CURRENT, 0, copied, open);
      CopyHigh(_Symbol, PERIOD_CURRENT, 0, copied, high);
      CopyLow(_Symbol, PERIOD_CURRENT, 0, copied, low);
      CopyClose(_Symbol, PERIOD_CURRENT, 0, copied, close);
      
      // Detect FVGs
      DetectFVGs(time, open, high, low, close);
      
      // Update FVG status
      UpdateFVGStatus(time, high, low, close);
      
      // Update zone mitigation
      if(buy_zone.is_active && buy_zone.is_locked)
         UpdateZoneMitigation(buy_zone, high, low, close);
      
      if(sell_zone.is_active && sell_zone.is_locked)
         UpdateZoneMitigation(sell_zone, high, low, close);
      
      // Check for trading signals on LOCKED zones
      if(buy_zone.is_active && buy_zone.is_locked && !buy_zone.signal_triggered)
      {
         if(CheckSweepAndPattern(time, open, high, low, close, true))
         {
            buy_zone.signal_triggered = true;
            CalculateStopLoss(buy_zone, high, low);
            buy_zone.entry_price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            
            double sl_points = MathAbs(buy_zone.entry_price - buy_zone.stop_loss_price) / _Point;
            
            // Validate SL
            if(sl_points < Min_SL_Points)
            {
               buy_zone.stop_loss_price = buy_zone.entry_price - Min_SL_Points * _Point;
               sl_points = Min_SL_Points;
            }
            if(sl_points > Max_SL_Points)
            {
               buy_zone.stop_loss_price = buy_zone.entry_price - Max_SL_Points * _Point;
               sl_points = Max_SL_Points;
            }
            
            buy_zone.lot_size = CalculateLotSize(sl_points);
            
            // Calculate TP levels
            double risk_distance = buy_zone.entry_price - buy_zone.stop_loss_price;
            buy_zone.tp1_price = buy_zone.entry_price + (risk_distance * RR_Level_1);
            buy_zone.tp2_price = buy_zone.entry_price + (risk_distance * RR_Level_2);
            buy_zone.tp3_price = buy_zone.entry_price + (risk_distance * RR_Level_3);
            
            DrawTradeLevels(buy_zone);
            
            string msg = StringFormat("🔵 BUY SIGNAL\nEntry: %.5f\nSL: %.5f (%.1f pts)\nLot: %.2f\nTP1: %.5f | TP2: %.5f | TP3: %.5f",
                                      buy_zone.entry_price, buy_zone.stop_loss_price, sl_points,
                                      buy_zone.lot_size, buy_zone.tp1_price, buy_zone.tp2_price, buy_zone.tp3_price);
            SendAlert(msg);
            
            // AUTO TRADE if enabled
            if(Auto_Trade_On_Signal && Trade_Buy_Signals)
            {
               ExecuteTrade(buy_zone);
            }
         }
      }
      
      if(sell_zone.is_active && sell_zone.is_locked && !sell_zone.signal_triggered)
      {
         if(CheckSweepAndPattern(time, open, high, low, close, false))
         {
            sell_zone.signal_triggered = true;
            CalculateStopLoss(sell_zone, high, low);
            sell_zone.entry_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            
            double sl_points = MathAbs(sell_zone.stop_loss_price - sell_zone.entry_price) / _Point;
            
            // Validate SL
            if(sl_points < Min_SL_Points)
            {
               sell_zone.stop_loss_price = sell_zone.entry_price + Min_SL_Points * _Point;
               sl_points = Min_SL_Points;
            }
            if(sl_points > Max_SL_Points)
            {
               sell_zone.stop_loss_price = sell_zone.entry_price + Max_SL_Points * _Point;
               sl_points = Max_SL_Points;
            }
            
            sell_zone.lot_size = CalculateLotSize(sl_points);
            
            // Calculate TP levels
            double risk_distance = sell_zone.stop_loss_price - sell_zone.entry_price;
            sell_zone.tp1_price = sell_zone.entry_price - (risk_distance * RR_Level_1);
            sell_zone.tp2_price = sell_zone.entry_price - (risk_distance * RR_Level_2);
            sell_zone.tp3_price = sell_zone.entry_price - (risk_distance * RR_Level_3);
            
            DrawTradeLevels(sell_zone);
            
            string msg = StringFormat("🔴 SELL SIGNAL\nEntry: %.5f\nSL: %.5f (%.1f pts)\nLot: %.2f\nTP1: %.5f | TP2: %.5f | TP3: %.5f",
                                      sell_zone.entry_price, sell_zone.stop_loss_price, sl_points,
                                      sell_zone.lot_size, sell_zone.tp1_price, sell_zone.tp2_price, sell_zone.tp3_price);
            SendAlert(msg);
            
            // AUTO TRADE if enabled
            if(Auto_Trade_On_Signal && Trade_Sell_Signals)
            {
               ExecuteTrade(sell_zone);
            }
         }
      }
   }
   
   // Manage open positions (every tick)
   ManageOpenPositions();
   
   // Update display info
   DisplayInfo();
}

//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
   if(id == CHARTEVENT_OBJECT_CLICK)
   {
      // Main buttons
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
      // BUY zone buttons
      else if(sparam == buy_zone.btn_lock_name)
      {
         LockZone(buy_zone);
         ObjectSetInteger(0, buy_zone.btn_lock_name, OBJPROP_STATE, false);
      }
      else if(sparam == buy_zone.btn_edit_name)
      {
         UnlockZone(buy_zone);
         ObjectSetInteger(0, buy_zone.btn_edit_name, OBJPROP_STATE, false);
      }
      else if(sparam == buy_zone.btn_delete_name)
      {
         DeleteZone(buy_zone);
         ObjectSetInteger(0, buy_zone.btn_delete_name, OBJPROP_STATE, false);
      }
      // SELL zone buttons
      else if(sparam == sell_zone.btn_lock_name)
      {
         LockZone(sell_zone);
         ObjectSetInteger(0, sell_zone.btn_lock_name, OBJPROP_STATE, false);
      }
      else if(sparam == sell_zone.btn_edit_name)
      {
         UnlockZone(sell_zone);
         ObjectSetInteger(0, sell_zone.btn_edit_name, OBJPROP_STATE, false);
      }
      else if(sparam == sell_zone.btn_delete_name)
      {
         DeleteZone(sell_zone);
         ObjectSetInteger(0, sell_zone.btn_delete_name, OBJPROP_STATE, false);
      }
   }
   
   // Update zone when dragged or resized
   if(id == CHARTEVENT_OBJECT_DRAG || id == CHARTEVENT_OBJECT_ENDEDIT)
   {
      if(sparam == buy_zone.rect_name && buy_zone.is_active && !buy_zone.is_locked)
      {
         // Cập nhật cả vị trí và kích thước
         buy_zone.top = ObjectGetDouble(0, buy_zone.rect_name, OBJPROP_PRICE, 0);
         buy_zone.bottom = ObjectGetDouble(0, buy_zone.rect_name, OBJPROP_PRICE, 1);
         
         // Đảm bảo top > bottom
         if(buy_zone.top < buy_zone.bottom)
         {
            double temp = buy_zone.top;
            buy_zone.top = buy_zone.bottom;
            buy_zone.bottom = temp;
         }
         
         Print("📐 BUY Zone updated: Top=", buy_zone.top, " | Bottom=", buy_zone.bottom, " | Size=", (buy_zone.top - buy_zone.bottom)/_Point, " points");
      }
      else if(sparam == sell_zone.rect_name && sell_zone.is_active && !sell_zone.is_locked)
      {
         // Cập nhật cả vị trí và kích thước
         sell_zone.top = ObjectGetDouble(0, sell_zone.rect_name, OBJPROP_PRICE, 0);
         sell_zone.bottom = ObjectGetDouble(0, sell_zone.rect_name, OBJPROP_PRICE, 1);
         
         // Đảm bảo top > bottom
         if(sell_zone.top < sell_zone.bottom)
         {
            double temp = sell_zone.top;
            sell_zone.top = sell_zone.bottom;
            sell_zone.bottom = temp;
         }
         
         Print("📐 SELL Zone updated: Top=", sell_zone.top, " | Bottom=", sell_zone.bottom, " | Size=", (sell_zone.top - sell_zone.bottom)/_Point, " points");
      }
   }
}

//+------------------------------------------------------------------+
void CreateButtons()
{
   int x_start = 20;
   int y_start = 30;
   int btn_width = 120;
   int btn_height = 35;
   int btn_spacing = 10;
   
   // Buy button
   if(ObjectCreate(0, btn_buy, OBJ_BUTTON, 0, 0, 0))
   {
      ObjectSetInteger(0, btn_buy, OBJPROP_XDISTANCE, x_start);
      ObjectSetInteger(0, btn_buy, OBJPROP_YDISTANCE, y_start);
      ObjectSetInteger(0, btn_buy, OBJPROP_XSIZE, btn_width);
      ObjectSetInteger(0, btn_buy, OBJPROP_YSIZE, btn_height);
      ObjectSetString(0, btn_buy, OBJPROP_TEXT, "➕ TẠO ZONE MUA");
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
      ObjectSetString(0, btn_sell, OBJPROP_TEXT, "➕ TẠO ZONE BÁN");
      ObjectSetInteger(0, btn_sell, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, btn_sell, OBJPROP_BGCOLOR, Button_Sell_Color);
      ObjectSetInteger(0, btn_sell, OBJPROP_BORDER_COLOR, clrBlack);
      ObjectSetInteger(0, btn_sell, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, btn_sell, OBJPROP_FONTSIZE, 10);
      ObjectSetString(0, btn_sell, OBJPROP_FONT, "Arial Bold");
   }
}

//+------------------------------------------------------------------+
void UpdateZoneButtons(TradingZone &zone)
{
   int y_base = zone.is_buy_zone ? 80 : 130;
   int x_start = 20;
   int btn_width = 80;
   int btn_height = 30;
   int btn_spacing = 5;
   
   // LOCK button (chỉ hiện khi chưa lock)
   if(ObjectFind(0, zone.btn_lock_name) >= 0)
      ObjectDelete(0, zone.btn_lock_name);
   
   if(zone.is_active && !zone.is_locked)
   {
      if(ObjectCreate(0, zone.btn_lock_name, OBJ_BUTTON, 0, 0, 0))
      {
         ObjectSetInteger(0, zone.btn_lock_name, OBJPROP_XDISTANCE, x_start);
         ObjectSetInteger(0, zone.btn_lock_name, OBJPROP_YDISTANCE, y_base);
         ObjectSetInteger(0, zone.btn_lock_name, OBJPROP_XSIZE, btn_width);
         ObjectSetInteger(0, zone.btn_lock_name, OBJPROP_YSIZE, btn_height);
         ObjectSetString(0, zone.btn_lock_name, OBJPROP_TEXT, "🔒 XÁC NHẬN");
         ObjectSetInteger(0, zone.btn_lock_name, OBJPROP_COLOR, clrBlack);
         ObjectSetInteger(0, zone.btn_lock_name, OBJPROP_BGCOLOR, clrGold);
         ObjectSetInteger(0, zone.btn_lock_name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
         ObjectSetInteger(0, zone.btn_lock_name, OBJPROP_FONTSIZE, 8);
      }
   }
   
   // EDIT button (chỉ hiện khi đã lock)
   if(ObjectFind(0, zone.btn_edit_name) >= 0)
      ObjectDelete(0, zone.btn_edit_name);
   
   if(zone.is_active && zone.is_locked)
   {
      if(ObjectCreate(0, zone.btn_edit_name, OBJ_BUTTON, 0, 0, 0))
      {
         ObjectSetInteger(0, zone.btn_edit_name, OBJPROP_XDISTANCE, x_start + btn_width + btn_spacing);
         ObjectSetInteger(0, zone.btn_edit_name, OBJPROP_YDISTANCE, y_base);
         ObjectSetInteger(0, zone.btn_edit_name, OBJPROP_XSIZE, btn_width);
         ObjectSetInteger(0, zone.btn_edit_name, OBJPROP_YSIZE, btn_height);
         ObjectSetString(0, zone.btn_edit_name, OBJPROP_TEXT, "✏️ SỬA");
         ObjectSetInteger(0, zone.btn_edit_name, OBJPROP_COLOR, clrWhite);
         ObjectSetInteger(0, zone.btn_edit_name, OBJPROP_BGCOLOR, Button_Edit_Color);
         ObjectSetInteger(0, zone.btn_edit_name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
         ObjectSetInteger(0, zone.btn_edit_name, OBJPROP_FONTSIZE, 9);
      }
   }
   
   // DELETE button (luôn hiện khi zone active)
   if(ObjectFind(0, zone.btn_delete_name) >= 0)
      ObjectDelete(0, zone.btn_delete_name);
   
   if(zone.is_active)
   {
      int x_pos = zone.is_locked ? (x_start + (btn_width + btn_spacing) * 2) : (x_start + btn_width + btn_spacing);
      
      if(ObjectCreate(0, zone.btn_delete_name, OBJ_BUTTON, 0, 0, 0))
      {
         ObjectSetInteger(0, zone.btn_delete_name, OBJPROP_XDISTANCE, x_pos);
         ObjectSetInteger(0, zone.btn_delete_name, OBJPROP_YDISTANCE, y_base);
         ObjectSetInteger(0, zone.btn_delete_name, OBJPROP_XSIZE, btn_width);
         ObjectSetInteger(0, zone.btn_delete_name, OBJPROP_YSIZE, btn_height);
         ObjectSetString(0, zone.btn_delete_name, OBJPROP_TEXT, "🗑️ XÓA");
         ObjectSetInteger(0, zone.btn_delete_name, OBJPROP_COLOR, clrWhite);
         ObjectSetInteger(0, zone.btn_delete_name, OBJPROP_BGCOLOR, clrMaroon);
         ObjectSetInteger(0, zone.btn_delete_name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
         ObjectSetInteger(0, zone.btn_delete_name, OBJPROP_FONTSIZE, 9);
      }
   }
}

//+------------------------------------------------------------------+
void CreateTradingZone(bool is_buy)
{
   double current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   // Tạo zone LỚN HƠN để dễ nhìn và dễ kéo (500 points = dễ thấy)
   double zone_size = 500 * _Point;  // Kích thước mặc định 500 points
   
   if(is_buy)
   {
      // BUY zone nằm DƯỚI giá hiện tại
      buy_zone.top = current_price - 200 * _Point;
      buy_zone.bottom = buy_zone.top - zone_size;
      buy_zone.original_top = buy_zone.top;
      buy_zone.original_bottom = buy_zone.bottom;
      buy_zone.is_active = true;
      buy_zone.is_locked = false;
      buy_zone.signal_triggered = false;
      buy_zone.order_placed = false;
      
      DrawTradingZone(buy_zone);
      UpdateZoneButtons(buy_zone);
      Print("✅ BUY zone created:");
      Print("   Top: ", buy_zone.top);
      Print("   Bottom: ", buy_zone.bottom);
      Print("   Size: ", zone_size/_Point, " points");
      Print("   👉 Kéo góc/cạnh để thay đổi kích thước!");
   }
   else
   {
      // SELL zone nằm TRÊN giá hiện tại
      sell_zone.bottom = current_price + 200 * _Point;
      sell_zone.top = sell_zone.bottom + zone_size;
      sell_zone.original_top = sell_zone.top;
      sell_zone.original_bottom = sell_zone.bottom;
      sell_zone.is_active = true;
      sell_zone.is_locked = false;
      sell_zone.signal_triggered = false;
      sell_zone.order_placed = false;
      
      DrawTradingZone(sell_zone);
      UpdateZoneButtons(sell_zone);
      Print("✅ SELL zone created:");
      Print("   Top: ", sell_zone.top);
      Print("   Bottom: ", sell_zone.bottom);
      Print("   Size: ", zone_size/_Point, " points");
      Print("   👉 Kéo góc/cạnh để thay đổi kích thước!");
   }
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
      
      // KEY CHANGE: Cho phép di chuyển và resize khi chưa lock
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, !zone.is_locked);  // Có thể chọn để di chuyển/resize
      ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, false);
      ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, Zone_Border_Width);
      ObjectSetInteger(0, name, OBJPROP_ZORDER, 0);
      
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
         string label_text;
         if(zone.is_locked)
         {
            label_text = zone.is_buy_zone ? "  🔒 BUY ZONE [LOCKED]" : "  🔒 SELL ZONE [LOCKED]";
         }
         else
         {
            label_text = zone.is_buy_zone ? "  🔵 BUY ZONE [Kéo góc/cạnh để thay đổi kích thước]" : "  🔴 SELL ZONE [Kéo góc/cạnh để thay đổi kích thước]";
         }
            
         ObjectSetString(0, label_name, OBJPROP_TEXT, label_text);
         ObjectSetInteger(0, label_name, OBJPROP_COLOR, zone_color);
         ObjectSetInteger(0, label_name, OBJPROP_FONTSIZE, 10);
         ObjectSetString(0, label_name, OBJPROP_FONT, "Arial Bold");
         ObjectSetInteger(0, label_name, OBJPROP_ANCHOR, ANCHOR_LEFT);
      }
   }
   
   ChartRedraw();
   
   if(!zone.is_locked)
   {
      Print("💡 ", zone.is_buy_zone ? "BUY" : "SELL", " Zone có thể:");
      Print("   - Kéo giữa box để DI CHUYỂN");
      Print("   - Kéo góc/cạnh box để THAY ĐỔI KÍCH THƯỚC");
      Print("   - Bấm XÁC NHẬN để cố định");
   }
}

//+------------------------------------------------------------------+
void LockZone(TradingZone &zone)
{
   if(!zone.is_active)
      return;
   
   zone.is_locked = true;
   ObjectSetInteger(0, zone.rect_name, OBJPROP_SELECTABLE, false);
   DrawTradingZone(zone);
   UpdateZoneButtons(zone);
   
   double zone_size = (zone.top - zone.bottom) / _Point;
   string zone_type = zone.is_buy_zone ? "BUY" : "SELL";
   
   Print("🔒 ", zone_type, " Zone LOCKED:");
   Print("   Top: ", zone.top);
   Print("   Bottom: ", zone.bottom);
   Print("   Size: ", zone_size, " points");
   Print("   ✅ Zone cố định! Sẵn sàng chờ tín hiệu...");
   
   Alert("🔒 ", zone_type, " zone đã được xác nhận và khóa!\nEA sẽ tự động vào lệnh khi có tín hiệu.");
}

//+------------------------------------------------------------------+
void UnlockZone(TradingZone &zone)
{
   if(!zone.is_active)
      return;
   
   zone.is_locked = false;
   zone.signal_triggered = false;
   zone.order_placed = false;
   ObjectSetInteger(0, zone.rect_name, OBJPROP_SELECTABLE, true);
   DrawTradingZone(zone);
   UpdateZoneButtons(zone);
   
   // Delete trade level lines
   string prefix = zone.is_buy_zone ? "BUY" : "SELL";
   ObjectDelete(0, prefix + "_SL_LINE");
   ObjectDelete(0, prefix + "_TP1_LINE");
   ObjectDelete(0, prefix + "_TP2_LINE");
   ObjectDelete(0, prefix + "_TP3_LINE");
   ObjectDelete(0, prefix + "_ENTRY_LINE");
   
   string zone_type = zone.is_buy_zone ? "BUY" : "SELL";
   Print("🔓 ", zone_type, " Zone UNLOCKED:");
   Print("   ✏️ Có thể di chuyển và thay đổi kích thước");
   Print("   👉 Kéo giữa box để di chuyển");
   Print("   👉 Kéo góc/cạnh để resize");
   
   Alert("🔓 ", zone_type, " zone đã mở khóa! Bạn có thể chỉnh sửa lại.");
   
   ChartRedraw();
}

//+------------------------------------------------------------------+
void DeleteZone(TradingZone &zone)
{
   if(!zone.is_active)
      return;
   
   // Delete rectangle
   ObjectDelete(0, zone.rect_name);
   ObjectDelete(0, zone.rect_name + "_LABEL");
   
   // Delete buttons
   ObjectDelete(0, zone.btn_lock_name);
   ObjectDelete(0, zone.btn_edit_name);
   ObjectDelete(0, zone.btn_delete_name);
   
   // Delete trade levels
   string prefix = zone.is_buy_zone ? "BUY" : "SELL";
   ObjectDelete(0, prefix + "_SL_LINE");
   ObjectDelete(0, prefix + "_TP1_LINE");
   ObjectDelete(0, prefix + "_TP2_LINE");
   ObjectDelete(0, prefix + "_TP3_LINE");
   ObjectDelete(0, prefix + "_ENTRY_LINE");
   
   zone.is_active = false;
   zone.is_locked = false;
   zone.signal_triggered = false;
   zone.order_placed = false;
   
   string zone_type = zone.is_buy_zone ? "BUY" : "SELL";
   Print("🗑️ ", zone_type, " zone DELETED");
   Alert("🗑️ ", zone_type, " zone đã được xóa!");
   
   ChartRedraw();
}

//+------------------------------------------------------------------+
void DetectFVGs(const datetime &time[], const double &open[], const double &high[], 
                const double &low[], const double &close[])
{
   int start_bar = MathMin(ArraySize(time) - 4, FVG_LookBack);
   
   for(int i = 3; i < start_bar; i++)
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
}

//+------------------------------------------------------------------+
bool CheckSweepAndPattern(const datetime &time[], const double &open[], const double &high[], 
                          const double &low[], const double &close[], bool is_buy_signal)
{
   for(int i = 1; i < 10; i++)
   {
      bool price_in_zone = false;
      
      if(is_buy_signal)
      {
         if(low[i] <= buy_zone.top && low[i] >= buy_zone.bottom)
            price_in_zone = true;
      }
      else
      {
         if(high[i] >= sell_zone.bottom && high[i] <= sell_zone.top)
            price_in_zone = true;
      }
      
      if(!price_in_zone)
         continue;
      
      if(IsSweepCandle(open, high, low, close, i, is_buy_signal))
      {
         if(is_buy_signal)
         {
            if(IsBottomFormation(open, high, low, close, i))
            {
               buy_zone.sweep_bar_index = i;
               buy_zone.sweep_low = low[i];
               buy_zone.sweep_high = high[i];
               
               // Đánh dấu mũi tên XANH
               MarkSweepCandle(time[i], low[i], true);
               
               Print("BUY Signal: Sweep at bar ", i, " (Low=", low[i], ") + Bottom formation detected!");
               return true;
            }
         }
         else
         {
            if(IsTopFormation(open, high, low, close, i))
            {
               sell_zone.sweep_bar_index = i;
               sell_zone.sweep_low = low[i];
               sell_zone.sweep_high = high[i];
               
               // Đánh dấu mũi tên ĐỎ
               MarkSweepCandle(time[i], high[i], false);
               
               Print("SELL Signal: Sweep at bar ", i, " (High=", high[i], ") + Top formation detected!");
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
      if(low[index] >= low[index + 1])
         return false;
      
      bool is_bearish = close[index] < open[index];
      
      if(is_bearish)
      {
         if(close[index] >= close[index + 1])
            return true;
      }
      else
      {
         if(close[index] >= open[index + 1])
            return true;
      }
   }
   else
   {
      if(high[index] <= high[index + 1])
         return false;
      
      bool is_bullish = close[index] > open[index];
      
      if(is_bullish)
      {
         if(close[index] <= close[index + 1])
            return true;
      }
      else
      {
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
   int search_end = MathMax(0, sweep_index - (Sweep_Candles_Count - 1));
   
   for(int i = sweep_index; i >= search_end; i--)
   {
      if(i + 1 >= ArraySize(close))
         continue;
         
      if(close[i] > high[i + 1])
      {
         int candle_from_sweep = sweep_index - i + 1;
         Print("Bottom formation found at bar ", i, " (candle #", candle_from_sweep, " from sweep)");
         Print("  Close[", i, "]=", close[i], " > High[", i+1, "]=", high[i+1]);
         return true;
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
bool IsTopFormation(const double &open[], const double &high[], const double &low[], 
                    const double &close[], int sweep_index)
{
   int search_end = MathMax(0, sweep_index - (Sweep_Candles_Count - 1));
   
   for(int i = sweep_index; i >= search_end; i--)
   {
      if(i + 1 >= ArraySize(close))
         continue;
         
      if(close[i] < low[i + 1])
      {
         int candle_from_sweep = sweep_index - i + 1;
         Print("Top formation found at bar ", i, " (candle #", candle_from_sweep, " from sweep)");
         Print("  Close[", i, "]=", close[i], " < Low[", i+1, "]=", low[i+1]);
         return true;
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
void SendAlert(string message)
{
   if(Enable_Alert)
      Alert(message);
   
   if(Enable_Sound)
      PlaySound(Alert_Sound);
   
   Print("SIGNAL: ", message);
}

//+------------------------------------------------------------------+
void MarkSweepCandle(datetime time, double price, bool is_sweep_low)
{
   string marker_name = sweep_prefix + TimeToString(time, TIME_DATE|TIME_SECONDS);
   
   // Delete if exists
   if(ObjectFind(0, marker_name) >= 0)
      ObjectDelete(0, marker_name);
   
   // Create arrow
   int arrow_code;
   color arrow_color;
   double arrow_price;
   
   // Calculate offset (khoảng cách từ nến để không che nến)
   double point_offset = 30 * _Point;
   
   if(is_sweep_low)
   {
      // Sweep low (BUY signal) - mũi tên XANH ở DƯỚI nến, hướng LÊN
      arrow_price = price - point_offset;
      arrow_code = 233;  // ✓ Check mark
      arrow_color = clrLime;
   }
   else
   {
      // Sweep high (SELL signal) - mũi tên ĐỎ ở TRÊN nến, hướng XUỐNG  
      arrow_price = price + point_offset;
      arrow_code = 234;  // ✗ X mark
      arrow_color = clrRed;
   }
   
   if(ObjectCreate(0, marker_name, OBJ_ARROW, 0, time, arrow_price))
   {
      ObjectSetInteger(0, marker_name, OBJPROP_ARROWCODE, arrow_code);
      ObjectSetInteger(0, marker_name, OBJPROP_COLOR, arrow_color);
      ObjectSetInteger(0, marker_name, OBJPROP_WIDTH, 3);
      ObjectSetInteger(0, marker_name, OBJPROP_BACK, false);
      ObjectSetInteger(0, marker_name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, marker_name, OBJPROP_HIDDEN, true);
      
      // Add tooltip
      string tooltip = is_sweep_low ? "✓ SWEEP LOW + FORMATION (BUY)" : "✗ SWEEP HIGH + FORMATION (SELL)";
      ObjectSetString(0, marker_name, OBJPROP_TEXT, tooltip);
      
      Print("📍 Marked sweep: ", is_sweep_low ? "LOW" : "HIGH", " at ", TimeToString(time), " price=", price);
   }
}

//+------------------------------------------------------------------+
void UpdateZoneMitigation(TradingZone &zone, const double &high[], const double &low[], const double &close[])
{
   if(!zone.is_active || !zone.is_locked)
      return;
   
   for(int i = 0; i < 5; i++)
   {
      bool is_modified = false;
      
      if(zone.is_buy_zone)
      {
         if(Zone_Delete_On_Break && close[i] < zone.bottom)
         {
            zone.is_active = false;
            ObjectDelete(0, zone.rect_name);
            ObjectDelete(0, zone.rect_name + "_LABEL");
            Print("Buy zone deleted - price broke below");
            return;
         }
         
         if(Zone_Mitigate_On_Touch && low[i] < zone.top && low[i] > zone.bottom)
         {
            zone.top = low[i];
            is_modified = true;
            
            if(zone.top - zone.bottom < 10 * _Point)
            {
               zone.is_active = false;
               ObjectDelete(0, zone.rect_name);
               ObjectDelete(0, zone.rect_name + "_LABEL");
               Print("Buy zone deleted - fully mitigated");
               return;
            }
         }
      }
      else
      {
         if(Zone_Delete_On_Break && close[i] > zone.top)
         {
            zone.is_active = false;
            ObjectDelete(0, zone.rect_name);
            ObjectDelete(0, zone.rect_name + "_LABEL");
            Print("Sell zone deleted - price broke above");
            return;
         }
         
         if(Zone_Mitigate_On_Touch && high[i] > zone.bottom && high[i] < zone.top)
         {
            zone.bottom = high[i];
            is_modified = true;
            
            if(zone.top - zone.bottom < 10 * _Point)
            {
               zone.is_active = false;
               ObjectDelete(0, zone.rect_name);
               ObjectDelete(0, zone.rect_name + "_LABEL");
               Print("Sell zone deleted - fully mitigated");
               return;
            }
         }
      }
      
      if(is_modified)
      {
         DrawTradingZone(zone);
         Print("Zone mitigated - new range: ", zone.top, " - ", zone.bottom);
      }
   }
}

//+------------------------------------------------------------------+
void CalculateStopLoss(TradingZone &zone, const double &high[], const double &low[])
{
   double sl_price = 0;
   
   if(zone.is_buy_zone)
   {
      if(SL_Use_Sweep_Low && zone.sweep_bar_index > 0)
      {
         sl_price = zone.sweep_low - (SL_Buffer_Points * _Point);
      }
      else if(SL_Use_Zone_Edge)
      {
         sl_price = zone.bottom - (SL_Buffer_Points * _Point);
      }
      else
      {
         sl_price = zone.bottom - (SL_Buffer_Points * _Point);
      }
   }
   else
   {
      if(SL_Use_Sweep_Low && zone.sweep_bar_index > 0)
      {
         sl_price = zone.sweep_high + (SL_Buffer_Points * _Point);
      }
      else if(SL_Use_Zone_Edge)
      {
         sl_price = zone.top + (SL_Buffer_Points * _Point);
      }
      else
      {
         sl_price = zone.top + (SL_Buffer_Points * _Point);
      }
   }
   
   zone.stop_loss_price = sl_price;
   Print("Stop Loss calculated: ", sl_price);
}

//+------------------------------------------------------------------+
double CalculateLotSize(double stop_loss_points)
{
   if(!Auto_Calculate_Lot)
      return NormalizeLot(Manual_Lot_Size);
   
   double risk_amount = 0;
   
   if(Risk_Amount_Per_Trade > 0)
   {
      risk_amount = Risk_Amount_Per_Trade;
   }
   else
   {
      risk_amount = account.Balance() * Risk_Percent_Per_Trade / 100.0;
   }
   
   double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   
   double point_value = tick_value;
   if(tick_size > 0)
      point_value = tick_value * (_Point / tick_size);
   
   double lot_size = 0;
   if(stop_loss_points > 0 && point_value > 0)
   {
      lot_size = risk_amount / (stop_loss_points * point_value);
   }
   
   lot_size = NormalizeLot(lot_size);
   
   if(lot_size > Max_Lot_Size)
      lot_size = Max_Lot_Size;
   
   Print("Calculated Lot Size: ", lot_size, " (Risk: $", risk_amount, ", SL: ", stop_loss_points, " pts)");
   
   return lot_size;
}

//+------------------------------------------------------------------+
double NormalizeLot(double lot)
{
   double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double max_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lot_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   lot = MathFloor(lot / lot_step) * lot_step;
   
   if(lot < min_lot) lot = min_lot;
   if(lot > max_lot) lot = max_lot;
   
   return lot;
}

//+------------------------------------------------------------------+
void DrawTradeLevels(TradingZone &zone)
{
   string prefix = zone.is_buy_zone ? "BUY_" : "SELL_";
   datetime time_start = iTime(_Symbol, PERIOD_CURRENT, 10);
   datetime time_end = TimeCurrent() + PeriodSeconds() * 100;
   
   // Draw Entry Line
   string entry_name = prefix + "ENTRY_LINE";
   if(ObjectFind(0, entry_name) >= 0) ObjectDelete(0, entry_name);
   if(ObjectCreate(0, entry_name, OBJ_TREND, 0, time_start, zone.entry_price, time_end, zone.entry_price))
   {
      ObjectSetInteger(0, entry_name, OBJPROP_COLOR, clrYellow);
      ObjectSetInteger(0, entry_name, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, entry_name, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, entry_name, OBJPROP_RAY_RIGHT, true);
      ObjectSetString(0, entry_name, OBJPROP_TEXT, "Entry: " + DoubleToString(zone.entry_price, _Digits));
   }
   
   // Draw Stop Loss Line
   string sl_name = prefix + "SL_LINE";
   if(ObjectFind(0, sl_name) >= 0) ObjectDelete(0, sl_name);
   if(ObjectCreate(0, sl_name, OBJ_TREND, 0, time_start, zone.stop_loss_price, time_end, zone.stop_loss_price))
   {
      ObjectSetInteger(0, sl_name, OBJPROP_COLOR, SL_Line_Color);
      ObjectSetInteger(0, sl_name, OBJPROP_STYLE, STYLE_DOT);
      ObjectSetInteger(0, sl_name, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, sl_name, OBJPROP_RAY_RIGHT, true);
      ObjectSetString(0, sl_name, OBJPROP_TEXT, "SL: " + DoubleToString(zone.stop_loss_price, _Digits));
   }
   
   // Draw TP Lines
   if(Use_RR_Exit)
   {
      // TP1
      string tp1_name = prefix + "TP1_LINE";
      if(ObjectFind(0, tp1_name) >= 0) ObjectDelete(0, tp1_name);
      if(ObjectCreate(0, tp1_name, OBJ_TREND, 0, time_start, zone.tp1_price, time_end, zone.tp1_price))
      {
         ObjectSetInteger(0, tp1_name, OBJPROP_COLOR, TP_Line_Color);
         ObjectSetInteger(0, tp1_name, OBJPROP_STYLE, STYLE_DASH);
         ObjectSetInteger(0, tp1_name, OBJPROP_WIDTH, 1);
         ObjectSetInteger(0, tp1_name, OBJPROP_RAY_RIGHT, true);
         ObjectSetString(0, tp1_name, OBJPROP_TEXT, StringFormat("TP1 (%.1fR): %.5f [%g%%]", RR_Level_1, zone.tp1_price, RR_Close_Percent_1));
      }
      
      // TP2
      string tp2_name = prefix + "TP2_LINE";
      if(ObjectFind(0, tp2_name) >= 0) ObjectDelete(0, tp2_name);
      if(ObjectCreate(0, tp2_name, OBJ_TREND, 0, time_start, zone.tp2_price, time_end, zone.tp2_price))
      {
         ObjectSetInteger(0, tp2_name, OBJPROP_COLOR, TP_Line_Color);
         ObjectSetInteger(0, tp2_name, OBJPROP_STYLE, STYLE_DASH);
         ObjectSetInteger(0, tp2_name, OBJPROP_WIDTH, 1);
         ObjectSetInteger(0, tp2_name, OBJPROP_RAY_RIGHT, true);
         ObjectSetString(0, tp2_name, OBJPROP_TEXT, StringFormat("TP2 (%.1fR): %.5f [%g%%]", RR_Level_2, zone.tp2_price, RR_Close_Percent_2));
      }
      
      // TP3
      string tp3_name = prefix + "TP3_LINE";
      if(ObjectFind(0, tp3_name) >= 0) ObjectDelete(0, tp3_name);
      if(ObjectCreate(0, tp3_name, OBJ_TREND, 0, time_start, zone.tp3_price, time_end, zone.tp3_price))
      {
         ObjectSetInteger(0, tp3_name, OBJPROP_COLOR, TP_Line_Color);
         ObjectSetInteger(0, tp3_name, OBJPROP_STYLE, STYLE_DASH);
         ObjectSetInteger(0, tp3_name, OBJPROP_WIDTH, 1);
         ObjectSetInteger(0, tp3_name, OBJPROP_RAY_RIGHT, true);
         ObjectSetString(0, tp3_name, OBJPROP_TEXT, StringFormat("TP3 (%.1fR): %.5f [%g%%]", RR_Level_3, zone.tp3_price, RR_Close_Percent_3));
      }
   }
   
   ChartRedraw();
}

//+------------------------------------------------------------------+
void ExecuteTrade(TradingZone &zone)
{
   if(!EA_Enabled)
      return;
   
   if(One_Trade_At_Time && HasOpenPosition(zone.is_buy_zone))
   {
      Print("⏸️ Already have open ", zone.is_buy_zone ? "BUY" : "SELL", " position");
      return;
   }
   
   zone.entry_price = NormalizeDouble(zone.entry_price, _Digits);
   zone.stop_loss_price = NormalizeDouble(zone.stop_loss_price, _Digits);
   zone.tp1_price = NormalizeDouble(zone.tp1_price, _Digits);
   
   zone.initial_lot = zone.lot_size;
   zone.remaining_lot = zone.lot_size;
   
   bool result = false;
   if(zone.is_buy_zone)
   {
      result = trade.Buy(zone.lot_size, _Symbol, zone.entry_price, zone.stop_loss_price, 0, Trade_Comment);
   }
   else
   {
      result = trade.Sell(zone.lot_size, _Symbol, zone.entry_price, zone.stop_loss_price, 0, Trade_Comment);
   }
   
   if(result)
   {
      zone.ticket = trade.ResultOrder();
      zone.order_placed = true;
      
      double sl_points = MathAbs(zone.entry_price - zone.stop_loss_price) / _Point;
      
      string msg = StringFormat("✅ %s ORDER PLACED\nTicket: %I64u\nEntry: %.5f\nSL: %.5f (%.1f pts)\nLot: %.2f\nTP1: %.5f (%.1fR)\nTP2: %.5f (%.1fR)\nTP3: %.5f (%.1fR)",
                               zone.is_buy_zone ? "BUY" : "SELL",
                               zone.ticket,
                               zone.entry_price, 
                               zone.stop_loss_price, 
                               sl_points,
                               zone.lot_size, 
                               zone.tp1_price, RR_Level_1,
                               zone.tp2_price, RR_Level_2,
                               zone.tp3_price, RR_Level_3);
      
      SendAlert(msg);
      Print(msg);
   }
   else
   {
      Print("❌ Order failed: ", trade.ResultRetcodeDescription());
      zone.order_placed = false;
   }
}

//+------------------------------------------------------------------+
void ManageOpenPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(position.SelectByIndex(i))
      {
         if(position.Symbol() != _Symbol || position.Magic() != Magic_Number)
            continue;
         
         ulong ticket = position.Ticket();
         bool is_buy = (position.Type() == POSITION_TYPE_BUY);
         double current_price = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         double open_price = position.PriceOpen();
         double sl = position.StopLoss();
         double current_lot = position.Volume();
         
         // Get corresponding zone
         TradingZone zone;
         if(is_buy)
            zone = buy_zone;
         else
            zone = sell_zone;
         
         if(zone.ticket != ticket)
            continue;
         
         // Check EMA exit
         if(Use_EMA_Exit && CheckEMAExit(is_buy))
         {
            if(trade.PositionClose(ticket))
            {
               SendAlert("🔔 EMA Exit: Closed " + (is_buy ? "BUY" : "SELL") + " position #" + IntegerToString(ticket));
               if(is_buy)
               {
                  buy_zone.order_placed = false;
                  buy_zone.signal_triggered = false;
               }
               else
               {
                  sell_zone.order_placed = false;
                  sell_zone.signal_triggered = false;
               }
               continue;
            }
         }
         
         // Check RR-based partial closures
         if(Use_RR_Exit)
         {
            double profit_distance = is_buy ? (current_price - open_price) : (open_price - current_price);
            double risk_distance = MathAbs(open_price - sl);
            double current_rr = profit_distance / risk_distance;
            
            // TP1
            if(current_rr >= RR_Level_1 && zone.remaining_lot > zone.initial_lot * (1 - RR_Close_Percent_1/100.0 + 0.001))
            {
               double lot_to_close = NormalizeLot(zone.initial_lot * RR_Close_Percent_1 / 100.0);
               ClosePartialPosition(ticket, lot_to_close, StringFormat("TP1 (%.1fR)", RR_Level_1));
               if(is_buy)
                  buy_zone.remaining_lot -= lot_to_close;
               else
                  sell_zone.remaining_lot -= lot_to_close;
            }
            // TP2
            else if(current_rr >= RR_Level_2 && zone.remaining_lot > zone.initial_lot * (1 - (RR_Close_Percent_1 + RR_Close_Percent_2)/100.0 + 0.001))
            {
               double lot_to_close = NormalizeLot(zone.initial_lot * RR_Close_Percent_2 / 100.0);
               ClosePartialPosition(ticket, lot_to_close, StringFormat("TP2 (%.1fR)", RR_Level_2));
               if(is_buy)
                  buy_zone.remaining_lot -= lot_to_close;
               else
                  sell_zone.remaining_lot -= lot_to_close;
            }
            // TP3
            else if(current_rr >= RR_Level_3 && zone.remaining_lot > 0.001)
            {
               if(trade.PositionClose(ticket))
               {
                  SendAlert(StringFormat("✅ TP3 (%.1fR): Closed remaining position", RR_Level_3));
                  if(is_buy)
                  {
                     buy_zone.order_placed = false;
                     buy_zone.signal_triggered = false;
                     buy_zone.remaining_lot = 0;
                  }
                  else
                  {
                     sell_zone.order_placed = false;
                     sell_zone.signal_triggered = false;
                     sell_zone.remaining_lot = 0;
                  }
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
void ClosePartialPosition(ulong ticket, double lot_to_close, string reason)
{
   if(lot_to_close < SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN))
      return;
   
   if(trade.PositionClosePartial(ticket, lot_to_close))
   {
      Print("✅ Partial close: ", lot_to_close, " lots at ", reason);
      SendAlert("💰 " + reason + ": Closed " + DoubleToString(lot_to_close, 2) + " lots");
   }
}

//+------------------------------------------------------------------+
bool HasOpenPosition(bool is_buy)
{
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(position.SelectByIndex(i))
      {
         if(position.Symbol() == _Symbol && position.Magic() == Magic_Number)
         {
            if(is_buy && position.Type() == POSITION_TYPE_BUY)
               return true;
            if(!is_buy && position.Type() == POSITION_TYPE_SELL)
               return true;
         }
      }
   }
   return false;
}

//+------------------------------------------------------------------+
bool CheckEMAExit(bool is_buy_position)
{
   if(!Use_EMA_Exit || ema_handle == INVALID_HANDLE)
      return false;
   
   if(CopyBuffer(ema_handle, 0, 0, 3, ema_buffer) <= 0)
      return false;
   
   double current_close = iClose(_Symbol, PERIOD_CURRENT, 0);
   double ema_value = ema_buffer[0];
   
   if(is_buy_position)
   {
      if(current_close < ema_value)
      {
         Print("EMA Exit signal for BUY: Close=", current_close, " < EMA=", ema_value);
         return true;
      }
   }
   else
   {
      if(current_close > ema_value)
      {
         Print("EMA Exit signal for SELL: Close=", current_close, " > EMA=", ema_value);
         return true;
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
void UpdateTrailingStop(TradingZone &zone)
{
   if(!zone.order_placed)
      return;
   
   if(CheckEMAExit(zone.is_buy_zone))
   {
      Print("EMA exit triggered - close position");
      SendAlert("EMA Exit: Close " + (zone.is_buy_zone ? "BUY" : "SELL") + " position");
   }
}

//+------------------------------------------------------------------+
void DisplayInfo()
{
   string info = "\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
   info += "  📊 FVG TRADING EA v2.0\n";
   info += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
   info += "Status: " + (EA_Enabled ? "🟢 ACTIVE" : "🔴 PAUSED") + "\n";
   info += "Auto Trade: " + (Auto_Trade_On_Signal ? "✅ ON" : "⏸️ OFF") + "\n";
   info += "Symbol: " + _Symbol + "\n";
   info += "Balance: $" + DoubleToString(account.Balance(), 2) + "\n";
   info += "Equity: $" + DoubleToString(account.Equity(), 2) + "\n";
   info += "FVGs Detected: " + IntegerToString(FVG_Count) + "\n";
   
   if(buy_zone.is_active)
      info += "🔵 BUY Zone: " + (buy_zone.is_locked ? "LOCKED" : "EDITING") + "\n";
   if(sell_zone.is_active)
      info += "🔴 SELL Zone: " + (sell_zone.is_locked ? "LOCKED" : "EDITING") + "\n";
   
   info += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
   
   int buy_count = 0, sell_count = 0;
   double buy_profit = 0, sell_profit = 0;
   
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(position.SelectByIndex(i))
      {
         if(position.Symbol() == _Symbol && position.Magic() == Magic_Number)
         {
            if(position.Type() == POSITION_TYPE_BUY)
            {
               buy_count++;
               buy_profit += position.Profit();
            }
            else
            {
               sell_count++;
               sell_profit += position.Profit();
            }
         }
      }
   }
   
   if(buy_count > 0)
      info += "📈 BUY: " + IntegerToString(buy_count) + " | P/L: $" + DoubleToString(buy_profit, 2) + "\n";
   if(sell_count > 0)
      info += "📉 SELL: " + IntegerToString(sell_count) + " | P/L: $" + DoubleToString(sell_profit, 2) + "\n";
   
   if(buy_count == 0 && sell_count == 0)
      info += "No open positions\n";
   
   info += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
   
   Comment(info);
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
      
      // Bước 1: Tìm bar index của FVG trong mảng hiện tại
      int fvg_bar_index = -1;
      for(int bar = 0; bar < ArraySize(time); bar++)
      {
         if(time[bar] == FVG_Array[i].time_start)
         {
            fvg_bar_index = bar;
            break;
         }
      }
      
      // Nếu không tìm thấy FVG bar (FVG quá cũ, nằm ngoài dữ liệu hiện tại), bỏ qua
      if(fvg_bar_index < 0)
         continue;
      
      // Bước 2: Quét TẤT CẢ các nến SAU khi FVG tạo (từ fvg_bar_index-1 đến nến hiện tại bar[0])
      // Vì mảng là reversed (bar[0] = newest), nên quét từ fvg_bar_index-1 về 0
      for(int bar = fvg_bar_index - 1; bar >= 0; bar--)
      {
         bool is_modified = false;
         bool should_delete = false;
         
         if(FVG_Array[i].is_bullish)
         {
            // BULLISH FVG - giá đi xuống
            double bar_low = low[bar];
            double bar_close = close[bar];
            
            // Delete On Break: giá CLOSE dưới bottom của FVG
            if(Delete_On_Break && bar_close < FVG_Array[i].bottom)
            {
               should_delete = true;
               Print("⚠️ FVG Bullish DELETED (Break): Bar time=", TimeToString(time[bar]), 
                     " Close=", bar_close, " < Bottom=", FVG_Array[i].bottom);
            }
            // Fill On Touch: giá LOW chạm vào FVG (giữa top và bottom)
            else if(Fill_On_Touch && bar_low < FVG_Array[i].top && bar_low > FVG_Array[i].bottom)
            {
               double old_top = FVG_Array[i].top;
               FVG_Array[i].top = bar_low;
               is_modified = true;
               
               Print("📉 FVG Bullish MITIGATED: Top ", old_top, " -> ", bar_low, 
                     " (Bar: ", TimeToString(time[bar]), ")");
               
               // Nếu FVG quá nhỏ sau khi mitigation, xóa luôn
               if(FVG_Array[i].top - FVG_Array[i].bottom < Min_FVG_Points * _Point)
               {
                  should_delete = true;
                  Print("⚠️ FVG Bullish DELETED (Too small after mitigation)");
               }
            }
         }
         else
         {
            // BEARISH FVG - giá đi lên
            double bar_high = high[bar];
            double bar_close = close[bar];
            
            // Delete On Break: giá CLOSE trên top của FVG
            if(Delete_On_Break && bar_close > FVG_Array[i].top)
            {
               should_delete = true;
               Print("⚠️ FVG Bearish DELETED (Break): Bar time=", TimeToString(time[bar]), 
                     " Close=", bar_close, " > Top=", FVG_Array[i].top);
            }
            // Fill On Touch: giá HIGH chạm vào FVG (giữa bottom và top)
            else if(Fill_On_Touch && bar_high > FVG_Array[i].bottom && bar_high < FVG_Array[i].top)
            {
               double old_bottom = FVG_Array[i].bottom;
               FVG_Array[i].bottom = bar_high;
               is_modified = true;
               
               Print("📈 FVG Bearish MITIGATED: Bottom ", old_bottom, " -> ", bar_high, 
                     " (Bar: ", TimeToString(time[bar]), ")");
               
               // Nếu FVG quá nhỏ sau khi mitigation, xóa luôn
               if(FVG_Array[i].top - FVG_Array[i].bottom < Min_FVG_Points * _Point)
               {
                  should_delete = true;
                  Print("⚠️ FVG Bearish DELETED (Too small after mitigation)");
               }
            }
         }
         
         // Xử lý xóa FVG
         if(should_delete)
         {
            FVG_Array[i].is_active = false;
            ObjectDelete(0, FVG_Array[i].rect_name);
            break;  // Dừng kiểm tra nến cho FVG này
         }
         
         // Vẽ lại FVG nếu có thay đổi
         if(is_modified)
         {
            DrawFVGRectangle(i);
         }
      }
      
      // Cập nhật thời gian kết thúc FVG (kéo dài đến tương lai)
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
   
   total = ObjectsTotal(0, 0, OBJ_TREND);
   for(int i = total - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i, 0, OBJ_TREND);
      if(StringFind(name, "BUY_") >= 0 || StringFind(name, "SELL_") >= 0)
         ObjectDelete(0, name);
   }
   
   // Delete sweep markers
   total = ObjectsTotal(0, 0, OBJ_ARROW);
   for(int i = total - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i, 0, OBJ_ARROW);
      if(StringFind(name, sweep_prefix) >= 0)
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
