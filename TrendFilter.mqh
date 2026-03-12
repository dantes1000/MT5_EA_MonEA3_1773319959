//+------------------------------------------------------------------+
//|                                                      TrendFilter.mqh |
//|                        Implements strict EMA200 H1 trend filter     |
//|                     with optional ADX trend strength validation     |
//+------------------------------------------------------------------+
#property copyright ""
#property link      ""
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| Indicator Filter Input Parameters                                |
//+------------------------------------------------------------------+
input double   InpMinATR = 0.0010;          // Minimum ATR volatility filter
input double   InpMaxATR = 0.0100;          // Maximum ATR volatility filter
input double   InpMinBBWidth = 0.0010;      // Minimum Bollinger Bands width
input double   InpMaxBBWidth = 0.0200;      // Maximum Bollinger Bands width
input bool     InpUseEMA200Filter = true;   // Enable EMA200 H1 trend filter
input bool     InpUseADXValidation = true;  // Enable ADX trend strength validation
input int      InpADXPeriod = 14;           // ADX period
input double   InpMinADXStrength = 25.0;    // Minimum ADX trend strength
input double   InpRSIOverbought = 70.0;     // RSI overbought level
input double   InpRSIOversold = 30.0;       // RSI oversold level
input int      InpRSIPeriod = 14;           // RSI period
input bool     InpUseVolumeFilter = true;   // Enable volume confirmation
input int      InpVolumeSMAPeriod = 20;     // Volume SMA period
input double   InpVolumeThreshold = 1.5;    // Volume threshold multiplier

//+------------------------------------------------------------------+
//| Time Filter Input Parameters                                     |
//+------------------------------------------------------------------+
input int      InpTradingStartHour = 8;     // Trading start hour (GMT)
input int      InpTradingEndHour = 21;      // Trading end hour (GMT)
input bool     InpCloseBeforeWeekend = true;// Close positions before weekend
input int      InpWeekendCloseHour = 21;    // Friday close hour (GMT)

//+------------------------------------------------------------------+
//| Market Session Enum                                              |
//+------------------------------------------------------------------+
enum ENUM_MARKET_SESSION
{
   SESSION_ASIAN = 0,    // Asian session (0-6h GMT)
   SESSION_LONDON = 1,   // London session (8-16h GMT)
   SESSION_NEWYORK = 2,  // New York session (13-21h GMT)
   SESSION_ALL = 3       // All sessions
};

//+------------------------------------------------------------------+
//| Trend Direction Enum                                             |
//+------------------------------------------------------------------+
enum ENUM_TREND_DIRECTION
{
   TREND_UP = 1,         // Uptrend
   TREND_DOWN = -1,      // Downtrend
   TREND_NEUTRAL = 0     // No trend
};

//+------------------------------------------------------------------+
//| CTrendFilter Class                                               |
//+------------------------------------------------------------------+
class CTrendFilter
{
private:
   // Indicator handles
   int m_atr_handle;
   int m_bb_handle;
   int m_ema_handle;
   int m_adx_handle;
   int m_rsi_handle;
   int m_volume_handle;
   
   // Time variables
   datetime m_last_check_time;
   
   // Helper methods
   bool IsTradingTime();
   bool IsWeekendCloseTime();
   ENUM_MARKET_SESSION GetCurrentSession();
   
public:
   // Constructor/Destructor
   CTrendFilter();
   ~CTrendFilter();
   
   // Initialization
   bool Init();
   void Deinit();
   
   // Main filter method
   ENUM_TREND_DIRECTION CheckTrendFilter(int direction);
   
   // Individual filter methods
   bool CheckATRFilter();
   bool CheckBBFilter();
   bool CheckEMAFilter(int direction);
   bool CheckADXFilter();
   bool CheckRSIFilter(int direction);
   bool CheckVolumeFilter();
   bool CheckTimeFilter();
   bool ShouldCloseBeforeWeekend();
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CTrendFilter::CTrendFilter() :
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
CTrendFilter::~CTrendFilter()
{
   Deinit();
}

//+------------------------------------------------------------------+
//| Initialization method                                            |
//+------------------------------------------------------------------+
bool CTrendFilter::Init()
{
   // Create ATR indicator handle
   m_atr_handle = iATR(Symbol(), PERIOD_CURRENT, 14);
   if(m_atr_handle == INVALID_HANDLE)
   {
      Print("Failed to create ATR indicator handle");
      return false;
   }
   
   // Create Bollinger Bands indicator handle
   m_bb_handle = iBands(Symbol(), PERIOD_CURRENT, 20, 0, 2.0, PRICE_CLOSE);
   if(m_bb_handle == INVALID_HANDLE)
   {
      Print("Failed to create Bollinger Bands indicator handle");
      return false;
   }
   
   // Create EMA200 H1 indicator handle
   m_ema_handle = iMA(Symbol(), PERIOD_H1, 200, 0, MODE_EMA, PRICE_CLOSE);
   if(m_ema_handle == INVALID_HANDLE)
   {
      Print("Failed to create EMA200 indicator handle");
      return false;
   }
   
   // Create ADX indicator handle
   m_adx_handle = iADX(Symbol(), PERIOD_CURRENT, InpADXPeriod);
   if(m_adx_handle == INVALID_HANDLE)
   {
      Print("Failed to create ADX indicator handle");
      return false;
   }
   
   // Create RSI indicator handle
   m_rsi_handle = iRSI(Symbol(), PERIOD_CURRENT, InpRSIPeriod, PRICE_CLOSE);
   if(m_rsi_handle == INVALID_HANDLE)
   {
      Print("Failed to create RSI indicator handle");
      return false;
   }
   
   // Create Volume indicator handle
   m_volume_handle = iVolumes(Symbol(), PERIOD_CURRENT, VOLUME_TICK);
   if(m_volume_handle == INVALID_HANDLE)
   {
      Print("Failed to create Volume indicator handle");
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Deinitialization method                                          |
//+------------------------------------------------------------------+
void CTrendFilter::Deinit()
{
   // Release indicator handles
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
//| Check if current time is within trading hours                    |
//+------------------------------------------------------------------+
bool CTrendFilter::IsTradingTime()
{
   MqlDateTime dt;
   TimeGMT(dt);
   
   // Check if current hour is within trading hours
   if(dt.hour >= InpTradingStartHour && dt.hour < InpTradingEndHour)
   {
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Check if it's time to close positions before weekend             |
//+------------------------------------------------------------------+
bool CTrendFilter::IsWeekendCloseTime()
{
   if(!InpCloseBeforeWeekend) return false;
   
   MqlDateTime dt;
   TimeGMT(dt);
   
   // Check if it's Friday and after the close hour
   if(dt.day_of_week == 5 && dt.hour >= InpWeekendCloseHour)
   {
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Get current market session                                       |
//+------------------------------------------------------------------+
ENUM_MARKET_SESSION CTrendFilter::GetCurrentSession()
{
   MqlDateTime dt;
   TimeGMT(dt);
   
   if(dt.hour >= 0 && dt.hour < 6)
      return SESSION_ASIAN;
   else if(dt.hour >= 8 && dt.hour < 16)
      return SESSION_LONDON;
   else if(dt.hour >= 13 && dt.hour < 21)
      return SESSION_NEWYORK;
   
   return SESSION_ALL;
}

//+------------------------------------------------------------------+
//| Check ATR volatility filter                                      |
//+------------------------------------------------------------------+
bool CTrendFilter::CheckATRFilter()
{
   double atr_values[1];
   if(CopyBuffer(m_atr_handle, 0, 0, 1, atr_values) < 1)
      return false;
   
   double current_atr = atr_values[0];
   
   // Check if ATR is within specified range
   if(current_atr >= InpMinATR && current_atr <= InpMaxATR)
   {
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Check Bollinger Bands width filter                               |
//+------------------------------------------------------------------+
bool CTrendFilter::CheckBBFilter()
{
   double upper_band[1], lower_band[1];
   if(CopyBuffer(m_bb_handle, 1, 0, 1, upper_band) < 1 ||
      CopyBuffer(m_bb_handle, 2, 0, 1, lower_band) < 1)
      return false;
   
   double bb_width = upper_band[0] - lower_band[0];
   
   // Check if BB width is within specified range
   if(bb_width >= InpMinBBWidth && bb_width <= InpMaxBBWidth)
   {
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Check EMA200 H1 trend filter                                     |
//+------------------------------------------------------------------+
bool CTrendFilter::CheckEMAFilter(int direction)
{
   if(!InpUseEMA200Filter) return true;
   
   double ema_values[1];
   double close_prices[1];
   
   // Get EMA200 value from H1 timeframe
   if(CopyBuffer(m_ema_handle, 0, 0, 1, ema_values) < 1)
      return false;
   
   // Get current close price
   if(CopyClose(Symbol(), PERIOD_CURRENT, 0, 1, close_prices) < 1)
      return false;
   
   double current_ema = ema_values[0];
   double current_close = close_prices[0];
   
   // Check trend direction relative to EMA200
   if(direction == 1 && current_close > current_ema)
   {
      return true;  // Uptrend confirmed
   }
   else if(direction == -1 && current_close < current_ema)
   {
      return true;  // Downtrend confirmed
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Check ADX trend strength validation                              |
//+------------------------------------------------------------------+
bool CTrendFilter::CheckADXFilter()
{
   if(!InpUseADXValidation) return true;
   
   double adx_values[1];
   if(CopyBuffer(m_adx_handle, 0, 0, 1, adx_values) < 1)
      return false;
   
   double current_adx = adx_values[0];
   
   // Check if ADX is above minimum strength
   if(current_adx >= InpMinADXStrength)
   {
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Check RSI overbought/oversold filter                             |
//+------------------------------------------------------------------+
bool CTrendFilter::CheckRSIFilter(int direction)
{
   double rsi_values[1];
   if(CopyBuffer(m_rsi_handle, 0, 0, 1, rsi_values) < 1)
      return false;
   
   double current_rsi = rsi_values[0];
   
   // For buy signals, avoid overbought conditions
   if(direction == 1 && current_rsi >= InpRSIOverbought)
   {
      return false;
   }
   
   // For sell signals, avoid oversold conditions
   if(direction == -1 && current_rsi <= InpRSIOversold)
   {
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Check volume confirmation filter                                 |
//+------------------------------------------------------------------+
bool CTrendFilter::CheckVolumeFilter()
{
   if(!InpUseVolumeFilter) return true;
   
   double volume_values[InpVolumeSMAPeriod + 1];
   if(CopyBuffer(m_volume_handle, 0, 0, InpVolumeSMAPeriod + 1, volume_values) < InpVolumeSMAPeriod + 1)
      return false;
   
   // Calculate SMA of volume
   double volume_sma = 0;
   for(int i = 1; i <= InpVolumeSMAPeriod; i++)
   {
      volume_sma += volume_values[i];
   }
   volume_sma /= InpVolumeSMAPeriod;
   
   double current_volume = volume_values[0];
   
   // Check if current volume is above threshold
   if(current_volume > volume_sma * InpVolumeThreshold)
   {
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Check time filter                                                |
//+------------------------------------------------------------------+
bool CTrendFilter::CheckTimeFilter()
{
   // Only allow trading during London session for entries
   ENUM_MARKET_SESSION current_session = GetCurrentSession();
   
   if(current_session == SESSION_LONDON && IsTradingTime())
   {
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Check if positions should be closed before weekend               |
//+------------------------------------------------------------------+
bool CTrendFilter::ShouldCloseBeforeWeekend()
{
   return IsWeekendCloseTime();
}

//+------------------------------------------------------------------+
//| Main trend filter method                                         |
//| direction: 1 for buy, -1 for sell                                |
//| Returns: TREND_UP, TREND_DOWN, or TREND_NEUTRAL                  |
//+------------------------------------------------------------------+
ENUM_TREND_DIRECTION CTrendFilter::CheckTrendFilter(int direction)
{
   // Check time filter first (only trade during London session)
   if(!CheckTimeFilter())
   {
      return TREND_NEUTRAL;
   }
   
   // Check all indicator filters
   if(!CheckATRFilter())
   {
      return TREND_NEUTRAL;
   }
   
   if(!CheckBBFilter())
   {
      return TREND_NEUTRAL;
   }
   
   if(!CheckEMAFilter(direction))
   {
      return TREND_NEUTRAL;
   }
   
   if(!CheckADXFilter())
   {
      return TREND_NEUTRAL;
   }
   
   if(!CheckRSIFilter(direction))
   {
      return TREND_NEUTRAL;
   }
   
   if(!CheckVolumeFilter())
   {
      return TREND_NEUTRAL;
   }
   
   // All filters passed
   if(direction == 1)
   {
      return TREND_UP;
   }
   else if(direction == -1)
   {
      return TREND_DOWN;
   }
   
   return TREND_NEUTRAL;
}
//+------------------------------------------------------------------+