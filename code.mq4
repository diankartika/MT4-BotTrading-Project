//+------------------------------------------------------------------+
//|                                                  MACD Sample.mq4 |
//|                   Copyright 2005-2014, MetaQuotes Software Corp. |
//|                                              http://www.mql4.com |
//+------------------------------------------------------------------+
#property copyright   "2005-2014, MetaQuotes Software Corp."
#property link        "http://www.mql4.com"

input double TakeProfit    = 100;
input double Lots          = 0.1;
input double TrailingStop  = 20;
input double MACDOpenLevel = 2;
input double MACDCloseLevel= 1;
input int    MATrendPeriod = 100; // Adjusted period for trend filtering
input double MaxDrawdown   = 100000; // Maximum drawdown limit

double initialBalance;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   initialBalance = AccountBalance();
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   // Cleanup code
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick(void)
  {
   // Check for maximum drawdown
   double currentBalance = AccountBalance();
   double drawdown = initialBalance - currentBalance;
   if (drawdown >= MaxDrawdown)
     {
      Print("Maximum drawdown limit reached. Stopping trading.");
      return;
     }
   
   double MacdCurrent, MacdPrevious;
   double SignalCurrent, SignalPrevious;
   double MaCurrent, MaPrevious;
   int    cnt, ticket, total;

   // Initial data checks
   if (Bars < 100)
     {
      Print("Bars less than 100");
      return;
     }
   if (TakeProfit < 10)
     {
      Print("TakeProfit less than 10");
      return;
     }

   // Data retrieval
   MacdCurrent = iMACD(NULL, 0, 12, 26, 9, PRICE_CLOSE, MODE_MAIN, 0);
   MacdPrevious = iMACD(NULL, 0, 12, 26, 9, PRICE_CLOSE, MODE_MAIN, 1);
   SignalCurrent = iMACD(NULL, 0, 12, 26, 9, PRICE_CLOSE, MODE_SIGNAL, 0);
   SignalPrevious = iMACD(NULL, 0, 12, 26, 9, PRICE_CLOSE, MODE_SIGNAL, 1);
   MaCurrent = iMA(NULL, 0, MATrendPeriod, 0, MODE_EMA, PRICE_CLOSE, 0);
   MaPrevious = iMA(NULL, 0, MATrendPeriod, 0, MODE_EMA, PRICE_CLOSE, 1);

   total = OrdersTotal();

   if (total < 1)
     {
      // No open orders
      if (AccountFreeMargin() < (1000 * Lots))
        {
         Print("We have no money. Free Margin = ", AccountFreeMargin());
         return;
        }

      // Check for buy position possibility
      if (MacdCurrent < 0 && MacdCurrent > SignalCurrent && MacdPrevious < SignalPrevious && 
          MathAbs(MacdCurrent) > (MACDOpenLevel * Point) && MaCurrent > MaPrevious)
        {
         ticket = OrderSend(Symbol(), OP_BUY, Lots, Ask, 3, 0, Ask + TakeProfit * Point, "MACD sample", 16384, 0, Green);
         if (ticket > 0)
           {
            if (OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES))
               Print("BUY order opened: ", OrderOpenPrice());
           }
         else
            Print("Error opening BUY order: ", GetLastError());
         return;
        }

      // Check for sell position possibility
      if (MacdCurrent > 0 && MacdCurrent < SignalCurrent && MacdPrevious > SignalPrevious && 
          MacdCurrent > (MACDOpenLevel * Point) && MaCurrent < MaPrevious)
        {
         ticket = OrderSend(Symbol(), OP_SELL, Lots, Bid, 3, 0, Bid - TakeProfit * Point, "MACD sample", 16384, 0, Red);
         if (ticket > 0)
           {
            if (OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES))
               Print("SELL order opened: ", OrderOpenPrice());
           }
         else
            Print("Error opening SELL order: ", GetLastError());
        }
      return;
     }

   // Manage open positions
   for (cnt = 0; cnt < total; cnt++)
     {
      if (!OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES))
         continue;
      if (OrderType() <= OP_SELL && OrderSymbol() == Symbol())
        {
         // Manage buy positions
         if (OrderType() == OP_BUY)
           {
            // Close conditions
            if (MacdCurrent > 0 && MacdCurrent < SignalCurrent && MacdPrevious > SignalPrevious && 
                MacdCurrent > (MACDCloseLevel * Point))
              {
               if (!OrderClose(OrderTicket(), OrderLots(), Bid, 3, Violet))
                  Print("OrderClose error: ", GetLastError());
               return;
              }
            // Trailing stop
            if (TrailingStop > 0)
              {
               if (Bid - OrderOpenPrice() > Point * TrailingStop)
                 {
                  if (OrderStopLoss() < Bid - Point * TrailingStop)
                    {
                     if (!OrderModify(OrderTicket(), OrderOpenPrice(), Bid - Point * TrailingStop, OrderTakeProfit(), 0, Green))
                        Print("OrderModify error: ", GetLastError());
                     return;
                    }
                 }
              }
           }
         else // Manage sell positions
           {
            // Close conditions
            if (MacdCurrent < 0 && MacdCurrent > SignalCurrent && MacdPrevious < SignalPrevious && 
                MathAbs(MacdCurrent) > (MACDCloseLevel * Point))
              {
               if (!OrderClose(OrderTicket(), OrderLots(), Ask, 3, Violet))
                  Print("OrderClose error: ", GetLastError());
               return;
              }
            // Trailing stop
            if (TrailingStop > 0)
              {
               if ((OrderOpenPrice() - Ask) > (Point * TrailingStop))
                 {
                  if ((OrderStopLoss() > (Ask + Point * TrailingStop)) || (OrderStopLoss() == 0))
                    {
                     if (!OrderModify(OrderTicket(), OrderOpenPrice(), Ask + Point * TrailingStop, OrderTakeProfit(), 0, Red))
                        Print("OrderModify error: ", GetLastError());
                     return;
                    }
                 }
              }
           }
        }
     }
  }
//+------------------------------------------------------------------+
