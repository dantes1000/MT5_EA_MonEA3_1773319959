//+------------------------------------------------------------------+
//|                                                   RiskManager.mqh |
//|                        Copyright 2023, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| Risk Management Configuration Parameters                         |
//+------------------------------------------------------------------+
input double   RiskPercentPerTrade     = 1.0;      // Risk percentage per trade (%)
input double   MaxDailyDrawdownPercent = 4.0;      // Maximum daily drawdown (%)
input double   MaxTotalDrawdownPercent = 20.0;     // Maximum total drawdown (%)
input int      MaxSimultaneousTrades   = 1;        // Maximum simultaneous trades
input int      MaxTradesPerDay         = 3;        // Maximum trades per day
input int      MinTradeIntervalMinutes = 60;       // Minimum interval between trades (minutes)
input bool     UseATRForTP             = true;     // Use ATR for Take Profit (true) or fixed R:R (false)
input double   FixedRRRatio            = 2.0;      // Fixed Risk:Reward ratio (if UseATRForTP=false)
input int      ATRPeriod               = 14;       // ATR period for dynamic TP
input double   ATRMultiplier           = 2.0;      // ATR multiplier for TP distance

//+------------------------------------------------------------------+
//| Risk Manager Class                                               |
//+------------------------------------------------------------------+
class CRiskManager
{
private:
   double      m_accountEquity;
   double      m_accountBalance;
   double      m_dailyEquityHigh;
   double      m_totalEquityHigh;
   datetime    m_lastTradeTime;
   int         m_tradesTodayCount;
   datetime    m_lastTradeDay;
   
   // Calculate lot size based on risk percentage
   double CalculateLotSize(string symbol, double stopLossPoints, double riskPercent)
   {
      double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
      double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
      double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
      
      if(tickSize <= 0 || tickValue <= 0 || lotStep <= 0)
         return 0.0;
      
      double riskAmount = m_accountEquity * (riskPercent / 100.0);
      double pointsValue = tickValue / (tickSize / Point());
      double lotSize = riskAmount / (stopLossPoints * pointsValue);
      
      // Normalize to lot step
      lotSize = MathFloor(lotSize / lotStep) * lotStep;
      
      // Apply minimum and maximum lot constraints
      double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
      double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
      
      lotSize = MathMax(lotSize, minLot);
      lotSize = MathMin(lotSize, maxLot);
      
      return lotSize;
   }
   
   // Calculate stop loss at opposite range level
   double CalculateStopLoss(string symbol, ENUM_ORDER_TYPE orderType, double entryPrice, double rangeHigh, double rangeLow)
   {
      if(orderType == ORDER_TYPE_BUY)
      {
         // For buy orders, stop loss below range low
         return rangeLow;
      }
      else if(orderType == ORDER_TYPE_SELL)
      {
         // For sell orders, stop loss above range high
         return rangeHigh;
      }
      return 0.0;
   }
   
   // Calculate take profit based on ATR or fixed R:R
   double CalculateTakeProfit(string symbol, ENUM_ORDER_TYPE orderType, double entryPrice, double stopLossPrice)
   {
      double stopLossDistance = MathAbs(entryPrice - stopLossPrice);
      
      if(UseATRForTP)
      {
         // Dynamic TP based on ATR
         double atrValue = iATR(symbol, PERIOD_CURRENT, ATRPeriod, 0);
         double tpDistance = atrValue * ATRMultiplier;
         
         if(orderType == ORDER_TYPE_BUY)
            return entryPrice + tpDistance;
         else if(orderType == ORDER_TYPE_SELL)
            return entryPrice - tpDistance;
      }
      else
      {
         // Fixed R:R ratio
         double tpDistance = stopLossDistance * FixedRRRatio;
         
         if(orderType == ORDER_TYPE_BUY)
            return entryPrice + tpDistance;
         else if(orderType == ORDER_TYPE_SELL)
            return entryPrice - tpDistance;
      }
      
      return 0.0;
   }
   
   // Check if daily drawdown limit is reached
   bool IsDailyDrawdownLimitReached()
   {
      double currentDrawdownPercent = ((m_dailyEquityHigh - m_accountEquity) / m_dailyEquityHigh) * 100.0;
      return (currentDrawdownPercent >= MaxDailyDrawdownPercent);
   }
   
   // Check if total drawdown limit is reached
   bool IsTotalDrawdownLimitReached()
   {
      double currentDrawdownPercent = ((m_totalEquityHigh - m_accountEquity) / m_totalEquityHigh) * 100.0;
      return (currentDrawdownPercent >= MaxTotalDrawdownPercent);
   }
   
   // Check if maximum simultaneous trades limit is reached
   bool IsMaxSimultaneousTradesReached()
   {
      int openPositions = PositionsTotal();
      return (openPositions >= MaxSimultaneousTrades);
   }
   
   // Check if maximum trades per day limit is reached
   bool IsMaxTradesPerDayReached()
   {
      MqlDateTime currentTime;
      TimeToStruct(TimeCurrent(), currentTime);
      
      // Reset counter if new day
      if(m_lastTradeDay != currentTime.day)
      {
         m_tradesTodayCount = 0;
         m_lastTradeDay = currentTime.day;
         m_dailyEquityHigh = m_accountEquity;
      }
      
      return (m_tradesTodayCount >= MaxTradesPerDay);
   }
   
   // Check if minimum trade interval has passed
   bool IsTradeIntervalRespected()
   {
      if(m_lastTradeTime == 0)
         return true;
      
      datetime currentTime = TimeCurrent();
      int secondsSinceLastTrade = (int)(currentTime - m_lastTradeTime);
      int requiredSeconds = MinTradeIntervalMinutes * 60;
      
      return (secondsSinceLastTrade >= requiredSeconds);
   }
   
public:
   // Constructor
   CRiskManager()
   {
      m_accountEquity = AccountInfoDouble(ACCOUNT_EQUITY);
      m_accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      m_dailyEquityHigh = m_accountEquity;
      m_totalEquityHigh = m_accountEquity;
      m_lastTradeTime = 0;
      m_tradesTodayCount = 0;
      
      MqlDateTime currentTime;
      TimeToStruct(TimeCurrent(), currentTime);
      m_lastTradeDay = currentTime.day;
   }
   
   // Destructor
   ~CRiskManager() {}
   
   // Update account information
   void UpdateAccountInfo()
   {
      m_accountEquity = AccountInfoDouble(ACCOUNT_EQUITY);
      m_accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      
      // Update equity highs
      if(m_accountEquity > m_dailyEquityHigh)
         m_dailyEquityHigh = m_accountEquity;
      
      if(m_accountEquity > m_totalEquityHigh)
         m_totalEquityHigh = m_accountEquity;
   }
   
   // Check if new trade is allowed
   bool IsTradeAllowed()
   {
      UpdateAccountInfo();
      
      if(IsDailyDrawdownLimitReached())
      {
         Print("Daily drawdown limit reached!");
         return false;
      }
      
      if(IsTotalDrawdownLimitReached())
      {
         Print("Total drawdown limit reached!");
         return false;
      }
      
      if(IsMaxSimultaneousTradesReached())
      {
         Print("Maximum simultaneous trades limit reached!");
         return false;
      }
      
      if(IsMaxTradesPerDayReached())
      {
         Print("Maximum trades per day limit reached!");
         return false;
      }
      
      if(!IsTradeIntervalRespected())
      {
         Print("Minimum trade interval not respected!");
         return false;
      }
      
      return true;
   }
   
   // Calculate position parameters
   bool CalculatePositionParams(string symbol, ENUM_ORDER_TYPE orderType, double entryPrice, 
                                double rangeHigh, double rangeLow,
                                double &lotSize, double &stopLoss, double &takeProfit)
   {
      if(!IsTradeAllowed())
         return false;
      
      // Calculate stop loss
      stopLoss = CalculateStopLoss(symbol, orderType, entryPrice, rangeHigh, rangeLow);
      if(stopLoss == 0.0)
         return false;
      
      // Calculate stop loss distance in points
      double stopLossPoints = MathAbs(entryPrice - stopLoss) / Point();
      
      // Calculate lot size
      lotSize = CalculateLotSize(symbol, stopLossPoints, RiskPercentPerTrade);
      if(lotSize == 0.0)
         return false;
      
      // Calculate take profit
      takeProfit = CalculateTakeProfit(symbol, orderType, entryPrice, stopLoss);
      if(takeProfit == 0.0)
         return false;
      
      return true;
   }
   
   // Record trade execution
   void RecordTradeExecution()
   {
      m_lastTradeTime = TimeCurrent();
      m_tradesTodayCount++;
      
      MqlDateTime currentTime;
      TimeToStruct(TimeCurrent(), currentTime);
      m_lastTradeDay = currentTime.day;
   }
   
   // Get current risk statistics
   void GetRiskStats(double &dailyDrawdownPercent, double &totalDrawdownPercent, 
                     int &tradesToday, int &minutesSinceLastTrade)
   {
      UpdateAccountInfo();
      
      dailyDrawdownPercent = ((m_dailyEquityHigh - m_accountEquity) / m_dailyEquityHigh) * 100.0;
      totalDrawdownPercent = ((m_totalEquityHigh - m_accountEquity) / m_totalEquityHigh) * 100.0;
      
      tradesToday = m_tradesTodayCount;
      
      if(m_lastTradeTime == 0)
         minutesSinceLastTrade = 0;
      else
         minutesSinceLastTrade = (int)((TimeCurrent() - m_lastTradeTime) / 60);
   }
};

//+------------------------------------------------------------------+
//| Global Risk Manager Instance                                     |
//+------------------------------------------------------------------+
CRiskManager RiskManager;

//+------------------------------------------------------------------+
//| Helper Functions                                                 |
//+------------------------------------------------------------------+

// Function to get the opposite range level for stop loss
// This should be implemented in your main EA based on your trading strategy
// Example implementation:
/*
bool GetRangeLevels(string symbol, double &rangeHigh, double &rangeLow)
{
   // Implement your range calculation logic here
   // For example, using recent high/low or support/resistance levels
   
   // This is just an example - replace with your actual logic
   rangeHigh = iHigh(symbol, PERIOD_CURRENT, 1);
   rangeLow = iLow(symbol, PERIOD_CURRENT, 1);
   
   return (rangeHigh > 0 && rangeLow > 0);
}
*/

//+------------------------------------------------------------------+
//| Example Usage in Expert Advisor                                  |
//+------------------------------------------------------------------+
/*
// In your EA's OnTick() function:

// 1. Check if trade is allowed
if(RiskManager.IsTradeAllowed())
{
   // 2. Get range levels (implement this function in your EA)
   double rangeHigh, rangeLow;
   if(GetRangeLevels(Symbol(), rangeHigh, rangeLow))
   {
      // 3. Calculate position parameters
      double lotSize, stopLoss, takeProfit;
      ENUM_ORDER_TYPE orderType = ORDER_TYPE_BUY; // Set based on your signal
      double entryPrice = SymbolInfoDouble(Symbol(), SYMBOL_ASK); // For buy orders
      
      if(RiskManager.CalculatePositionParams(Symbol(), orderType, entryPrice, 
                                            rangeHigh, rangeLow,
                                            lotSize, stopLoss, takeProfit))
      {
         // 4. Execute trade (implement your trade execution logic)
         // ...
         
         // 5. Record trade execution
         RiskManager.RecordTradeExecution();
      }
   }
}

// Get risk statistics for display
void DisplayRiskStats()
{
   double dailyDD, totalDD;
   int tradesToday, minutesSinceLastTrade;
   
   RiskManager.GetRiskStats(dailyDD, totalDD, tradesToday, minutesSinceLastTrade);
   
   Comment(StringFormat("Daily DD: %.2f%%, Total DD: %.2f%%, Trades Today: %d, Last Trade: %d min ago",
                        dailyDD, totalDD, tradesToday, minutesSinceLastTrade));
}
*/
//+------------------------------------------------------------------+