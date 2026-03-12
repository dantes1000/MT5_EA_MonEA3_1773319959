//+------------------------------------------------------------------+
//|                                                      NewsFilter.mqh |
//|                        Manages economic news filtering and trading |
//+------------------------------------------------------------------+
#property copyright ""
#property link      ""
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| Input parameters for indicator filters                           |
//+------------------------------------------------------------------+
input double   InpMinATR = 0.0005;          // Minimum ATR for volatility filter
input double   InpMaxATR = 0.0020;          // Maximum ATR for volatility filter
input double   InpMinBBWidth = 0.0010;      // Minimum Bollinger Bands width
input double   InpMaxBBWidth = 0.0050;      // Maximum Bollinger Bands width
input int      InpADXPeriod = 14;           // ADX period
input double   InpMinADX = 25.0;            // Minimum ADX strength
input int      InpRSIPeriod = 14;           // RSI period
input double   InpRSIOverbought = 70.0;     // RSI overbought level
input double   InpRSIOversold = 30.0;       // RSI oversold level
input int      InpVolumeSMA = 20;           // Volume SMA period
input double   InpVolumeThreshold = 1.5;    // Volume threshold multiplier

//+------------------------------------------------------------------+
//| Input parameters for time filters                                |
//+------------------------------------------------------------------+
input int      InpTradingStartHour = 8;     // Trading start hour (GMT)
input int      InpTradingEndHour = 21;      // Trading end hour (GMT)
input int      InpNewsPreBuffer = 60;       // Minutes before high-impact news
input int      InpNewsPostBuffer = 30;      // Minutes after high-impact news

//+------------------------------------------------------------------+
//| Input parameters for FFCal integration                           |
//+------------------------------------------------------------------+
input string   InpFFCalSymbol = "EURUSD";   // Symbol for FFCal news
input int      InpFFCalImpact = 3;          // Minimum impact level (1-3)

//+------------------------------------------------------------------+
//| Enumerations                                                     |
//+------------------------------------------------------------------+
enum ENUM_TREND_DIRECTION
{
   TREND_UP,      // Uptrend
   TREND_DOWN,    // Downtrend
   TREND_SIDEWAYS // Sideways
};

//+------------------------------------------------------------------+
//| Class CNewsFilter                                                |
//+------------------------------------------------------------------+
class CNewsFilter
{
private:
   // Indicator handles
   int            m_atr_handle;
   int            m_bb_handle;
   int            m_ema_handle;
   int            m_adx_handle;
   int            m_rsi_handle;
   int            m_volume_handle;
   
   // Time variables
   datetime       m_last_check_time;
   
   // Helper methods
   bool           CheckIndicatorFilters();
   bool           CheckTimeFilters();
   bool           CheckNewsFilter();
   double         GetATRValue();
   double         GetBBWidth();
   ENUM_TREND_DIRECTION GetTrendDirection();
   double         GetADXValue();
   double         GetRSIValue();
   bool           CheckVolume();
   bool           IsHighImpactNewsNear();
   
public:
                  CNewsFilter();
                 ~CNewsFilter();
   bool           Initialize();
   void           Deinitialize();
   bool           CanOpenTrade();
   bool           ShouldCloseTrades();
   datetime       GetNextNewsTime();
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CNewsFilter::CNewsFilter() :
   m_atr_handle(INVALID_HANDLE),
   m_bb_handle(INVALID_HANDLE),
   m_ema_handle(INVALID_HANDLE),
   m_adx_handle(INVALID_HANDLE),
   m_rsi_handle(INVALID_HANDLE),
   m_volume_handle(INVALID_HANDLE),
   m_last_check_time(0)
{
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CNewsFilter::~CNewsFilter()
{
   Deinitialize();
}

//+------------------------------------------------------------------+
//| Initialize indicator handles                                     |
//+------------------------------------------------------------------+
bool CNewsFilter::Initialize()
{
   // Initialize ATR indicator
   m_atr_handle = iATR(_Symbol, PERIOD_H1, 14);
   if(m_atr_handle == INVALID_HANDLE)
   {
      Print("Failed to create ATR handle");
      return false;
   }
   
   // Initialize Bollinger Bands indicator
   m_bb_handle = iBands(_Symbol, PERIOD_H1, 20, 0, 2, PRICE_CLOSE);
   if(m_bb_handle == INVALID_HANDLE)
   {
      Print("Failed to create Bollinger Bands handle");
      return false;
   }
   
   // Initialize EMA indicator
   m_ema_handle = iMA(_Symbol, PERIOD_H1, 200, 0, MODE_EMA, PRICE_CLOSE);
   if(m_ema_handle == INVALID_HANDLE)
   {
      Print("Failed to create EMA handle");
      return false;
   }
   
   // Initialize ADX indicator
   m_adx_handle = iADX(_Symbol, PERIOD_H1, InpADXPeriod);
   if(m_adx_handle == INVALID_HANDLE)
   {
      Print("Failed to create ADX handle");
      return false;
   }
   
   // Initialize RSI indicator
   m_rsi_handle = iRSI(_Symbol, PERIOD_H1, InpRSIPeriod, PRICE_CLOSE);
   if(m_rsi_handle == INVALID_HANDLE)
   {
      Print("Failed to create RSI handle");
      return false;
   }
   
   // Initialize Volume indicator
   m_volume_handle = iVolumes(_Symbol, PERIOD_H1, VOLUME_TICK);
   if(m_volume_handle == INVALID_HANDLE)
   {
      Print("Failed to create Volume handle");
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Deinitialize indicator handles                                   |
//+------------------------------------------------------------------+
void CNewsFilter::Deinitialize()
{
   if(m_atr_handle != INVALID_HANDLE)
   {
      IndicatorRelease(m_atr_handle);
      m_atr_handle = INVALID_HANDLE;
   }
   
   if(m_bb_handle != INVALID_HANDLE)
   {
      IndicatorRelease(m_bb_handle);
      m_bb_handle = INVALID_HANDLE;
   }
   
   if(m_ema_handle != INVALID_HANDLE)
   {
      IndicatorRelease(m_ema_handle);
      m_ema_handle = INVALID_HANDLE;
   }
   
   if(m_adx_handle != INVALID_HANDLE)
   {
      IndicatorRelease(m_adx_handle);
      m_adx_handle = INVALID_HANDLE;
   }
   
   if(m_rsi_handle != INVALID_HANDLE)
   {
      IndicatorRelease(m_rsi_handle);
      m_rsi_handle = INVALID_HANDLE;
   }
   
   if(m_volume_handle != INVALID_HANDLE)
   {
      IndicatorRelease(m_volume_handle);
      m_volume_handle = INVALID_HANDLE;
   }
}

//+------------------------------------------------------------------+
//| Check if trade can be opened                                     |
//+------------------------------------------------------------------+
bool CNewsFilter::CanOpenTrade()
{
   // Check all filters
   if(!CheckIndicatorFilters())
      return false;
   
   if(!CheckTimeFilters())
      return false;
   
   if(!CheckNewsFilter())
      return false;
   
   return true;
}

//+------------------------------------------------------------------+
//| Check if trades should be closed                                 |
//+------------------------------------------------------------------+
bool CNewsFilter::ShouldCloseTrades()
{
   MqlDateTime dt;
   TimeCurrent(dt);
   
   // Close positions before weekend (Friday 21:00 GMT)
   if(dt.day_of_week == 5 && dt.hour >= 21) // Friday 21:00 GMT
      return true;
   
   // Close positions before high-impact news
   if(IsHighImpactNewsNear())
      return true;
   
   return false;
}

//+------------------------------------------------------------------+
//| Check indicator filters                                          |
//+------------------------------------------------------------------+
bool CNewsFilter::CheckIndicatorFilters()
{
   // Check ATR volatility filter
   double atr_value = GetATRValue();
   if(atr_value < InpMinATR || atr_value > InpMaxATR)
   {
      Print("ATR filter failed: ", atr_value);
      return false;
   }
   
   // Check Bollinger Bands width filter
   double bb_width = GetBBWidth();
   if(bb_width < InpMinBBWidth || bb_width > InpMaxBBWidth)
   {
      Print("BB width filter failed: ", bb_width);
      return false;
   }
   
   // Check EMA trend filter
   ENUM_TREND_DIRECTION trend = GetTrendDirection();
   if(trend == TREND_SIDEWAYS)
   {
      Print("EMA trend filter failed");
      return false;
   }
   
   // Check ADX strength filter
   double adx_value = GetADXValue();
   if(adx_value < InpMinADX)
   {
      Print("ADX filter failed: ", adx_value);
      return false;
   }
   
   // Check RSI overbought/oversold filter
   double rsi_value = GetRSIValue();
   if(rsi_value > InpRSIOverbought || rsi_value < InpRSIOversold)
   {
      Print("RSI filter failed: ", rsi_value);
      return false;
   }
   
   // Check volume confirmation
   if(!CheckVolume())
   {
      Print("Volume filter failed");
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Check time filters                                               |
//+------------------------------------------------------------------+
bool CNewsFilter::CheckTimeFilters()
{
   MqlDateTime dt;
   TimeCurrent(dt);
   
   // Check trading hours (after 8h GMT - London open)
   if(dt.hour < InpTradingStartHour)
   {
      Print("Before trading hours");
      return false;
   }
   
   // Check trading days (all days allowed)
   // No restriction needed as per specifications
   
   return true;
}

//+------------------------------------------------------------------+
//| Check news filter                                                |
//+------------------------------------------------------------------+
bool CNewsFilter::CheckNewsFilter()
{
   // Check if high-impact news is near
   if(IsHighImpactNewsNear())
   {
      Print("High-impact news nearby - trading suspended");
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Get ATR value                                                    |
//+------------------------------------------------------------------+
double CNewsFilter::GetATRValue()
{
   double atr_buffer[1];
   if(CopyBuffer(m_atr_handle, 0, 0, 1, atr_buffer) <= 0)
      return 0.0;
   
   return atr_buffer[0];
}

//+------------------------------------------------------------------+
//| Get Bollinger Bands width                                        |
//+------------------------------------------------------------------+
double CNewsFilter::GetBBWidth()
{
   double upper_buffer[1], lower_buffer[1];
   if(CopyBuffer(m_bb_handle, 1, 0, 1, upper_buffer) <= 0 ||
      CopyBuffer(m_bb_handle, 2, 0, 1, lower_buffer) <= 0)
      return 0.0;
   
   return (upper_buffer[0] - lower_buffer[0]) / SymbolInfoDouble(_Symbol, SYMBOL_BID);
}

//+------------------------------------------------------------------+
//| Get trend direction based on EMA                                 |
//+------------------------------------------------------------------+
ENUM_TREND_DIRECTION CNewsFilter::GetTrendDirection()
{
   double ema_buffer[1];
   double close_buffer[1];
   
   if(CopyBuffer(m_ema_handle, 0, 0, 1, ema_buffer) <= 0)
      return TREND_SIDEWAYS;
   
   if(CopyClose(_Symbol, PERIOD_H1, 0, 1, close_buffer) <= 0)
      return TREND_SIDEWAYS;
   
   if(close_buffer[0] > ema_buffer[0])
      return TREND_UP;
   else if(close_buffer[0] < ema_buffer[0])
      return TREND_DOWN;
   
   return TREND_SIDEWAYS;
}

//+------------------------------------------------------------------+
//| Get ADX value                                                    |
//+------------------------------------------------------------------+
double CNewsFilter::GetADXValue()
{
   double adx_buffer[1];
   if(CopyBuffer(m_adx_handle, 0, 0, 1, adx_buffer) <= 0)
      return 0.0;
   
   return adx_buffer[0];
}

//+------------------------------------------------------------------+
//| Get RSI value                                                    |
//+------------------------------------------------------------------+
double CNewsFilter::GetRSIValue()
{
   double rsi_buffer[1];
   if(CopyBuffer(m_rsi_handle, 0, 0, 1, rsi_buffer) <= 0)
      return 50.0;
   
   return rsi_buffer[0];
}

//+------------------------------------------------------------------+
//| Check volume confirmation                                        |
//+------------------------------------------------------------------+
bool CNewsFilter::CheckVolume()
{
   double volume_buffer[InpVolumeSMA + 1];
   if(CopyBuffer(m_volume_handle, 0, 0, InpVolumeSMA + 1, volume_buffer) <= InpVolumeSMA)
      return false;
   
   // Calculate SMA of volume
   double volume_sma = 0;
   for(int i = 1; i <= InpVolumeSMA; i++)
      volume_sma += volume_buffer[i];
   volume_sma /= InpVolumeSMA;
   
   // Check current volume against SMA
   double current_volume = volume_buffer[0];
   if(current_volume < volume_sma * InpVolumeThreshold)
      return false;
   
   return true;
}

//+------------------------------------------------------------------+
//| Check if high-impact news is near                                |
//+------------------------------------------------------------------+
bool CNewsFilter::IsHighImpactNewsNear()
{
   // Note: This is a placeholder for FFCal integration
   // In a real implementation, you would integrate with FFCal indicator
   // to get actual news events and their impact levels
   
   // For demonstration purposes, this returns false
   // Actual implementation should:
   // 1. Get news events from FFCal for InpFFCalSymbol
   // 2. Check if any event with impact >= InpFFCalImpact is within
   //    InpNewsPreBuffer minutes before or InpNewsPostBuffer minutes after
   // 3. Return true if such news exists
   
   return false;
}

//+------------------------------------------------------------------+
//| Get next high-impact news time                                   |
//+------------------------------------------------------------------+
datetime CNewsFilter::GetNextNewsTime()
{
   // Note: This is a placeholder for FFCal integration
   // In a real implementation, you would query FFCal for the next
   // high-impact news event and return its timestamp
   
   return 0;
}

//+------------------------------------------------------------------+
