//+------------------------------------------------------------------+
//|                                                      Utilities.mqh |
//|                        Copyright 2023, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| Utility functions for pip calculations, timeframe conversions,   |
//| error handling, and logging                                      |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Pip calculation functions                                        |
//+------------------------------------------------------------------+

//--- Calculate pip value for current symbol
double PipValue()
{
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   if(point == 0 || tickSize == 0) return(0);
   
   return((tickValue * point) / tickSize);
}

//--- Convert pips to price points
double PipsToPoints(double pips)
{
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double digits = SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   
   if(digits == 3 || digits == 5) // 5-digit brokers
      return(pips * 10 * point);
   else // 4-digit brokers
      return(pips * point);
}

//--- Convert price points to pips
double PointsToPips(double points)
{
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double digits = SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   
   if(point == 0) return(0);
   
   if(digits == 3 || digits == 5) // 5-digit brokers
      return(points / (10 * point));
   else // 4-digit brokers
      return(points / point);
}

//--- Calculate stop loss in pips from price
double CalculateStopLossPips(double entryPrice, double stopLossPrice, bool isBuy)
{
   if(isBuy)
      return(PointsToPips(entryPrice - stopLossPrice));
   else
      return(PointsToPips(stopLossPrice - entryPrice));
}

//--- Calculate take profit in pips from price
double CalculateTakeProfitPips(double entryPrice, double takeProfitPrice, bool isBuy)
{
   if(isBuy)
      return(PointsToPips(takeProfitPrice - entryPrice));
   else
      return(PointsToPips(entryPrice - takeProfitPrice));
}

//+------------------------------------------------------------------+
//| Timeframe conversion functions                                   |
//+------------------------------------------------------------------+

//--- Convert ENUM_TIMEFRAMES to string
string TimeframeToString(ENUM_TIMEFRAMES tf)
{
   switch(tf)
   {
      case PERIOD_M1:   return "M1";
      case PERIOD_M2:   return "M2";
      case PERIOD_M3:   return "M3";
      case PERIOD_M4:   return "M4";
      case PERIOD_M5:   return "M5";
      case PERIOD_M6:   return "M6";
      case PERIOD_M10:  return "M10";
      case PERIOD_M12:  return "M12";
      case PERIOD_M15:  return "M15";
      case PERIOD_M20:  return "M20";
      case PERIOD_M30:  return "M30";
      case PERIOD_H1:   return "H1";
      case PERIOD_H2:   return "H2";
      case PERIOD_H3:   return "H3";
      case PERIOD_H4:   return "H4";
      case PERIOD_H6:   return "H6";
      case PERIOD_H8:   return "H8";
      case PERIOD_H12:  return "H12";
      case PERIOD_D1:   return "D1";
      case PERIOD_W1:   return "W1";
      case PERIOD_MN1:  return "MN1";
      default:          return "Unknown";
   }
}

//--- Convert string to ENUM_TIMEFRAMES
ENUM_TIMEFRAMES StringToTimeframe(string tfStr)
{
   if(tfStr == "M1")   return PERIOD_M1;
   if(tfStr == "M2")   return PERIOD_M2;
   if(tfStr == "M3")   return PERIOD_M3;
   if(tfStr == "M4")   return PERIOD_M4;
   if(tfStr == "M5")   return PERIOD_M5;
   if(tfStr == "M6")   return PERIOD_M6;
   if(tfStr == "M10")  return PERIOD_M10;
   if(tfStr == "M12")  return PERIOD_M12;
   if(tfStr == "M15")  return PERIOD_M15;
   if(tfStr == "M20")  return PERIOD_M20;
   if(tfStr == "M30")  return PERIOD_M30;
   if(tfStr == "H1")   return PERIOD_H1;
   if(tfStr == "H2")   return PERIOD_H2;
   if(tfStr == "H3")   return PERIOD_H3;
   if(tfStr == "H4")   return PERIOD_H4;
   if(tfStr == "H6")   return PERIOD_H6;
   if(tfStr == "H8")   return PERIOD_H8;
   if(tfStr == "H12")  return PERIOD_H12;
   if(tfStr == "D1")   return PERIOD_D1;
   if(tfStr == "W1")   return PERIOD_W1;
   if(tfStr == "MN1")  return PERIOD_MN1;
   
   return PERIOD_CURRENT;
}

//--- Get timeframe multiplier (seconds in timeframe)
int GetTimeframeSeconds(ENUM_TIMEFRAMES tf)
{
   switch(tf)
   {
      case PERIOD_M1:   return 60;
      case PERIOD_M2:   return 120;
      case PERIOD_M3:   return 180;
      case PERIOD_M4:   return 240;
      case PERIOD_M5:   return 300;
      case PERIOD_M6:   return 360;
      case PERIOD_M10:  return 600;
      case PERIOD_M12:  return 720;
      case PERIOD_M15:  return 900;
      case PERIOD_M20:  return 1200;
      case PERIOD_M30:  return 1800;
      case PERIOD_H1:   return 3600;
      case PERIOD_H2:   return 7200;
      case PERIOD_H3:   return 10800;
      case PERIOD_H4:   return 14400;
      case PERIOD_H6:   return 21600;
      case PERIOD_H8:   return 28800;
      case PERIOD_H12:  return 43200;
      case PERIOD_D1:   return 86400;
      case PERIOD_W1:   return 604800;
      case PERIOD_MN1:  return 2592000;
      default:          return 0;
   }
}

//--- Check if timeframe1 is higher than timeframe2
bool IsHigherTimeframe(ENUM_TIMEFRAMES tf1, ENUM_TIMEFRAMES tf2)
{
   return GetTimeframeSeconds(tf1) > GetTimeframeSeconds(tf2);
}

//+------------------------------------------------------------------+
//| Error handling functions                                         |
//+------------------------------------------------------------------+

//--- Get error description
string GetErrorDescription(int errorCode)
{
   switch(errorCode)
   {
      case 0:     return "No error";
      case 1:     return "No error, but result unknown";
      case 2:     return "Common error";
      case 3:     return "Invalid trade parameters";
      case 4:     return "Trade server is busy";
      case 5:     return "Old version of the client terminal";
      case 6:     return "No connection with trade server";
      case 7:     return "Not enough rights";
      case 8:     return "Too frequent requests";
      case 9:     return "Malfunctional trade operation";
      case 64:    return "Account disabled";
      case 65:    return "Invalid account";
      case 128:   return "Trade timeout";
      case 129:   return "Invalid price";
      case 130:   return "Invalid stops";
      case 131:   return "Invalid trade volume";
      case 132:   return "Market is closed";
      case 133:   return "Trade is disabled";
      case 134:   return "Not enough money";
      case 135:   return "Price changed";
      case 136:   return "Off quotes";
      case 137:   return "Broker is busy";
      case 138:   return "Requote";
      case 139:   return "Order is locked";
      case 140:   return "Long positions only allowed";
      case 141:   return "Too many requests";
      case 145:   return "Modification denied because order is too close to market";
      case 146:   return "Trade context is busy";
      case 147:   return "Expirations are denied by broker";
      case 148:   return "Amount of open and pending orders has reached the limit";
      case 149:   return "Hedging is prohibited";
      case 150:   return "Prohibit closing by opposite order";
      case 4000:  return "No error (no error)";
      case 4001:  return "Wrong function pointer";
      case 4002:  return "Array index is out of range";
      case 4003:  return "No memory for function call stack";
      case 4004:  return "Recursive stack overflow";
      case 4005:  return "Not enough stack for parameter";
      case 4006:  return "No memory for parameter string";
      case 4007:  return "No memory for temp string";
      case 4008:  return "Not initialized string";
      case 4009:  return "Not initialized string in array";
      case 4010:  return "No memory for array string";
      case 4011:  return "Too long string";
      case 4012:  return "Remainder from zero divide";
      case 4013:  return "Zero divide";
      case 4014:  return "Unknown command";
      case 4015:  return "Wrong jump";
      case 4016:  return "Not initialized array";
      case 4017:  return "DLL calls are not allowed";
      case 4018:  return "Cannot load library";
      case 4019:  return "Cannot call function";
      case 4020:  return "Expert function calls are not allowed";
      case 4021:  return "Not enough memory for string returned from function";
      case 4022:  return "System is busy";
      case 4050:  return "Invalid function parameters count";
      case 4051:  return "Invalid function parameter value";
      case 4052:  return "String function internal error";
      case 4053:  return "Some array error";
      case 4054:  return "Incorrect series array using";
      case 4055:  return "Custom indicator error";
      case 4056:  return "Arrays are incompatible";
      case 4057:  return "Global variables processing error";
      case 4058:  return "Global variable not found";
      case 4059:  return "Function is not allowed in testing mode";
      case 4060:  return "Function is not confirmed";
      case 4061:  return "Send mail error";
      case 4062:  return "String parameter expected";
      case 4063:  return "Integer parameter expected";
      case 4064:  return "Double parameter expected";
      case 4065:  return "Array as parameter expected";
      case 4066:  return "Requested history data is in updating state";
      case 4067:  return "Some error in trade operation";
      case 4099:  return "End of file";
      case 4100:  return "Some file error";
      case 4101:  return "Wrong file name";
      case 4102:  return "Too many opened files";
      case 4103:  return "Cannot open file";
      case 4104:  return "Incompatible access to a file";
      case 4105:  return "No order selected";
      case 4106:  return "Unknown symbol";
      case 4107:  return "Invalid price parameter for trade function";
      case 4108:  return "Invalid ticket";
      case 4109:  return "Trade is not allowed";
      case 4110:  return "Longs are not allowed";
      case 4111:  return "Shorts are not allowed";
      case 4200:  return "Object already exists";
      case 4201:  return "Unknown object property";
      case 4202:  return "Object does not exist";
      case 4203:  return "Unknown object type";
      case 4204:  return "No object name";
      case 4205:  return "Object coordinates error";
      case 4206:  return "No specified subwindow";
      case 4207:  return "Some error in object function";
      default:    return "Unknown error";
   }
}

//--- Check last error and log it
bool CheckLastError(string context = "")
{
   int lastError = GetLastError();
   if(lastError != 0)
   {
      string errorMsg = "Error in " + context + ": " + IntegerToString(lastError) + " - " + GetErrorDescription(lastError);
      Print(errorMsg);
      return false;
   }
   return true;
}

//--- Reset last error
void ResetLastError()
{
   ResetLastError();
}

//+------------------------------------------------------------------+
//| Logging functions                                                |
//+------------------------------------------------------------------+

//--- Log message with timestamp
void LogMessage(string message, bool printToJournal = true)
{
   string timestamp = TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS);
   string logMsg = timestamp + " - " + message;
   
   if(printToJournal)
      Print(logMsg);
}

//--- Log error message
void LogError(string context, int errorCode)
{
   string errorMsg = context + " - Error " + IntegerToString(errorCode) + ": " + GetErrorDescription(errorCode);
   LogMessage("ERROR: " + errorMsg);
}

//--- Log trade operation
void LogTradeOperation(string operation, double volume, double price, double sl, double tp, string comment = "")
{
   string logMsg = operation + " - Symbol: " + _Symbol + ", Volume: " + DoubleToString(volume, 2) + 
                   ", Price: " + DoubleToString(price, _Digits) + ", SL: " + DoubleToString(sl, _Digits) + 
                   ", TP: " + DoubleToString(tp, _Digits);
   
   if(comment != "")
      logMsg += ", Comment: " + comment;
   
   LogMessage(logMsg);
}

//--- Log indicator values
void LogIndicatorValues(string indicatorName, double value1, double value2 = 0, double value3 = 0)
{
   string logMsg = indicatorName + " - Value1: " + DoubleToString(value1, 4);
   
   if(value2 != 0)
      logMsg += ", Value2: " + DoubleToString(value2, 4);
   
   if(value3 != 0)
      logMsg += ", Value3: " + DoubleToString(value3, 4);
   
   LogMessage(logMsg, false); // Don't print to journal by default
}

//+------------------------------------------------------------------+
//| General utility functions                                        |
//+------------------------------------------------------------------+

//--- Normalize price to tick size
double NormalizePrice(double price)
{
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickSize == 0) return price;
   
   return NormalizeDouble(MathRound(price / tickSize) * tickSize, _Digits);
}

//--- Normalize volume to lot step
double NormalizeVolume(double volume)
{
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   
   if(lotStep == 0) return volume;
   
   volume = MathRound(volume / lotStep) * lotStep;
   volume = MathMax(volume, minLot);
   volume = MathMin(volume, maxLot);
   
   return NormalizeDouble(volume, 2);
}

//--- Calculate spread in pips
double GetSpreadPips()
{
   double spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double digits = SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   
   if(digits == 3 || digits == 5) // 5-digit brokers
      return(spread * point * 10);
   else // 4-digit brokers
      return(spread * point);
}

//--- Check if market is open
bool IsMarketOpen()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   
   // Check if it's weekend
   if(dt.day_of_week == 0 || dt.day_of_week == 6) // Sunday=0, Saturday=6
      return false;
   
   // Check trading session times (adjust based on your broker)
   int hour = dt.hour;
   
   // Forex market typically open Sunday 22:00 GMT to Friday 21:00 GMT
   // This is a simplified check - adjust for your specific needs
   if(dt.day_of_week == 1 && hour < 22) // Monday before 22:00
      return false;
   if(dt.day_of_week == 5 && hour >= 21) // Friday after 21:00
      return false;
   
   return true;
}

//--- Calculate commission per lot
double GetCommissionPerLot()
{
   // This is broker-specific - adjust according to your broker's commission structure
   // Default: $3.5 per lot (standard commission for many brokers)
   return 3.5;
}

//--- Calculate required margin for position
double CalculateRequiredMargin(double volume, double price)
{
   double margin = 0;
   
   if(OrderCalcMargin(ORDER_TYPE_BUY, _Symbol, volume, price, margin))
      return margin;
   
   return 0;
}

//--- Check if there's enough margin for trade
bool HasEnoughMargin(double volume, double price, double riskPercent = 50)
{
   double accountEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   double requiredMargin = CalculateRequiredMargin(volume, price);
   
   if(requiredMargin == 0) return false;
   
   double marginRatio = (requiredMargin / accountEquity) * 100;
   
   return marginRatio <= riskPercent;
}

//+------------------------------------------------------------------+
//| Array utility functions                                          |
//+------------------------------------------------------------------+

//--- Find maximum value in array
double ArrayMax(double &arr[], int start = 0, int count = WHOLE_ARRAY)
{
   if(count == WHOLE_ARRAY) count = ArraySize(arr);
   
   double maxVal = arr[start];
   for(int i = start + 1; i < start + count; i++)
   {
      if(arr[i] > maxVal) maxVal = arr[i];
   }
   
   return maxVal;
}

//--- Find minimum value in array
double ArrayMin(double &arr[], int start = 0, int count = WHOLE_ARRAY)
{
   if(count == WHOLE_ARRAY) count = ArraySize(arr);
   
   double minVal = arr[start];
   for(int i = start + 1; i < start + count; i++)
   {
      if(arr[i] < minVal) minVal = arr[i];
   }
   
   return minVal;
}

//--- Calculate average of array values
double ArrayAverage(double &arr[], int start = 0, int count = WHOLE_ARRAY)
{
   if(count == WHOLE_ARRAY) count = ArraySize(arr);
   
   double sum = 0;
   for(int i = start; i < start + count; i++)
   {
      sum += arr[i];
   }
   
   return sum / count;
}

//--- Calculate standard deviation of array values
double ArrayStdDev(double &arr[], int start = 0, int count = WHOLE_ARRAY)
{
   if(count == WHOLE_ARRAY) count = ArraySize(arr);
   
   double mean = ArrayAverage(arr, start, count);
   double sumSq = 0;
   
   for(int i = start; i < start + count; i++)
   {
      double diff = arr[i] - mean;
      sumSq += diff * diff;
   }
   
   return MathSqrt(sumSq / count);
}

//+------------------------------------------------------------------+
