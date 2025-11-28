//+------------------------------------------------------------------+
//|                                                FVG_Auto_EA.mq5   |
//|                    Fair Value Gap Automatic Trading EA           |
//|                    Fully Automated - No Manual Zones             |
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
input group    "=== FVG Detection ==="
input int      FVG_LookBack = 500;
input int      Min_FVG_Points = 10;
input bool     Show_Bullish_FVG = true;
input bool     Show_Bearish_FVG = true;
input bool     Fill_On_Touch = true;
input bool     Delete_On_Break = true;
input color    Bullish_FVG_Color = clrGreen;
input color    Bearish_FVG_Color = clrRed;
input int      FVG_Transparency = 80;

//--- Input parameters - Trading Signals
input group    "=== Signal Detection ==="
input int      Sweep_Candles_Count = 5;       // Số nến sau sweep để tìm formation
input int      FVG_Zone_Lookback = 20;        // Tìm FVG trong N cây nến gần nhất
input bool     Trade_On_Bullish_FVG = true;   // Trade khi có FVG tăng
input bool     Trade_On_Bearish_FVG = true;   // Trade khi có FVG giảm

//--- Input parameters - Stop Loss
input group    "=== Stop Loss Settings ==="
input bool     SL_Use_Sweep_Low = true;
input int      SL_Buffer_Points = 5;
input int      Min_SL_Points = 50;
input int      Max_SL_Points = 500;

//--- Input parameters - Risk Management
input group    "=== Position Sizing ==="
input double   Risk_Percent_Per_Trade = 1.0;
input double   Risk_Amount_Per_Trade = 0;
input bool     Auto_Calculate_Lot = true;
input double   Manual_Lot_Size = 0.01;
input double   Max_Lot_Size = 10.0;

//--- Input parameters - Take Profit
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

//--- Input parameters - EA Control
input group    "=== EA Control ==="
input bool     EA_Enabled = true;
input bool     Trade_Buy_Signals = true;
input bool     Trade_Sell_Signals = true;
input bool     One_Trade_At_Time = true;
input int      Magic_Number = 123789;
input string   Trade_Comment = "FVG_Auto";

//--- Input parameters - Alerts
input group    "=== Alerts ==="
input bool     Enable_Alert = true;
input bool     Enable_Sound = true;
input string   Alert_Sound = "alert.wav";

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
   int      bar_index;
};

struct TradeSignal
{
   bool     is_valid;
   bool     is_buy;
   double   entry_price;
   double   stop_loss;
   double   tp1;
   double   tp2;
   double   tp3;
   double   lot_size;
   int      fvg_index;
   int      sweep_bar;
   double   sweep_low;
   double   sweep_high;
};

struct ActiveTrade
{
   ulong    ticket;
   bool     is_buy;
   double   initial_lot;
   double   remaining_lot;
   double   entry_price;
   double   stop_loss;
   double   tp1_price;
   double   tp2_price;
   double   tp3_price;
   bool     tp1_hit;
   bool     tp2_hit;
};

//--- Global variables
FVG_Structure FVG_Array[];
int FVG_Count = 0;

ActiveTrade active_trades[];
int active_trade_count = 0;

int ema_handle = INVALID_HANDLE;
double ema_buffer[];

datetime last_bar_time = 0;

//--- Forward declarations
void DetectFVGs();
void DrawFVGRectangle(int index);
void UpdateFVGStatus();
TradeSignal CheckForTradeSignal();
bool CheckSweepInFVG(int fvg_index, bool &sweep_bar_out, double &sweep_low_out, double &sweep_high_out);
bool IsSweepCandle(int index, bool check_for_buy);
bool IsBottomFormation(int sweep_index);
bool IsTopFormation(int sweep_index);
void ExecuteTrade(TradeSignal &signal);
void ManageActiveTrades();
void ClosePartialPosition(ulong ticket, double lot_to_close, string reason);
bool CheckEMAExit(bool is_buy_position);
double CalculateLotSize(double stop_loss_points);
double NormalizeLot(double lot);
void SendAlert(string message);
void DisplayInfo();
void DeleteAllObjects();
int FindActiveTradeByTicket(ulong ticket);
void RemoveActiveTrade(int index);

//+------------------------------------------------------------------+
int OnInit()
{
   Print("========================================");
   Print("  FVG AUTO EA v3.0 - FULLY AUTOMATED");
   Print("========================================");
   
   // Setup trade object
   trade.SetExpertMagicNumber(Magic_Number);
   trade.SetDeviationInPoints(10);
   trade.SetTypeFilling(ORDER_FILLING_FOK);
   trade.SetAsyncMode(false);
   
   DeleteAllObjects();
   ArrayResize(FVG_Array, 0);
   ArrayResize(active_trades, 0);
   FVG_Count = 0;
   active_trade_count = 0;
   
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
   
   Print("✅ FVG Auto EA initialized successfully");
   Print("   EA Status: ", EA_Enabled ? "ENABLED ✅" : "DISABLED ❌");
   Print("   Trade BUY: ", Trade_Buy_Signals ? "Yes" : "No");
   Print("   Trade SELL: ", Trade_Sell_Signals ? "Yes" : "No");
   Print("   Risk per trade: ", Risk_Percent_Per_Trade, "%");
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
   
   Print("FVG Auto EA stopped. Reason: ", reason);
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
      
      // Detect FVGs
      DetectFVGs();
      
      // Update FVG status
      UpdateFVGStatus();
      
      // Check for trade signals
      TradeSignal signal = CheckForTradeSignal();
      
      if(signal.is_valid)
      {
         // Check if we can open new trade
         if(One_Trade_At_Time)
         {
            bool has_same_direction = false;
            for(int i = 0; i < active_trade_count; i++)
            {
               if(active_trades[i].is_buy == signal.is_buy)
               {
                  has_same_direction = true;
                  break;
               }
            }
            
            if(has_same_direction)
            {
               Print("⏸️ Already have ", signal.is_buy ? "BUY" : "SELL", " position - skipping signal");
            }
            else
            {
               ExecuteTrade(signal);
            }
         }
         else
         {
            ExecuteTrade(signal);
         }
      }
   }
   
   // Manage active trades (every tick)
   ManageActiveTrades();
   
   // Update display
   DisplayInfo();
}

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
   
   int copied = CopyTime(_Symbol, PERIOD_CURRENT, 0, MathMin(FVG_LookBack + 10, 1000), time);
   if(copied <= 0) return;
   
   CopyOpen(_Symbol, PERIOD_CURRENT, 0, copied, open);
   CopyHigh(_Symbol, PERIOD_CURRENT, 0, copied, high);
   CopyLow(_Symbol, PERIOD_CURRENT, 0, copied, low);
   CopyClose(_Symbol, PERIOD_CURRENT, 0, copied, close);
   
   int start_bar = MathMin(copied - 4, FVG_LookBack);
   
   for(int i = 3; i < start_bar; i++)
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
               {
                  FVG_Count++;
                  ArrayResize(FVG_Array, FVG_Count);
                  int idx = FVG_Count - 1;
                  
                  FVG_Array[idx].time_start = time[i+2];
                  FVG_Array[idx].time_end = TimeCurrent() + PeriodSeconds() * 500;
                  FVG_Array[idx].top = gap_top;
                  FVG_Array[idx].bottom = gap_bottom;
                  FVG_Array[idx].original_top = gap_top;
                  FVG_Array[idx].original_bottom = gap_bottom;
                  FVG_Array[idx].is_bullish = true;
                  FVG_Array[idx].is_active = true;
                  FVG_Array[idx].bar_index = i+2;
                  FVG_Array[idx].rect_name = "FVG_" + TimeToString(time[i+2], TIME_DATE|TIME_SECONDS) + "_Bull";
                  
                  DrawFVGRectangle(idx);
               }
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
               {
                  FVG_Count++;
                  ArrayResize(FVG_Array, FVG_Count);
                  int idx = FVG_Count - 1;
                  
                  FVG_Array[idx].time_start = time[i+2];
                  FVG_Array[idx].time_end = TimeCurrent() + PeriodSeconds() * 500;
                  FVG_Array[idx].top = gap_top;
                  FVG_Array[idx].bottom = gap_bottom;
                  FVG_Array[idx].original_top = gap_top;
                  FVG_Array[idx].original_bottom = gap_bottom;
                  FVG_Array[idx].is_bullish = false;
                  FVG_Array[idx].is_active = true;
                  FVG_Array[idx].bar_index = i+2;
                  FVG_Array[idx].rect_name = "FVG_" + TimeToString(time[i+2], TIME_DATE|TIME_SECONDS) + "_Bear";
                  
                  DrawFVGRectangle(idx);
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
TradeSignal CheckForTradeSignal()
{
   TradeSignal signal;
   signal.is_valid = false;
   
   // Check most recent FVGs
   for(int i = 0; i < FVG_Count && i < FVG_Zone_Lookback; i++)
   {
      if(!FVG_Array[i].is_active)
         continue;
      
      // Check for BUY signal (bullish FVG)
      if(FVG_Array[i].is_bullish && Trade_Buy_Signals)
      {
         int sweep_bar;
         double sweep_low, sweep_high;
         
         if(CheckSweepInFVG(i, sweep_bar, sweep_low, sweep_high))
         {
            if(IsBottomFormation(sweep_bar))
            {
               signal.is_valid = true;
               signal.is_buy = true;
               signal.entry_price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
               
               // Calculate SL
               if(SL_Use_Sweep_Low)
                  signal.stop_loss = sweep_low - (SL_Buffer_Points * _Point);
               else
                  signal.stop_loss = FVG_Array[i].bottom - (SL_Buffer_Points * _Point);
               
               // Validate SL
               double sl_points = MathAbs(signal.entry_price - signal.stop_loss) / _Point;
               if(sl_points < Min_SL_Points)
               {
                  signal.stop_loss = signal.entry_price - Min_SL_Points * _Point;
                  sl_points = Min_SL_Points;
               }
               if(sl_points > Max_SL_Points)
               {
                  signal.stop_loss = signal.entry_price - Max_SL_Points * _Point;
                  sl_points = Max_SL_Points;
               }
               
               signal.lot_size = CalculateLotSize(sl_points);
               
               // Calculate TPs
               double risk = signal.entry_price - signal.stop_loss;
               signal.tp1 = signal.entry_price + (risk * RR_Level_1);
               signal.tp2 = signal.entry_price + (risk * RR_Level_2);
               signal.tp3 = signal.entry_price + (risk * RR_Level_3);
               
               signal.fvg_index = i;
               signal.sweep_bar = sweep_bar;
               signal.sweep_low = sweep_low;
               signal.sweep_high = sweep_high;
               
               Print("🔵 BUY SIGNAL DETECTED!");
               Print("   FVG: ", FVG_Array[i].bottom, " - ", FVG_Array[i].top);
               Print("   Entry: ", signal.entry_price);
               Print("   SL: ", signal.stop_loss, " (", sl_points, " pts)");
               Print("   Lot: ", signal.lot_size);
               
               return signal;
            }
         }
      }
      
      // Check for SELL signal (bearish FVG)
      if(!FVG_Array[i].is_bullish && Trade_Sell_Signals)
      {
         int sweep_bar;
         double sweep_low, sweep_high;
         
         if(CheckSweepInFVG(i, sweep_bar, sweep_low, sweep_high))
         {
            if(IsTopFormation(sweep_bar))
            {
               signal.is_valid = true;
               signal.is_buy = false;
               signal.entry_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
               
               // Calculate SL
               if(SL_Use_Sweep_Low)
                  signal.stop_loss = sweep_high + (SL_Buffer_Points * _Point);
               else
                  signal.stop_loss = FVG_Array[i].top + (SL_Buffer_Points * _Point);
               
               // Validate SL
               double sl_points = MathAbs(signal.stop_loss - signal.entry_price) / _Point;
               if(sl_points < Min_SL_Points)
               {
                  signal.stop_loss = signal.entry_price + Min_SL_Points * _Point;
                  sl_points = Min_SL_Points;
               }
               if(sl_points > Max_SL_Points)
               {
                  signal.stop_loss = signal.entry_price + Max_SL_Points * _Point;
                  sl_points = Max_SL_Points;
               }
               
               signal.lot_size = CalculateLotSize(sl_points);
               
               // Calculate TPs
               double risk = signal.stop_loss - signal.entry_price;
               signal.tp1 = signal.entry_price - (risk * RR_Level_1);
               signal.tp2 = signal.entry_price - (risk * RR_Level_2);
               signal.tp3 = signal.entry_price - (risk * RR_Level_3);
               
               signal.fvg_index = i;
               signal.sweep_bar = sweep_bar;
               signal.sweep_low = sweep_low;
               signal.sweep_high = sweep_high;
               
               Print("🔴 SELL SIGNAL DETECTED!");
               Print("   FVG: ", FVG_Array[i].bottom, " - ", FVG_Array[i].top);
               Print("   Entry: ", signal.entry_price);
               Print("   SL: ", signal.stop_loss, " (", sl_points, " pts)");
               Print("   Lot: ", signal.lot_size);
               
               return signal;
            }
         }
      }
   }
   
   return signal;
}

//+------------------------------------------------------------------+
bool CheckSweepInFVG(int fvg_index, bool &sweep_bar_out, double &sweep_low_out, double &sweep_high_out)
{
   double high[], low[];
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   
   CopyHigh(_Symbol, PERIOD_CURRENT, 0, 20, high);
   CopyLow(_Symbol, PERIOD_CURRENT, 0, 20, low);
   
   for(int i = 1; i < 10; i++)
   {
      bool price_in_fvg = false;
      
      if(FVG_Array[fvg_index].is_bullish)
      {
         if(low[i] <= FVG_Array[fvg_index].top && low[i] >= FVG_Array[fvg_index].bottom)
            price_in_fvg = true;
      }
      else
      {
         if(high[i] >= FVG_Array[fvg_index].bottom && high[i] <= FVG_Array[fvg_index].top)
            price_in_fvg = true;
      }
      
      if(!price_in_fvg)
         continue;
      
      if(IsSweepCandle(i, FVG_Array[fvg_index].is_bullish))
      {
         sweep_bar_out = i;
         sweep_low_out = low[i];
         sweep_high_out = high[i];
         return true;
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
         return (close[index] >= close[index + 1]);
      else
         return (close[index] >= open[index + 1]);
   }
   else
   {
      if(high[index] <= high[index + 1])
         return false;
      
      bool is_bullish = close[index] > open[index];
      
      if(is_bullish)
         return (close[index] <= close[index + 1]);
      else
         return (close[index] <= open[index + 1]);
   }
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
void ExecuteTrade(TradeSignal &signal)
{
   if(!EA_Enabled)
      return;
   
   signal.entry_price = NormalizeDouble(signal.entry_price, _Digits);
   signal.stop_loss = NormalizeDouble(signal.stop_loss, _Digits);
   
   bool result = false;
   
   if(signal.is_buy)
   {
      result = trade.Buy(signal.lot_size, _Symbol, signal.entry_price, signal.stop_loss, 0, Trade_Comment);
   }
   else
   {
      result = trade.Sell(signal.lot_size, _Symbol, signal.entry_price, signal.stop_loss, 0, Trade_Comment);
   }
   
   if(result)
   {
      ulong ticket = trade.ResultOrder();
      
      // Add to active trades
      active_trade_count++;
      ArrayResize(active_trades, active_trade_count);
      int idx = active_trade_count - 1;
      
      active_trades[idx].ticket = ticket;
      active_trades[idx].is_buy = signal.is_buy;
      active_trades[idx].initial_lot = signal.lot_size;
      active_trades[idx].remaining_lot = signal.lot_size;
      active_trades[idx].entry_price = signal.entry_price;
      active_trades[idx].stop_loss = signal.stop_loss;
      active_trades[idx].tp1_price = signal.tp1;
      active_trades[idx].tp2_price = signal.tp2;
      active_trades[idx].tp3_price = signal.tp3;
      active_trades[idx].tp1_hit = false;
      active_trades[idx].tp2_hit = false;
      
      double sl_pts = MathAbs(signal.entry_price - signal.stop_loss) / _Point;
      
      string msg = StringFormat("✅ %s ORDER OPENED\nTicket: %I64u\nEntry: %.5f | SL: %.5f (%.0f pts)\nLot: %.2f\nTP1: %.5f | TP2: %.5f | TP3: %.5f",
                               signal.is_buy ? "BUY" : "SELL",
                               ticket,
                               signal.entry_price,
                               signal.stop_loss,
                               sl_pts,
                               signal.lot_size,
                               signal.tp1,
                               signal.tp2,
                               signal.tp3);
      
      SendAlert(msg);
      Print(msg);
   }
   else
   {
      Print("❌ Order failed: ", trade.ResultRetcodeDescription());
   }
}

//+------------------------------------------------------------------+
void ManageActiveTrades()
{
   for(int i = active_trade_count - 1; i >= 0; i--)
   {
      if(!position.SelectByTicket(active_trades[i].ticket))
      {
         // Position closed
         RemoveActiveTrade(i);
         continue;
      }
      
      if(position.Symbol() != _Symbol || position.Magic() != Magic_Number)
         continue;
      
      bool is_buy = active_trades[i].is_buy;
      double current_price = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double open_price = active_trades[i].entry_price;
      double sl = active_trades[i].stop_loss;
      double current_lot = position.Volume();
      
      // Check EMA exit
      if(Use_EMA_Exit && CheckEMAExit(is_buy))
      {
         if(trade.PositionClose(active_trades[i].ticket))
         {
            SendAlert("🔔 EMA Exit: Closed " + (is_buy ? "BUY" : "SELL") + " position");
            RemoveActiveTrade(i);
            continue;
         }
      }
      
      // Check RR-based partial closures
      if(Use_RR_Exit)
      {
         double profit_distance = is_buy ? (current_price - open_price) : (open_price - current_price);
         double risk_distance = MathAbs(open_price - sl);
         double current_rr = (risk_distance > 0) ? (profit_distance / risk_distance) : 0;
         
         // TP1
         if(!active_trades[i].tp1_hit && current_rr >= RR_Level_1 && 
            active_trades[i].remaining_lot > active_trades[i].initial_lot * (1 - RR_Close_Percent_1/100.0 + 0.001))
         {
            double lot_to_close = NormalizeLot(active_trades[i].initial_lot * RR_Close_Percent_1 / 100.0);
            if(lot_to_close > 0 && lot_to_close <= current_lot)
            {
               ClosePartialPosition(active_trades[i].ticket, lot_to_close, StringFormat("TP1 (%.1fR)", RR_Level_1));
               active_trades[i].tp1_hit = true;
               active_trades[i].remaining_lot -= lot_to_close;
            }
         }
         
         // TP2
         if(active_trades[i].tp1_hit && !active_trades[i].tp2_hit && current_rr >= RR_Level_2 &&
            active_trades[i].remaining_lot > active_trades[i].initial_lot * (1 - (RR_Close_Percent_1 + RR_Close_Percent_2)/100.0 + 0.001))
         {
            double lot_to_close = NormalizeLot(active_trades[i].initial_lot * RR_Close_Percent_2 / 100.0);
            if(lot_to_close > 0 && lot_to_close <= current_lot)
            {
               ClosePartialPosition(active_trades[i].ticket, lot_to_close, StringFormat("TP2 (%.1fR)", RR_Level_2));
               active_trades[i].tp2_hit = true;
               active_trades[i].remaining_lot -= lot_to_close;
            }
         }
         
         // TP3
         if(active_trades[i].tp1_hit && active_trades[i].tp2_hit && current_rr >= RR_Level_3)
         {
            if(trade.PositionClose(active_trades[i].ticket))
            {
               SendAlert(StringFormat("✅ TP3 (%.1fR): Closed remaining position", RR_Level_3));
               RemoveActiveTrade(i);
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
double CalculateLotSize(double stop_loss_points)
{
   if(!Auto_Calculate_Lot)
      return NormalizeLot(Manual_Lot_Size);
   
   double risk_amount = 0;
   
   if(Risk_Amount_Per_Trade > 0)
      risk_amount = Risk_Amount_Per_Trade;
   else
      risk_amount = account.Balance() * Risk_Percent_Per_Trade / 100.0;
   
   double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   
   double point_value = tick_value;
   if(tick_size > 0)
      point_value = tick_value * (_Point / tick_size);
   
   double lot_size = 0;
   if(stop_loss_points > 0 && point_value > 0)
      lot_size = risk_amount / (stop_loss_points * point_value);
   
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
void SendAlert(string message)
{
   if(Enable_Alert)
      Alert(message);
   
   if(Enable_Sound)
      PlaySound(Alert_Sound);
   
   Print(message);
}

//+------------------------------------------------------------------+
void DisplayInfo()
{
   string info = "\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
   info += "  📊 FVG AUTO EA v3.0\n";
   info += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
   info += "Status: " + (EA_Enabled ? "🟢 ACTIVE" : "🔴 PAUSED") + "\n";
   info += "Symbol: " + _Symbol + "\n";
   info += "Balance: $" + DoubleToString(account.Balance(), 2) + "\n";
   info += "Equity: $" + DoubleToString(account.Equity(), 2) + "\n";
   info += "FVGs: " + IntegerToString(FVG_Count) + " detected\n";
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
      if(!FVG_Array[i].is_active)
         continue;
         
      for(int bar = 0; bar < copied; bar++)
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
      if(StringFind(name, "FVG_") >= 0)
         ObjectDelete(0, name);
   }
}

//+------------------------------------------------------------------+
int FindActiveTradeByTicket(ulong ticket)
{
   for(int i = 0; i < active_trade_count; i++)
   {
      if(active_trades[i].ticket == ticket)
         return i;
   }
   return -1;
}

//+------------------------------------------------------------------+
void RemoveActiveTrade(int index)
{
   if(index < 0 || index >= active_trade_count)
      return;
   
   // Shift array
   for(int i = index; i < active_trade_count - 1; i++)
   {
      active_trades[i] = active_trades[i + 1];
   }
   
   active_trade_count--;
   ArrayResize(active_trades, active_trade_count);
}
//+------------------------------------------------------------------+
