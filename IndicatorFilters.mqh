//+------------------------------------------------------------------+
//|                                                      IndicatorFilters.mqh |
//|                        Copyright 2023, MetaQuotes Ltd.             |
//|                                             https://www.mql5.com   |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| Indicator Filter Configuration Parameters                        |
//+------------------------------------------------------------------+
input double   InpATRMinVolatility     = 0.0010;   // Minimum ATR volatility filter (0.001 = 10 pips)
input double   InpATRMaxVolatility     = 0.0100;   // Maximum ATR volatility filter (0.010 = 100 pips)
input double   InpBBWidthMin           = 0.0015;   // Minimum Bollinger Bands width
input double   InpBBWidthMax           = 0.0150;   // Maximum Bollinger Bands width
input int      InpBBPeriod             = 20;       // Bollinger Bands period
input double   InpBBDeviation          = 2.0;      // Bollinger Bands deviation
input int      InpEMAPeriod            = 200;      // EMA period for trend filter (H1)
input double   InpADXMinStrength       = 25.0;     // Minimum ADX trend strength
input int      InpADXPeriod            = 14;       // ADX period
input double   InpRSIOverbought        = 70.0;     // RSI overbought level (exclusion zone)
input double   InpRSIOversold          = 30.0;     // RSI oversold level (exclusion zone)
input int      InpRSIPeriod            = 14;       // RSI period
input double   InpVolumeThreshold      = 1.5;      // Volume confirmation threshold (x SMA20)
input int      InpVolumeSMAPeriod      = 20;       // Volume SMA period
input int      InpTradingStartHour     = 8;        // Trading start hour (GMT)
input int      InpTradingEndHour       = 21;       // Trading end hour (GMT) - Friday close
input bool     InpCloseBeforeWeekend   = true;     // Close positions before weekend (Friday 21:00 GMT)

//+------------------------------------------------------------------+
//| Indicator Filter Class                                           |
//+------------------------------------------------------------------+
class CIndicatorFilters
{
private:
   // Handle declarations
   int               m_atr_handle;
   int               m_bb_handle;
   int               m_ema_handle;
   int               m_adx_handle;
   int               m_rsi_handle;
   int               m_volume_handle;
   int               m_volume_sma_handle;
   
   // Time variables
   datetime          m_last_bar_time;
   
   // Error tracking
   string            m_error_msg;
   
   // Helper methods
   bool              InitializeHandles();
   bool              CheckTimeFilters();
   bool              IsTradingAllowed();
   
public:
   // Constructor/Destructor
                     CIndicatorFilters();
                    ~CIndicatorFilters();
   
   // Initialization
   bool              Init();
   void              Deinit();
   
   // Main filter methods
   bool              CheckATRFilter();
   bool              CheckBBFilter();
   bool              CheckEMAFilter();
   bool              CheckADXFilter();
   bool              CheckRSIFilter();
   bool              CheckVolumeFilter();
   bool              CheckAllFilters();
   
   // Time filter methods
   bool              CheckTradingTime();
   bool              CheckSessionTime();
   bool              CheckWeekendClose();
   
   // Utility methods
   string            GetError() const { return m_error_msg; }
   void              ClearError() { m_error_msg = ""; }
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CIndicatorFilters::CIndicatorFilters() :
   m_atr_handle(INVALID_HANDLE),
   m_bb_handle(INVALID_HANDLE),
   m_ema_handle(INVALID_HANDLE),
   m_adx_handle(INVALID_HANDLE),
   m_rsi_handle(INVALID_HANDLE),
   m_volume_handle(INVALID_HANDLE),
   m_volume_sma_handle(INVALID_HANDLE),
   m_last_bar_time(0),
   m_error_msg("")
{
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CIndicatorFilters::~CIndicatorFilters()
{
   Deinit();
}

//+------------------------------------------------------------------+
//| Initialize indicator handles                                     |
//+------------------------------------------------------------------+
bool CIndicatorFilters::InitializeHandles()
{
   // Initialize ATR handle
   m_atr_handle = iATR(_Symbol, PERIOD_CURRENT, 14);
   if(m_atr_handle == INVALID_HANDLE)
   {
      m_error_msg = "Failed to create ATR indicator";
      return false;
   }
   
   // Initialize Bollinger Bands handle
   m_bb_handle = iBands(_Symbol, PERIOD_CURRENT, InpBBPeriod, 0, InpBBDeviation, PRICE_CLOSE);
   if(m_bb_handle == INVALID_HANDLE)
   {
      m_error_msg = "Failed to create Bollinger Bands indicator";
      return false;
   }
   
   // Initialize EMA handle (H1 timeframe)
   m_ema_handle = iMA(_Symbol, PERIOD_H1, InpEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   if(m_ema_handle == INVALID_HANDLE)
   {
      m_error_msg = "Failed to create EMA indicator";
      return false;
   }
   
   // Initialize ADX handle
   m_adx_handle = iADX(_Symbol, PERIOD_CURRENT, InpADXPeriod);
   if(m_adx_handle == INVALID_HANDLE)
   {
      m_error_msg = "Failed to create ADX indicator";
      return false;
   }
   
   // Initialize RSI handle
   m_rsi_handle = iRSI(_Symbol, PERIOD_CURRENT, InpRSIPeriod, PRICE_CLOSE);
   if(m_rsi_handle == INVALID_HANDLE)
   {
      m_error_msg = "Failed to create RSI indicator";
      return false;
   }
   
   // Initialize Volume handle
   m_volume_handle = iVolumes(_Symbol, PERIOD_CURRENT, VOLUME_TICK);
   if(m_volume_handle == INVALID_HANDLE)
   {
      m_error_msg = "Failed to create Volume indicator";
      return false;
   }
   
   // Initialize Volume SMA handle
   m_volume_sma_handle = iMAOnArray(GetVolumeBuffer(), 0, InpVolumeSMAPeriod, 0, MODE_SMA, 0);
   if(m_volume_sma_handle == INVALID_HANDLE)
   {
      m_error_msg = "Failed to create Volume SMA indicator";
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Get volume buffer for SMA calculation                           |
//+------------------------------------------------------------------+
double GetVolumeBuffer()
{
   double volume_buffer[];
   ArraySetAsSeries(volume_buffer, true);
   
   if(CopyBuffer(m_volume_handle, 0, 0, InpVolumeSMAPeriod + 1, volume_buffer) <= 0)
   {
      return 0;
   }
   
   return volume_buffer;
}

//+------------------------------------------------------------------+
//| Initialize the filter system                                     |
//+------------------------------------------------------------------+
bool CIndicatorFilters::Init()
{
   ClearError();
   
   if(!InitializeHandles())
   {
      return false;
   }
   
   m_last_bar_time = iTime(_Symbol, PERIOD_CURRENT, 0);
   
   return true;
}

//+------------------------------------------------------------------+
//| Deinitialize the filter system                                   |
//+------------------------------------------------------------------+
void CIndicatorFilters::Deinit()
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
   
   if(m_volume_sma_handle != INVALID_HANDLE)
   {
      IndicatorRelease(m_volume_sma_handle);
      m_volume_sma_handle = INVALID_HANDLE;
   }
}

//+------------------------------------------------------------------+
//| Check ATR volatility filter                                      |
//| Returns: true if volatility is within min/max range              |
//+------------------------------------------------------------------+
bool CIndicatorFilters::CheckATRFilter()
{
   double atr_buffer[1];
   
   if(CopyBuffer(m_atr_handle, 0, 0, 1, atr_buffer) <= 0)
   {
      m_error_msg = "Failed to copy ATR buffer";
      return false;
   }
   
   double current_atr = atr_buffer[0];
   
   // Check if ATR is within specified range
   if(current_atr < InpATRMinVolatility || current_atr > InpATRMaxVolatility)
   {
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Check Bollinger Bands width filter                               |
//| Returns: true if BB width is within min/max range                |
//+------------------------------------------------------------------+
bool CIndicatorFilters::CheckBBFilter()
{
   double upper_buffer[1], lower_buffer[1];
   
   if(CopyBuffer(m_bb_handle, 1, 0, 1, upper_buffer) <= 0 ||
      CopyBuffer(m_bb_handle, 2, 0, 1, lower_buffer) <= 0)
   {
      m_error_msg = "Failed to copy Bollinger Bands buffers";
      return false;
   }
   
   double bb_width = upper_buffer[0] - lower_buffer[0];
   
   // Check if BB width is within specified range
   if(bb_width < InpBBWidthMin || bb_width > InpBBWidthMax)
   {
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Check EMA trend filter                                           |
//| Returns: true if price is above EMA200 (H1) for long trades      |
//|          or below EMA200 (H1) for short trades                   |
//+------------------------------------------------------------------+
bool CIndicatorFilters::CheckEMAFilter()
{
   double ema_buffer[1];
   double current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   if(CopyBuffer(m_ema_handle, 0, 0, 1, ema_buffer) <= 0)
   {
      m_error_msg = "Failed to copy EMA buffer";
      return false;
   }
   
   double ema_value = ema_buffer[0];
   
   // For long trades: price must be above EMA200
   // For short trades: price must be below EMA200
   // This method should be called with trade direction context
   return true; // Placeholder - actual implementation depends on trade direction
}

//+------------------------------------------------------------------+
//| Check ADX trend strength filter                                  |
//| Returns: true if ADX is above minimum strength                   |
//+------------------------------------------------------------------+
bool CIndicatorFilters::CheckADXFilter()
{
   double adx_buffer[1];
   
   if(CopyBuffer(m_adx_handle, 0, 0, 1, adx_buffer) <= 0)
   {
      m_error_msg = "Failed to copy ADX buffer";
      return false;
   }
   
   double current_adx = adx_buffer[0];
   
   // Check if ADX is above minimum strength
   if(current_adx < InpADXMinStrength)
   {
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Check RSI overbought/oversold filter                             |
//| Returns: true if RSI is NOT in overbought/oversold zones         |
//+------------------------------------------------------------------+
bool CIndicatorFilters::CheckRSIFilter()
{
   double rsi_buffer[1];
   
   if(CopyBuffer(m_rsi_handle, 0, 0, 1, rsi_buffer) <= 0)
   {
      m_error_msg = "Failed to copy RSI buffer";
      return false;
   }
   
   double current_rsi = rsi_buffer[0];
   
   // Check if RSI is in exclusion zones
   if(current_rsi > InpRSIOverbought || current_rsi < InpRSIOversold)
   {
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Check volume confirmation filter                                 |
//| Returns: true if current volume > SMA20 * threshold              |
//+------------------------------------------------------------------+
bool CIndicatorFilters::CheckVolumeFilter()
{
   double volume_buffer[1];
   double volume_sma_buffer[1];
   
   if(CopyBuffer(m_volume_handle, 0, 0, 1, volume_buffer) <= 0)
   {
      m_error_msg = "Failed to copy Volume buffer";
      return false;
   }
   
   if(CopyBuffer(m_volume_sma_handle, 0, 0, 1, volume_sma_buffer) <= 0)
   {
      m_error_msg = "Failed to copy Volume SMA buffer";
      return false;
   }
   
   double current_volume = volume_buffer[0];
   double volume_sma = volume_sma_buffer[0];
   
   // Check if volume is above threshold
   if(current_volume <= volume_sma * InpVolumeThreshold)
   {
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Check all indicator filters                                      |
//| Returns: true if ALL filters pass                                |
//+------------------------------------------------------------------+
bool CIndicatorFilters::CheckAllFilters()
{
   ClearError();
   
   if(!CheckATRFilter())
   {
      m_error_msg = "ATR filter failed";
      return false;
   }
   
   if(!CheckBBFilter())
   {
      m_error_msg = "Bollinger Bands filter failed";
      return false;
   }
   
   if(!CheckADXFilter())
   {
      m_error_msg = "ADX filter failed";
      return false;
   }
   
   if(!CheckRSIFilter())
   {
      m_error_msg = "RSI filter failed";
      return false;
   }
   
   if(!CheckVolumeFilter())
   {
      m_error_msg = "Volume filter failed";
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Check trading time window                                        |
//| Returns: true if current time is within trading hours            |
//+------------------------------------------------------------------+
bool CIndicatorFilters::CheckTradingTime()
{
   MqlDateTime time_struct;
   TimeToStruct(TimeCurrent(), time_struct);
   
   int current_hour = time_struct.hour;
   
   // Check if current hour is after trading start (8:00 GMT)
   if(current_hour < InpTradingStartHour)
   {
      return false;
   }
   
   // Check if it's Friday and after trading end (21:00 GMT)
   if(time_struct.day_of_week == 5 && current_hour >= InpTradingEndHour)
   {
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Check market session time                                        |
//| Returns: true if current time is in Asian session (0-6h GMT)     |
//|          for calculation or London session for entry             |
//+------------------------------------------------------------------+
bool CIndicatorFilters::CheckSessionTime()
{
   MqlDateTime time_struct;
   TimeToStruct(TimeCurrent(), time_struct);
   
   int current_hour = time_struct.hour;
   
   // Asian session: 0-6h GMT (for calculation)
   // London session: 8h+ GMT (for entry)
   // This is handled by CheckTradingTime() for entry timing
   
   return true;
}

//+------------------------------------------------------------------+
//| Check weekend close condition                                    |
//| Returns: true if positions should be closed before weekend       |
//+------------------------------------------------------------------+
bool CIndicatorFilters::CheckWeekendClose()
{
   if(!InpCloseBeforeWeekend)
   {
      return false;
   }
   
   MqlDateTime time_struct;
   TimeToStruct(TimeCurrent(), time_struct);
   
   // Check if it's Friday and after 21:00 GMT
   if(time_struct.day_of_week == 5 && time_struct.hour >= InpTradingEndHour)
   {
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Check if trading is currently allowed                            |
//| Returns: true if all time filters pass                           |
//+------------------------------------------------------------------+
bool CIndicatorFilters::IsTradingAllowed()
{
   if(!CheckTradingTime())
   {
      return false;
   }
   
   if(CheckWeekendClose())
   {
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Global instance of indicator filters                             |
//+------------------------------------------------------------------+
CIndicatorFilters IndicatorFilters;

//+------------------------------------------------------------------+
