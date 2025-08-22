//+------------------------------------------------------------------+
//|                                 Ichimoku_Cloud_Entry_Strategy.mq5 |
//|                        Copyright 2024, MetaQuotes Software Corp. |
//|                                             https://www.metaquotes.net/ |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Software Corp."
#property link      "https://www.metaquotes.net/"
#property version   "1.00"
#property strict

// Input parameters
input int TenkanSen = 9;     // Tenkan-sen (Conversion Line) period
input int KijunSen = 26;     // Kijun-sen (Base Line) period
input int SenkouSpanB = 52;  // Senkou Span B (Leading Span B) period

// Global variables
int IchimokuHandle;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Create Ichimoku Kinko Hyo indicator handle
   IchimokuHandle = iIchimoku(NULL, 0, TenkanSen, KijunSen, SenkouSpanB);
   
   if (IchimokuHandle == INVALID_HANDLE)
   {
      Print("Failed to create Ichimoku indicator handle!");
      return(INIT_FAILED);
   }
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if (IchimokuHandle != INVALID_HANDLE)
      IndicatorRelease(IchimokuHandle);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Get current prices
   double close = iClose(NULL, 0, 1);  // Previous candle close
   double open = iOpen(NULL, 0, 1);    // Previous candle open

   // Get Ichimoku components
   double TenkanSenArray[], KijunSenArray[], SenkouSpanAArray[], SenkouSpanBArray[];
   
   // Copy indicator values
   CopyBuffer(IchimokuHandle, 0, 0, 3, TenkanSenArray);  // Tenkan-sen (Conversion Line)
   CopyBuffer(IchimokuHandle, 1, 0, 3, KijunSenArray);   // Kijun-sen (Base Line)
   CopyBuffer(IchimokuHandle, 2, 0, 3, SenkouSpanAArray); // Senkou Span A (Leading Span A)
   CopyBuffer(IchimokuHandle, 3, 0, 3, SenkouSpanBArray); // Senkou Span B (Leading Span B)

   // Check if data is valid
   if (ArraySize(TenkanSenArray) < 3 || ArraySize(KijunSenArray) < 3 || 
       ArraySize(SenkouSpanAArray) < 3 || ArraySize(SenkouSpanBArray) < 3)
   {
      Print("Not enough data for Ichimoku Cloud!");
      return;
   }

   // Define cloud (Kumo) boundaries
   double UpperCloud = MathMax(SenkouSpanAArray[1], SenkouSpanBArray[1]); // Cloud top
   double LowerCloud = MathMin(SenkouSpanAArray[1], SenkouSpanBArray[1]); // Cloud bottom

   // Check for buy signal (price above cloud & Tenkan-sen > Kijun-sen)
   if (close > UpperCloud && TenkanSenArray[1] > KijunSenArray[1])
   {
      if (PositionsTotal() == 0) // No existing position
      {
         Print("BUY SIGNAL: Price above cloud & Tenkan > Kijun");
         // Place buy order (example: Market Buy)
         // OrderSend(Symbol(), OP_BUY, 0.1, Ask, 3, 0, 0, "Ichimoku Buy", 0, 0, clrGreen);
      }
   }

   // Check for sell signal (price below cloud & Tenkan-sen < Kijun-sen)
   else if (close < LowerCloud && TenkanSenArray[1] < KijunSenArray[1])
   {
      if (PositionsTotal() == 0) // No existing position
      {
         Print("SELL SIGNAL: Price below cloud & Tenkan < Kijun");
         // Place sell order (example: Market Sell)
         // OrderSend(Symbol(), OP_SELL, 0.1, Bid, 3, 0, 0, "Ichimoku Sell", 0, 0, clrRed);
      }
   }
}
//+------------------------------------------------------------------+