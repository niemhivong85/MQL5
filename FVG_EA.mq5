//+------------------------------------------------------------------+
//|                                                       FVG_EA.mq5 |
//|                              FVG Trading Expert Advisor          |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025"
#property version   "2.00"
#property strict

#include <Trade\Trade.mqh>

CTrade trade;

//--- Input parameters
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

input group    "=== Risk Management ==="
input double   Risk_Percent = 2.0;              // % tài khoản rủi ro
input double   Fixed_Risk_Amount = 0;           // Hoặc số tiền cố định (0=dùng %)
input bool     Auto_Calculate_Lot = true;
input double   Manual_Lot_Size = 0.01;
input int      Magic_Number = 789456;
input int      Max_Slippage = 10;
input int      Max_Open_Trades = 1;

input group    "=== Take Profit Settings ==="
input bool     Use_EMA_Exit = true;
input int      EMA_Period = 20;
input ENUM_TIMEFRAMES EMA_Timeframe = PERIOD_CURRENT;
input bool     Use_RR_Exit = true;
input double   RR_Level_1 = 1.0;
input double   RR_Close_Percent_1 = 50.0;
input double   RR_Level_2 = 2.0;
input double   RR_Close_Percent_2 = 30.0;
input double   RR_Level_3 = 3.0;
input double   RR_Close_Percent_3 = 20.0;

input group    "=== Trading Control ==="
input bool     Auto_Trade_Enabled = true;       // BẬT/TẮT tự động giao dịch
input bool     Close_Opposite_Trades = true;
input bool     Enable_News_Filter = false;

input group    "=== Display Colors ==="
input color    Buy_Zone_Color = clrDodgerBlue;
input color    Sell_Zone_Color = clrOrangeRed;
input color    Button_Buy_Color = clrLimeGreen;
input color    Button_Sell_Color = clrRed;
input color    Button_Confirm_Color = clrGold;
input color    Button_Edit_Color = clrOrange;
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
   bool     is_active;
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
   int      sweep_bar_index;
   double   sweep_low;
   double   sweep_high;
   double   stop_loss_price;
   double   entry_price;
   double   lot_size;
   double   tp1_price;
   double   tp2_price;
   double   tp3_price;
   ulong    ticket;
   double   original_lot;
   bool     tp1_hit;
   bool     tp2_hit;
};

//--- Global variables
FVG_Structure FVG_Array[];
int FVG_Count = 0;

TradingZone buy_zone;
TradingZone sell_zone;

int ema_handle = INVALID_HANDLE;
double ema_buffer[];

datetime last_bar_time = 0;

// Button names
string btn_buy = "BTN_BUY";
string btn_sell = "BTN_SELL";
string btn_confirm = "BTN_CONFIRM";
string btn_edit = "BTN_EDIT";

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("=================================================");
   Print("      FVG EXPERT ADVISOR STARTING");
   Print("=================================================");
   
   // Setup trade object
   trade.SetExpertMagicNumber(Magic_Number);
   trade.SetDeviationInPoints(Max_Slippage);
   trade.SetTypeFilling(ORDER_FILLING_FOK);
   trade.SetAsyncMode(false);
   
   // Clear all objects
   DeleteAllObjects();
   
   // Initialize arrays
   ArrayResize(FVG_Array, 0);
   FVG_Count = 0;
   
   // Initialize buy zone
   buy_zone.is_active = false;
   buy_zone.is_locked = false;
   buy_zone.is_buy_zone = true;
   buy_zone.rect_name = "ZONE_BUY";
   buy_zone.signal_triggered = false;
   buy_zone.ticket = 0;
   buy_zone.tp1_hit = false;
   buy_zone.tp2_hit = false;
   
   // Initialize sell zone
   sell_zone.is_active = false;
   sell_zone.is_locked = false;
   sell_zone.is_buy_zone = false;
   sell_zone.rect_name = "ZONE_SELL";
   sell_zone.signal_triggered = false;
   sell_zone.ticket = 0;
   sell_zone.tp1_hit = false;
   sell_zone.tp2_hit = false;
   
   // Initialize EMA
   if(Use_EMA_Exit)
   {
      ema_handle = iMA(_Symbol, EMA_Timeframe, EMA_Period, 0, MODE_EMA, PRICE_CLOSE);
      if(ema_handle == INVALID_HANDLE)
      {
         Print("❌ ERROR: Failed to create EMA indicator");
         return(INIT_FAILED);
      }
      ArraySetAsSeries(ema_buffer, true);
   }
   
   // Create control buttons
   CreateButtons();
   ChartRedraw();
   
   Print("✅ EA Initialized Successfully!");
   Print("Auto Trading: ", Auto_Trade_Enabled ? "ENABLED ✅" : "DISABLED ❌");
   Print("Risk per trade: ", Risk_Percent, "%");
   Print("Magic Number: ", Magic_Number);
   Print("=================================================");
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(ema_handle != INVALID_HANDLE)
      IndicatorRelease(ema_handle);
   
   DeleteAllObjects();
   
   Print("=================================================");
   Print("      FVG EA STOPPED");
   Print("=================================================");
}

//+------------------------------------------------------------------+
//| Expert tick function (MAIN TRADING LOGIC)                        |
//+------------------------------------------------------------------+
void OnTick()
{
   // Check for new bar
   datetime current_bar_time = iTime(_Symbol, PERIOD_CURRENT, 0);
   bool new_bar = (current_bar_time != last_bar_time);
   
   if(new_bar)
   {
      last_bar_time = current_bar_time;
      
      // Detect and update FVGs
      DetectFVGs();
      UpdateFVGStatus();
      
      // Update zones
      if(buy_zone.is_active && buy_zone.is_locked)
         UpdateZoneMitigation(buy_zone);
      
      if(sell_zone.is_active && sell_zone.is_locked)
         UpdateZoneMitigation(sell_zone);
   }
   
   // Check for trading signals (every tick)
   if(Auto_Trade_Enabled)
   {
      CheckForSignals();
   }
   
   // Manage open positions (every tick)
   ManageOpenPositions();
}

//+------------------------------------------------------------------+
//| Detect FVG patterns                                              |
//+------------------------------------------------------------------+
void DetectFVGs()
{
   datetime time[];
   double open[], high[], low[], close[];
   
   ArraySetAsSeries(time, true);
   ArraySetAsSeries(open, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);
   
   int copied = CopyTime(_Symbol, PERIOD_CURRENT, 0, 100, time);
   if(copied <= 0) return;
   
   CopyOpen(_Symbol, PERIOD_CURRENT, 0, 100, open);
   CopyHigh(_Symbol, PERIOD_CURRENT, 0, 100, high);
   CopyLow(_Symbol, PERIOD_CURRENT, 0, 100, low);
   CopyClose(_Symbol, PERIOD_CURRENT, 0, 100, close);
   
   for(int i = 3; i < 50 && i < copied - 2; i++)
   {
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
                     FVG_Array[j].is_bullish)
                  {
                     exists = true;
                     break;
                  }
               }
               if(!exists)
                  CreateFVG(time[i+2], gap_top, gap_bottom, true);
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
                     !FVG_Array[j].is_bullish)
                  {
                     exists = true;
                     break;
                  }
               }
               if(!exists)
                  CreateFVG(time[i+2], gap_top, gap_bottom, false);
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Check for trading signals and place orders                       |
//+------------------------------------------------------------------+
void CheckForSignals()
{
   // Check if max trades reached
   int open_trades = CountOpenTrades();
   if(open_trades >= Max_Open_Trades)
      return;
   
   // Check BUY signal
   if(buy_zone.is_active && buy_zone.is_locked && !buy_zone.signal_triggered && buy_zone.ticket == 0)
   {
      if(CheckSweepAndPattern(true))
      {
         buy_zone.signal_triggered = true;
         
         // Calculate entry and stops
         CalculateStopLoss(buy_zone);
         buy_zone.entry_price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         
         double sl_points = MathAbs(buy_zone.entry_price - buy_zone.stop_loss_price) / _Point;
         buy_zone.lot_size = CalculateLotSize(sl_points);
         
         // Calculate TPs
         double risk_distance = buy_zone.entry_price - buy_zone.stop_loss_price;
         buy_zone.tp1_price = buy_zone.entry_price + (risk_distance * RR_Level_1);
         buy_zone.tp2_price = buy_zone.entry_price + (risk_distance * RR_Level_2);
         buy_zone.tp3_price = buy_zone.entry_price + (risk_distance * RR_Level_3);
         buy_zone.original_lot = buy_zone.lot_size;
         
         DrawTradeLevels(buy_zone);
         
         // Send alert
         string msg = StringFormat("🔵 BUY SIGNAL!\nEntry: %.5f | SL: %.5f (%.0f pts)\nLot: %.2f | TP1: %.5f | TP2: %.5f | TP3: %.5f",
                                   buy_zone.entry_price, buy_zone.stop_loss_price, sl_points,
                                   buy_zone.lot_size, buy_zone.tp1_price, buy_zone.tp2_price, buy_zone.tp3_price);
         SendAlert(msg);
         
         // Place order
         if(Close_Opposite_Trades)
            CloseOppositeTrades(true);
         
         OpenBuyOrder(buy_zone);
      }
   }
   
   // Check SELL signal
   if(sell_zone.is_active && sell_zone.is_locked && !sell_zone.signal_triggered && sell_zone.ticket == 0)
   {
      if(CheckSweepAndPattern(false))
      {
         sell_zone.signal_triggered = true;
         
         // Calculate entry and stops
         CalculateStopLoss(sell_zone);
         sell_zone.entry_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         
         double sl_points = MathAbs(sell_zone.stop_loss_price - sell_zone.entry_price) / _Point;
         sell_zone.lot_size = CalculateLotSize(sl_points);
         
         // Calculate TPs
         double risk_distance = sell_zone.stop_loss_price - sell_zone.entry_price;
         sell_zone.tp1_price = sell_zone.entry_price - (risk_distance * RR_Level_1);
         sell_zone.tp2_price = sell_zone.entry_price - (risk_distance * RR_Level_2);
         sell_zone.tp3_price = sell_zone.entry_price - (risk_distance * RR_Level_3);
         sell_zone.original_lot = sell_zone.lot_size;
         
         DrawTradeLevels(sell_zone);
         
         // Send alert
         string msg = StringFormat("🔴 SELL SIGNAL!\nEntry: %.5f | SL: %.5f (%.0f pts)\nLot: %.2f | TP1: %.5f | TP2: %.5f | TP3: %.5f",
                                   sell_zone.entry_price, sell_zone.stop_loss_price, sl_points,
                                   sell_zone.lot_size, sell_zone.tp1_price, sell_zone.tp2_price, sell_zone.tp3_price);
         SendAlert(msg);
         
         // Place order
         if(Close_Opposite_Trades)
            CloseOppositeTrades(false);
         
         OpenSellOrder(sell_zone);
      }
   }
}

//+------------------------------------------------------------------+
//| Open BUY order                                                   |
//+------------------------------------------------------------------+
void OpenBuyOrder(TradingZone &zone)
{
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double sl = zone.stop_loss_price;
   double tp = zone.tp3_price;
   
   if(trade.Buy(zone.lot_size, _Symbol, ask, sl, tp, "FVG Buy"))
   {
      zone.ticket = trade.ResultOrder();
      zone.tp1_hit = false;
      zone.tp2_hit = false;
      
      Print("✅ BUY ORDER OPENED!");
      Print("   Ticket: #", zone.ticket);
      Print("   Lot: ", zone.lot_size);
      Print("   Entry: ", ask);
      Print("   SL: ", sl);
      Print("   TP: ", tp);
   }
   else
   {
      Print("❌ BUY ORDER FAILED!");
      Print("   Error: ", trade.ResultRetcodeDescription());
      zone.signal_triggered = false;
   }
}

//+------------------------------------------------------------------+
//| Open SELL order                                                  |
//+------------------------------------------------------------------+
void OpenSellOrder(TradingZone &zone)
{
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double sl = zone.stop_loss_price;
   double tp = zone.tp3_price;
   
   if(trade.Sell(zone.lot_size, _Symbol, bid, sl, tp, "FVG Sell"))
   {
      zone.ticket = trade.ResultOrder();
      zone.tp1_hit = false;
      zone.tp2_hit = false;
      
      Print("✅ SELL ORDER OPENED!");
      Print("   Ticket: #", zone.ticket);
      Print("   Lot: ", zone.lot_size);
      Print("   Entry: ", bid);
      Print("   SL: ", sl);
      Print("   TP: ", tp);
   }
   else
   {
      Print("❌ SELL ORDER FAILED!");
      Print("   Error: ", trade.ResultRetcodeDescription());
      zone.signal_triggered = false;
   }
}

//+------------------------------------------------------------------+
//| Manage open positions                                            |
//+------------------------------------------------------------------+
void ManageOpenPositions()
{
   // Manage buy position
   if(buy_zone.ticket > 0 && PositionSelectByTicket(buy_zone.ticket))
   {
      double current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double position_volume = PositionGetDouble(POSITION_VOLUME);
      
      // Check TP levels
      if(Use_RR_Exit)
      {
         // TP1
         if(!buy_zone.tp1_hit && current_price >= buy_zone.tp1_price)
         {
            double close_vol = NormalizeDouble(buy_zone.original_lot * RR_Close_Percent_1 / 100.0, 2);
            if(close_vol > 0 && close_vol <= position_volume)
            {
               if(trade.PositionClosePartial(buy_zone.ticket, close_vol))
               {
                  buy_zone.tp1_hit = true;
                  Print("✅ TP1 HIT - Closed ", RR_Close_Percent_1, "%");
                  SendAlert(StringFormat("TP1 Hit @ %.5f - Closed %.0f%%", current_price, RR_Close_Percent_1));
               }
            }
         }
         
         // TP2
         if(buy_zone.tp1_hit && !buy_zone.tp2_hit && current_price >= buy_zone.tp2_price)
         {
            double close_vol = NormalizeDouble(buy_zone.original_lot * RR_Close_Percent_2 / 100.0, 2);
            if(close_vol > 0 && close_vol <= position_volume)
            {
               if(trade.PositionClosePartial(buy_zone.ticket, close_vol))
               {
                  buy_zone.tp2_hit = true;
                  Print("✅ TP2 HIT - Closed ", RR_Close_Percent_2, "%");
                  SendAlert(StringFormat("TP2 Hit @ %.5f - Closed %.0f%%", current_price, RR_Close_Percent_2));
               }
            }
         }
      }
      
      // Check EMA exit
      if(Use_EMA_Exit && CheckEMAExit(true))
      {
         if(trade.PositionClose(buy_zone.ticket))
         {
            Print("✅ BUY position closed by EMA");
            SendAlert("BUY closed by EMA exit");
            buy_zone.ticket = 0;
         }
      }
   }
   else if(buy_zone.ticket > 0)
   {
      // Position closed
      buy_zone.ticket = 0;
   }
   
   // Manage sell position
   if(sell_zone.ticket > 0 && PositionSelectByTicket(sell_zone.ticket))
   {
      double current_price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double position_volume = PositionGetDouble(POSITION_VOLUME);
      
      // Check TP levels
      if(Use_RR_Exit)
      {
         // TP1
         if(!sell_zone.tp1_hit && current_price <= sell_zone.tp1_price)
         {
            double close_vol = NormalizeDouble(sell_zone.original_lot * RR_Close_Percent_1 / 100.0, 2);
            if(close_vol > 0 && close_vol <= position_volume)
            {
               if(trade.PositionClosePartial(sell_zone.ticket, close_vol))
               {
                  sell_zone.tp1_hit = true;
                  Print("✅ TP1 HIT - Closed ", RR_Close_Percent_1, "%");
                  SendAlert(StringFormat("TP1 Hit @ %.5f - Closed %.0f%%", current_price, RR_Close_Percent_1));
               }
            }
         }
         
         // TP2
         if(sell_zone.tp1_hit && !sell_zone.tp2_hit && current_price <= sell_zone.tp2_price)
         {
            double close_vol = NormalizeDouble(sell_zone.original_lot * RR_Close_Percent_2 / 100.0, 2);
            if(close_vol > 0 && close_vol <= position_volume)
            {
               if(trade.PositionClosePartial(sell_zone.ticket, close_vol))
               {
                  sell_zone.tp2_hit = true;
                  Print("✅ TP2 HIT - Closed ", RR_Close_Percent_2, "%");
                  SendAlert(StringFormat("TP2 Hit @ %.5f - Closed %.0f%%", current_price, RR_Close_Percent_2));
               }
            }
         }
      }
      
      // Check EMA exit
      if(Use_EMA_Exit && CheckEMAExit(false))
      {
         if(trade.PositionClose(sell_zone.ticket))
         {
            Print("✅ SELL position closed by EMA");
            SendAlert("SELL closed by EMA exit");
            sell_zone.ticket = 0;
         }
      }
   }
   else if(sell_zone.ticket > 0)
   {
      // Position closed
      sell_zone.ticket = 0;
   }
}

//+------------------------------------------------------------------+
//| Count open trades                                                |
//+------------------------------------------------------------------+
int CountOpenTrades()
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
//| Close opposite trades                                            |
//+------------------------------------------------------------------+
void CloseOppositeTrades(bool is_buy_signal)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == Magic_Number)
      {
         ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         
         if((is_buy_signal && pos_type == POSITION_TYPE_SELL) || 
            (!is_buy_signal && pos_type == POSITION_TYPE_BUY))
         {
            ulong ticket = PositionGetInteger(POSITION_TICKET);
            trade.PositionClose(ticket);
            Print("Closed opposite position: ", ticket);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Chart event handler                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   if(id == CHARTEVENT_OBJECT_CLICK)
   {
      if(sparam == btn_buy)
      {
         CreateTradingZone(true);
         ObjectSetInteger(0, btn_buy, OBJPROP_STATE, false);
      }
      else if(sparam == btn_sell)
      {
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
//| Helper Functions                                                 |
//+------------------------------------------------------------------+

void CreateButtons()
{
   int x = 20, y = 30, w = 80, h = 30, sp = 10;
   
   ObjectCreate(0, btn_buy, OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, btn_buy, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, btn_buy, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, btn_buy, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, btn_buy, OBJPROP_YSIZE, h);
   ObjectSetString(0, btn_buy, OBJPROP_TEXT, "MUA");
   ObjectSetInteger(0, btn_buy, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btn_buy, OBJPROP_BGCOLOR, Button_Buy_Color);
   ObjectSetInteger(0, btn_buy, OBJPROP_FONTSIZE, 10);
   
   ObjectCreate(0, btn_sell, OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, btn_sell, OBJPROP_XDISTANCE, x + w + sp);
   ObjectSetInteger(0, btn_sell, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, btn_sell, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, btn_sell, OBJPROP_YSIZE, h);
   ObjectSetString(0, btn_sell, OBJPROP_TEXT, "BÁN");
   ObjectSetInteger(0, btn_sell, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btn_sell, OBJPROP_BGCOLOR, Button_Sell_Color);
   ObjectSetInteger(0, btn_sell, OBJPROP_FONTSIZE, 10);
   
   ObjectCreate(0, btn_confirm, OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, btn_confirm, OBJPROP_XDISTANCE, x + (w + sp) * 2);
   ObjectSetInteger(0, btn_confirm, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, btn_confirm, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, btn_confirm, OBJPROP_YSIZE, h);
   ObjectSetString(0, btn_confirm, OBJPROP_TEXT, "XÁC NHẬN");
   ObjectSetInteger(0, btn_confirm, OBJPROP_COLOR, clrBlack);
   ObjectSetInteger(0, btn_confirm, OBJPROP_BGCOLOR, Button_Confirm_Color);
   ObjectSetInteger(0, btn_confirm, OBJPROP_FONTSIZE, 9);
   
   ObjectCreate(0, btn_edit, OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, btn_edit, OBJPROP_XDISTANCE, x + (w + sp) * 3);
   ObjectSetInteger(0, btn_edit, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, btn_edit, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, btn_edit, OBJPROP_YSIZE, h);
   ObjectSetString(0, btn_edit, OBJPROP_TEXT, "SỬA");
   ObjectSetInteger(0, btn_edit, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btn_edit, OBJPROP_BGCOLOR, Button_Edit_Color);
   ObjectSetInteger(0, btn_edit, OBJPROP_FONTSIZE, 10);
}

void CreateTradingZone(bool is_buy)
{
   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   if(is_buy)
   {
      buy_zone.top = price - 100 * _Point;
      buy_zone.bottom = price - 300 * _Point;
      buy_zone.original_top = buy_zone.top;
      buy_zone.original_bottom = buy_zone.bottom;
      buy_zone.is_active = true;
      buy_zone.is_locked = false;
      buy_zone.signal_triggered = false;
      buy_zone.ticket = 0;
      DrawTradingZone(buy_zone);
      Print("✅ Buy zone created");
   }
   else
   {
      sell_zone.top = price + 300 * _Point;
      sell_zone.bottom = price + 100 * _Point;
      sell_zone.original_top = sell_zone.top;
      sell_zone.original_bottom = sell_zone.bottom;
      sell_zone.is_active = true;
      sell_zone.is_locked = false;
      sell_zone.signal_triggered = false;
      sell_zone.ticket = 0;
      DrawTradingZone(sell_zone);
      Print("✅ Sell zone created");
   }
}

void DrawTradingZone(TradingZone &zone)
{
   if(ObjectFind(0, zone.rect_name) >= 0)
      ObjectDelete(0, zone.rect_name);
   
   datetime t1 = iTime(_Symbol, PERIOD_CURRENT, 50);
   datetime t2 = TimeCurrent() + PeriodSeconds() * 500;
   
   ObjectCreate(0, zone.rect_name, OBJ_RECTANGLE, 0, t1, zone.top, t2, zone.bottom);
   
   color c = zone.is_buy_zone ? Buy_Zone_Color : Sell_Zone_Color;
   ObjectSetInteger(0, zone.rect_name, OBJPROP_COLOR, c);
   ObjectSetInteger(0, zone.rect_name, OBJPROP_FILL, true);
   ObjectSetInteger(0, zone.rect_name, OBJPROP_BACK, false);
   ObjectSetInteger(0, zone.rect_name, OBJPROP_SELECTABLE, !zone.is_locked);
   ObjectSetInteger(0, zone.rect_name, OBJPROP_WIDTH, Zone_Border_Width);
   
   int r = (int)(c & 0xFF);
   int g = (int)((c >> 8) & 0xFF);
   int b = (int)((c >> 16) & 0xFF);
   int alpha = (int)((100 - Zone_Transparency) * 2.55);
   r = r + (255 - r) * (255 - alpha) / 255;
   g = g + (255 - g) * (255 - alpha) / 255;
   b = b + (255 - b) * (255 - alpha) / 255;
   color bg = (color)((b << 16) | (g << 8) | r);
   ObjectSetInteger(0, zone.rect_name, OBJPROP_BGCOLOR, bg);
   
   ChartRedraw();
}

void LockTradingZones()
{
   if(buy_zone.is_active)
   {
      buy_zone.is_locked = true;
      ObjectSetInteger(0, buy_zone.rect_name, OBJPROP_SELECTABLE, false);
      Print("Buy zone LOCKED ✅");
   }
   
   if(sell_zone.is_active)
   {
      sell_zone.is_locked = true;
      ObjectSetInteger(0, sell_zone.rect_name, OBJPROP_SELECTABLE, false);
      Print("Sell zone LOCKED ✅");
   }
   
   Alert("Trading zones locked - Ready for auto trading!");
}

void UnlockTradingZones()
{
   if(buy_zone.is_active)
   {
      buy_zone.is_locked = false;
      buy_zone.signal_triggered = false;
      buy_zone.ticket = 0;
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
      sell_zone.ticket = 0;
      ObjectSetInteger(0, sell_zone.rect_name, OBJPROP_SELECTABLE, true);
      ObjectDelete(0, "SELL_SL_LINE");
      ObjectDelete(0, "SELL_TP1_LINE");
      ObjectDelete(0, "SELL_TP2_LINE");
      ObjectDelete(0, "SELL_TP3_LINE");
      ObjectDelete(0, "SELL_ENTRY_LINE");
   }
   
   ChartRedraw();
   Print("Zones UNLOCKED for editing");
}

bool CheckSweepAndPattern(bool is_buy)
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
      bool in_zone = false;
      
      if(is_buy)
      {
         if(low[i] <= buy_zone.top && low[i] >= buy_zone.bottom)
            in_zone = true;
      }
      else
      {
         if(high[i] >= sell_zone.bottom && high[i] <= sell_zone.top)
            in_zone = true;
      }
      
      if(!in_zone) continue;
      
      if(IsSweepCandle(i, is_buy))
      {
         if(is_buy)
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

bool IsSweepCandle(int idx, bool for_buy)
{
   double open[], high[], low[], close[];
   ArraySetAsSeries(open, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);
   
   CopyOpen(_Symbol, PERIOD_CURRENT, 0, idx + 2, open);
   CopyHigh(_Symbol, PERIOD_CURRENT, 0, idx + 2, high);
   CopyLow(_Symbol, PERIOD_CURRENT, 0, idx + 2, low);
   CopyClose(_Symbol, PERIOD_CURRENT, 0, idx + 2, close);
   
   if(idx + 1 >= ArraySize(open)) return false;
   
   if(for_buy)
   {
      if(low[idx] >= low[idx + 1]) return false;
      bool bearish = close[idx] < open[idx];
      if(bearish)
         return (close[idx] >= close[idx + 1]);
      else
         return (close[idx] >= open[idx + 1]);
   }
   else
   {
      if(high[idx] <= high[idx + 1]) return false;
      bool bullish = close[idx] > open[idx];
      if(bullish)
         return (close[idx] <= close[idx + 1]);
      else
         return (close[idx] <= open[idx + 1]);
   }
}

bool IsBottomFormation(int sweep_idx)
{
   double open[], high[], low[], close[];
   ArraySetAsSeries(open, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);
   
   int needed = sweep_idx + Sweep_Candles_Count + 1;
   CopyOpen(_Symbol, PERIOD_CURRENT, 0, needed, open);
   CopyHigh(_Symbol, PERIOD_CURRENT, 0, needed, high);
   CopyLow(_Symbol, PERIOD_CURRENT, 0, needed, low);
   CopyClose(_Symbol, PERIOD_CURRENT, 0, needed, close);
   
   int end = MathMax(0, sweep_idx - (Sweep_Candles_Count - 1));
   
   for(int i = sweep_idx; i >= end; i--)
   {
      if(i + 1 >= ArraySize(close)) continue;
      if(close[i] > high[i + 1]) return true;
   }
   
   return false;
}

bool IsTopFormation(int sweep_idx)
{
   double open[], high[], low[], close[];
   ArraySetAsSeries(open, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);
   
   int needed = sweep_idx + Sweep_Candles_Count + 1;
   CopyOpen(_Symbol, PERIOD_CURRENT, 0, needed, open);
   CopyHigh(_Symbol, PERIOD_CURRENT, 0, needed, high);
   CopyLow(_Symbol, PERIOD_CURRENT, 0, needed, low);
   CopyClose(_Symbol, PERIOD_CURRENT, 0, needed, close);
   
   int end = MathMax(0, sweep_idx - (Sweep_Candles_Count - 1));
   
   for(int i = sweep_idx; i >= end; i--)
   {
      if(i + 1 >= ArraySize(close)) continue;
      if(close[i] < low[i + 1]) return true;
   }
   
   return false;
}

void CalculateStopLoss(TradingZone &zone)
{
   double high[], low[];
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   
   CopyHigh(_Symbol, PERIOD_CURRENT, 0, 20, high);
   CopyLow(_Symbol, PERIOD_CURRENT, 0, 20, low);
   
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

double CalculateLotSize(double sl_points)
{
   if(!Auto_Calculate_Lot)
      return Manual_Lot_Size;
   
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double risk_money = (Fixed_Risk_Amount > 0) ? Fixed_Risk_Amount : (balance * Risk_Percent / 100.0);
   
   double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double max_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lot_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   double point_value = (tick_size > 0) ? (tick_value * _Point / tick_size) : tick_value;
   
   double lot = 0;
   if(sl_points > 0 && point_value > 0)
      lot = risk_money / (sl_points * point_value);
   
   lot = MathFloor(lot / lot_step) * lot_step;
   
   if(lot < min_lot) lot = min_lot;
   if(lot > max_lot) lot = max_lot;
   
   return lot;
}

void DrawTradeLevels(TradingZone &zone)
{
   string prefix = zone.is_buy_zone ? "BUY_" : "SELL_";
   datetime t1 = iTime(_Symbol, PERIOD_CURRENT, 10);
   datetime t2 = TimeCurrent() + PeriodSeconds() * 100;
   
   ObjectDelete(0, prefix + "ENTRY_LINE");
   ObjectCreate(0, prefix + "ENTRY_LINE", OBJ_TREND, 0, t1, zone.entry_price, t2, zone.entry_price);
   ObjectSetInteger(0, prefix + "ENTRY_LINE", OBJPROP_COLOR, clrYellow);
   ObjectSetInteger(0, prefix + "ENTRY_LINE", OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, prefix + "ENTRY_LINE", OBJPROP_RAY_RIGHT, true);
   
   ObjectDelete(0, prefix + "SL_LINE");
   ObjectCreate(0, prefix + "SL_LINE", OBJ_TREND, 0, t1, zone.stop_loss_price, t2, zone.stop_loss_price);
   ObjectSetInteger(0, prefix + "SL_LINE", OBJPROP_COLOR, clrRed);
   ObjectSetInteger(0, prefix + "SL_LINE", OBJPROP_STYLE, STYLE_DOT);
   ObjectSetInteger(0, prefix + "SL_LINE", OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, prefix + "SL_LINE", OBJPROP_RAY_RIGHT, true);
   
   if(Use_RR_Exit)
   {
      ObjectDelete(0, prefix + "TP1_LINE");
      ObjectCreate(0, prefix + "TP1_LINE", OBJ_TREND, 0, t1, zone.tp1_price, t2, zone.tp1_price);
      ObjectSetInteger(0, prefix + "TP1_LINE", OBJPROP_COLOR, clrGreen);
      ObjectSetInteger(0, prefix + "TP1_LINE", OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, prefix + "TP1_LINE", OBJPROP_RAY_RIGHT, true);
      
      ObjectDelete(0, prefix + "TP2_LINE");
      ObjectCreate(0, prefix + "TP2_LINE", OBJ_TREND, 0, t1, zone.tp2_price, t2, zone.tp2_price);
      ObjectSetInteger(0, prefix + "TP2_LINE", OBJPROP_COLOR, clrGreen);
      ObjectSetInteger(0, prefix + "TP2_LINE", OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, prefix + "TP2_LINE", OBJPROP_RAY_RIGHT, true);
      
      ObjectDelete(0, prefix + "TP3_LINE");
      ObjectCreate(0, prefix + "TP3_LINE", OBJ_TREND, 0, t1, zone.tp3_price, t2, zone.tp3_price);
      ObjectSetInteger(0, prefix + "TP3_LINE", OBJPROP_COLOR, clrGreen);
      ObjectSetInteger(0, prefix + "TP3_LINE", OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, prefix + "TP3_LINE", OBJPROP_RAY_RIGHT, true);
   }
   
   ChartRedraw();
}

bool CheckEMAExit(bool is_buy)
{
   if(!Use_EMA_Exit || ema_handle == INVALID_HANDLE)
      return false;
   
   if(CopyBuffer(ema_handle, 0, 0, 3, ema_buffer) <= 0)
      return false;
   
   double close_price = iClose(_Symbol, PERIOD_CURRENT, 0);
   double ema = ema_buffer[0];
   
   if(is_buy)
      return (close_price < ema);
   else
      return (close_price > ema);
}

void SendAlert(string msg)
{
   if(Enable_Alert)
      Alert(msg);
   
   if(Enable_Sound)
      PlaySound(Alert_Sound);
   
   Print(msg);
}

void CreateFVG(datetime start_time, double top, double bottom, bool is_bullish)
{
   FVG_Count++;
   ArrayResize(FVG_Array, FVG_Count);
   
   int idx = FVG_Count - 1;
   FVG_Array[idx].time_start = start_time;
   FVG_Array[idx].time_end = TimeCurrent() + PeriodSeconds() * 500;
   FVG_Array[idx].top = top;
   FVG_Array[idx].bottom = bottom;
   FVG_Array[idx].original_top = top;
   FVG_Array[idx].original_bottom = bottom;
   FVG_Array[idx].is_bullish = is_bullish;
   FVG_Array[idx].is_active = true;
   FVG_Array[idx].rect_name = "FVG_" + TimeToString(start_time, TIME_DATE|TIME_SECONDS) + (is_bullish ? "_B" : "_S");
   
   DrawFVGRectangle(idx);
}

void DrawFVGRectangle(int idx)
{
   string name = FVG_Array[idx].rect_name;
   if(ObjectFind(0, name) >= 0) ObjectDelete(0, name);
   
   ObjectCreate(0, name, OBJ_RECTANGLE, 0, FVG_Array[idx].time_start, FVG_Array[idx].top, 
                FVG_Array[idx].time_end, FVG_Array[idx].bottom);
   
   color c = FVG_Array[idx].is_bullish ? Bullish_FVG_Color : Bearish_FVG_Color;
   ObjectSetInteger(0, name, OBJPROP_COLOR, c);
   ObjectSetInteger(0, name, OBJPROP_FILL, true);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   
   int r = (int)(c & 0xFF);
   int g = (int)((c >> 8) & 0xFF);
   int b = (int)((c >> 16) & 0xFF);
   int alpha = (int)((100 - FVG_Transparency) * 2.55);
   r = r + (255 - r) * (255 - alpha) / 255;
   g = g + (255 - g) * (255 - alpha) / 255;
   b = b + (255 - b) * (255 - alpha) / 255;
   color bg = (color)((b << 16) | (g << 8) | r);
   
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg);
}

void UpdateFVGStatus()
{
   datetime time[];
   double high[], low[], close[];
   
   ArraySetAsSeries(time, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);
   
   int copied = CopyTime(_Symbol, PERIOD_CURRENT, 0, 100, time);
   if(copied <= 0) return;
   
   CopyHigh(_Symbol, PERIOD_CURRENT, 0, 100, high);
   CopyLow(_Symbol, PERIOD_CURRENT, 0, 100, low);
   CopyClose(_Symbol, PERIOD_CURRENT, 0, 100, close);
   
   for(int i = 0; i < FVG_Count; i++)
   {
      if(!FVG_Array[i].is_active) continue;
      
      for(int bar = 0; bar < copied; bar++)
      {
         if(time[bar] <= FVG_Array[i].time_start) continue;
         
         bool modified = false;
         
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
               modified = true;
               
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
               modified = true;
               
               if(FVG_Array[i].top - FVG_Array[i].bottom < Min_FVG_Points * _Point)
               {
                  FVG_Array[i].is_active = false;
                  ObjectDelete(0, FVG_Array[i].rect_name);
                  break;
               }
            }
         }
         
         if(modified)
            DrawFVGRectangle(i);
      }
      
      if(FVG_Array[i].is_active)
      {
         FVG_Array[i].time_end = TimeCurrent() + PeriodSeconds() * 500;
         ObjectSetInteger(0, FVG_Array[i].rect_name, OBJPROP_TIME, 1, FVG_Array[i].time_end);
      }
   }
}

void UpdateZoneMitigation(TradingZone &zone)
{
   if(!zone.is_active || !zone.is_locked) return;
   
   double high[], low[], close[];
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);
   
   CopyHigh(_Symbol, PERIOD_CURRENT, 0, 5, high);
   CopyLow(_Symbol, PERIOD_CURRENT, 0, 5, low);
   CopyClose(_Symbol, PERIOD_CURRENT, 0, 5, close);
   
   for(int i = 0; i < 5; i++)
   {
      bool modified = false;
      
      if(zone.is_buy_zone)
      {
         if(Zone_Delete_On_Break && close[i] < zone.bottom)
         {
            zone.is_active = false;
            ObjectDelete(0, zone.rect_name);
            return;
         }
         
         if(Zone_Mitigate_On_Touch && low[i] < zone.top && low[i] > zone.bottom)
         {
            zone.top = low[i];
            modified = true;
            
            if(zone.top - zone.bottom < 10 * _Point)
            {
               zone.is_active = false;
               ObjectDelete(0, zone.rect_name);
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
            return;
         }
         
         if(Zone_Mitigate_On_Touch && high[i] > zone.bottom && high[i] < zone.top)
         {
            zone.bottom = high[i];
            modified = true;
            
            if(zone.top - zone.bottom < 10 * _Point)
            {
               zone.is_active = false;
               ObjectDelete(0, zone.rect_name);
               return;
            }
         }
      }
      
      if(modified)
         DrawTradingZone(zone);
   }
}

void DeleteAllObjects()
{
   for(int i = ObjectsTotal(0, 0, OBJ_RECTANGLE) - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i, 0, OBJ_RECTANGLE);
      if(StringFind(name, "FVG_") >= 0 || StringFind(name, "ZONE_") >= 0)
         ObjectDelete(0, name);
   }
   
   for(int i = ObjectsTotal(0, 0, OBJ_BUTTON) - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i, 0, OBJ_BUTTON);
      if(StringFind(name, "BTN_") >= 0)
         ObjectDelete(0, name);
   }
   
   for(int i = ObjectsTotal(0, 0, OBJ_TREND) - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i, 0, OBJ_TREND);
      if(StringFind(name, "BUY_") >= 0 || StringFind(name, "SELL_") >= 0)
         ObjectDelete(0, name);
   }
}
//+------------------------------------------------------------------+
