//+------------------------------------------------------------------+
//|                                              FVG_Trading_EA.mq5  |
//|                    Fair Value Gap Expert Advisor with Auto Trade |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025"
#property version   "2.00"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\AccountInfo.mqh>

//--- Trade objects
CTrade         trade;
CPositionInfo  position;
CAccountInfo   account;

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
input int      Sweep_Candles_Count = 5;
input bool     Enable_Alert = true;
input bool     Enable_Sound = true;
input string   Alert_Sound = "alert.wav";
input bool     Zone_Mitigate_On_Touch = true;
input bool     Zone_Delete_On_Break = true;

input group    "=== Stop Loss Settings ==="
input bool     SL_Use_Sweep_Low = true;
input bool     SL_Use_Zone_Edge = false;
input int      SL_Buffer_Points = 5;

input group    "=== Position Sizing ==="
input double   Risk_Amount_Per_Trade = 100.0;
input bool     Auto_Calculate_Lot = true;
input double   Manual_Lot_Size = 0.01;
input int      Max_Slippage = 10;

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

input group    "=== EA Settings ==="
input int      Magic_Number = 123456;
input bool     Auto_Trade = true;
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
   ulong    position_ticket;
   bool     tp1_hit;
   bool     tp2_hit;
   bool     tp3_hit;
   double   remaining_lot;
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

// EMA Handle
int ema_handle = INVALID_HANDLE;
double ema_buffer[];

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
void UpdateFVGStatus();

// Trading Zone functions
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
void ExecuteTrade(TradingZone &zone);
bool CheckEMAExit(bool is_buy_position);
void ManagePositions();
bool ClosePartialPosition(ulong ticket, double close_lot, string reason);

//+------------------------------------------------------------------+
int OnInit()
{
   // Setup trade object
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
   buy_zone.position_ticket = 0;
   buy_zone.tp1_hit = false;
   buy_zone.tp2_hit = false;
   buy_zone.tp3_hit = false;
   buy_zone.remaining_lot = 0;
   
   sell_zone.is_active = false;
   sell_zone.is_locked = false;
   sell_zone.is_buy_zone = false;
   sell_zone.rect_name = zone_prefix + "SELL";
   sell_zone.signal_triggered = false;
   sell_zone.order_placed = false;
   sell_zone.position_ticket = 0;
   sell_zone.tp1_hit = false;
   sell_zone.tp2_hit = false;
   sell_zone.tp3_hit = false;
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
   
   CreateButtons();
   ChartRedraw();
   
   Print("FVG Trading EA initialized successfully");
   Print("Auto Trade: ", Auto_Trade ? "ENABLED" : "DISABLED");
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(ema_handle != INVALID_HANDLE)
      IndicatorRelease(ema_handle);
   
   DeleteAllObjects();
   
   Print("FVG Trading EA deinitialized. Reason: ", reason);
}

//+------------------------------------------------------------------+
void OnTick()
{
   // Update FVG status
   UpdateFVGStatus();
   
   // Update zone mitigation
   if(buy_zone.is_active && buy_zone.is_locked)
      UpdateZoneMitigation(buy_zone);
   
   if(sell_zone.is_active && sell_zone.is_locked)
      UpdateZoneMitigation(sell_zone);
   
   // Check for new signals
   if(buy_zone.is_active && buy_zone.is_locked && !buy_zone.signal_triggered)
   {
      if(CheckSweepAndPattern(true))
      {
         buy_zone.signal_triggered = true;
         CalculateStopLoss(buy_zone);
         buy_zone.entry_price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         
         double sl_points = MathAbs(buy_zone.entry_price - buy_zone.stop_loss_price) / _Point;
         buy_zone.lot_size = CalculateLotSize(sl_points);
         
         double risk_distance = buy_zone.entry_price - buy_zone.stop_loss_price;
         buy_zone.tp1_price = buy_zone.entry_price + (risk_distance * RR_Level_1);
         buy_zone.tp2_price = buy_zone.entry_price + (risk_distance * RR_Level_2);
         buy_zone.tp3_price = buy_zone.entry_price + (risk_distance * RR_Level_3);
         buy_zone.remaining_lot = buy_zone.lot_size;
         
         DrawTradeLevels(buy_zone);
         
         string msg = StringFormat("BUY SIGNAL\nEntry: %.5f\nSL: %.5f (%.1f pts)\nLot: %.2f\nTP1: %.5f | TP2: %.5f | TP3: %.5f",
                                   buy_zone.entry_price, buy_zone.stop_loss_price, sl_points,
                                   buy_zone.lot_size, buy_zone.tp1_price, buy_zone.tp2_price, buy_zone.tp3_price);
         SendAlert(msg);
         
         if(Auto_Trade)
            ExecuteTrade(buy_zone);
      }
   }
   
   if(sell_zone.is_active && sell_zone.is_locked && !sell_zone.signal_triggered)
   {
      if(CheckSweepAndPattern(false))
      {
         sell_zone.signal_triggered = true;
         CalculateStopLoss(sell_zone);
         sell_zone.entry_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         
         double sl_points = MathAbs(sell_zone.stop_loss_price - sell_zone.entry_price) / _Point;
         sell_zone.lot_size = CalculateLotSize(sl_points);
         
         double risk_distance = sell_zone.stop_loss_price - sell_zone.entry_price;
         sell_zone.tp1_price = sell_zone.entry_price - (risk_distance * RR_Level_1);
         sell_zone.tp2_price = sell_zone.entry_price - (risk_distance * RR_Level_2);
         sell_zone.tp3_price = sell_zone.entry_price - (risk_distance * RR_Level_3);
         sell_zone.remaining_lot = sell_zone.lot_size;
         
         DrawTradeLevels(sell_zone);
         
         string msg = StringFormat("SELL SIGNAL\nEntry: %.5f\nSL: %.5f (%.1f pts)\nLot: %.2f\nTP1: %.5f | TP2: %.5f | TP3: %.5f",
                                   sell_zone.entry_price, sell_zone.stop_loss_price, sl_points,
                                   sell_zone.lot_size, sell_zone.tp1_price, sell_zone.tp2_price, sell_zone.tp3_price);
         SendAlert(msg);
         
         if(Auto_Trade)
            ExecuteTrade(sell_zone);
      }
   }
   
   // Manage open positions
   ManagePositions();
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
void ExecuteTrade(TradingZone &zone)
{
   if(!Auto_Trade)
   {
      Print("Auto Trade is disabled. Trade NOT executed.");
      return;
   }
   
   if(zone.order_placed)
   {
      Print("Order already placed for this zone.");
      return;
   }
   
   // Check account
   if(!account.TradeAllowed())
   {
      Print("Trade not allowed for account");
      return;
   }
   
   // Normalize prices
   double entry = NormalizeDouble(zone.entry_price, _Digits);
   double sl = NormalizeDouble(zone.stop_loss_price, _Digits);
   double lot = NormalizeDouble(zone.lot_size, 2);
   
   // Place order
   bool result = false;
   
   if(zone.is_buy_zone)
   {
      result = trade.Buy(lot, _Symbol, entry, sl, 0, Trade_Comment);
   }
   else
   {
      result = trade.Sell(lot, _Symbol, entry, sl, 0, Trade_Comment);
   }
   
   if(result)
   {
      zone.order_placed = true;
      zone.position_ticket = trade.ResultOrder();
      zone.remaining_lot = lot;
      
      Print("✅ Order placed successfully!");
      Print("  Type: ", zone.is_buy_zone ? "BUY" : "SELL");
      Print("  Ticket: ", zone.position_ticket);
      Print("  Lot: ", lot);
      Print("  Entry: ", entry);
      Print("  SL: ", sl);
      
      SendAlert("Order placed: " + (zone.is_buy_zone ? "BUY" : "SELL") + " " + DoubleToString(lot, 2) + " lots");
   }
   else
   {
      Print("❌ Order failed! Error: ", trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription());
      SendAlert("Order FAILED: " + trade.ResultRetcodeDescription());
   }
}

//+------------------------------------------------------------------+
void ManagePositions()
{
   // Check buy zone position
   if(buy_zone.order_placed && buy_zone.position_ticket > 0)
   {
      if(position.SelectByTicket(buy_zone.position_ticket))
      {
         double current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         
         // Check RR exits
         if(Use_RR_Exit)
         {
            if(!buy_zone.tp1_hit && current_price >= buy_zone.tp1_price)
            {
               double close_lot = NormalizeDouble(buy_zone.lot_size * RR_Close_Percent_1 / 100.0, 2);
               if(ClosePartialPosition(buy_zone.position_ticket, close_lot, "TP1"))
               {
                  buy_zone.tp1_hit = true;
                  buy_zone.remaining_lot -= close_lot;
               }
            }
            else if(buy_zone.tp1_hit && !buy_zone.tp2_hit && current_price >= buy_zone.tp2_price)
            {
               double close_lot = NormalizeDouble(buy_zone.lot_size * RR_Close_Percent_2 / 100.0, 2);
               if(ClosePartialPosition(buy_zone.position_ticket, close_lot, "TP2"))
               {
                  buy_zone.tp2_hit = true;
                  buy_zone.remaining_lot -= close_lot;
               }
            }
            else if(buy_zone.tp2_hit && !buy_zone.tp3_hit && current_price >= buy_zone.tp3_price)
            {
               // Close remaining
               if(ClosePartialPosition(buy_zone.position_ticket, buy_zone.remaining_lot, "TP3"))
               {
                  buy_zone.tp3_hit = true;
                  buy_zone.order_placed = false;
               }
            }
         }
         
         // Check EMA exit
         if(Use_EMA_Exit && CheckEMAExit(true))
         {
            if(ClosePartialPosition(buy_zone.position_ticket, buy_zone.remaining_lot, "EMA Exit"))
            {
               buy_zone.order_placed = false;
            }
         }
      }
      else
      {
         // Position closed (by SL or manual)
         buy_zone.order_placed = false;
         Print("Buy position closed (SL hit or manual close)");
      }
   }
   
   // Check sell zone position
   if(sell_zone.order_placed && sell_zone.position_ticket > 0)
   {
      if(position.SelectByTicket(sell_zone.position_ticket))
      {
         double current_price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         
         // Check RR exits
         if(Use_RR_Exit)
         {
            if(!sell_zone.tp1_hit && current_price <= sell_zone.tp1_price)
            {
               double close_lot = NormalizeDouble(sell_zone.lot_size * RR_Close_Percent_1 / 100.0, 2);
               if(ClosePartialPosition(sell_zone.position_ticket, close_lot, "TP1"))
               {
                  sell_zone.tp1_hit = true;
                  sell_zone.remaining_lot -= close_lot;
               }
            }
            else if(sell_zone.tp1_hit && !sell_zone.tp2_hit && current_price <= sell_zone.tp2_price)
            {
               double close_lot = NormalizeDouble(sell_zone.lot_size * RR_Close_Percent_2 / 100.0, 2);
               if(ClosePartialPosition(sell_zone.position_ticket, close_lot, "TP2"))
               {
                  sell_zone.tp2_hit = true;
                  sell_zone.remaining_lot -= close_lot;
               }
            }
            else if(sell_zone.tp2_hit && !sell_zone.tp3_hit && current_price <= sell_zone.tp3_price)
            {
               // Close remaining
               if(ClosePartialPosition(sell_zone.position_ticket, sell_zone.remaining_lot, "TP3"))
               {
                  sell_zone.tp3_hit = true;
                  sell_zone.order_placed = false;
               }
            }
         }
         
         // Check EMA exit
         if(Use_EMA_Exit && CheckEMAExit(false))
         {
            if(ClosePartialPosition(sell_zone.position_ticket, sell_zone.remaining_lot, "EMA Exit"))
            {
               sell_zone.order_placed = false;
            }
         }
      }
      else
      {
         // Position closed (by SL or manual)
         sell_zone.order_placed = false;
         Print("Sell position closed (SL hit or manual close)");
      }
   }
}

//+------------------------------------------------------------------+
bool ClosePartialPosition(ulong ticket, double close_lot, string reason)
{
   if(!position.SelectByTicket(ticket))
      return false;
   
   double current_lot = position.Volume();
   if(close_lot > current_lot)
      close_lot = current_lot;
   
   close_lot = NormalizeDouble(close_lot, 2);
   
   if(close_lot < SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN))
   {
      Print("Close lot too small: ", close_lot);
      return false;
   }
   
   bool result = trade.PositionClosePartial(ticket, close_lot);
   
   if(result)
   {
      Print("✅ Partial close success: ", close_lot, " lots at ", reason);
      SendAlert(reason + ": Closed " + DoubleToString(close_lot, 2) + " lots");
      return true;
   }
   else
   {
      Print("❌ Partial close failed: ", trade.ResultRetcode());
      return false;
   }
}

//+------------------------------------------------------------------+
// Copy all other functions from indicator...
// I'll add the key ones here:

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
      ObjectSetInteger(0, btn_buy, OBJPROP_BORDER_COLOR, clrBlack);
      ObjectSetInteger(0, btn_buy, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, btn_buy, OBJPROP_FONTSIZE, 10);
      ObjectSetString(0, btn_buy, OBJPROP_FONT, "Arial Bold");
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
      ObjectSetInteger(0, btn_sell, OBJPROP_BORDER_COLOR, clrBlack);
      ObjectSetInteger(0, btn_sell, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, btn_sell, OBJPROP_FONTSIZE, 10);
      ObjectSetString(0, btn_sell, OBJPROP_FONT, "Arial Bold");
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
      ObjectSetInteger(0, btn_confirm, OBJPROP_BORDER_COLOR, clrBlack);
      ObjectSetInteger(0, btn_confirm, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, btn_confirm, OBJPROP_FONTSIZE, 9);
      ObjectSetString(0, btn_confirm, OBJPROP_FONT, "Arial Bold");
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
      ObjectSetInteger(0, btn_edit, OBJPROP_BORDER_COLOR, clrBlack);
      ObjectSetInteger(0, btn_edit, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, btn_edit, OBJPROP_FONTSIZE, 10);
      ObjectSetString(0, btn_edit, OBJPROP_FONT, "Arial Bold");
   }
}

//+------------------------------------------------------------------+
void CreateTradingZone(bool is_buy)
{
   double current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   if(is_buy)
   {
      buy_zone.top = current_price - 50 * _Point;
      buy_zone.bottom = current_price - 150 * _Point;
      buy_zone.original_top = buy_zone.top;
      buy_zone.original_bottom = buy_zone.bottom;
      buy_zone.is_active = true;
      buy_zone.is_locked = false;
      buy_zone.signal_triggered = false;
      buy_zone.order_placed = false;
      buy_zone.position_ticket = 0;
      buy_zone.tp1_hit = false;
      buy_zone.tp2_hit = false;
      buy_zone.tp3_hit = false;
      
      DrawTradingZone(buy_zone);
   }
   else
   {
      sell_zone.top = current_price + 150 * _Point;
      sell_zone.bottom = current_price + 50 * _Point;
      sell_zone.original_top = sell_zone.top;
      sell_zone.original_bottom = sell_zone.bottom;
      sell_zone.is_active = true;
      sell_zone.is_locked = false;
      sell_zone.signal_triggered = false;
      sell_zone.order_placed = false;
      sell_zone.position_ticket = 0;
      sell_zone.tp1_hit = false;
      sell_zone.tp2_hit = false;
      sell_zone.tp3_hit = false;
      
      DrawTradingZone(sell_zone);
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
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, false);
      ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
      
      int r = (zone_color & 0xFF);
      int g = ((zone_color >> 8) & 0xFF);
      int b = ((zone_color >> 16) & 0xFF);
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
      buy_zone.order_placed = false;
      buy_zone.tp1_hit = false;
      buy_zone.tp2_hit = false;
      buy_zone.tp3_hit = false;
      ObjectSetInteger(0, buy_zone.rect_name, OBJPROP_SELECTABLE, true);
      
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
      sell_zone.tp1_hit = false;
      sell_zone.tp2_hit = false;
      sell_zone.tp3_hit = false;
      ObjectSetInteger(0, sell_zone.rect_name, OBJPROP_SELECTABLE, true);
      
      ObjectDelete(0, "SELL_SL_LINE");
      ObjectDelete(0, "SELL_TP1_LINE");
      ObjectDelete(0, "SELL_TP2_LINE");
      ObjectDelete(0, "SELL_TP3_LINE");
      ObjectDelete(0, "SELL_ENTRY_LINE");
   }
   
   Print("Trading zones unlocked for editing");
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
   
   int copied = CopyTime(_Symbol, PERIOD_CURRENT, 0, 20, time);
   if(copied <= 0) return false;
   
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
      
      if(!price_in_zone) continue;
      
      if(IsSweepCandle(i, is_buy_signal))
      {
         if(is_buy_signal)
         {
            if(IsBottomFormation(i))
            {
               buy_zone.sweep_bar_index = i;
               buy_zone.sweep_low = low[i];
               buy_zone.sweep_high = high[i];
               Print("BUY Signal: Sweep + Bottom formation detected!");
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
               Print("SELL Signal: Sweep + Top formation detected!");
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
   
   CopyOpen(_Symbol, PERIOD_CURRENT, 0, index + 5, open);
   CopyHigh(_Symbol, PERIOD_CURRENT, 0, index + 5, high);
   CopyLow(_Symbol, PERIOD_CURRENT, 0, index + 5, low);
   CopyClose(_Symbol, PERIOD_CURRENT, 0, index + 5, close);
   
   if(index + 1 >= ArraySize(open)) return false;
   
   if(check_for_buy)
   {
      if(low[index] >= low[index + 1]) return false;
      
      bool is_bearish = close[index] < open[index];
      if(is_bearish)
      {
         if(close[index] >= close[index + 1]) return true;
      }
      else
      {
         if(close[index] >= open[index + 1]) return true;
      }
   }
   else
   {
      if(high[index] <= high[index + 1]) return false;
      
      bool is_bullish = close[index] > open[index];
      if(is_bullish)
      {
         if(close[index] <= close[index + 1]) return true;
      }
      else
      {
         if(close[index] <= open[index + 1]) return true;
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
   
   CopyOpen(_Symbol, PERIOD_CURRENT, 0, sweep_index + 10, open);
   CopyHigh(_Symbol, PERIOD_CURRENT, 0, sweep_index + 10, high);
   CopyLow(_Symbol, PERIOD_CURRENT, 0, sweep_index + 10, low);
   CopyClose(_Symbol, PERIOD_CURRENT, 0, sweep_index + 10, close);
   
   int search_end = MathMax(0, sweep_index - (Sweep_Candles_Count - 1));
   
   for(int i = sweep_index; i >= search_end; i--)
   {
      if(i + 1 >= ArraySize(close)) continue;
      
      if(close[i] > high[i + 1])
      {
         Print("Bottom formation at bar ", i);
         return true;
      }
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
   
   CopyOpen(_Symbol, PERIOD_CURRENT, 0, sweep_index + 10, open);
   CopyHigh(_Symbol, PERIOD_CURRENT, 0, sweep_index + 10, high);
   CopyLow(_Symbol, PERIOD_CURRENT, 0, sweep_index + 10, low);
   CopyClose(_Symbol, PERIOD_CURRENT, 0, sweep_index + 10, close);
   
   int search_end = MathMax(0, sweep_index - (Sweep_Candles_Count - 1));
   
   for(int i = sweep_index; i >= search_end; i--)
   {
      if(i + 1 >= ArraySize(close)) continue;
      
      if(close[i] < low[i + 1])
      {
         Print("Top formation at bar ", i);
         return true;
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
void CalculateStopLoss(TradingZone &zone)
{
   double open[], high[], low[];
   ArraySetAsSeries(open, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   
   CopyOpen(_Symbol, PERIOD_CURRENT, 0, 20, open);
   CopyHigh(_Symbol, PERIOD_CURRENT, 0, 20, high);
   CopyLow(_Symbol, PERIOD_CURRENT, 0, 20, low);
   
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
      return Manual_Lot_Size;
   
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
      lot_size = Risk_Amount_Per_Trade / (stop_loss_points * point_value);
   }
   
   lot_size = MathFloor(lot_size / lot_step) * lot_step;
   
   if(lot_size < min_lot) lot_size = min_lot;
   if(lot_size > max_lot) lot_size = max_lot;
   
   Print("Calculated Lot Size: ", lot_size, " (Risk: $", Risk_Amount_Per_Trade, ", SL: ", stop_loss_points, " pts)");
   
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
      ObjectSetString(0, entry_name, OBJPROP_TEXT, "Entry: " + DoubleToString(zone.entry_price, _Digits));
   }
   
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
         ObjectSetString(0, tp1_name, OBJPROP_TEXT, StringFormat("TP1 (%.1fR): %.5f [%g%%]", RR_Level_1, zone.tp1_price, RR_Close_Percent_1));
      }
      
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
      }
   }
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
void UpdateFVGStatus()
{
   // Placeholder for FVG updates (not essential for EA trading functionality)
   // Can be implemented later if needed
}

//+------------------------------------------------------------------+
void CreateFVG(datetime start_time, double top, double bottom, bool is_bullish, int bar_index)
{
   // Placeholder for FVG creation (not essential for EA trading functionality)
}

//+------------------------------------------------------------------+
void DrawFVGRectangle(int index)
{
   // Placeholder for FVG drawing (not essential for EA trading functionality)
}

//+------------------------------------------------------------------+
void LoadNewsSettings()
{
   // Placeholder for news settings (not essential for EA trading functionality)
}

//+------------------------------------------------------------------+
void AddNewsTime(int &count, string curr, int day, int hour, int min, int impact, string name)
{
   // Placeholder
}

//+------------------------------------------------------------------+
bool IsNewsTime(datetime check_time)
{
   return false;
}
//+------------------------------------------------------------------+
