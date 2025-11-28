//+------------------------------------------------------------------+
//|                                    FVG_Manual_EA_Enhanced.mq5    |
//|                    Fair Value Gap EA with Independent Zones      |
//|                    Each zone can be edited/deleted separately    |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025"
#property version   "3.00"
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

//--- Trading Zone & Sweep Parameters
input group    "=== Trading Zone Settings ==="
input int      Sweep_Candles_Count = 5;
input bool     Enable_Alert = true;
input bool     Enable_Sound = true;
input string   Alert_Sound = "alert.wav";

input group    "=== Stop Loss Settings ==="
input bool     SL_Use_Sweep_Low = true;
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
input bool     Auto_Trade_On_Signal = true;
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
input int      Zone_Transparency = 70;
input int      Zone_Border_Width = 2;

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

struct TradingZone
{
   double   top;
   double   bottom;
   bool     is_active;
   bool     is_locked;
   bool     is_buy_zone;
   string   rect_name;
   string   btn_lock_name;
   string   btn_edit_name;
   string   btn_delete_name;
   bool     signal_triggered;
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
string zone_prefix = "ZONE_";
string button_prefix = "BTN_";

// Trading Zone variables
TradingZone buy_zone;
TradingZone sell_zone;

// EMA Handle
int ema_handle = INVALID_HANDLE;
double ema_buffer[];

// Button names for CREATE
string btn_create_buy = button_prefix + "CREATE_BUY";
string btn_create_sell = button_prefix + "CREATE_SELL";

// Last bar time for new bar detection
datetime last_bar_time = 0;

//--- Forward declarations
void DeleteAllObjects();
void CreateFVG(datetime start_time, double top, double bottom, bool is_bullish, int bar_index);
void DrawFVGRectangle(int index);
void UpdateFVGStatus(const datetime &time[], const double &high[], const double &low[], const double &close[]);
void CreateMainButtons();
void CreateTradingZone(bool is_buy);
void DrawTradingZone(TradingZone &zone);
void UpdateZoneButtons(TradingZone &zone);
void LockZone(TradingZone &zone);
void UnlockZone(TradingZone &zone);
void DeleteZone(TradingZone &zone);
bool CheckSweepAndPattern(const datetime &time[], const double &open[], const double &high[], const double &low[], const double &close[], TradingZone &zone);
bool IsSweepCandle(const double &open[], const double &high[], const double &low[], const double &close[], int index, bool check_for_buy);
bool IsBottomFormation(const double &open[], const double &high[], const double &low[], const double &close[], int sweep_index);
bool IsTopFormation(const double &open[], const double &high[], const double &low[], const double &close[], int sweep_index);
void SendAlert(string message);
void CalculateStopLoss(TradingZone &zone, const double &high[], const double &low[]);
double CalculateLotSize(double stop_loss_points);
void DrawTradeLevels(TradingZone &zone);
void ExecuteTrade(TradingZone &zone);
bool CheckEMAExit(bool is_buy_position);
void ManageOpenPositions();
void ClosePartialPosition(ulong ticket, double lot_to_close, string reason);
bool HasOpenPosition(bool is_buy);
double NormalizeLot(double lot);
void DisplayInfo();
void DetectFVGs(const datetime &time[], const double &open[], const double &high[], const double &low[], const double &close[]);
void CleanupHistoricalFVGs();
int GetActiveFVGCount();

//+------------------------------------------------------------------+
int OnInit()
{
   Print("========================================");
   Print("  FVG MANUAL EA v3.0 - ENHANCED");
   Print("  Independent Zone Control");
   Print("========================================");
   
   // Setup trade object
   trade.SetExpertMagicNumber(Magic_Number);
   trade.SetDeviationInPoints(10);
   trade.SetTypeFilling(ORDER_FILLING_FOK);
   trade.SetAsyncMode(false);
   
   DeleteAllObjects();
   ArrayResize(FVG_Array, 0);
   FVG_Count = 0;
   
   // Initialize BUY trading zone
   buy_zone.is_active = false;
   buy_zone.is_locked = false;
   buy_zone.is_buy_zone = true;
   buy_zone.rect_name = zone_prefix + "BUY";
   buy_zone.btn_lock_name = button_prefix + "BUY_LOCK";
   buy_zone.btn_edit_name = button_prefix + "BUY_EDIT";
   buy_zone.btn_delete_name = button_prefix + "BUY_DELETE";
   buy_zone.signal_triggered = false;
   buy_zone.order_placed = false;
   buy_zone.ticket = 0;
   
   // Initialize SELL trading zone
   sell_zone.is_active = false;
   sell_zone.is_locked = false;
   sell_zone.is_buy_zone = false;
   sell_zone.rect_name = zone_prefix + "SELL";
   sell_zone.btn_lock_name = button_prefix + "SELL_LOCK";
   sell_zone.btn_edit_name = button_prefix + "SELL_EDIT";
   sell_zone.btn_delete_name = button_prefix + "SELL_DELETE";
   sell_zone.signal_triggered = false;
   sell_zone.order_placed = false;
   sell_zone.ticket = 0;
   
   // Initialize EMA
   if(Use_EMA_Exit)
   {
      ema_handle = iMA(_Symbol, EMA_Timeframe, EMA_Period, 0, MODE_EMA, PRICE_CLOSE);
      if(ema_handle == INVALID_HANDLE)
      {
         Print("❌ Failed to create EMA indicator handle");
         return(INIT_FAILED);
      }
      ArraySetAsSeries(ema_buffer, true);
   }
   
   // Validate TP percentages
   double total_percent = RR_Close_Percent_1 + RR_Close_Percent_2 + RR_Close_Percent_3;
   if(MathAbs(total_percent - 100.0) > 0.01)
   {
      Print("⚠️ Warning: TP percentages don't sum to 100% (Total: ", total_percent, "%)");
   }
   
   CreateMainButtons();
   
   // Detect initial FVGs on startup
   Print("🔍 Detecting initial FVGs...");
   datetime init_time[];
   double init_open[], init_high[], init_low[], init_close[];
   
   ArraySetAsSeries(init_time, true);
   ArraySetAsSeries(init_open, true);
   ArraySetAsSeries(init_high, true);
   ArraySetAsSeries(init_low, true);
   ArraySetAsSeries(init_close, true);
   
   int init_bars = MathMin(FVG_LookBack + 10, Bars(_Symbol, PERIOD_CURRENT));
   if(CopyTime(_Symbol, PERIOD_CURRENT, 0, init_bars, init_time) > 0)
   {
      CopyOpen(_Symbol, PERIOD_CURRENT, 0, init_bars, init_open);
      CopyHigh(_Symbol, PERIOD_CURRENT, 0, init_bars, init_high);
      CopyLow(_Symbol, PERIOD_CURRENT, 0, init_bars, init_low);
      CopyClose(_Symbol, PERIOD_CURRENT, 0, init_bars, init_close);
      
      DetectFVGs(init_time, init_open, init_high, init_low, init_close);
      CleanupHistoricalFVGs();
      
      Print("✅ Initial FVGs detected: ", GetActiveFVGCount());
   }
   
   ChartRedraw();
   
   Print("✅ FVG Manual EA initialized successfully");
   Print("   Manual Zone Creation: ENABLED");
   Print("   Auto Trade: ", Auto_Trade_On_Signal ? "ENABLED" : "DISABLED");
   Print("========================================");
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(ema_handle != INVALID_HANDLE)
      IndicatorRelease(ema_handle);
   
   DeleteAllObjects();
   Comment("");
   
   Print("FVG Manual EA stopped. Reason: ", reason);
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
      
      // Update FVG status (check for mitigation)
      UpdateFVGStatus(time, high, low, close);
      
      // Check for trading signals on LOCKED zones
      if(buy_zone.is_active && buy_zone.is_locked && !buy_zone.signal_triggered)
      {
         if(CheckSweepAndPattern(time, open, high, low, close, buy_zone))
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
            
            string msg = StringFormat("🔵 BUY SIGNAL\nEntry: %.5f\nSL: %.5f (%.1f pts)\nLot: %.2f",
                                      buy_zone.entry_price, buy_zone.stop_loss_price, sl_points, buy_zone.lot_size);
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
         if(CheckSweepAndPattern(time, open, high, low, close, sell_zone))
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
            
            string msg = StringFormat("🔴 SELL SIGNAL\nEntry: %.5f\nSL: %.5f (%.1f pts)\nLot: %.2f",
                                      sell_zone.entry_price, sell_zone.stop_loss_price, sl_points, sell_zone.lot_size);
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
   // CREATE BUTTONS
   if(id == CHARTEVENT_OBJECT_CLICK)
   {
      if(sparam == btn_create_buy)
      {
         CreateTradingZone(true);
         ObjectSetInteger(0, btn_create_buy, OBJPROP_STATE, false);
      }
      else if(sparam == btn_create_sell)
      {
         CreateTradingZone(false);
         ObjectSetInteger(0, btn_create_sell, OBJPROP_STATE, false);
      }
      // BUY ZONE BUTTONS
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
      // SELL ZONE BUTTONS
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
   
   // DRAG & RESIZE ZONES
   if(id == CHARTEVENT_OBJECT_DRAG || id == CHARTEVENT_OBJECT_ENDEDIT)
   {
      if(sparam == buy_zone.rect_name && buy_zone.is_active && !buy_zone.is_locked)
      {
         buy_zone.top = ObjectGetDouble(0, buy_zone.rect_name, OBJPROP_PRICE, 0);
         buy_zone.bottom = ObjectGetDouble(0, buy_zone.rect_name, OBJPROP_PRICE, 1);
         
         if(buy_zone.top < buy_zone.bottom)
         {
            double temp = buy_zone.top;
            buy_zone.top = buy_zone.bottom;
            buy_zone.bottom = temp;
         }
         
         Print("📏 Buy zone resized: Top=", buy_zone.top, " Bottom=", buy_zone.bottom, " Height=", (buy_zone.top - buy_zone.bottom)/_Point, " pts");
         DrawTradingZone(buy_zone);
      }
      else if(sparam == sell_zone.rect_name && sell_zone.is_active && !sell_zone.is_locked)
      {
         sell_zone.top = ObjectGetDouble(0, sell_zone.rect_name, OBJPROP_PRICE, 0);
         sell_zone.bottom = ObjectGetDouble(0, sell_zone.rect_name, OBJPROP_PRICE, 1);
         
         if(sell_zone.top < sell_zone.bottom)
         {
            double temp = sell_zone.top;
            sell_zone.top = sell_zone.bottom;
            sell_zone.bottom = temp;
         }
         
         Print("📏 Sell zone resized: Top=", sell_zone.top, " Bottom=", sell_zone.bottom, " Height=", (sell_zone.top - sell_zone.bottom)/_Point, " pts");
         DrawTradingZone(sell_zone);
      }
   }
}

//+------------------------------------------------------------------+
void CreateMainButtons()
{
   int x_start = 20;
   int y_start = 30;
   int btn_width = 120;
   int btn_height = 35;
   int btn_spacing = 10;
   
   // CREATE BUY button
   if(ObjectCreate(0, btn_create_buy, OBJ_BUTTON, 0, 0, 0))
   {
      ObjectSetInteger(0, btn_create_buy, OBJPROP_XDISTANCE, x_start);
      ObjectSetInteger(0, btn_create_buy, OBJPROP_YDISTANCE, y_start);
      ObjectSetInteger(0, btn_create_buy, OBJPROP_XSIZE, btn_width);
      ObjectSetInteger(0, btn_create_buy, OBJPROP_YSIZE, btn_height);
      ObjectSetString(0, btn_create_buy, OBJPROP_TEXT, "➕ TẠO ZONE MUA");
      ObjectSetInteger(0, btn_create_buy, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, btn_create_buy, OBJPROP_BGCOLOR, Button_Buy_Color);
      ObjectSetInteger(0, btn_create_buy, OBJPROP_BORDER_COLOR, clrBlack);
      ObjectSetInteger(0, btn_create_buy, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, btn_create_buy, OBJPROP_FONTSIZE, 10);
      ObjectSetString(0, btn_create_buy, OBJPROP_FONT, "Arial Bold");
   }
   
   // CREATE SELL button
   if(ObjectCreate(0, btn_create_sell, OBJ_BUTTON, 0, 0, 0))
   {
      ObjectSetInteger(0, btn_create_sell, OBJPROP_XDISTANCE, x_start + btn_width + btn_spacing);
      ObjectSetInteger(0, btn_create_sell, OBJPROP_YDISTANCE, y_start);
      ObjectSetInteger(0, btn_create_sell, OBJPROP_XSIZE, btn_width);
      ObjectSetInteger(0, btn_create_sell, OBJPROP_YSIZE, btn_height);
      ObjectSetString(0, btn_create_sell, OBJPROP_TEXT, "➕ TẠO ZONE BÁN");
      ObjectSetInteger(0, btn_create_sell, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, btn_create_sell, OBJPROP_BGCOLOR, Button_Sell_Color);
      ObjectSetInteger(0, btn_create_sell, OBJPROP_BORDER_COLOR, clrBlack);
      ObjectSetInteger(0, btn_create_sell, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, btn_create_sell, OBJPROP_FONTSIZE, 10);
      ObjectSetString(0, btn_create_sell, OBJPROP_FONT, "Arial Bold");
   }
}

//+------------------------------------------------------------------+
void CreateTradingZone(bool is_buy)
{
   double current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   if(is_buy)
   {
      if(buy_zone.is_active)
      {
         Alert("⚠️ Buy zone đã tồn tại! Xóa zone cũ trước khi tạo mới.");
         return;
      }
      
      // Tạo zone lớn hơn để dễ điều chỉnh
      buy_zone.top = current_price - 100 * _Point;
      buy_zone.bottom = current_price - 500 * _Point;
      buy_zone.is_active = true;
      buy_zone.is_locked = false;
      buy_zone.signal_triggered = false;
      buy_zone.order_placed = false;
      
      DrawTradingZone(buy_zone);
      UpdateZoneButtons(buy_zone);
      
      Alert("✅ Buy zone đã tạo! Kéo góc để thay đổi kích thước, sau đó bấm 'XÁC NHẬN'");
      Print("📦 Buy zone created at: Top=", buy_zone.top, " Bottom=", buy_zone.bottom);
   }
   else
   {
      if(sell_zone.is_active)
      {
         Alert("⚠️ Sell zone đã tồn tại! Xóa zone cũ trước khi tạo mới.");
         return;
      }
      
      sell_zone.top = current_price + 500 * _Point;
      sell_zone.bottom = current_price + 100 * _Point;
      sell_zone.is_active = true;
      sell_zone.is_locked = false;
      sell_zone.signal_triggered = false;
      sell_zone.order_placed = false;
      
      DrawTradingZone(sell_zone);
      UpdateZoneButtons(sell_zone);
      
      Alert("✅ Sell zone đã tạo! Kéo góc để thay đổi kích thước, sau đó bấm 'XÁC NHẬN'");
      Print("📦 Sell zone created at: Top=", sell_zone.top, " Bottom=", sell_zone.bottom);
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
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, !zone.is_locked);  // Có thể kéo khi CHƯA lock
      ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, false);
      ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, Zone_Border_Width);
      
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
   }
   
   ChartRedraw();
}

//+------------------------------------------------------------------+
void UpdateZoneButtons(TradingZone &zone)
{
   int y_base = zone.is_buy_zone ? 80 : 130;  // Buy buttons ở hàng trên, Sell buttons ở hàng dưới
   int x_start = 20;
   int btn_width = 80;
   int btn_height = 30;
   int btn_spacing = 5;
   
   // LOCK button
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
   
   // EDIT button
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
         ObjectSetInteger(0, zone.btn_edit_name, OBJPROP_BGCOLOR, clrOrange);
         ObjectSetInteger(0, zone.btn_edit_name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
         ObjectSetInteger(0, zone.btn_edit_name, OBJPROP_FONTSIZE, 9);
      }
   }
   
   // DELETE button
   if(ObjectFind(0, zone.btn_delete_name) >= 0)
      ObjectDelete(0, zone.btn_delete_name);
   
   if(zone.is_active)
   {
      if(ObjectCreate(0, zone.btn_delete_name, OBJ_BUTTON, 0, 0, 0))
      {
         int x_pos = zone.is_locked ? (x_start + (btn_width + btn_spacing) * 2) : (x_start + btn_width + btn_spacing);
         
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
void LockZone(TradingZone &zone)
{
   if(!zone.is_active)
      return;
   
   zone.is_locked = true;
   ObjectSetInteger(0, zone.rect_name, OBJPROP_SELECTABLE, false);
   DrawTradingZone(zone);
   UpdateZoneButtons(zone);
   
   double height = (zone.top - zone.bottom) / _Point;
   string zone_type = zone.is_buy_zone ? "BUY" : "SELL";
   
   Alert("🔒 ", zone_type, " zone đã được xác nhận và khóa!");
   Print("🔒 ", zone_type, " zone LOCKED: Top=", zone.top, " Bottom=", zone.bottom, " Height=", height, " pts");
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
   
   // Delete trade levels
   string prefix = zone.is_buy_zone ? "BUY" : "SELL";
   ObjectDelete(0, prefix + "_SL_LINE");
   ObjectDelete(0, prefix + "_TP1_LINE");
   ObjectDelete(0, prefix + "_TP2_LINE");
   ObjectDelete(0, prefix + "_TP3_LINE");
   ObjectDelete(0, prefix + "_ENTRY_LINE");
   
   string zone_type = zone.is_buy_zone ? "BUY" : "SELL";
   Alert("🔓 ", zone_type, " zone đã mở khóa, có thể chỉnh sửa!");
   Print("🔓 ", zone_type, " zone UNLOCKED");
}

//+------------------------------------------------------------------+
void DeleteZone(TradingZone &zone)
{
   if(!zone.is_active)
      return;
   
   // Delete rectangle
   ObjectDelete(0, zone.rect_name);
   
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
   Alert("🗑️ ", zone_type, " zone đã được xóa!");
   Print("🗑️ ", zone_type, " zone DELETED");
   
   ChartRedraw();
}

//+------------------------------------------------------------------+
void DetectFVGs(const datetime &time[], const double &open[], const double &high[], 
                const double &low[], const double &close[])
{
   int start_bar = MathMin(ArraySize(time) - 4, FVG_LookBack);
   
   for(int i = 3; i < start_bar; i++)
   {
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
                          const double &low[], const double &close[], TradingZone &zone)
{
   for(int i = 1; i < 10; i++)
   {
      bool price_in_zone = false;
      
      if(zone.is_buy_zone)
      {
         if(low[i] <= zone.top && low[i] >= zone.bottom)
            price_in_zone = true;
      }
      else
      {
         if(high[i] >= zone.bottom && high[i] <= zone.top)
            price_in_zone = true;
      }
      
      if(!price_in_zone)
         continue;
      
      if(IsSweepCandle(open, high, low, close, i, zone.is_buy_zone))
      {
         if(zone.is_buy_zone)
         {
            if(IsBottomFormation(open, high, low, close, i))
            {
               zone.sweep_bar_index = i;
               zone.sweep_low = low[i];
               zone.sweep_high = high[i];
               
               Print("✅ BUY Signal: Sweep at bar ", i, " + Bottom formation");
               return true;
            }
         }
         else
         {
            if(IsTopFormation(open, high, low, close, i))
            {
               zone.sweep_bar_index = i;
               zone.sweep_low = low[i];
               zone.sweep_high = high[i];
               
               Print("✅ SELL Signal: Sweep at bar ", i, " + Top formation");
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
      
      bool is_red_candle = (close[index] < open[index]);
      double min_prev = MathMin(open[index + 1], close[index + 1]);
      
      if(is_red_candle)
         return (close[index] >= min_prev);
      else
         return (open[index] >= min_prev);
   }
   else
   {
      if(high[index] <= high[index + 1])
         return false;
      
      double max_prev = MathMax(open[index + 1], close[index + 1]);
      return (close[index] <= max_prev);
   }
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
         return true;
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
         return true;
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
void CalculateStopLoss(TradingZone &zone, const double &high[], const double &low[])
{
   if(zone.is_buy_zone)
   {
      if(SL_Use_Sweep_Low && zone.sweep_bar_index > 0)
         zone.stop_loss_price = zone.sweep_low - (SL_Buffer_Points * _Point);
      else
         zone.stop_loss_price = zone.bottom - (SL_Buffer_Points * _Point);
   }
   else
   {
      if(SL_Use_Sweep_Low && zone.sweep_bar_index > 0)
         zone.stop_loss_price = zone.sweep_high + (SL_Buffer_Points * _Point);
      else
         zone.stop_loss_price = zone.top + (SL_Buffer_Points * _Point);
   }
}

//+------------------------------------------------------------------+
double CalculateLotSize(double stop_loss_points)
{
   if(!Auto_Calculate_Lot)
      return NormalizeLot(Manual_Lot_Size);
   
   double risk_amount = (Risk_Amount_Per_Trade > 0) ? Risk_Amount_Per_Trade : (account.Balance() * Risk_Percent_Per_Trade / 100.0);
   
   double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double point_value = (tick_size > 0) ? (tick_value * (_Point / tick_size)) : tick_value;
   
   double lot_size = (stop_loss_points > 0 && point_value > 0) ? (risk_amount / (stop_loss_points * point_value)) : 0;
   lot_size = NormalizeLot(lot_size);
   
   if(lot_size > Max_Lot_Size)
      lot_size = Max_Lot_Size;
   
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
   
   // Entry line
   string entry_name = prefix + "ENTRY_LINE";
   if(ObjectFind(0, entry_name) >= 0) ObjectDelete(0, entry_name);
   if(ObjectCreate(0, entry_name, OBJ_TREND, 0, time_start, zone.entry_price, time_end, zone.entry_price))
   {
      ObjectSetInteger(0, entry_name, OBJPROP_COLOR, clrYellow);
      ObjectSetInteger(0, entry_name, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, entry_name, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, entry_name, OBJPROP_RAY_RIGHT, true);
   }
   
   // SL line
   string sl_name = prefix + "SL_LINE";
   if(ObjectFind(0, sl_name) >= 0) ObjectDelete(0, sl_name);
   if(ObjectCreate(0, sl_name, OBJ_TREND, 0, time_start, zone.stop_loss_price, time_end, zone.stop_loss_price))
   {
      ObjectSetInteger(0, sl_name, OBJPROP_COLOR, clrRed);
      ObjectSetInteger(0, sl_name, OBJPROP_STYLE, STYLE_DOT);
      ObjectSetInteger(0, sl_name, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, sl_name, OBJPROP_RAY_RIGHT, true);
   }
   
   // TP lines
   if(Use_RR_Exit)
   {
      string tp1_name = prefix + "TP1_LINE";
      if(ObjectFind(0, tp1_name) >= 0) ObjectDelete(0, tp1_name);
      if(ObjectCreate(0, tp1_name, OBJ_TREND, 0, time_start, zone.tp1_price, time_end, zone.tp1_price))
      {
         ObjectSetInteger(0, tp1_name, OBJPROP_COLOR, clrLime);
         ObjectSetInteger(0, tp1_name, OBJPROP_STYLE, STYLE_DASH);
         ObjectSetInteger(0, tp1_name, OBJPROP_WIDTH, 1);
         ObjectSetInteger(0, tp1_name, OBJPROP_RAY_RIGHT, true);
      }
      
      string tp2_name = prefix + "TP2_LINE";
      if(ObjectFind(0, tp2_name) >= 0) ObjectDelete(0, tp2_name);
      if(ObjectCreate(0, tp2_name, OBJ_TREND, 0, time_start, zone.tp2_price, time_end, zone.tp2_price))
      {
         ObjectSetInteger(0, tp2_name, OBJPROP_COLOR, clrLime);
         ObjectSetInteger(0, tp2_name, OBJPROP_STYLE, STYLE_DASH);
         ObjectSetInteger(0, tp2_name, OBJPROP_WIDTH, 1);
         ObjectSetInteger(0, tp2_name, OBJPROP_RAY_RIGHT, true);
      }
      
      string tp3_name = prefix + "TP3_LINE";
      if(ObjectFind(0, tp3_name) >= 0) ObjectDelete(0, tp3_name);
      if(ObjectCreate(0, tp3_name, OBJ_TREND, 0, time_start, zone.tp3_price, time_end, zone.tp3_price))
      {
         ObjectSetInteger(0, tp3_name, OBJPROP_COLOR, clrLime);
         ObjectSetInteger(0, tp3_name, OBJPROP_STYLE, STYLE_DASH);
         ObjectSetInteger(0, tp3_name, OBJPROP_WIDTH, 1);
         ObjectSetInteger(0, tp3_name, OBJPROP_RAY_RIGHT, true);
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
      Print("⏸️ Already have ", zone.is_buy_zone ? "BUY" : "SELL", " position");
      return;
   }
   
   zone.entry_price = NormalizeDouble(zone.entry_price, _Digits);
   zone.stop_loss_price = NormalizeDouble(zone.stop_loss_price, _Digits);
   zone.initial_lot = zone.lot_size;
   zone.remaining_lot = zone.lot_size;
   
   bool result = false;
   if(zone.is_buy_zone)
      result = trade.Buy(zone.lot_size, _Symbol, zone.entry_price, zone.stop_loss_price, 0, Trade_Comment);
   else
      result = trade.Sell(zone.lot_size, _Symbol, zone.entry_price, zone.stop_loss_price, 0, Trade_Comment);
   
   if(result)
   {
      zone.ticket = trade.ResultOrder();
      zone.order_placed = true;
      
      double sl_points = MathAbs(zone.entry_price - zone.stop_loss_price) / _Point;
      
      string msg = StringFormat("✅ %s ORDER PLACED\nTicket: %I64u\nEntry: %.5f\nSL: %.5f (%.0f pts)\nLot: %.2f",
                               zone.is_buy_zone ? "BUY" : "SELL",
                               zone.ticket, zone.entry_price, zone.stop_loss_price, sl_points, zone.lot_size);
      SendAlert(msg);
   }
   else
   {
      Print("❌ Order failed: ", trade.ResultRetcodeDescription());
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
               SendAlert("🔔 EMA Exit: Closed position");
               if(is_buy)
                  buy_zone.order_placed = false;
               else
                  sell_zone.order_placed = false;
               continue;
            }
         }
         
         // Check RR exits
         if(Use_RR_Exit)
         {
            double profit_distance = is_buy ? (current_price - open_price) : (open_price - current_price);
            double risk_distance = MathAbs(open_price - sl);
            double current_rr = (risk_distance > 0) ? (profit_distance / risk_distance) : 0;
            
            if(current_rr >= RR_Level_1 && zone.remaining_lot > zone.initial_lot * 0.51)
            {
               double lot_to_close = NormalizeLot(zone.initial_lot * RR_Close_Percent_1 / 100.0);
               ClosePartialPosition(ticket, lot_to_close, "TP1");
               if(is_buy)
                  buy_zone.remaining_lot -= lot_to_close;
               else
                  sell_zone.remaining_lot -= lot_to_close;
            }
            else if(current_rr >= RR_Level_2 && zone.remaining_lot > zone.initial_lot * 0.21)
            {
               double lot_to_close = NormalizeLot(zone.initial_lot * RR_Close_Percent_2 / 100.0);
               ClosePartialPosition(ticket, lot_to_close, "TP2");
               if(is_buy)
                  buy_zone.remaining_lot -= lot_to_close;
               else
                  sell_zone.remaining_lot -= lot_to_close;
            }
            else if(current_rr >= RR_Level_3)
            {
               if(trade.PositionClose(ticket))
               {
                  SendAlert("✅ TP3: Closed remaining position");
                  if(is_buy)
                     buy_zone.order_placed = false;
                  else
                     sell_zone.order_placed = false;
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
      SendAlert("💰 " + reason + ": " + DoubleToString(lot_to_close, 2) + " lots");
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
      return (current_close < ema_value);
   else
      return (current_close > ema_value);
}

//+------------------------------------------------------------------+
void DisplayInfo()
{
   string info = "\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
   info += "  📊 FVG MANUAL EA v3.0\n";
   info += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
   info += "Status: " + (EA_Enabled ? "🟢 ACTIVE" : "🔴 PAUSED") + "\n";
   info += "Auto Trade: " + (Auto_Trade_On_Signal ? "✅ ON" : "⏸️ OFF") + "\n";
   info += "Symbol: " + _Symbol + "\n";
   info += "Balance: $" + DoubleToString(account.Balance(), 2) + "\n";
   info += "FVGs: " + IntegerToString(GetActiveFVGCount()) + "\n";
   
   if(buy_zone.is_active)
      info += "🔵 BUY Zone: " + (buy_zone.is_locked ? "LOCKED ✅" : "EDITING ✏️") + "\n";
   if(sell_zone.is_active)
      info += "🔴 SELL Zone: " + (sell_zone.is_locked ? "LOCKED ✅" : "EDITING ✏️") + "\n";
   
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
      info += "📈 BUY: " + IntegerToString(buy_count) + " | $" + DoubleToString(buy_profit, 2) + "\n";
   if(sell_count > 0)
      info += "📉 SELL: " + IntegerToString(sell_count) + " | $" + DoubleToString(sell_profit, 2) + "\n";
   
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
      
      int fvg_bar_index = -1;
      for(int bar = 0; bar < ArraySize(time); bar++)
      {
         if(time[bar] == FVG_Array[i].time_start)
         {
            fvg_bar_index = bar;
            break;
         }
      }
      
      if(fvg_bar_index < 0)
         continue;
      
      for(int bar = fvg_bar_index - 1; bar >= 0; bar--)
      {
         bool should_delete = false;
         
         if(FVG_Array[i].is_bullish)
         {
            if(Delete_On_Break && close[bar] < FVG_Array[i].bottom)
               should_delete = true;
            else if(Fill_On_Touch && low[bar] < FVG_Array[i].top && low[bar] > FVG_Array[i].bottom)
            {
               FVG_Array[i].top = low[bar];
               if(FVG_Array[i].top - FVG_Array[i].bottom < Min_FVG_Points * _Point)
                  should_delete = true;
               else
                  DrawFVGRectangle(i);
            }
         }
         else
         {
            if(Delete_On_Break && close[bar] > FVG_Array[i].top)
               should_delete = true;
            else if(Fill_On_Touch && high[bar] > FVG_Array[i].bottom && high[bar] < FVG_Array[i].top)
            {
               FVG_Array[i].bottom = high[bar];
               if(FVG_Array[i].top - FVG_Array[i].bottom < Min_FVG_Points * _Point)
                  should_delete = true;
               else
                  DrawFVGRectangle(i);
            }
         }
         
         if(should_delete)
         {
            FVG_Array[i].is_active = false;
            ObjectDelete(0, FVG_Array[i].rect_name);
            break;
         }
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
      if(StringFind(name, indicator_prefix) >= 0 || StringFind(name, zone_prefix) >= 0)
         ObjectDelete(0, name);
   }
   
   total = ObjectsTotal(0, 0, OBJ_BUTTON);
   for(int i = total - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i, 0, OBJ_BUTTON);
      if(StringFind(name, button_prefix) >= 0)
         ObjectDelete(0, name);
   }
   
   total = ObjectsTotal(0, 0, OBJ_TREND);
   for(int i = total - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i, 0, OBJ_TREND);
      if(StringFind(name, "BUY_") >= 0 || StringFind(name, "SELL_") >= 0)
         ObjectDelete(0, name);
   }
}

//+------------------------------------------------------------------+
void CleanupHistoricalFVGs()
{
   datetime time[];
   double high[], low[], close[];
   
   ArraySetAsSeries(time, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);
   
   int bars = MathMin(FVG_LookBack + 100, Bars(_Symbol, PERIOD_CURRENT));
   
   if(CopyTime(_Symbol, PERIOD_CURRENT, 0, bars, time) <= 0) return;
   CopyHigh(_Symbol, PERIOD_CURRENT, 0, bars, high);
   CopyLow(_Symbol, PERIOD_CURRENT, 0, bars, low);
   CopyClose(_Symbol, PERIOD_CURRENT, 0, bars, close);
   
   for(int i = 0; i < FVG_Count; i++)
   {
      if(!FVG_Array[i].is_active)
         continue;
      
      for(int bar = 0; bar < bars; bar++)
      {
         if(time[bar] <= FVG_Array[i].time_start)
            continue;
         
         if(FVG_Array[i].is_bullish)
         {
            if(Delete_On_Break && close[bar] < FVG_Array[i].bottom)
            {
               FVG_Array[i].is_active = false;
               ObjectDelete(0, FVG_Array[i].rect_name);
               break;
            }
            
            if(Fill_On_Touch && low[bar] < FVG_Array[i].top && low[bar] > FVG_Array[i].bottom)
            {
               FVG_Array[i].top = low[bar];
               
               if(FVG_Array[i].top - FVG_Array[i].bottom < Min_FVG_Points * _Point)
               {
                  FVG_Array[i].is_active = false;
                  ObjectDelete(0, FVG_Array[i].rect_name);
                  break;
               }
               
               DrawFVGRectangle(i);
            }
         }
         else
         {
            if(Delete_On_Break && close[bar] > FVG_Array[i].top)
            {
               FVG_Array[i].is_active = false;
               ObjectDelete(0, FVG_Array[i].rect_name);
               break;
            }
            
            if(Fill_On_Touch && high[bar] > FVG_Array[i].bottom && high[bar] < FVG_Array[i].top)
            {
               FVG_Array[i].bottom = high[bar];
               
               if(FVG_Array[i].top - FVG_Array[i].bottom < Min_FVG_Points * _Point)
               {
                  FVG_Array[i].is_active = false;
                  ObjectDelete(0, FVG_Array[i].rect_name);
                  break;
               }
               
               DrawFVGRectangle(i);
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
int GetActiveFVGCount()
{
   int count = 0;
   for(int i = 0; i < FVG_Count; i++)
   {
      if(FVG_Array[i].is_active)
         count++;
   }
   return count;
}
//+------------------------------------------------------------------+
