//+------------------------------------------------------------------+
//| PositionManager.mqh                                             |
//| Handles order execution with pending buy/sell stops, slippage   |
//| control, retry logic, magic number, order comments, and partial |
//| close functionality                                             |
//+------------------------------------------------------------------+
#property copyright ""
#property link      ""
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| Input parameters for order execution                            |
//+------------------------------------------------------------------+
input int      MagicNumber = 12345;           // Magic number for orders
input double   Slippage = 5;                  // Maximum slippage in points
input int      MaxRetries = 3;                // Maximum retry attempts
input int      RetryDelay = 100;              // Delay between retries (ms)
input bool     UsePartialClose = true;        // Enable partial close
input double   PartialClosePercent = 50.0;    // Percentage to close partially
input string   OrderComment = "Breakout EA";  // Order comment

//+------------------------------------------------------------------+
//| CPositionManager class                                           |
//+------------------------------------------------------------------+
class CPositionManager
{
private:
   int               m_magic;                 // Magic number
   double            m_slippage;              // Slippage in points
   int               m_maxRetries;            // Max retry attempts
   int               m_retryDelay;            // Delay between retries
   bool              m_usePartialClose;       // Partial close flag
   double            m_partialClosePercent;   // Partial close percentage
   string            m_orderComment;          // Order comment
   
public:
   // Constructor
   CPositionManager(int magic, double slippage, int maxRetries, int retryDelay, bool usePartialClose, double partialClosePercent, string orderComment)
   {
      m_magic = magic;
      m_slippage = slippage;
      m_maxRetries = maxRetries;
      m_retryDelay = retryDelay;
      m_usePartialClose = usePartialClose;
      m_partialClosePercent = partialClosePercent;
      m_orderComment = orderComment;
   }
   
   // Default constructor
   CPositionManager()
   {
      m_magic = MagicNumber;
      m_slippage = Slippage;
      m_maxRetries = MaxRetries;
      m_retryDelay = RetryDelay;
      m_usePartialClose = UsePartialClose;
      m_partialClosePercent = PartialClosePercent;
      m_orderComment = OrderComment;
   }
   
   // Execute pending buy stop order
   bool ExecuteBuyStop(double price, double volume, double stopLoss, double takeProfit)
   {
      return ExecuteOrder(ORDER_TYPE_BUY_STOP, price, volume, stopLoss, takeProfit);
   }
   
   // Execute pending sell stop order
   bool ExecuteSellStop(double price, double volume, double stopLoss, double takeProfit)
   {
      return ExecuteOrder(ORDER_TYPE_SELL_STOP, price, volume, stopLoss, takeProfit);
   }
   
   // Close position partially
   bool ClosePartial(long ticket, double percent)
   {
      if(!m_usePartialClose) return false;
      
      if(!PositionSelectByTicket(ticket))
      {
         Print("Position with ticket ", ticket, " not found");
         return false;
      }
      
      double volume = PositionGetDouble(POSITION_VOLUME);
      double closeVolume = NormalizeDouble(volume * percent / 100.0, 2);
      
      if(closeVolume < SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN))
      {
         Print("Partial close volume too small");
         return false;
      }
      
      MqlTradeRequest request = {};
      MqlTradeResult  result = {};
      
      request.action    = TRADE_ACTION_DEAL;
      request.position  = ticket;
      request.symbol    = Symbol();
      request.volume    = closeVolume;
      request.type      = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
      request.price     = (request.type == ORDER_TYPE_SELL) ? SymbolInfoDouble(Symbol(), SYMBOL_BID) : SymbolInfoDouble(Symbol(), SYMBOL_ASK);
      request.deviation = (int)m_slippage;
      request.magic     = m_magic;
      request.comment   = m_orderComment + " Partial Close";
      
      for(int i = 0; i < m_maxRetries; i++)
      {
         if(OrderSend(request, result))
         {
            if(result.retcode == TRADE_RETCODE_DONE)
            {
               Print("Partial close executed successfully. Ticket: ", result.order);
               return true;
            }
            else
            {
               Print("Partial close failed. Retcode: ", result.retcode, ", Retrying...");
            }
         }
         else
         {
            Print("OrderSend failed. Error: ", GetLastError());
         }
         
         if(i < m_maxRetries - 1)
            Sleep(m_retryDelay);
      }
      
      Print("Partial close failed after ", m_maxRetries, " attempts");
      return false;
   }
   
   // Close position fully
   bool CloseFull(long ticket)
   {
      if(!PositionSelectByTicket(ticket))
      {
         Print("Position with ticket ", ticket, " not found");
         return false;
      }
      
      MqlTradeRequest request = {};
      MqlTradeResult  result = {};
      
      request.action    = TRADE_ACTION_DEAL;
      request.position  = ticket;
      request.symbol    = Symbol();
      request.volume    = PositionGetDouble(POSITION_VOLUME);
      request.type      = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
      request.price     = (request.type == ORDER_TYPE_SELL) ? SymbolInfoDouble(Symbol(), SYMBOL_BID) : SymbolInfoDouble(Symbol(), SYMBOL_ASK);
      request.deviation = (int)m_slippage;
      request.magic     = m_magic;
      request.comment   = m_orderComment + " Full Close";
      
      for(int i = 0; i < m_maxRetries; i++)
      {
         if(OrderSend(request, result))
         {
            if(result.retcode == TRADE_RETCODE_DONE)
            {
               Print("Full close executed successfully. Ticket: ", result.order);
               return true;
            }
            else
            {
               Print("Full close failed. Retcode: ", result.retcode, ", Retrying...");
            }
         }
         else
         {
            Print("OrderSend failed. Error: ", GetLastError());
         }
         
         if(i < m_maxRetries - 1)
            Sleep(m_retryDelay);
      }
      
      Print("Full close failed after ", m_maxRetries, " attempts");
      return false;
   }
   
   // Modify position stop loss and take profit
   bool ModifyPosition(long ticket, double stopLoss, double takeProfit)
   {
      if(!PositionSelectByTicket(ticket))
      {
         Print("Position with ticket ", ticket, " not found");
         return false;
      }
      
      MqlTradeRequest request = {};
      MqlTradeResult  result = {};
      
      request.action    = TRADE_ACTION_SLTP;
      request.position  = ticket;
      request.symbol    = Symbol();
      request.sl        = stopLoss;
      request.tp        = takeProfit;
      request.magic     = m_magic;
      
      for(int i = 0; i < m_maxRetries; i++)
      {
         if(OrderSend(request, result))
         {
            if(result.retcode == TRADE_RETCODE_DONE)
            {
               Print("Position modified successfully. Ticket: ", ticket);
               return true;
            }
            else
            {
               Print("Modify failed. Retcode: ", result.retcode, ", Retrying...");
            }
         }
         else
         {
            Print("OrderSend failed. Error: ", GetLastError());
         }
         
         if(i < m_maxRetries - 1)
            Sleep(m_retryDelay);
      }
      
      Print("Modify failed after ", m_maxRetries, " attempts");
      return false;
   }
   
   // Get total positions count for this magic number
   int GetPositionsCount()
   {
      int count = 0;
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         if(PositionSelectByTicket(PositionGetTicket(i)))
         {
            if(PositionGetInteger(POSITION_MAGIC) == m_magic)
               count++;
         }
      }
      return count;
   }
   
   // Get total volume for this magic number
   double GetPositionsVolume()
   {
      double volume = 0.0;
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         if(PositionSelectByTicket(PositionGetTicket(i)))
         {
            if(PositionGetInteger(POSITION_MAGIC) == m_magic)
               volume += PositionGetDouble(POSITION_VOLUME);
         }
      }
      return volume;
   }
   
   // Close all positions for this magic number
   bool CloseAllPositions()
   {
      bool success = true;
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         long ticket = PositionGetTicket(i);
         if(PositionSelectByTicket(ticket))
         {
            if(PositionGetInteger(POSITION_MAGIC) == m_magic)
            {
               if(!CloseFull(ticket))
                  success = false;
            }
         }
      }
      return success;
   }
   
private:
   // Execute order with retry logic
   bool ExecuteOrder(ENUM_ORDER_TYPE type, double price, double volume, double stopLoss, double takeProfit)
   {
      MqlTradeRequest request = {};
      MqlTradeResult  result = {};
      
      request.action    = TRADE_ACTION_PENDING;
      request.symbol    = Symbol();
      request.volume    = volume;
      request.type      = type;
      request.price     = NormalizeDouble(price, Digits());
      request.sl        = (stopLoss > 0) ? NormalizeDouble(stopLoss, Digits()) : 0;
      request.tp        = (takeProfit > 0) ? NormalizeDouble(takeProfit, Digits()) : 0;
      request.deviation = (int)m_slippage;
      request.magic     = m_magic;
      request.comment   = m_orderComment;
      
      // Set expiration if needed (optional)
      // request.expiration = TimeCurrent() + 86400; // 1 day
      
      for(int i = 0; i < m_maxRetries; i++)
      {
         if(OrderSend(request, result))
         {
            if(result.retcode == TRADE_RETCODE_DONE)
            {
               Print("Order executed successfully. Ticket: ", result.order);
               return true;
            }
            else
            {
               Print("Order execution failed. Retcode: ", result.retcode, ", Retrying...");
            }
         }
         else
         {
            Print("OrderSend failed. Error: ", GetLastError());
         }
         
         if(i < m_maxRetries - 1)
            Sleep(m_retryDelay);
      }
      
      Print("Order execution failed after ", m_maxRetries, " attempts");
      return false;
   }
};

//+------------------------------------------------------------------+
//| Global instance of PositionManager                               |
//+------------------------------------------------------------------+
CPositionManager PositionManager;