//+------------------------------------------------------------------+
//|                                       FVG_Auto_Trading_EA.mq5    |
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

//--- Trading Signal Parameters
input group    "=== Trading Signal Settings ==="
input int      Sweep_Candles_Count = 5;
input int      FVG_Signal_Lookback = 20;        // Tìm tín hiệu trong N FVG gần nhất
input bool     Trade_On_Bullish_FVG = true;     // Trade khi FVG tăng + sweep
input bool     Trade_On_Bearish_FVG = true;     // Trade khi FVG giảm + sweep
input bool     Enable_Alert = true;
input bool     Enable_Sound = true;
input string   Alert_Sound = "alert.wav";

input group    "=== Sweep Marker Display ==="
input bool     Show_Sweep_Markers = true;
input bool     Show_Historical_Sweeps = false;
input int      Historical_Bars = 500;
input bool     Show_Sweep_With_Formation = true;
input bool     Show_Sweep_Without_Formation = false;
input color    Sweep_Low_Color = clrLime;
input color    Sweep_High_Color = clrRed;
input int      Arrow_Size = 2;

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
input bool     Trade_Buy_Signals = true;
input bool     Trade_Sell_Signals = true;
input bool     One_Trade_At_Time = true;
input int      Magic_Number = 123789;
input string   Trade_Comment = "FVG_Auto";

input group    "=== Trading Session Filter ==="
input bool     Enable_Session_Filter = false;
input bool     Trade_Asian_Session = true;
input bool     Trade_London_Session = true;
input bool     Trade_NewYork_Session = true;
input int      Asian_Start_Hour = 0;
input int      Asian_End_Hour = 9;
input int      London_Start_Hour = 8;
input int      London_End_Hour = 17;
input int      NewYork_Start_Hour = 13;
input int      NewYork_End_Hour = 22;

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
string indicator_prefix = "FVG_";
string sweep_prefix = "SWEEP_";
NewsTime news_times[];

ActiveTrade active_trades[];
int active_trade_count = 0;

int ema_handle = INVALID_HANDLE;
double ema_buffer[];

datetime last_bar_time = 0;

//--- Forward declarations
void DeleteAllObjects();
void LoadNewsSettings();
void AddNewsTime(int &count, string curr, int day, int hour, int min, int impact, string name);
bool IsNewsTime(datetime check_time);
void CreateFVG(datetime start_time, double top, double bottom, bool is_bullish, int bar_index);
void DrawFVGRectangle(int index);
void UpdateFVGStatus(const datetime &time[], const double &high[], const double &low[], const double &close[]);
void DetectFVGs(const datetime &time[], const double &open[], const double &high[], const double &low[], const double &close[]);
TradeSignal CheckForTradeSignal(const datetime &time[], const double &open[], const double &high[], const double &low[], const double &close[]);
bool CheckSweepInFVG(int fvg_index, const datetime &time[], const double &open[], const double &high[], const double &low[], const double &close[], int &sweep_bar_out, double &sweep_low_out, double &sweep_high_out);
bool IsSweepCandle(const double &open[], const double &high[], const double &low[], const double &close[], int index, bool check_for_buy);
bool IsBottomFormation(const double &open[], const double &high[], const double &low[], const double &close[], int sweep_index);
bool IsTopFormation(const double &open[], const double &high[], const double &low[], const double &close[], int sweep_index);
void SendAlert(string message);
double CalculateLotSize(double stop_loss_points);
void ExecuteTrade(TradeSignal &signal);
bool CheckEMAExit(bool is_buy_position);
void ManageActiveTrades();
void ClosePartialPosition(ulong ticket, double lot_to_close, string reason);
double NormalizeLot(double lot);
void DisplayInfo();
bool IsInTradingSession();
string GetCurrentSession();
void MarkSweepCandle(datetime time, double price, bool is_sweep_low, bool has_formation);
void ScanHistoricalSweeps();
void DeleteSweepMarkers();
void CleanupHistoricalFVGs();
int GetActiveFVGCount();
int FindActiveTradeByTicket(ulong ticket);
void RemoveActiveTrade(int index);

//+------------------------------------------------------------------+
int OnInit()
{
   Print("========================================");
   Print("  FVG AUTO TRADING EA v3.0");
   Print("  FULLY AUTOMATED - NO MANUAL ZONES");
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
   
   if(Enable_News_Filter)
      LoadNewsSettings();
   
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
   
   // Scan historical sweeps if enabled
   if(Show_Sweep_Markers && Show_Historical_Sweeps)
   {
      ScanHistoricalSweeps();
   }
   
   ChartRedraw();
   
   Print("✅ FVG Auto Trading EA initialized successfully");
   Print("   EA Status: ", EA_Enabled ? "ENABLED ✅" : "DISABLED ❌");
   Print("   Trade BUY: ", Trade_Buy_Signals ? "Yes" : "No");
   Print("   Trade SELL: ", Trade_Sell_Signals ? "Yes" : "No");
   Print("   Risk per trade: ", Risk_Percent_Per_Trade, "%");
   
   if(Enable_Session_Filter)
   {
      Print("   Session Filter: ENABLED");
      if(Trade_Asian_Session) Print("      ✅ Asian (", Asian_Start_Hour, "-", Asian_End_Hour, " GMT)");
      if(Trade_London_Session) Print("      ✅ London (", London_Start_Hour, "-", London_End_Hour, " GMT)");
      if(Trade_NewYork_Session) Print("      ✅ New York (", NewYork_Start_Hour, "-", NewYork_End_Hour, " GMT)");
   }
   else
   {
      Print("   Session Filter: DISABLED (Trading 24/7)");
   }
   
   Print("========================================");
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(ema_handle != INVALID_HANDLE)
      IndicatorRelease(ema_handle);
   
   DeleteAllObjects();
   DeleteSweepMarkers();
   Comment("");
   
   Print("FVG Auto Trading EA stopped. Reason: ", reason);
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
      
      // Check for trading signals
      TradeSignal signal = CheckForTradeSignal(time, open, high, low, close);
      
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
void DetectFVGs(const datetime &time[], const double &open[], const double &high[], 
                const double &low[], const double &close[])
{
   int start_bar = MathMin(ArraySize(time) - 4, FVG_LookBack);
   
   for(int i = 3; i < start_bar; i++)
   {
      if(Enable_News_Filter && IsNewsTime(time[i]))
         continue;
      
      if(Show_Bullish_FVG && Trade_On_Bullish_FVG)
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
      
      if(Show_Bearish_FVG && Trade_On_Bearish_FVG)
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
TradeSignal CheckForTradeSignal(const datetime &time[], const double &open[], const double &high[], 
                                 const double &low[], const double &close[])
{
   TradeSignal signal;
   signal.is_valid = false;
   
   // Check most recent FVGs
   int check_count = 0;
   for(int i = 0; i < FVG_Count && check_count < FVG_Signal_Lookback; i++)
   {
      if(!FVG_Array[i].is_active)
         continue;
      
      check_count++;
      
      // Check for BUY signal (bullish FVG)
      if(FVG_Array[i].is_bullish && Trade_Buy_Signals && Trade_On_Bullish_FVG)
      {
         int sweep_bar;
         double sweep_low, sweep_high;
         
         if(CheckSweepInFVG(i, time, open, high, low, close, sweep_bar, sweep_low, sweep_high))
         {
            if(IsBottomFormation(open, high, low, close, sweep_bar))
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
               
               // Mark sweep with formation
               if(Show_Sweep_Markers)
                  MarkSweepCandle(time[sweep_bar], sweep_low, true, true);
               
               Print("🔵 BUY SIGNAL DETECTED!");
               Print("   FVG: ", FVG_Array[i].bottom, " - ", FVG_Array[i].top);
               Print("   Sweep at bar ", sweep_bar, " (Low=", sweep_low, ")");
               Print("   Entry: ", signal.entry_price);
               Print("   SL: ", signal.stop_loss, " (", sl_points, " pts)");
               Print("   Lot: ", signal.lot_size);
               
               return signal;
            }
         }
      }
      
      // Check for SELL signal (bearish FVG)
      if(!FVG_Array[i].is_bullish && Trade_Sell_Signals && Trade_On_Bearish_FVG)
      {
         int sweep_bar;
         double sweep_low, sweep_high;
         
         if(CheckSweepInFVG(i, time, open, high, low, close, sweep_bar, sweep_low, sweep_high))
         {
            if(IsTopFormation(open, high, low, close, sweep_bar))
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
               
               // Mark sweep with formation
               if(Show_Sweep_Markers)
                  MarkSweepCandle(time[sweep_bar], sweep_high, false, true);
               
               Print("🔴 SELL SIGNAL DETECTED!");
               Print("   FVG: ", FVG_Array[i].bottom, " - ", FVG_Array[i].top);
               Print("   Sweep at bar ", sweep_bar, " (High=", sweep_high, ")");
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
bool CheckSweepInFVG(int fvg_index, const datetime &time[], const double &open[], const double &high[], 
                     const double &low[], const double &close[], int &sweep_bar_out, 
                     double &sweep_low_out, double &sweep_high_out)
{
   for(int i = 1; i < 15; i++)
   {
      if(i >= ArraySize(low))
         break;
      
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
      
      if(IsSweepCandle(open, high, low, close, i, FVG_Array[fvg_index].is_bullish))
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
bool IsSweepCandle(const double &open[], const double &high[], const double &low[], 
                   const double &close[], int index, bool check_for_buy)
{
   if(index + 1 >= ArraySize(open))
      return false;
   
   if(check_for_buy)
   {
      // SWEEP LOW (cho tín hiệu MUA)
      if(low[index] >= low[index + 1])
         return false;
      
      bool is_red_candle = (close[index] < open[index]);
      
      if(is_red_candle)
      {
         double min_prev = MathMin(open[index + 1], close[index + 1]);
         if(close[index] >= min_prev)
            return true;
      }
      else
      {
         double min_prev = MathMin(open[index + 1], close[index + 1]);
         if(open[index] >= min_prev)
            return true;
      }
   }
   else
   {
      // SWEEP HIGH (cho tín hiệu BÁN)
      if(high[index] <= high[index + 1])
         return false;
      
      double max_prev = MathMax(open[index + 1], close[index + 1]);
      if(close[index] <= max_prev)
         return true;
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
void ExecuteTrade(TradeSignal &signal)
{
   if(!EA_Enabled)
      return;
   
   // CHECK TRADING SESSION
   if(Enable_Session_Filter && !IsInTradingSession())
   {
      Print("⏸️ Ngoài phiên giao dịch cho phép. Bỏ qua tín hiệu.");
      return;
   }
   
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
      
      string msg = StringFormat("✅ %s ORDER OPENED\nTicket: %I64u\nEntry: %.5f | SL: %.5f (%.0f pts)\nLot: %.2f\nTP1: %.5f (%.1fR) | TP2: %.5f (%.1fR) | TP3: %.5f (%.1fR)",
                               signal.is_buy ? "BUY" : "SELL",
                               ticket,
                               signal.entry_price,
                               signal.stop_loss,
                               sl_pts,
                               signal.lot_size,
                               signal.tp1, RR_Level_1,
                               signal.tp2, RR_Level_2,
                               signal.tp3, RR_Level_3);
      
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
   
   // Show session info
   if(Enable_Session_Filter)
   {
      string current_session = GetCurrentSession();
      bool can_trade = IsInTradingSession();
      info += "Session: " + (can_trade ? "✅ " : "⏸️ ") + current_session + "\n";
   }
   
   info += "Symbol: " + _Symbol + "\n";
   info += "Balance: $" + DoubleToString(account.Balance(), 2) + "\n";
   info += "Equity: $" + DoubleToString(account.Equity(), 2) + "\n";
   info += "Active FVGs: " + IntegerToString(GetActiveFVGCount()) + "\n";
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
         bool is_modified = false;
         bool should_delete = false;
         
         if(FVG_Array[i].is_bullish)
         {
            if(Delete_On_Break && close[bar] < FVG_Array[i].bottom)
            {
               should_delete = true;
            }
            else if(Fill_On_Touch && low[bar] < FVG_Array[i].top && low[bar] > FVG_Array[i].bottom)
            {
               FVG_Array[i].top = low[bar];
               is_modified = true;
               
               if(FVG_Array[i].top - FVG_Array[i].bottom < Min_FVG_Points * _Point)
                  should_delete = true;
            }
         }
         else
         {
            if(Delete_On_Break && close[bar] > FVG_Array[i].top)
            {
               should_delete = true;
            }
            else if(Fill_On_Touch && high[bar] > FVG_Array[i].bottom && high[bar] < FVG_Array[i].top)
            {
               FVG_Array[i].bottom = high[bar];
               is_modified = true;
               
               if(FVG_Array[i].top - FVG_Array[i].bottom < Min_FVG_Points * _Point)
                  should_delete = true;
            }
         }
         
         if(should_delete)
         {
            FVG_Array[i].is_active = false;
            ObjectDelete(0, FVG_Array[i].rect_name);
            break;
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
      if(StringFind(name, indicator_prefix) >= 0)
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
   
   for(int i = index; i < active_trade_count - 1; i++)
   {
      active_trades[i] = active_trades[i + 1];
   }
   
   active_trade_count--;
   ArrayResize(active_trades, active_trade_count);
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
   }
   
   if(Filter_EUR)
   {
      AddNewsTime(count, "EUR", 3, 12, 0, 3, "ECB Rate");
      AddNewsTime(count, "EUR", 3, 12, 30, 3, "ECB Press Conf");
      AddNewsTime(count, "EUR", 4, 10, 0, 3, "Eurozone GDP");
   }
   
   if(Filter_GBP)
   {
      AddNewsTime(count, "GBP", 4, 12, 0, 3, "BOE Rate");
      AddNewsTime(count, "GBP", 3, 7, 0, 3, "UK GDP");
      AddNewsTime(count, "GBP", 2, 7, 0, 2, "UK CPI");
   }
   
   Print("News filter loaded: ", count, " events");
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
bool IsInTradingSession()
{
   if(!Enable_Session_Filter)
      return true;
   
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   int current_hour = dt.hour;
   
   if(Trade_Asian_Session)
   {
      if((Asian_Start_Hour < Asian_End_Hour && current_hour >= Asian_Start_Hour && current_hour < Asian_End_Hour) ||
         (Asian_Start_Hour >= Asian_End_Hour && (current_hour >= Asian_Start_Hour || current_hour < Asian_End_Hour)))
         return true;
   }
   
   if(Trade_London_Session)
   {
      if((London_Start_Hour < London_End_Hour && current_hour >= London_Start_Hour && current_hour < London_End_Hour) ||
         (London_Start_Hour >= London_End_Hour && (current_hour >= London_Start_Hour || current_hour < London_End_Hour)))
         return true;
   }
   
   if(Trade_NewYork_Session)
   {
      if((NewYork_Start_Hour < NewYork_End_Hour && current_hour >= NewYork_Start_Hour && current_hour < NewYork_End_Hour) ||
         (NewYork_Start_Hour >= NewYork_End_Hour && (current_hour >= NewYork_Start_Hour || current_hour < NewYork_End_Hour)))
         return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
string GetCurrentSession()
{
   if(!Enable_Session_Filter)
      return "All Sessions";
   
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   int current_hour = dt.hour;
   
   string sessions = "";
   
   if(Trade_Asian_Session)
   {
      if((Asian_Start_Hour < Asian_End_Hour && current_hour >= Asian_Start_Hour && current_hour < Asian_End_Hour) ||
         (Asian_Start_Hour >= Asian_End_Hour && (current_hour >= Asian_Start_Hour || current_hour < Asian_End_Hour)))
         sessions += "Asian ";
   }
   
   if(Trade_London_Session)
   {
      if((London_Start_Hour < London_End_Hour && current_hour >= London_Start_Hour && current_hour < London_End_Hour) ||
         (London_Start_Hour >= London_End_Hour && (current_hour >= London_Start_Hour || current_hour < London_End_Hour)))
         sessions += "London ";
   }
   
   if(Trade_NewYork_Session)
   {
      if((NewYork_Start_Hour < NewYork_End_Hour && current_hour >= NewYork_Start_Hour && current_hour < NewYork_End_Hour) ||
         (NewYork_Start_Hour >= NewYork_End_Hour && (current_hour >= NewYork_Start_Hour || current_hour < NewYork_End_Hour)))
         sessions += "NY ";
   }
   
   if(sessions == "")
      sessions = "No Active Session";
   
   return sessions;
}

//+------------------------------------------------------------------+
void MarkSweepCandle(datetime time, double price, bool is_sweep_low, bool has_formation)
{
   if(!Show_Sweep_Markers)
      return;
   
   if(has_formation && !Show_Sweep_With_Formation)
      return;
   
   if(!has_formation && !Show_Sweep_Without_Formation)
      return;
   
   string marker_name = sweep_prefix + TimeToString(time, TIME_DATE|TIME_SECONDS);
   
   if(ObjectFind(0, marker_name) >= 0)
      ObjectDelete(0, marker_name);
   
   int arrow_code;
   color arrow_color;
   double arrow_price;
   double point_offset = 50 * _Point;
   
   if(is_sweep_low)
   {
      arrow_price = price - point_offset;
      
      if(has_formation)
      {
         arrow_code = 233;
         arrow_color = Sweep_Low_Color;
      }
      else
      {
         arrow_code = 241;
         arrow_color = clrYellow;
      }
   }
   else
   {
      arrow_price = price + point_offset;
      
      if(has_formation)
      {
         arrow_code = 234;
         arrow_color = Sweep_High_Color;
      }
      else
      {
         arrow_code = 241;
         arrow_color = clrOrange;
      }
   }
   
   if(ObjectCreate(0, marker_name, OBJ_ARROW, 0, time, arrow_price))
   {
      ObjectSetInteger(0, marker_name, OBJPROP_ARROWCODE, arrow_code);
      ObjectSetInteger(0, marker_name, OBJPROP_COLOR, arrow_color);
      ObjectSetInteger(0, marker_name, OBJPROP_WIDTH, Arrow_Size);
      ObjectSetInteger(0, marker_name, OBJPROP_BACK, false);
      ObjectSetInteger(0, marker_name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, marker_name, OBJPROP_HIDDEN, true);
      
      string tooltip = "SWEEP " + (is_sweep_low ? "LOW" : "HIGH");
      if(has_formation)
         tooltip += " + FORMATION ✓";
      else
         tooltip += " (No pattern yet)";
      
      ObjectSetString(0, marker_name, OBJPROP_TEXT, tooltip);
   }
}

//+------------------------------------------------------------------+
void ScanHistoricalSweeps()
{
   if(!Show_Sweep_Markers || !Show_Historical_Sweeps)
      return;
   
   Print("🔍 Scanning historical sweeps...");
   
   datetime time[];
   double open[], high[], low[], close[];
   
   ArraySetAsSeries(time, true);
   ArraySetAsSeries(open, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);
   
   int bars = MathMin(Historical_Bars, Bars(_Symbol, PERIOD_CURRENT) - 10);
   
   if(CopyTime(_Symbol, PERIOD_CURRENT, 0, bars, time) <= 0) return;
   CopyOpen(_Symbol, PERIOD_CURRENT, 0, bars, open);
   CopyHigh(_Symbol, PERIOD_CURRENT, 0, bars, high);
   CopyLow(_Symbol, PERIOD_CURRENT, 0, bars, low);
   CopyClose(_Symbol, PERIOD_CURRENT, 0, bars, close);
   
   int sweep_count = 0;
   
   for(int i = bars - 10; i >= 1; i--)
   {
      if(IsSweepCandle(open, high, low, close, i, true))
      {
         bool has_formation = IsBottomFormation(open, high, low, close, i);
         MarkSweepCandle(time[i], low[i], true, has_formation);
         sweep_count++;
      }
      
      if(IsSweepCandle(open, high, low, close, i, false))
      {
         bool has_formation = IsTopFormation(open, high, low, close, i);
         MarkSweepCandle(time[i], high[i], false, has_formation);
         sweep_count++;
      }
   }
   
   Print("✅ Historical scan complete: ", sweep_count, " sweeps marked");
}

//+------------------------------------------------------------------+
void DeleteSweepMarkers()
{
   int total = ObjectsTotal(0, 0, OBJ_ARROW);
   for(int i = total - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i, 0, OBJ_ARROW);
      if(StringFind(name, sweep_prefix) >= 0)
         ObjectDelete(0, name);
   }
}

//+------------------------------------------------------------------+
void CleanupHistoricalFVGs()
{
   Print("🧹 Cleaning up historical FVGs...");
   
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
   
   int cleaned = 0;
   
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
               cleaned++;
               break;
            }
            
            if(Fill_On_Touch && low[bar] < FVG_Array[i].top && low[bar] > FVG_Array[i].bottom)
            {
               FVG_Array[i].top = low[bar];
               
               if(FVG_Array[i].top - FVG_Array[i].bottom < Min_FVG_Points * _Point)
               {
                  FVG_Array[i].is_active = false;
                  ObjectDelete(0, FVG_Array[i].rect_name);
                  cleaned++;
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
               cleaned++;
               break;
            }
            
            if(Fill_On_Touch && high[bar] > FVG_Array[i].bottom && high[bar] < FVG_Array[i].top)
            {
               FVG_Array[i].bottom = high[bar];
               
               if(FVG_Array[i].top - FVG_Array[i].bottom < Min_FVG_Points * _Point)
               {
                  FVG_Array[i].is_active = false;
                  ObjectDelete(0, FVG_Array[i].rect_name);
                  cleaned++;
                  break;
               }
               
               DrawFVGRectangle(i);
            }
         }
      }
   }
   
   Print("✅ Cleanup complete: ", cleaned, " FVGs removed, ", GetActiveFVGCount(), " active");
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
