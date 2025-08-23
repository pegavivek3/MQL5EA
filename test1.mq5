//+------------------------------------------------------------------+
//|                                                        test1.mq5 |
//|                                          Copyright 2025, Vivek D |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Vivek D"
#property link      "https://www.mql5.com"
#property version   "1.00"
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
#include <trade/trade.mqh>
input ENUM_TIMEFRAMES Timeframe = PERIOD_H1;
input double TriggerFactor = 2.5;
input int AtrPeriods =14;
input double Lots = 0.1;
input int tpPoints = 500;
input int slPoints = 500;
input int TslTriggerPoints = 200;
input int TslPoints = 100;
input int magic1 = 123456;
int AtrHandle;
CTrade trade;
int BarsTotal;
string commentary = "ATR Breakout";

int OnInit()
  {
//---
   Print("initialisation started");
//---
   trade.SetExpertMagicNumber(magic1);
   BarsTotal = iBars(NULL,Timeframe);
   AtrHandle = iATR(NULL,Timeframe,AtrPeriods);
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   
   Print("deinitialized----:",reason);
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---
   for(int i=0;i < PositionsTotal();i++){
      ulong posTicket = PositionGetTicket(i);
      
      if(PositionGetInteger(POSITION_MAGIC) != magic1) continue;
      if(PositionGetSymbol(POSITION_SYMBOL) != _Symbol) continue;
      
      double bid = SymbolInfoDouble(_Symbol,SYMBOL_BID);
      double ask = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      
      double posPriceOpen = PositionGetDouble(POSITION_PRICE_OPEN);
      double posSl = PositionGetDouble(POSITION_SL);
      double posTp = PositionGetDouble(POSITION_TP);
      if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY){
         if(bid > posPriceOpen + TslTriggerPoints * _Point){
         double sl = posSl + TslPoints * _Point;
         sl = NormalizeDouble(sl,_Digits);
            if(sl > posSl){
            trade.PositionModify(posTicket,sl,posTp);
            }
         }
      }else if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL){
         if(ask < posPriceOpen - TslTriggerPoints * _Point){
            double sl = posSl - TslPoints * _Point;
            sl = NormalizeDouble(sl,_Digits);
            if(sl < posSl || posSl == 0){
               trade.PositionModify(posTicket,sl,posTp);
               }
          }
      }
   }
   int bars;
   bars = iBars(NULL,Timeframe);
   if(bars != BarsTotal){
        BarsTotal = bars;
        double atr[];
        CopyBuffer(AtrHandle,0,1,1,atr); 
        double open = iOpen(NULL,Timeframe,1);
        double close = iClose(NULL,Timeframe,1);
        
        if( open < close && (close - open) > atr[0]*TriggerFactor){
        // buy signal
        executeBuy();
        }else if( open > close && (open - close) > atr[0]*TriggerFactor ){
        // sell signal
        executeSell();
        }
     }
     
  }
  
//+------------------------------------------------------------------+
void executeBuy(){

        Print("buy signal...");
        double entry = SymbolInfoDouble(NULL,SYMBOL_ASK);
        entry = NormalizeDouble(entry,_Digits);
        double tp = entry + tpPoints * _Point;
        tp = NormalizeDouble(tp,_Digits);
        double sl = entry - slPoints * _Point;
        sl = NormalizeDouble(sl,_Digits);
        trade.Buy(Lots,NULL,entry,sl,tp,commentary);
}
void executeSell(){
        Print("sell signal..");
        double entry = SymbolInfoDouble(NULL,SYMBOL_ASK);
        entry = NormalizeDouble(entry,_Digits);
        double tp = entry - tpPoints * _Point;
        tp = NormalizeDouble(tp,_Digits);
        double sl = entry + slPoints * _Point;
        sl = NormalizeDouble(sl,_Digits);
        trade.Sell(Lots,NULL,entry,sl,tp,commentary);
        
}