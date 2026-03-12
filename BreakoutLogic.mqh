//+------------------------------------------------------------------+
//|                                                      BreakoutLogic.mqh |
//|                        Copyright 2023, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| Input parameters for breakout detection                         |
//+------------------------------------------------------------------+
input bool   AllowLong = true;               // Allow long positions
input bool   AllowShort = true;              // Allow short positions
input bool   RequireVolumeConfirm = true;    // Require volume confirmation
input bool   RequireRetest = false;          // Wait for retest before entry
input ENUM_TIMEFRAMES RangeTF = PERIOD_D1;   // Timeframe for range calculation
input int    TrendFilterEMA = 200;           // EMA period for trend filter (0=disabled)
input ENUM_TIMEFRAMES ExecTF = PERIOD_M15;   // Timeframe for trade execution

//+------------------------------------------------------------------+
//| Input parameters for news filter                                |
//+------------------------------------------------------------------+
input bool   UseNewsFilter = true;           // Enable economic news filter
input int    NewsMinutesBefore = 60;         // Minutes before news to suspend trading
input int    NewsMinutesAfter = 30;          // Minutes after news to resume trading
input int    NewsImpactLevel = 3;            // Minimum impact level: 1=low, 2=medium, 3=high
input bool   CloseOnHighImpact = true;       // Close positions before high impact news

//+------------------------------------------------------------------+
//| Input parameters for indicator filters                          |
//+------------------------------------------------------------------+
input bool   UseATRFilter = true;            // Enable ATR filter
input int    ATRPeriod = 14;                 // ATR period
input double MinATRPips = 20.0;              // Minimum ATR required (pips)
input double MaxATRPips = 150.0;             // Maximum ATR allowed (pips)
input double ATR_Mult_Min = 1.25;            // Minimum ATR multiplier for breakout validation
input double ATR_Mult_Max = 3.0;             // Maximum ATR multiplier

input bool   UseBBFilter = true;             // Enable Bollinger Bands filter
input int    BBPeriod = 20;                  // Bollinger Bands period
input double BBDeviation = 2.0;              // Bollinger Bands standard deviation
input double Min_Width_Pips = 30.0;          // Minimum BB width (pips)
input double Max_Width_Pips = 120.0;         // Maximum BB width (pips)

input bool   UseEMAFilter = true;            // Enable EMA filter
input int    EMAPeriod = 200;                // EMA period for trend filter
input ENUM_TIMEFRAMES EMATf = PERIOD_H1;     // EMA timeframe
input int    Trend_Filter = 1;               // 0=Strict (price >/< EMA), 1=EMA+ADX

input bool   UseADXFilter = true;            // Enable ADX filter (if Trend_Filter=1)
input int    ADXPeriod = 14;                 // ADX period
input double ADXThreshold = 20.0;            // Minimum ADX threshold

input bool   UseRSIFilter = false;           // Enable RSI filter
input int    RSIPeriod = 14;                 // RSI period
input double RSIOverbought = 70.0;           // RSI overbought level (do not buy above)
input double RSIOversold = 30.0;             // RSI oversold level (do not sell below)

//+------------------------------------------------------------------+
//| Class for breakout detection logic                              |
//+------------------------------------------------------------------+
class CBreakoutLogic
{
private:
   string m_symbol;
   double m_point;
   
   // Handle for indicators
   int m_atr_handle;
   int m_bb_handle;
   int m_ema_handle;
   int m_adx_handle;
   int m_rsi_handle;
   
   // Volume confirmation
   double m_volume_sma[1];
   
   // News filter
   bool m_is_news_time;
   
public:
   // Constructor
   CBreakoutLogic(string symbol) : m_symbol(symbol)
   {
      m_point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      m_atr_handle = iATR(symbol, ExecTF, ATRPeriod);
      m_bb_handle = iBands(symbol, RangeTF, BBPeriod, 0, BBDeviation, PRICE_CLOSE);
      m_ema_handle = iMA(symbol, EMATf, EMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
      m_adx_handle = iADX(symbol, ExecTF, ADXPeriod);
      m_rsi_handle = iRSI(symbol, ExecTF, RSIPeriod, PRICE_CLOSE);
      m_is_news_time = false;
   }
   
   // Destructor
   ~CBreakoutLogic()
   {
      IndicatorRelease(m_atr_handle);
      IndicatorRelease(m_bb_handle);
      IndicatorRelease(m_ema_handle);
      IndicatorRelease(m_adx_handle);
      IndicatorRelease(m_rsi_handle);
   }
   
   // Check if trading is allowed based on news filter
   bool IsTradingAllowed()
   {
      if(!UseNewsFilter) return true;
      
      // Check for high impact news events
      m_is_news_time = CheckNewsEvents();
      return !m_is_news_time;
   }
   
   // Check for breakout signals
   int CheckBreakout()
   {
      // 0 = no signal, 1 = long, -1 = short
      
      // Check news filter first
      if(!IsTradingAllowed()) return 0;
      
      // Get daily range
      double daily_high = iHigh(m_symbol, RangeTF, 1);
      double daily_low = iLow(m_symbol, RangeTF, 1);
      double daily_range = daily_high - daily_low;
      
      // Get current price
      double current_price = SymbolInfoDouble(m_symbol, SYMBOL_BID);
      
      // Check for breakout
      bool long_breakout = false;
      bool short_breakout = false;
      
      if(AllowLong && current_price > daily_high)
      {
         long_breakout = true;
      }
      
      if(AllowShort && current_price < daily_low)
      {
         short_breakout = true;
      }
      
      // Apply volume confirmation if required
      if(RequireVolumeConfirm && (long_breakout || short_breakout))
      {
         if(!CheckVolumeConfirmation())
         {
            long_breakout = false;
            short_breakout = false;
         }
      }
      
      // Apply indicator filters
      if(long_breakout && !CheckLongFilters(current_price, daily_range))
      {
         long_breakout = false;
      }
      
      if(short_breakout && !CheckShortFilters(current_price, daily_range))
      {
         short_breakout = false;
      }
      
      // Return signal
      if(long_breakout) return 1;
      if(short_breakout) return -1;
      
      return 0;
   }
   
   // Check if positions should be closed due to news
   bool ShouldClosePositions()
   {
      if(!UseNewsFilter || !CloseOnHighImpact) return false;
      
      // Check for upcoming high impact news
      return CheckHighImpactNews();
   }
   
private:
   // Check volume confirmation
   bool CheckVolumeConfirmation()
   {
      double current_volume = iVolume(m_symbol, ExecTF, 0);
      
      // Calculate SMA of volume (20 periods)
      double volume_sma = 0;
      for(int i = 0; i < 20; i++)
      {
         volume_sma += iVolume(m_symbol, ExecTF, i);
      }
      volume_sma /= 20.0;
      
      // Check if current volume is > 1.5x SMA
      return (current_volume > (volume_sma * 1.5));
   }
   
   // Check filters for long positions
   bool CheckLongFilters(double price, double range)
   {
      // ATR filter
      if(UseATRFilter)
      {
         double atr_values[1];
         if(CopyBuffer(m_atr_handle, 0, 0, 1, atr_values) <= 0) return false;
         
         double atr_pips = atr_values[0] / m_point;
         if(atr_pips < MinATRPips || atr_pips > MaxATRPips) return false;
         
         // Check ATR multiplier for range validation
         double atr_multiplier = range / atr_values[0];
         if(atr_multiplier < ATR_Mult_Min || atr_multiplier > ATR_Mult_Max) return false;
      }
      
      // Bollinger Bands filter
      if(UseBBFilter)
      {
         double bb_upper[1], bb_lower[1];
         if(CopyBuffer(m_bb_handle, 1, 0, 1, bb_upper) <= 0) return false;
         if(CopyBuffer(m_bb_handle, 2, 0, 1, bb_lower) <= 0) return false;
         
         double bb_width_pips = (bb_upper[0] - bb_lower[0]) / m_point;
         if(bb_width_pips < Min_Width_Pips || bb_width_pips > Max_Width_Pips) return false;
      }
      
      // EMA filter
      if(UseEMAFilter && TrendFilterEMA > 0)
      {
         double ema_values[1];
         if(CopyBuffer(m_ema_handle, 0, 0, 1, ema_values) <= 0) return false;
         
         if(Trend_Filter == 0) // Strict mode
         {
            if(price <= ema_values[0]) return false;
         }
         else if(Trend_Filter == 1) // EMA + ADX mode
         {
            if(price <= ema_values[0]) return false;
            
            if(UseADXFilter)
            {
               double adx_values[1];
               if(CopyBuffer(m_adx_handle, 0, 0, 1, adx_values) <= 0) return false;
               
               if(adx_values[0] < ADXThreshold) return false;
            }
         }
      }
      
      // RSI filter
      if(UseRSIFilter)
      {
         double rsi_values[1];
         if(CopyBuffer(m_rsi_handle, 0, 0, 1, rsi_values) <= 0) return false;
         
         if(rsi_values[0] >= RSIOverbought) return false;
      }
      
      return true;
   }
   
   // Check filters for short positions
   bool CheckShortFilters(double price, double range)
   {
      // ATR filter
      if(UseATRFilter)
      {
         double atr_values[1];
         if(CopyBuffer(m_atr_handle, 0, 0, 1, atr_values) <= 0) return false;
         
         double atr_pips = atr_values[0] / m_point;
         if(atr_pips < MinATRPips || atr_pips > MaxATRPips) return false;
         
         // Check ATR multiplier for range validation
         double atr_multiplier = range / atr_values[0];
         if(atr_multiplier < ATR_Mult_Min || atr_multiplier > ATR_Mult_Max) return false;
      }
      
      // Bollinger Bands filter
      if(UseBBFilter)
      {
         double bb_upper[1], bb_lower[1];
         if(CopyBuffer(m_bb_handle, 1, 0, 1, bb_upper) <= 0) return false;
         if(CopyBuffer(m_bb_handle, 2, 0, 1, bb_lower) <= 0) return false;
         
         double bb_width_pips = (bb_upper[0] - bb_lower[0]) / m_point;
         if(bb_width_pips < Min_Width_Pips || bb_width_pips > Max_Width_Pips) return false;
      }
      
      // EMA filter
      if(UseEMAFilter && TrendFilterEMA > 0)
      {
         double ema_values[1];
         if(CopyBuffer(m_ema_handle, 0, 0, 1, ema_values) <= 0) return false;
         
         if(Trend_Filter == 0) // Strict mode
         {
            if(price >= ema_values[0]) return false;
         }
         else if(Trend_Filter == 1) // EMA + ADX mode
         {
            if(price >= ema_values[0]) return false;
            
            if(UseADXFilter)
            {
               double adx_values[1];
               if(CopyBuffer(m_adx_handle, 0, 0, 1, adx_values) <= 0) return false;
               
               if(adx_values[0] < ADXThreshold) return false;
            }
         }
      }
      
      // RSI filter
      if(UseRSIFilter)
      {
         double rsi_values[1];
         if(CopyBuffer(m_rsi_handle, 0, 0, 1, rsi_values) <= 0) return false;
         
         if(rsi_values[0] <= RSIOversold) return false;
      }
      
      return true;
   }
   
   // Check for news events using FFCal indicator
   bool CheckNewsEvents()
   {
      // Note: FFCal indicator is not directly accessible in MQL5
      // This is a placeholder implementation
      // In real implementation, you would need to:
      // 1. Include FFCal indicator or use Calendar API
      // 2. Check for events within NewsMinutesBefore/After window
      // 3. Filter by NewsImpactLevel
      
      // For now, return false (no news)
      return false;
   }
   
   // Check for high impact news
   bool CheckHighImpactNews()
   {
      // Similar to CheckNewsEvents but specifically for high impact
      // This would check if there's high impact news coming up
      // that should trigger position closing
      
      // Placeholder implementation
      return false;
   }
};

//+------------------------------------------------------------------+
