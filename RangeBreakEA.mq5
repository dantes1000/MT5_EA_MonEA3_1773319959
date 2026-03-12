//+------------------------------------------------------------------+
//|                                                      RangeBreakEA.mq5 |
//|                        Copyright 2023, MetaQuotes Ltd.               |
//|                                             https://www.mql5.com      |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property description "Range Breakout EA with multiple filters"

//--- Include standard libraries
#include <Trade/Trade.mqh>
#include <Trade/SymbolInfo.mqh>
#include <Indicators/Trend.mqh>
#include <Indicators/Oscilators.mqh>
#include <Indicators/BillWilliams.mqh>
#include <Indicators/Volumes.mqh>
#include <Calendar/Calendar.mqh>

//--- Input parameters for Breakout
input int      BreakoutType = 0;               // 0=Range, 1=BollingerBands, 2=ATR
input bool     AllowLong = true;               // Allow long positions
input bool     AllowShort = true;              // Allow short positions
input bool     RequireVolumeConfirm = true;    // Require volume confirmation
input bool     RequireRetest = false;          // Wait for retest before entry
input ENUM_TIMEFRAMES RangeTF = PERIOD_D1;     // Timeframe for range calculation
input int      TrendFilterEMA = 200;           // EMA period for trend filter (0=disabled)
input ENUM_TIMEFRAMES ExecTF = PERIOD_M15;     // Timeframe for trade execution

//--- Input parameters for News Filter
input bool     UseNewsFilter = true;           // Enable economic news filter
input int      NewsMinutesBefore = 60;         // Minutes before news to suspend trading
input int      NewsMinutesAfter = 30;          // Minutes after news to resume trading
input int      NewsImpactLevel = 3;            // Minimum impact level: 1=low, 2=medium, 3=high
input bool     CloseOnHighImpact = true;       // Close positions before high impact news

//--- Input parameters for Indicator Filters
input bool     UseATRFilter = true;            // Enable ATR filter
input int      ATRPeriod = 14;                 // ATR period
input double   MinATRPips = 20;                // Minimum ATR required (pips)
input double   MaxATRPips = 150;               // Maximum ATR allowed (pips)
input double   ATR_Mult_Min = 1.25;            // Minimum ATR multiplier for breakout
input double   ATR_Mult_Max = 3.0;             // Maximum ATR multiplier
input bool     UseBBFilter = true;             // Enable Bollinger Bands filter
input int      BBPeriod = 20;                  // Bollinger Bands period
input double   BBDeviation = 2.0;              // BB standard deviation
input double   Min_Width_Pips = 30;            // Minimum BB width (pips)
input double   Max_Width_Pips = 120;           // Maximum BB width (pips)
input bool     UseEMAFilter = true;            // Enable EMA filter
input int      EMAPeriod = 200;                // EMA period for trend filter
input ENUM_TIMEFRAMES EMATf = PERIOD_H1;       // EMA timeframe
input int      Trend_Filter = 1;               // 0=Strict (price >/< EMA), 1=EMA+ADX
input bool     UseADXFilter = true;            // Enable ADX filter (if Trend_Filter=1)
input int      ADXPeriod = 14;                 // ADX period
input double   ADXThreshold = 20.0;            // Minimum ADX threshold
input bool     UseRSIFilter = false;           // Enable RSI filter
input int      RSIPeriod = 14;                 // RSI period
input double   RSIOverbought = 70;             // RSI overbought level (no buy above)
input double   RSIOversold = 30;               // RSI oversold level (no sell below)
input bool     UseVolumeFilter = true;         // Enable volume filter
input int      VolumePeriod = 20;              // Volume moving average period
input double   VolumeMultiplier = 1.5;         // Minimum volume multiplier
input int      Vol_Confirm_Type = 0;           // 0=Real Volume

//--- Input parameters for Position Management
input ulong    MagicNumber = 123456;           // Unique EA order identifier
input string   OrderComment = "RangeBreakEA";  // Order comment
input int      MaxSlippage = 3;                // Maximum allowed slippage (points)
input int      MaxOrderRetries = 3;            // Maximum order send attempts
input bool     UsePartialClose = false;        // Enable partial close
input double   PartialCloseRR = 1.0;           // R:R for partial close

//--- Global variables
CTrade         trade;
CSymbolInfo    symbolInfo;
CiATR          atr;
CiBands        bb;
CiMA           ema;
CiADX          adx;
CiRSI          rsi;
CiVolumes      volume;
CCalendar      calendar;
double         rangeHigh, rangeLow;
datetime       lastBarTime = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- Initialize trade object
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(MaxSlippage);
   trade.SetAsyncMode(false);
   
   //--- Initialize symbol info
   if(!symbolInfo.Name(_Symbol))
      return INIT_FAILED;
   
   //--- Initialize indicators
   if(UseATRFilter && !atr.Create(_Symbol, ExecTF, ATRPeriod))
      return INIT_FAILED;
   
   if(UseBBFilter && !bb.Create(_Symbol, ExecTF, BBPeriod, 0, BBDeviation, PRICE_CLOSE))
      return INIT_FAILED;
   
   if(UseEMAFilter && !ema.Create(_Symbol, EMATf, EMAPeriod, 0, MODE_EMA, PRICE_CLOSE))
      return INIT_FAILED;
   
   if(UseADXFilter && !adx.Create(_Symbol, ExecTF, ADXPeriod))
      return INIT_FAILED;
   
   if(UseRSIFilter && !rsi.Create(_Symbol, ExecTF, RSIPeriod, PRICE_CLOSE))
      return INIT_FAILED;
   
   if(UseVolumeFilter && !volume.Create(_Symbol, ExecTF, VOLUME_TICK))
      return INIT_FAILED;
   
   //--- Initialize calendar for news filter
   if(UseNewsFilter && !calendar.Create())
      return INIT_FAILED;
   
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   //--- Clean up indicators
   atr.Release();
   bb.Release();
   ema.Release();
   adx.Release();
   rsi.Release();
   volume.Release();
   calendar.Release();
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   //--- Check for new bar on execution timeframe
   datetime currentBarTime = iTime(_Symbol, ExecTF, 0);
   if(currentBarTime == lastBarTime)
      return;
   lastBarTime = currentBarTime;
   
   //--- Update symbol info
   symbolInfo.RefreshRates();
   
   //--- Check news filter
   if(UseNewsFilter && IsNewsTime())
   {
      if(CloseOnHighImpact && NewsImpactLevel >= 3)
         CloseAllPositions();
      return;
   }
   
   //--- Calculate daily range
   CalculateDailyRange();
   
   //--- Check for breakout signals
   CheckBreakoutSignals();
}

//+------------------------------------------------------------------+
//| Calculate daily range                                            |
//+------------------------------------------------------------------+
void CalculateDailyRange()
{
   rangeHigh = iHigh(_Symbol, RangeTF, 1);
   rangeLow = iLow(_Symbol, RangeTF, 1);
}

//+------------------------------------------------------------------+
//| Check breakout signals                                           |
//+------------------------------------------------------------------+
void CheckBreakoutSignals()
{
   double currentPrice = symbolInfo.Ask();
   double bidPrice = symbolInfo.Bid();
   
   //--- Check if price is near range boundaries
   bool nearRangeHigh = (currentPrice >= rangeHigh - symbolInfo.Point() * 10);
   bool nearRangeLow = (currentPrice <= rangeLow + symbolInfo.Point() * 10);
   
   //--- Check indicator filters
   bool filtersPassed = CheckAllFilters();
   
   //--- Generate signals
   if(AllowLong && nearRangeHigh && filtersPassed)
   {
      if(CheckVolumeConfirmation())
         PlaceBuyStopOrder(rangeHigh + symbolInfo.Point() * 10);
   }
   
   if(AllowShort && nearRangeLow && filtersPassed)
   {
      if(CheckVolumeConfirmation())
         PlaceSellStopOrder(rangeLow - symbolInfo.Point() * 10);
   }
}

//+------------------------------------------------------------------+
//| Check all indicator filters                                      |
//+------------------------------------------------------------------+
bool CheckAllFilters()
{
   //--- ATR filter
   if(UseATRFilter)
   {
      atr.Refresh();
      double atrValue = atr.Main(0);
      double atrPips = atrValue / symbolInfo.Point() * 10;
      
      if(atrPips < MinATRPips || atrPips > MaxATRPips)
         return false;
      
      double rangeSize = rangeHigh - rangeLow;
      double atrMultiplier = rangeSize / atrValue;
      
      if(atrMultiplier < ATR_Mult_Min || atrMultiplier > ATR_Mult_Max)
         return false;
   }
   
   //--- Bollinger Bands filter
   if(UseBBFilter)
   {
      bb.Refresh();
      double bbUpper = bb.Upper(0);
      double bbLower = bb.Lower(0);
      double bbWidth = (bbUpper - bbLower) / symbolInfo.Point() * 10;
      
      if(bbWidth < Min_Width_Pips || bbWidth > Max_Width_Pips)
         return false;
   }
   
   //--- EMA filter
   if(UseEMAFilter)
   {
      ema.Refresh();
      double emaValue = ema.Main(0);
      double currentPrice = symbolInfo.Ask();
      
      if(Trend_Filter == 0) // Strict mode
      {
         // For long: price must be above EMA, for short: price must be below EMA
         // This check is done in signal generation
      }
      else if(Trend_Filter == 1) // EMA+ADX mode
      {
         if(UseADXFilter)
         {
            adx.Refresh();
            double adxValue = adx.Main(0);
            
            if(adxValue < ADXThreshold)
               return false;
         }
      }
   }
   
   //--- RSI filter
   if(UseRSIFilter)
   {
      rsi.Refresh();
      double rsiValue = rsi.Main(0);
      
      // Don't buy if RSI is overbought, don't sell if RSI is oversold
      // This check is done in signal generation
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Check volume confirmation                                        |
//+------------------------------------------------------------------+
bool CheckVolumeConfirmation()
{
   if(!RequireVolumeConfirm)
      return true;
      
   if(!UseVolumeFilter)
      return true;
      
   volume.Refresh();
   
   //--- Calculate volume moving average
   double volumeSum = 0;
   for(int i = 0; i < VolumePeriod; i++)
   {
      volumeSum += volume.Main(i);
   }
   double volumeMA = volumeSum / VolumePeriod;
   
   //--- Check current volume
   double currentVolume = volume.Main(0);
   
   return (currentVolume > volumeMA * VolumeMultiplier);
}

//+------------------------------------------------------------------+
//| Check if current time is near news event                         |
//+------------------------------------------------------------------+
bool IsNewsTime()
{
   if(!UseNewsFilter)
      return false;
      
   datetime currentTime = TimeCurrent();
   
   //--- Get upcoming events
   CCalendarEvent events[];
   int eventsCount = calendar.GetEvents(events, currentTime, currentTime + 3600 * 24);
   
   for(int i = 0; i < eventsCount; i++)
   {
      if(events[i].impact >= NewsImpactLevel)
      {
         datetime eventTime = events[i].time;
         
         // Check if current time is within news window
         if(currentTime >= eventTime - NewsMinutesBefore * 60 &&
            currentTime <= eventTime + NewsMinutesAfter * 60)
         {
            return true;
         }
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Place buy stop order                                             |
//+------------------------------------------------------------------+
void PlaceBuyStopOrder(double price)
{
   double sl = price - (rangeHigh - rangeLow);
   double tp = price + (rangeHigh - rangeLow) * 2;
   
   //--- Check RSI filter for overbought condition
   if(UseRSIFilter)
   {
      rsi.Refresh();
      if(rsi.Main(0) > RSIOverbought)
         return;
   }
   
   //--- Check EMA strict filter
   if(UseEMAFilter && Trend_Filter == 0)
   {
      ema.Refresh();
      if(symbolInfo.Ask() < ema.Main(0))
         return;
   }
   
   for(int attempt = 0; attempt < MaxOrderRetries; attempt++)
   {
      if(trade.BuyStop(symbolInfo.LotsMin(), price, _Symbol, sl, tp, ORDER_TIME_GTC, 0, OrderComment))
         break;
      
      Sleep(100);
   }
}

//+------------------------------------------------------------------+
//| Place sell stop order                                            |
//+------------------------------------------------------------------+
void PlaceSellStopOrder(double price)
{
   double sl = price + (rangeHigh - rangeLow);
   double tp = price - (rangeHigh - rangeLow) * 2;
   
   //--- Check RSI filter for oversold condition
   if(UseRSIFilter)
   {
      rsi.Refresh();
      if(rsi.Main(0) < RSIOversold)
         return;
   }
   
   //--- Check EMA strict filter
   if(UseEMAFilter && Trend_Filter == 0)
   {
      ema.Refresh();
      if(symbolInfo.Bid() > ema.Main(0))
         return;
   }
   
   for(int attempt = 0; attempt < MaxOrderRetries; attempt++)
   {
      if(trade.SellStop(symbolInfo.LotsMin(), price, _Symbol, sl, tp, ORDER_TIME_GTC, 0, OrderComment))
         break;
      
      Sleep(100);
   }
}

//+------------------------------------------------------------------+
//| Close all positions                                              |
//+------------------------------------------------------------------+
void CloseAllPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionGetString(POSITION_COMMENT) == OrderComment)
      {
         trade.PositionClose(ticket);
      }
   }
}

//+------------------------------------------------------------------+
