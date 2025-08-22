
#property copyright "Copyright 2025, Vivek D"
#property link      "https://www.mql5.com"
#property version   "1.00"
//+------------------------------------------------------------------+
//| includes                                                         |
//+------------------------------------------------------------------+
#include <Trade\Trade.mqh>
//+------------------------------------------------------------------+
//| input variable                                                   |
//+------------------------------------------------------------------+
input int InpFastPeriod = 14; //fastperiod
input int InpSlowPeriod = 21; //slowperiod
input int InpStopLoss = 100;  //stop loss in points
input int InpTakeProfit = 200; //TP in points
//+------------------------------------------------------------------+
//| global variable                                                  |
//+------------------------------------------------------------------+
int fastHandle;
int slowHandle;
double slowBuffer[];
double fastBuffer[];
CTrade trade;
datetime openTimeBuy = 0;
datetime openTimeSell = 0;
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
   if(InpFastPeriod <= 0){
      Alert("fast period <= 0");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(InpSlowPeriod <= 0){
      Alert("slow period <= 0");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(InpSlowPeriod <= InpFastPeriod){
      Alert("slow period <= fast period");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(InpStopLoss <= 0){
      Alert("stop loss <= 0");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(InpTakeProfit <= 0){
      Alert("TakeProfit <= 0");
      return INIT_PARAMETERS_INCORRECT;
   }
   // create handles
   fastHandle = iMA(_Symbol,PERIOD_CURRENT,InpFastPeriod,0,MODE_SMA,PRICE_CLOSE);
   if(fastHandle == INVALID_HANDLE){
      Alert("invalid handle");
      return INIT_FAILED;
   }
   slowHandle = iMA(_Symbol,PERIOD_CURRENT,InpSlowPeriod,0,MODE_SMA,PRICE_CLOSE);
   if(slowHandle == INVALID_HANDLE){
      Alert("invalid handle");
      return INIT_FAILED;
   }
   ArraySetAsSeries(fastBuffer,true);
   ArraySetAsSeries(slowBuffer,true);

   return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason){
   if(fastHandle != INVALID_HANDLE) {IndicatorRelease(fastHandle);}
   if(slowHandle != INVALID_HANDLE) {IndicatorRelease(slowHandle);}  
   
}
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick(){
   int values = CopyBuffer(fastHandle,0,0,2,fastBuffer);
   if(values != 2){
      Print("not enough data");
      return;
   }
   values = CopyBuffer(slowHandle,0,0,2,slowBuffer);
   if(values != 2){
      Print("not enough data");
      return;
   }
   Comment("fast[0]",fastBuffer[0],"\n",
           "fast[1]",fastBuffer[1],"\n",
           "slow[0]",slowBuffer[0],"\n",
           "slow[1]",slowBuffer[1]);
   
   //check for cross buy
   if(fastBuffer[1] <= slowBuffer[1] && fastBuffer[0] > slowBuffer[0] && openTimeBuy != iTime(_Symbol,PERIOD_CURRENT,0)){
      openTimeBuy = iTime(_Symbol,PERIOD_CURRENT,0);
      double ask = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      double sl = ask - InpStopLoss * SymbolInfoDouble(_Symbol,SYMBOL_POINT);
      double tp = ask + InpTakeProfit * SymbolInfoDouble(_Symbol,SYMBOL_POINT);
      trade.PositionOpen(_Symbol,ORDER_TYPE_BUY,1.0,ask,sl,tp,"MA Croass Over");
   }
   //check for cross sell
   if(fastBuffer[1] >= slowBuffer[1] && fastBuffer[0] < slowBuffer[0] && openTimeSell != iTime(_Symbol,PERIOD_CURRENT,0)){
      openTimeSell = iTime(_Symbol,PERIOD_CURRENT,0);
      double bid = SymbolInfoDouble(_Symbol,SYMBOL_BID);
      double sl = bid + InpStopLoss * SymbolInfoDouble(_Symbol,SYMBOL_POINT);
      double tp = bid - InpTakeProfit * SymbolInfoDouble(_Symbol,SYMBOL_POINT);
      trade.PositionOpen(_Symbol,ORDER_TYPE_SELL,1.0,bid,sl,tp,"MA Croass Over");
   }
   
   
   
}
//+------------------------------------------------------------------+
