//+------------------------------------------------------------------+
//|                                              open close hour.mq5 |
//|                                          Copyright 2025, Vivek D |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Vivek D"
#property link      "https://www.mql5.com"
#property version   "1.00"
//+------------------------------------------------------------------+
//| includes                                                         |
//+------------------------------------------------------------------+
#include <trade/trade.mqh>
//+------------------------------------------------------------------+
//| Expert initialization variable                                   |
//+------------------------------------------------------------------+
input int openHour = 10;
input int closeHour = 12;
bool isTradeOpen = false;
CTrade trade;
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
  if(openHour == closeHour){
   Print("input parameters are wrong");
   return INIT_PARAMETERS_INCORRECT;
   }
   
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   //get current time
   MqlDateTime timeNow;
   TimeToStruct(TimeCurrent(),timeNow);
   if(openHour == timeNow.hour && !isTradeOpen){
      trade.PositionOpen(_Symbol,ORDER_TYPE_BUY,1,SymbolInfoDouble(_Symbol,SYMBOL_ASK),0,0);
      isTradeOpen = true;
      }
   if(closeHour == timeNow.hour && isTradeOpen){
      trade.PositionClose(_Symbol);
      isTradeOpen = false;
      }
  }
//+------------------------------------------------------------------+
