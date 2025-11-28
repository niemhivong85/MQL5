//+------------------------------------------------------------------+
//|                                              FVG_Trading_EA.mq5 |
//|                    Fair Value Gap Trading Expert Advisor         |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025"
#property version   "2.00"
#property description "FVG + Trading Zone EA with Auto Trading"

#include <Trade\Trade.mqh>

//--- Trade object
CTrade trade;

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

//--- Trading Zone & Sweep Parameters
input group    "=== Trading Zone Settings ==="
input int      Sweep_Candles_Count = 5;        // N cây nến sau sweep để tìm đáy/đỉnh
input bool     Enable_Alert = true;             // Bật thông báo
input bool     Enable_Sound = true;             // Bật âm thanh
input string   Alert_Sound = "alert.wav";       // File âm thanh
input bool     Zone_Mitigate_On_Touch = true;  // Giảm zone khi giá chạm
input bool     Zone_Delete_On_Break = true;    // Xóa zone khi giá break

input group    "=== Stop Loss Settings ==="
input bool     SL_Use_Sweep_Low = true;        // SL dưới cây sweep (BUY) / trên sweep (SELL)
input bool     SL_Use_Zone_Edge = false;       // SL dưới zone (BUY) / trên zone (SELL)
input int      SL_Buffer_Points = 5;           // Thêm buffer cho SL (points)

input group    "=== Position Sizing ==="
input double   Risk_Percent = 2.0;             // Rủi ro % tài khoản
input double   Risk_Amount_Per_Trade = 0;      // Hoặc số tiền cố định ($, 0=dùng %)
input bool     Auto_Calculate_Lot = true;      // Tự động tính lot size
input double   Manual_Lot_Size = 0.01;         // Lot size thủ công (nếu không auto)
input int      Max_Slippage = 10;              // Slippage tối đa (points)
input int      Magic_Number = 123456;          // Magic number

input group    "=== Take Profit - EMA Trailing ==="
input bool     Use_EMA_Exit = true;            // Chốt lời theo EMA
input int      EMA_Period = 20;                // Chu kỳ EMA
input ENUM_TIMEFRAMES EMA_Timeframe = PERIOD_CURRENT; // Timeframe EMA

input group    "=== Take Profit - Risk Reward ==="
input bool     Use_RR_Exit = true;             // Chốt lời theo RR
input double   RR_Level_1 = 1.0;               // R đầu tiên
input double   RR_Close_Percent_1 = 50.0;      // % đóng ở 1R
input double   RR_Level_2 = 2.0;               // R thứ hai
input double   RR_Close_Percent_2 = 30.0;      // % đóng ở 2R
input double   RR_Level_3 = 3.0;               // R thứ ba
input double   RR_Close_Percent_3 = 20.0;      // % đóng ở 3R (còn lại)

input group    "=== Auto Trading ==="
input bool     Auto_Trade = true;              // BẬT/TẮT giao dịch tự động
input bool     Close_On_Opposite = true;       // Đóng lệnh ngược chiều
input int      Max_Orders = 1;                 // Số lệnh tối đa cùng lúc

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
   double   original_lot;
   bool     tp1_hit;
   bool     tp2_hit;
   bool     tp3_hit;
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

// EMA Handle
int ema_handle = INVALID_HANDLE;
double ema_buffer[];

// Button names
string btn_buy = button_prefix + "BUY";
string btn_sell = button_prefix + "SELL";
string btn_confirm = button_prefix + "CONFIRM";
string btn_edit = button_prefix + "EDIT";

// For tracking bars
datetime last_bar_time = 0;

//--- Forward declarations
void DeleteAllObjects();
void LoadNewsSettings();
void AddNewsTime(int &count, string curr, int day, int hour, int min, int impact, string name);
bool IsNewsTime(datetime check_time);
void CreateFVG(datetime start_time, double top, double bottom, bool is_bullish, int bar_index);
void DrawFVGRectangle(int index);
void UpdateFVGStatus();
void CreateButtons();
void CreateTradingZone(bool is_buy);
void DrawTradingZone(TradingZone &zone);
void LockTradingZones();
void UnlockTradingZones();
bool CheckSweepAndPattern(bool is_buy_signal);
bool IsSweepCandle(int index, bool check_for_buy);
bool IsBottomFormation(int sweep_index);
bool IsTopFormation(int sweep_index);
void SendAlert(string message);
void UpdateZoneMitigation(TradingZone &zone);
void CalculateStopLoss(TradingZone &zone);
double CalculateLotSize(double stop_loss_points);
void DrawTradeLevels(TradingZone &zone);
bool CheckEMAExit(bool is_buy_position);
void CheckForSignals();
void OpenBuyOrder(TradingZone &zone);
void OpenSellOrder(TradingZone &zone);
void ManageOpenOrders();
int CountOpenOrders();
void CloseOppositeOrders(bool is_buy);

//+------------------------------------------------------------------+
int OnInit()
{
   // Set trade parameters
   trade.SetExpertMagicNumber(Magic_Number);
   trade.SetDeviationInPoints(Max_Slippage);
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
   buy_zone.signal_triggered = false;
   buy_zone.order_placed = false;
   buy_zone.ticket = 0;
   buy_zone.tp1_hit = false;
   buy_zone.tp2_hit = false;
   buy_zone.tp3_hit = false;
   
   sell_zone.is_active = false;
   sell_zone.is_locked = false;
   sell_zone.is_buy_zone = false;
   sell_zone.rect_name = zone_prefix + "SELL";
   sell_zone.signal_triggered = false;
   sell_zone.order_placed = false;
   sell_zone.ticket = 0;
   sell_zone.tp1_hit = false;
   sell_zone.tp2_hit = false;
   sell_zone.tp3_hit = false;
   
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
   
   CreateButtons();
   ChartRedraw();
   
   Print("FVG Trading EA initialized successfully");
   Print("Auto Trading: ", Auto_Trade ? "ENABLED" : "DISABLED");
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(ema_handle != INVALID_HANDLE)
      IndicatorRelease(ema_handle);
   
   DeleteAllObjects();
   Print("FVG Trading EA removed");
}

//+------------------------------------------------------------------+
void OnTick()
{
   // Check if new bar
   datetime current_bar_time = iTime(_Symbol, PERIOD_CURRENT, 0);
   bool new_bar = (current_bar_time != last_bar_time);
   if(new_bar)
      last_bar_time = current_bar_time;
   
   // Detect FVGs on new bar
   if(new_bar)
   {
      datetime time[];
      double open[], high[], low[], close[];
      
      ArraySetAsSeries(time, true);
      ArraySetAsSeries(open, true);
      ArraySetAsSeries(high, true);
      ArraySetAsSeries(low, true);
      ArraySetAsSeries(close, true);
      
      int copied = CopyTime(_Symbol, PERIOD_CURRENT, 0, 100, time);
      if(copied > 0)
      {
         CopyOpen(_Symbol, PERIOD_CURRENT, 0, 100, open);
         CopyHigh(_Symbol, PERIOD_CURRENT, 0, 100, high);
         CopyLow(_Symbol, PERIOD_CURRENT, 0, 100, low);
         CopyClose(_Symbol, PERIOD_CURRENT, 0, 100, close);
         
         // Detect FVGs
         for(int i = 3; i < 50 && i < copied - 2; i++)
         {
            if(Enable_News_Filter && IsNewsTime(time[i]))
               continue;
            
            // Bullish FVG
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
            
            // Bearish FVG
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
         
         UpdateFVGStatus();
      }
   }
   
   // Update zone mitigation
   if(buy_zone.is_active && buy_zone.is_locked)
      UpdateZoneMitigation(buy_zone);
   
   if(sell_zone.is_active && sell_zone.is_locked)
      UpdateZoneMitigation(sell_zone);
   
   // Check for trading signals
   if(Auto_Trade)
      CheckForSignals();
   
   // Manage open orders
   ManageOpenOrders();
}

//+------------------------------------------------------------------+
void CheckForSignals()
{
   // Check buy zone
   if(buy_zone.is_active && buy_zone.is_locked && !buy_zone.signal_triggered && !buy_zone.order_placed)
   {
      if(CheckSweepAndPattern(true))
      {
         buy_zone.signal_triggered = true;
         CalculateStopLoss(buy_zone);
         buy_zone.entry_price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         
         double sl_points = MathAbs(buy_zone.entry_price - buy_zone.stop_loss_price) / _Point;
         buy_zone.lot_size = CalculateLotSize(sl_points);
         
         // Calculate TP levels
         double risk_distance = buy_zone.entry_price - buy_zone.stop_loss_price;
         buy_zone.tp1_price = buy_zone.entry_price + (risk_distance * RR_Level_1);
         buy_zone.tp2_price = buy_zone.entry_price + (risk_distance * RR_Level_2);
         buy_zone.tp3_price = buy_zone.entry_price + (risk_distance * RR_Level_3);
         buy_zone.original_lot = buy_zone.lot_size;
         
         DrawTradeLevels(buy_zone);
         
         string msg = StringFormat("BUY SIGNAL\nEntry: %.5f\nSL: %.5f (%.1f pts)\nLot: %.2f\nTP1: %.5f | TP2: %.5f | TP3: %.5f",
                                   buy_zone.entry_price, buy_zone.stop_loss_price, sl_points,
                                   buy_zone.lot_size, buy_zone.tp1_price, buy_zone.tp2_price, buy_zone.tp3_price);
         SendAlert(msg);
         
         // Open order
         if(CountOpenOrders() < Max_Orders)
         {
            if(Close_On_Opposite)
               CloseOppositeOrders(true);
            
            OpenBuyOrder(buy_zone);
         }
      }
   }
   
   // Check sell zone
   if(sell_zone.is_active && sell_zone.is_locked && !sell_zone.signal_triggered && !sell_zone.order_placed)
   {
      if(CheckSweepAndPattern(false))
      {
         sell_zone.signal_triggered = true;
         CalculateStopLoss(sell_zone);
         sell_zone.entry_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         
         double sl_points = MathAbs(sell_zone.stop_loss_price - sell_zone.entry_price) / _Point;
         sell_zone.lot_size = CalculateLotSize(sl_points);
         
         // Calculate TP levels
         double risk_distance = sell_zone.stop_loss_price - sell_zone.entry_price;
         sell_zone.tp1_price = sell_zone.entry_price - (risk_distance * RR_Level_1);
         sell_zone.tp2_price = sell_zone.entry_price - (risk_distance * RR_Level_2);
         sell_zone.tp3_price = sell_zone.entry_price - (risk_distance * RR_Level_3);
         sell_zone.original_lot = sell_zone.lot_size;
         
         DrawTradeLevels(sell_zone);
         
         string msg = StringFormat("SELL SIGNAL\nEntry: %.5f\nSL: %.5f (%.1f pts)\nLot: %.2f\nTP1: %.5f | TP2: %.5f | TP3: %.5f",
                                   sell_zone.entry_price, sell_zone.stop_loss_price, sl_points,
                                   sell_zone.lot_size, sell_zone.tp1_price, sell_zone.tp2_price, sell_zone.tp3_price);
         SendAlert(msg);
         
         // Open order
         if(CountOpenOrders() < Max_Orders)
         {
            if(Close_On_Opposite)
               CloseOppositeOrders(false);
            
            OpenSellOrder(sell_zone);
         }
      }
   }
}

//+------------------------------------------------------------------+
void OpenBuyOrder(TradingZone &zone)
{
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double sl = zone.stop_loss_price;
   double tp = zone.tp3_price; // Use final TP
   
   if(trade.Buy(zone.lot_size, _Symbol, ask, sl, tp, "FVG Buy"))
   {
      zone.ticket = trade.ResultOrder();
      zone.order_placed = true;
      zone.tp1_hit = false;
      zone.tp2_hit = false;
      zone.tp3_hit = false;
      
      Print("✅ BUY ORDER OPENED: Ticket #", zone.ticket, " | Lot: ", zone.lot_size, " | SL: ", sl, " | TP: ", tp);
      SendAlert("BUY order opened - Ticket #" + IntegerToString(zone.ticket));
   }
   else
   {
      Print("❌ BUY ORDER FAILED: ", trade.ResultRetcodeDescription());
   }
}

//+------------------------------------------------------------------+
void OpenSellOrder(TradingZone &zone)
{
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double sl = zone.stop_loss_price;
   double tp = zone.tp3_price; // Use final TP
   
   if(trade.Sell(zone.lot_size, _Symbol, bid, sl, tp, "FVG Sell"))
   {
      zone.ticket = trade.ResultOrder();
      zone.order_placed = true;
      zone.tp1_hit = false;
      zone.tp2_hit = false;
      zone.tp3_hit = false;
      
      Print("✅ SELL ORDER OPENED: Ticket #", zone.ticket, " | Lot: ", zone.lot_size, " | SL: ", sl, " | TP: ", tp);
      SendAlert("SELL order opened - Ticket #" + IntegerToString(zone.ticket));
   }
   else
   {
      Print("❌ SELL ORDER FAILED: ", trade.ResultRetcodeDescription());
   }
}

//+------------------------------------------------------------------+
void ManageOpenOrders()
{
   // Manage buy zone order
   if(buy_zone.order_placed && buy_zone.ticket > 0)
   {
      if(PositionSelectByTicket(buy_zone.ticket))
      {
         double current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double position_volume = PositionGetDouble(POSITION_VOLUME);
         
         // Check TP levels and close partially
         if(Use_RR_Exit)
         {
            // TP1
            if(!buy_zone.tp1_hit && current_price >= buy_zone.tp1_price)
            {
               double close_volume = NormalizeDouble(buy_zone.original_lot * RR_Close_Percent_1 / 100.0, 2);
               if(close_volume > 0 && close_volume <= position_volume)
               {
                  if(trade.PositionClosePartial(buy_zone.ticket, close_volume))
                  {
                     buy_zone.tp1_hit = true;
                     Print("✅ TP1 Hit - Closed ", RR_Close_Percent_1, "% at ", current_price);
                     SendAlert("TP1 Hit - Partial close " + DoubleToString(RR_Close_Percent_1, 1) + "%");
                  }
               }
            }
            
            // TP2
            if(buy_zone.tp1_hit && !buy_zone.tp2_hit && current_price >= buy_zone.tp2_price)
            {
               double close_volume = NormalizeDouble(buy_zone.original_lot * RR_Close_Percent_2 / 100.0, 2);
               if(close_volume > 0 && close_volume <= position_volume)
               {
                  if(trade.PositionClosePartial(buy_zone.ticket, close_volume))
                  {
                     buy_zone.tp2_hit = true;
                     Print("✅ TP2 Hit - Closed ", RR_Close_Percent_2, "% at ", current_price);
                     SendAlert("TP2 Hit - Partial close " + DoubleToString(RR_Close_Percent_2, 1) + "%");
                  }
               }
            }
         }
         
         // Check EMA exit
         if(Use_EMA_Exit && CheckEMAExit(true))
         {
            if(trade.PositionClose(buy_zone.ticket))
            {
               Print("✅ Position closed by EMA exit");
               SendAlert("BUY position closed by EMA");
               buy_zone.order_placed = false;
               buy_zone.ticket = 0;
            }
         }
      }
      else
      {
         // Position closed
         buy_zone.order_placed = false;
         buy_zone.ticket = 0;
         Print("BUY position closed");
      }
   }
   
   // Manage sell zone order
   if(sell_zone.order_placed && sell_zone.ticket > 0)
   {
      if(PositionSelectByTicket(sell_zone.ticket))
      {
         double current_price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         double position_volume = PositionGetDouble(POSITION_VOLUME);
         
         // Check TP levels and close partially
         if(Use_RR_Exit)
         {
            // TP1
            if(!sell_zone.tp1_hit && current_price <= sell_zone.tp1_price)
            {
               double close_volume = NormalizeDouble(sell_zone.original_lot * RR_Close_Percent_1 / 100.0, 2);
               if(close_volume > 0 && close_volume <= position_volume)
               {
                  if(trade.PositionClosePartial(sell_zone.ticket, close_volume))
                  {
                     sell_zone.tp1_hit = true;
                     Print("✅ TP1 Hit - Closed ", RR_Close_Percent_1, "% at ", current_price);
                     SendAlert("TP1 Hit - Partial close " + DoubleToString(RR_Close_Percent_1, 1) + "%");
                  }
               }
            }
            
            // TP2
            if(sell_zone.tp1_hit && !sell_zone.tp2_hit && current_price <= sell_zone.tp2_price)
            {
               double close_volume = NormalizeDouble(sell_zone.original_lot * RR_Close_Percent_2 / 100.0, 2);
               if(close_volume > 0 && close_volume <= position_volume)
               {
                  if(trade.PositionClosePartial(sell_zone.ticket, close_volume))
                  {
                     sell_zone.tp2_hit = true;
                     Print("✅ TP2 Hit - Closed ", RR_Close_Percent_2, "% at ", current_price);
                     SendAlert("TP2 Hit - Partial close " + DoubleToString(RR_Close_Percent_2, 1) + "%");
                  }
               }
            }
         }
         
         // Check EMA exit
         if(Use_EMA_Exit && CheckEMAExit(false))
         {
            if(trade.PositionClose(sell_zone.ticket))
            {
               Print("✅ Position closed by EMA exit");
               SendAlert("SELL position closed by EMA");
               sell_zone.order_placed = false;
               sell_zone.ticket = 0;
            }
         }
      }
      else
      {
         // Position closed
         sell_zone.order_placed = false;
         sell_zone.ticket = 0;
         Print("SELL position closed");
      }
   }
}

//+------------------------------------------------------------------+
int CountOpenOrders()
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == Magic_Number)
         count++;
   }
   return count;
}

//+------------------------------------------------------------------+
void CloseOppositeOrders(bool is_buy)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == Magic_Number)
      {
         ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         
         if((is_buy && pos_type == POSITION_TYPE_SELL) || (!is_buy && pos_type == POSITION_TYPE_BUY))
         {
            ulong ticket = PositionGetInteger(POSITION_TICKET);
            if(trade.PositionClose(ticket))
               Print("Closed opposite position: ", ticket);
         }
      }
   }
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
// Helper functions (same as indicator but adapted for EA)
//+------------------------------------------------------------------+

void CreateButtons()
{
   int x_start = 20;
   int y_start = 30;
   int btn_width = 80;
   int btn_height = 30;
   int btn_spacing = 10;
   
   if(ObjectCreate(0, btn_buy, OBJ_BUTTON, 0, 0, 0))
   {
      ObjectSetInteger(0, btn_buy, OBJPROP_XDISTANCE, x_start);
      ObjectSetInteger(0, btn_buy, OBJPROP_YDISTANCE, y_start);
      ObjectSetInteger(0, btn_buy, OBJPROP_XSIZE, btn_width);
      ObjectSetInteger(0, btn_buy, OBJPROP_YSIZE, btn_height);
      ObjectSetString(0, btn_buy, OBJPROP_TEXT, "MUA");
      ObjectSetInteger(0, btn_buy, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, btn_buy, OBJPROP_BGCOLOR, Button_Buy_Color);
      ObjectSetInteger(0, btn_buy, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, btn_buy, OBJPROP_FONTSIZE, 10);
   }
   
   if(ObjectCreate(0, btn_sell, OBJ_BUTTON, 0, 0, 0))
   {
      ObjectSetInteger(0, btn_sell, OBJPROP_XDISTANCE, x_start + btn_width + btn_spacing);
      ObjectSetInteger(0, btn_sell, OBJPROP_YDISTANCE, y_start);
      ObjectSetInteger(0, btn_sell, OBJPROP_XSIZE, btn_width);
      ObjectSetInteger(0, btn_sell, OBJPROP_YSIZE, btn_height);
      ObjectSetString(0, btn_sell, OBJPROP_TEXT, "BÁN");
      ObjectSetInteger(0, btn_sell, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, btn_sell, OBJPROP_BGCOLOR, Button_Sell_Color);
      ObjectSetInteger(0, btn_sell, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, btn_sell, OBJPROP_FONTSIZE, 10);
   }
   
   if(ObjectCreate(0, btn_confirm, OBJ_BUTTON, 0, 0, 0))
   {
      ObjectSetInteger(0, btn_confirm, OBJPROP_XDISTANCE, x_start + (btn_width + btn_spacing) * 2);
      ObjectSetInteger(0, btn_confirm, OBJPROP_YDISTANCE, y_start);
      ObjectSetInteger(0, btn_confirm, OBJPROP_XSIZE, btn_width);
      ObjectSetInteger(0, btn_confirm, OBJPROP_YSIZE, btn_height);
      ObjectSetString(0, btn_confirm, OBJPROP_TEXT, "XÁC NHẬN");
      ObjectSetInteger(0, btn_confirm, OBJPROP_COLOR, clrBlack);
      ObjectSetInteger(0, btn_confirm, OBJPROP_BGCOLOR, Button_Confirm_Color);
      ObjectSetInteger(0, btn_confirm, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, btn_confirm, OBJPROP_FONTSIZE, 9);
   }
   
   if(ObjectCreate(0, btn_edit, OBJ_BUTTON, 0, 0, 0))
   {
      ObjectSetInteger(0, btn_edit, OBJPROP_XDISTANCE, x_start + (btn_width + btn_spacing) * 3);
      ObjectSetInteger(0, btn_edit, OBJPROP_YDISTANCE, y_start);
      ObjectSetInteger(0, btn_edit, OBJPROP_XSIZE, btn_width);
      ObjectSetInteger(0, btn_edit, OBJPROP_YSIZE, btn_height);
      ObjectSetString(0, btn_edit, OBJPROP_TEXT, "SỬA");
      ObjectSetInteger(0, btn_edit, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, btn_edit, OBJPROP_BGCOLOR, Button_Edit_Color);
      ObjectSetInteger(0, btn_edit, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, btn_edit, OBJPROP_FONTSIZE, 10);
   }
}

//+------------------------------------------------------------------+
void CreateTradingZone(bool is_buy)
{
   double current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   if(is_buy)
   {
      buy_zone.top = current_price - 100 * _Point;
      buy_zone.bottom = current_price - 300 * _Point;
      buy_zone.original_top = buy_zone.top;
      buy_zone.original_bottom = buy_zone.bottom;
      buy_zone.is_active = true;
      buy_zone.is_locked = false;
      buy_zone.signal_triggered = false;
      buy_zone.order_placed = false;
      buy_zone.ticket = 0;
      
      DrawTradingZone(buy_zone);
      Print("✅ Buy zone created: ", buy_zone.top, " - ", buy_zone.bottom);
   }
   else
   {
      sell_zone.top = current_price + 300 * _Point;
      sell_zone.bottom = current_price + 100 * _Point;
      sell_zone.original_top = sell_zone.top;
      sell_zone.original_bottom = sell_zone.bottom;
      sell_zone.is_active = true;
      sell_zone.is_locked = false;
      sell_zone.signal_triggered = false;
      sell_zone.order_placed = false;
      sell_zone.ticket = 0;
      
      DrawTradingZone(sell_zone);
      Print("✅ Sell zone created: ", sell_zone.top, " - ", sell_zone.bottom);
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
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, !zone.is_locked);
      ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, Zone_Border_Width);
      
      int r = (int)(zone_color & 0xFF);
      int g = (int)((zone_color >> 8) & 0xFF);
      int b = (int)((zone_color >> 16) & 0xFF);
      int alpha = (int)((100 - Zone_Transparency) * 2.55);
      r = r + (255 - r) * (255 - alpha) / 255;
      g = g + (255 - g) * (255 - alpha) / 255;
      b = b + (255 - b) * (255 - alpha) / 255;
      color bg_color = (color)((b << 16) | (g << 8) | r);
      
      ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg_color);
      
      string label_name = name + "_LABEL";
      if(ObjectFind(0, label_name) >= 0)
         ObjectDelete(0, label_name);
         
      if(ObjectCreate(0, label_name, OBJ_TEXT, 0, time_start, zone.top))
      {
         string label_text = zone.is_buy_zone ? "  BUY ZONE" : "  SELL ZONE";
         if(zone.is_locked)
            label_text += " [LOCKED]";
         else
            label_text += " [Drag to move]";
            
         ObjectSetString(0, label_name, OBJPROP_TEXT, label_text);
         ObjectSetInteger(0, label_name, OBJPROP_COLOR, zone_color);
         ObjectSetInteger(0, label_name, OBJPROP_FONTSIZE, 10);
         ObjectSetInteger(0, label_name, OBJPROP_ANCHOR, ANCHOR_LEFT);
      }
   }
   
   ChartRedraw();
}

//+------------------------------------------------------------------+
void LockTradingZones()
{
   if(buy_zone.is_active)
   {
      buy_zone.is_locked = true;
      ObjectSetInteger(0, buy_zone.rect_name, OBJPROP_SELECTABLE, false);
      DrawTradingZone(buy_zone);
      Print("Buy zone locked");
   }
   
   if(sell_zone.is_active)
   {
      sell_zone.is_locked = true;
      ObjectSetInteger(0, sell_zone.rect_name, OBJPROP_SELECTABLE, false);
      DrawTradingZone(sell_zone);
      Print("Sell zone locked");
   }
   
   Alert("Trading zones locked - Auto trading ready!");
}

//+------------------------------------------------------------------+
void UnlockTradingZones()
{
   if(buy_zone.is_active)
   {
      buy_zone.is_locked = false;
      buy_zone.signal_triggered = false;
      buy_zone.order_placed = false;
      buy_zone.ticket = 0;
      ObjectSetInteger(0, buy_zone.rect_name, OBJPROP_SELECTABLE, true);
      DrawTradingZone(buy_zone);
      
      ObjectDelete(0, "BUY_SL_LINE");
      ObjectDelete(0, "BUY_TP1_LINE");
      ObjectDelete(0, "BUY_TP2_LINE");
      ObjectDelete(0, "BUY_TP3_LINE");
      ObjectDelete(0, "BUY_ENTRY_LINE");
   }
   
   if(sell_zone.is_active)
   {
      sell_zone.is_locked = false;
      sell_zone.signal_triggered = false;
      sell_zone.order_placed = false;
      sell_zone.ticket = 0;
      ObjectSetInteger(0, sell_zone.rect_name, OBJPROP_SELECTABLE, true);
      DrawTradingZone(sell_zone);
      
      ObjectDelete(0, "SELL_SL_LINE");
      ObjectDelete(0, "SELL_TP1_LINE");
      ObjectDelete(0, "SELL_TP2_LINE");
      ObjectDelete(0, "SELL_TP3_LINE");
      ObjectDelete(0, "SELL_ENTRY_LINE");
   }
   
   ChartRedraw();
   Print("Trading zones unlocked");
}

//+------------------------------------------------------------------+
bool CheckSweepAndPattern(bool is_buy_signal)
{
   datetime time[];
   double open[], high[], low[], close[];
   
   ArraySetAsSeries(time, true);
   ArraySetAsSeries(open, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);
   
   CopyTime(_Symbol, PERIOD_CURRENT, 0, 20, time);
   CopyOpen(_Symbol, PERIOD_CURRENT, 0, 20, open);
   CopyHigh(_Symbol, PERIOD_CURRENT, 0, 20, high);
   CopyLow(_Symbol, PERIOD_CURRENT, 0, 20, low);
   CopyClose(_Symbol, PERIOD_CURRENT, 0, 20, close);
   
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
      
      if(IsSweepCandle(i, is_buy_signal))
      {
         if(is_buy_signal)
         {
            if(IsBottomFormation(i))
            {
               buy_zone.sweep_bar_index = i;
               buy_zone.sweep_low = low[i];
               buy_zone.sweep_high = high[i];
               return true;
            }
         }
         else
         {
            if(IsTopFormation(i))
            {
               sell_zone.sweep_bar_index = i;
               sell_zone.sweep_low = low[i];
               sell_zone.sweep_high = high[i];
               return true;
            }
         }
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
bool IsSweepCandle(int index, bool check_for_buy)
{
   double open[], high[], low[], close[];
   ArraySetAsSeries(open, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);
   
   CopyOpen(_Symbol, PERIOD_CURRENT, 0, index + 2, open);
   CopyHigh(_Symbol, PERIOD_CURRENT, 0, index + 2, high);
   CopyLow(_Symbol, PERIOD_CURRENT, 0, index + 2, low);
   CopyClose(_Symbol, PERIOD_CURRENT, 0, index + 2, close);
   
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
bool IsBottomFormation(int sweep_index)
{
   double open[], high[], low[], close[];
   ArraySetAsSeries(open, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);
   
   int needed = sweep_index + Sweep_Candles_Count + 1;
   CopyOpen(_Symbol, PERIOD_CURRENT, 0, needed, open);
   CopyHigh(_Symbol, PERIOD_CURRENT, 0, needed, high);
   CopyLow(_Symbol, PERIOD_CURRENT, 0, needed, low);
   CopyClose(_Symbol, PERIOD_CURRENT, 0, needed, close);
   
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
bool IsTopFormation(int sweep_index)
{
   double open[], high[], low[], close[];
   ArraySetAsSeries(open, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);
   
   int needed = sweep_index + Sweep_Candles_Count + 1;
   CopyOpen(_Symbol, PERIOD_CURRENT, 0, needed, open);
   CopyHigh(_Symbol, PERIOD_CURRENT, 0, needed, high);
   CopyLow(_Symbol, PERIOD_CURRENT, 0, needed, low);
   CopyClose(_Symbol, PERIOD_CURRENT, 0, needed, close);
   
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
void UpdateZoneMitigation(TradingZone &zone)
{
   if(!zone.is_active || !zone.is_locked)
      return;
   
   double high[], low[], close[];
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);
   
   CopyHigh(_Symbol, PERIOD_CURRENT, 0, 5, high);
   CopyLow(_Symbol, PERIOD_CURRENT, 0, 5, low);
   CopyClose(_Symbol, PERIOD_CURRENT, 0, 5, close);
   
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
               return;
            }
         }
      }
      
      if(is_modified)
         DrawTradingZone(zone);
   }
}

//+------------------------------------------------------------------+
void CalculateStopLoss(TradingZone &zone)
{
   double high[], low[];
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   
   CopyHigh(_Symbol, PERIOD_CURRENT, 0, 20, high);
   CopyLow(_Symbol, PERIOD_CURRENT, 0, 20, low);
   
   double sl_price = 0;
   
   if(zone.is_buy_zone)
   {
      if(SL_Use_Sweep_Low && zone.sweep_bar_index > 0)
      {
         sl_price = zone.sweep_low - (SL_Buffer_Points * _Point);
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
      else
      {
         sl_price = zone.top + (SL_Buffer_Points * _Point);
      }
   }
   
   zone.stop_loss_price = sl_price;
}

//+------------------------------------------------------------------+
double CalculateLotSize(double stop_loss_points)
{
   if(!Auto_Calculate_Lot)
      return Manual_Lot_Size;
   
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double risk_money = (Risk_Amount_Per_Trade > 0) ? Risk_Amount_Per_Trade : (balance * Risk_Percent / 100.0);
   
   double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double max_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lot_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   double point_value = tick_value;
   if(tick_size > 0)
      point_value = tick_value * (_Point / tick_size);
   
   double lot_size = 0;
   if(stop_loss_points > 0 && point_value > 0)
   {
      lot_size = risk_money / (stop_loss_points * point_value);
   }
   
   lot_size = MathFloor(lot_size / lot_step) * lot_step;
   
   if(lot_size < min_lot) lot_size = min_lot;
   if(lot_size > max_lot) lot_size = max_lot;
   
   return lot_size;
}

//+------------------------------------------------------------------+
void DrawTradeLevels(TradingZone &zone)
{
   string prefix = zone.is_buy_zone ? "BUY_" : "SELL_";
   datetime time_start = iTime(_Symbol, PERIOD_CURRENT, 10);
   datetime time_end = TimeCurrent() + PeriodSeconds() * 100;
   
   string entry_name = prefix + "ENTRY_LINE";
   if(ObjectFind(0, entry_name) >= 0) ObjectDelete(0, entry_name);
   if(ObjectCreate(0, entry_name, OBJ_TREND, 0, time_start, zone.entry_price, time_end, zone.entry_price))
   {
      ObjectSetInteger(0, entry_name, OBJPROP_COLOR, clrYellow);
      ObjectSetInteger(0, entry_name, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, entry_name, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, entry_name, OBJPROP_RAY_RIGHT, true);
   }
   
   string sl_name = prefix + "SL_LINE";
   if(ObjectFind(0, sl_name) >= 0) ObjectDelete(0, sl_name);
   if(ObjectCreate(0, sl_name, OBJ_TREND, 0, time_start, zone.stop_loss_price, time_end, zone.stop_loss_price))
   {
      ObjectSetInteger(0, sl_name, OBJPROP_COLOR, SL_Line_Color);
      ObjectSetInteger(0, sl_name, OBJPROP_STYLE, STYLE_DOT);
      ObjectSetInteger(0, sl_name, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, sl_name, OBJPROP_RAY_RIGHT, true);
   }
   
   if(Use_RR_Exit)
   {
      string tp1_name = prefix + "TP1_LINE";
      if(ObjectFind(0, tp1_name) >= 0) ObjectDelete(0, tp1_name);
      if(ObjectCreate(0, tp1_name, OBJ_TREND, 0, time_start, zone.tp1_price, time_end, zone.tp1_price))
      {
         ObjectSetInteger(0, tp1_name, OBJPROP_COLOR, TP_Line_Color);
         ObjectSetInteger(0, tp1_name, OBJPROP_STYLE, STYLE_DASH);
         ObjectSetInteger(0, tp1_name, OBJPROP_WIDTH, 1);
         ObjectSetInteger(0, tp1_name, OBJPROP_RAY_RIGHT, true);
      }
      
      string tp2_name = prefix + "TP2_LINE";
      if(ObjectFind(0, tp2_name) >= 0) ObjectDelete(0, tp2_name);
      if(ObjectCreate(0, tp2_name, OBJ_TREND, 0, time_start, zone.tp2_price, time_end, zone.tp2_price))
      {
         ObjectSetInteger(0, tp2_name, OBJPROP_COLOR, TP_Line_Color);
         ObjectSetInteger(0, tp2_name, OBJPROP_STYLE, STYLE_DASH);
         ObjectSetInteger(0, tp2_name, OBJPROP_WIDTH, 1);
         ObjectSetInteger(0, tp2_name, OBJPROP_RAY_RIGHT, true);
      }
      
      string tp3_name = prefix + "TP3_LINE";
      if(ObjectFind(0, tp3_name) >= 0) ObjectDelete(0, tp3_name);
      if(ObjectCreate(0, tp3_name, OBJ_TREND, 0, time_start, zone.tp3_price, time_end, zone.tp3_price))
      {
         ObjectSetInteger(0, tp3_name, OBJPROP_COLOR, TP_Line_Color);
         ObjectSetInteger(0, tp3_name, OBJPROP_STYLE, STYLE_DASH);
         ObjectSetInteger(0, tp3_name, OBJPROP_WIDTH, 1);
         ObjectSetInteger(0, tp3_name, OBJPROP_RAY_RIGHT, true);
      }
   }
   
   ChartRedraw();
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
         return true;
   }
   else
   {
      if(current_close > ema_value)
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
      
      int r = (int)(fvg_color & 0xFF);
      int g = (int)((fvg_color >> 8) & 0xFF);
      int b = (int)((fvg_color >> 16) & 0xFF);
      int alpha = (int)((100 - FVG_Transparency) * 2.55);
      r = r + (255 - r) * (255 - alpha) / 255;
      g = g + (255 - g) * (255 - alpha) / 255;
      b = b + (255 - b) * (255 - alpha) / 255;
      color bg_color = (color)((b << 16) | (g << 8) | r);
      
      ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg_color);
   }
}

//+------------------------------------------------------------------+
void UpdateFVGStatus()
{
   datetime time[];
   double high[], low[], close[];
   
   ArraySetAsSeries(time, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);
   
   CopyTime(_Symbol, PERIOD_CURRENT, 0, 100, time);
   CopyHigh(_Symbol, PERIOD_CURRENT, 0, 100, high);
   CopyLow(_Symbol, PERIOD_CURRENT, 0, 100, low);
   CopyClose(_Symbol, PERIOD_CURRENT, 0, 100, close);
   
   for(int i = 0; i < FVG_Count; i++)
   {
      if(!FVG_Array[i].is_active)
         continue;
         
      for(int bar = 0; bar < ArraySize(time); bar++)
      {
         if(time[bar] <= FVG_Array[i].time_start)
            continue;
            
         bool is_modified = false;
         
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
            if(Delete_On_Break && close[bar] > FVG_Array[i].top)
            {
               FVG_Array[i].is_active = false;
               ObjectDelete(0, FVG_Array[i].rect_name);
               break;
            }
            
            if(Fill_On_Touch && high[bar] > FVG_Array[i].bottom && high[bar] < FVG_Array[i].top)
            {
               FVG_Array[i].bottom = high[bar];
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
      AddNewsTime(count, "USD", 3, 13, 30, 2, "CPI");
   }
   
   if(Filter_EUR)
   {
      AddNewsTime(count, "EUR", 3, 12, 0, 3, "ECB Rate");
      AddNewsTime(count, "EUR", 4, 10, 0, 3, "Eurozone GDP");
   }
   
   if(Filter_GBP)
   {
      AddNewsTime(count, "GBP", 4, 12, 0, 3, "BOE Rate");
      AddNewsTime(count, "GBP", 3, 7, 0, 3, "UK GDP");
   }
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
