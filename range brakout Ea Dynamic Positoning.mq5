
#property copyright "Copyright 2025, Vivek D"
#property link      "https://www.mql5.com"
#property version   "1.00"
//+------------------------------------------------------------------+
//| Includes                                                         |
//+------------------------------------------------------------------+
#include <Trade\Trade.mqh>
//+------------------------------------------------------------------+
//| Inputs                                                           |
//+------------------------------------------------------------------+
input group "========General Inputs======"
input long InpMagicNumber = 1234;   //magic number

enum LOT_MODE_ENUM{
   LOT_MODE_FIXED,            //fixed lots
   LOT_MODE_MONEY,            //lots based on money
   LOT_MODE_PCT_ACCOUNT       //lots based on % of account
};
input LOT_MODE_ENUM InpLotMode = LOT_MODE_FIXED; //lot mode
input double InpLots = 0.01;        //lots / money / percent

input int InpStopLoss = 150;        // stoploss in % of the range, 0 sl=off
input int InpTakeProfit = 200;      // TakeProfit in % of the range, 0 tp=off

enum BREAKOUT_MODE_ENUM{
   ONE_SIGNAL,                      // one breakout for range
   TWO_SIGNALS                      // low and high breakouts
};
input BREAKOUT_MODE_ENUM InpBreakoutMode = ONE_SIGNAL; //breakout mode

input group "=========Range Inputs========"
input int InpRangeStart = 600;      // range start in minutes
input int InpRangeDuration = 120;   // range duration in minutes
input int InpRangeClose = 1200;     // range close in minutes, -1 off

input group "=========Day of the Week filter========="
input bool InpMonday = true;        // range on Monday
input bool InpTuesday = true;       // range on Tuesday
input bool InpWednesday = true;     // range on Wednesday
input bool InpThursday = true;      // range on Thursday
input bool InpFriday = true;        // range on Friday
//+------------------------------------------------------------------+
//| Globals                                                          |
//+------------------------------------------------------------------+
struct RANGE_STRUCT{
   datetime start_time;    //start of the range
   datetime end_time;      //end of the range
   datetime close_time;    //close time
   double high;            //high of the range
   double low;             //low of the range
   bool f_entry;           // flag if are inside range
   bool f_high_breakout;   // flag if high breakout occured
   bool f_low_breakout;    //flag if low breakout occured
   RANGE_STRUCT() : start_time(0),end_time(0),close_time(0),high(0),low(DBL_MAX),f_entry(false),f_high_breakout(false),f_low_breakout(false) {};
};
RANGE_STRUCT range;
MqlTick prevTick, lastTick;
CTrade trade;
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
   
   if(!CheckInputs()){return INIT_PARAMETERS_INCORRECT;}
   
   //set magic number
   trade.SetExpertMagicNumber(InpMagicNumber);
   
   //calculate new range
   if(_UninitReason==REASON_PARAMETERS && CountOpenPositions() ==0){ // positions are not open
      CalculateRange();
   }  
   
   //Draw objects
   DrawObjects();
   return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason){
   ObjectsDeleteAll(NULL,"range");
   
}
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick(){
   prevTick = lastTick;
   SymbolInfoTick(_Symbol,lastTick);
   
   //range calculation
   if(lastTick.time>=range.start_time && lastTick.time<range.end_time){
      //set flag entry
      range.f_entry = true;
      
      if(lastTick.ask > range.high){
         range.high = lastTick.ask;
         DrawObjects();
      }
      if(lastTick.bid < range.low){
         range.low = lastTick.bid;
         DrawObjects();
      }
   }
   
   //check close positions
   if(InpRangeClose >=0 && lastTick.time >= range.close_time){
      if(!ClosePosition()) {return;}
   }
   
   //calculate new range if...
   if(((InpRangeClose>=0 && lastTick.time>=range.close_time)     //close time reached
      || (range.f_high_breakout && range.f_low_breakout)        //both breakout flags are true
      || (range.end_time == 0)                                  //range is not calculated yet
      || (range.end_time != 0 && lastTick.time > range.end_time && !range.f_entry)) // range was calculated but no tick inside
      && CountOpenPositions() == 0 ){
      CalculateRange();
   }
   
   // check for breakouts
   CheckBreakouts();
}


// calculate new range...
void CalculateRange()
{
   //reset range variables
   range.start_time = 0;
   range.end_time = 0;
   range.close_time = 0;
   range.high = 0.0;
   range.low = DBL_MAX;
   range.f_entry = false;
   range.f_low_breakout = false;
   range.f_high_breakout = false;
   
   //calculate range start time
   int time_cycle = 86400;
   range.start_time = (lastTick.time - (lastTick.time % 86400)) + InpRangeStart*60;
   for(int i=0;i < 8;i++){
      MqlDateTime tmp;
      TimeToStruct(range.start_time,tmp);
      int dow = tmp.day_of_week;
      if(lastTick.time>=range.start_time || dow==6 ||dow==0 || (dow == 1 && !InpMonday) || (dow == 2 && !InpTuesday)
       || (dow == 3 && !InpWednesday) || (dow == 4 && !InpThursday) || (dow == 5 && !InpFriday)){
         range.start_time += time_cycle;
      }
   } 
   
   // calculate range end time
   range.end_time = range.start_time + InpRangeDuration*60;
   for(int i=0;i<2;i++){
      MqlDateTime tmp;
      TimeToStruct(range.end_time,tmp);
      int dow = tmp.day_of_week;
      if(dow == 6 || dow ==0){
         range.end_time += time_cycle;
      }  
   }
   
   //calculate close time
   if(InpRangeClose >= 0){
      range.close_time = (range.end_time - (range.end_time % 86400)) + InpRangeClose*60;
      for(int i=0;i < 3;i++){
         MqlDateTime tmp;
         TimeToStruct(range.close_time,tmp);
         int dow = tmp.day_of_week;
         if(range.close_time<=range.end_time || dow==6 ||dow==0){
            range.close_time += time_cycle;
         }
      }
    }
   DrawObjects(); 
}

// check Break Outs and position entry
void CheckBreakouts(){
   
   //check if are after range end
   if(lastTick.time >= range.end_time && range.end_time>0 && range.f_entry){
      //check for high breakout
      if(!range.f_high_breakout && lastTick.ask >= range.high){
         range.f_high_breakout = true;
         if(InpBreakoutMode == ONE_SIGNAL){range.f_low_breakout = true;}
         
         //calculate stop loss and take profit
         double sl = InpStopLoss == 0 ? 0 : NormalizeDouble((lastTick.bid - (range.high - range.low) * InpStopLoss * 0.01),_Digits);
         double tp = InpTakeProfit == 0 ? 0 :NormalizeDouble((lastTick.bid + (range.high - range.low) * InpTakeProfit * 0.01),_Digits);
         
         //calculate lots
         double lots;
         if(!CalculateLots(lastTick.bid-sl,lots)){return;}
         
         //open buy position
         trade.PositionOpen(_Symbol,ORDER_TYPE_BUY,lots,lastTick.ask,sl,tp,"Time Range EA BUY");   
      }
      if(!range.f_low_breakout && lastTick.bid <= range.low){
         range.f_low_breakout = true;
         if(InpBreakoutMode == ONE_SIGNAL){range.f_high_breakout = true;}
         
         //calculate stop loss and take profit
         double sl = InpStopLoss == 0 ? 0 : NormalizeDouble((lastTick.ask + (range.high - range.low) * InpStopLoss * 0.01),_Digits);
         double tp = InpTakeProfit == 0 ? 0 :NormalizeDouble((lastTick.ask - (range.high - range.low) * InpTakeProfit * 0.01),_Digits);
         
         //calculate lots
         double lots;
         if(!CalculateLots(sl-lastTick.ask,lots)){return;}
         
         //open sell position
         trade.PositionOpen(_Symbol,ORDER_TYPE_SELL,lots,lastTick.bid,sl,tp,"Time Range EA SELL");   
      }
   }
}


bool CalculateLots(double slDistance,double &lots){
   
   lots = 0.0;
   if(InpLotMode==LOT_MODE_FIXED){
      lots = InpLots;
   }
   else{
      double tickSize = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
      double tickValue = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE);
      double volumeStep = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
      
      double riskMoney = InpLotMode==LOT_MODE_MONEY ? InpLots : AccountInfoDouble(ACCOUNT_EQUITY) * InpLots * 0.01;
      double moneyVolumeStep = (slDistance / tickSize) * tickValue * volumeStep;
      
      lots = MathFloor(riskMoney/moneyVolumeStep) * volumeStep;   
   }
   
   //check calculated lots
   if(!CheckLots(lots)){return false;}

   return true;
}


//check lots for min ,max and step
bool CheckLots(double &lots){
   
   double min = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   double max = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
   double step = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);

   if(lots<min){
      Print("Lot size will be set to minimum allowable volume");
      lots = min;
      return true;
   }
   if(lots>max){
      Print("Lot size is greater than max allowable volume,Lots :",lots,"max :",max);
      return false;
   }
   
   lots = (int)MathFloor(lots/step) * step;

   return true;
}

//close all open positions
bool ClosePosition(){  
   int total = PositionsTotal();
   for(int i=total-1;i>=0;i--){
      if(total!=PositionsTotal()){total = PositionsTotal(); i = total; continue;}
      ulong ticket = PositionGetTicket(i); //select position
      if(ticket <=0){Print("failed to get ticket"); return false; }
      if(!PositionSelectByTicket(ticket)){Print("failed select position by ticket"); return false;}
      long magicnumber;
      if(!PositionGetInteger(POSITION_MAGIC,magicnumber)){Print("failed to get position magic number"); return false;}
      if(magicnumber == InpMagicNumber){
         trade.PositionClose(ticket);
         if(trade.ResultRetcode()!=TRADE_RETCODE_DONE){
            Print("Failed close position. Result: "+(string)trade.ResultRetcode()+":"+trade.ResultRetcodeDescription());
            return false;
         }
      }
   }
   return true;
}


//count open positions
int CountOpenPositions(){
   int counter = 0;
   int total = PositionsTotal();
   for(int i=total-1;i>=0;i--){
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0){Print("Failed get position ticket"); return -1;}
      if(!PositionSelectByTicket(ticket)){Print("Failed to get positon by ticket"); return -1;}
      long magicnumber;
      if(!PositionGetInteger(POSITION_MAGIC,magicnumber)){Print("Failed to get position MagicNumber"); return -1;}
      if(InpMagicNumber == magicnumber){counter++;}
   }
   return counter;
}

//draw objects on chart
void DrawObjects(){

   //start time
   ObjectDelete(NULL,"range start");
   if(range.start_time>0){
      ObjectCreate(NULL,"range start",OBJ_VLINE,0,range.start_time,0);
      ObjectSetString(NULL,"range start",OBJPROP_TOOLTIP,"start of the range \n"+TimeToString(range.start_time,TIME_DATE|TIME_MINUTES));
      ObjectSetInteger(NULL,"range start",OBJPROP_COLOR,clrBlue);
      ObjectSetInteger(NULL,"range start",OBJPROP_WIDTH,2);
      ObjectSetInteger(NULL,"range start",OBJPROP_BACK,true);
   }
   
   //end time
   ObjectDelete(NULL,"range end");
   if(range.end_time>0){
      ObjectCreate(NULL,"range end",OBJ_VLINE,0,range.end_time,0);
      ObjectSetString(NULL,"range end",OBJPROP_TOOLTIP,"end of the range \n"+TimeToString(range.end_time,TIME_DATE|TIME_MINUTES));
      ObjectSetInteger(NULL,"range end",OBJPROP_COLOR,clrBlue);
      ObjectSetInteger(NULL,"range end",OBJPROP_WIDTH,2);
      ObjectSetInteger(NULL,"range end",OBJPROP_BACK,true);
   }
   
   //close time
   ObjectDelete(NULL,"range close");
   if(range.close_time>0){
      ObjectCreate(NULL,"range close",OBJ_VLINE,0,range.close_time,0);
      ObjectSetString(NULL,"range close",OBJPROP_TOOLTIP,"close of the range \n"+TimeToString(range.close_time,TIME_DATE|TIME_MINUTES));
      ObjectSetInteger(NULL,"range close",OBJPROP_COLOR,clrDarkRed);
      ObjectSetInteger(NULL,"range close",OBJPROP_WIDTH,2);
      ObjectSetInteger(NULL,"range close",OBJPROP_BACK,true);
   }
   
   //high
   ObjectsDeleteAll(NULL,"range high");
   if(range.high>0){
      ObjectCreate(NULL,"range high",OBJ_TREND,0,range.start_time,range.high,range.end_time,range.high);
      ObjectSetString(NULL,"range high",OBJPROP_TOOLTIP,"high of the range: "+DoubleToString(range.high,_Digits));
      ObjectSetInteger(NULL,"range high",OBJPROP_COLOR,clrBlue);
      ObjectSetInteger(NULL,"range high",OBJPROP_WIDTH,2);
      ObjectSetInteger(NULL,"range high",OBJPROP_BACK,true);
      
      ObjectCreate(NULL,"range high ",OBJ_TREND,0,range.end_time,range.high,InpRangeClose >= 0 ? range.close_time : INT_MAX,range.high);
      ObjectSetString(NULL,"range high ",OBJPROP_TOOLTIP,"high of the range: "+DoubleToString(range.high,_Digits));
      ObjectSetInteger(NULL,"range high ",OBJPROP_COLOR,clrBlue);
      ObjectSetInteger(NULL,"range high ",OBJPROP_BACK,true);
      ObjectSetInteger(NULL,"range high ",OBJPROP_STYLE,STYLE_DOT);
   }
   
   //low
   ObjectsDeleteAll(NULL,"range low");
   if(range.low<DBL_MAX){
      ObjectCreate(NULL,"range low",OBJ_TREND,0,range.start_time,range.low,range.end_time,range.low);
      ObjectSetString(NULL,"range low",OBJPROP_TOOLTIP,"high of the range: "+DoubleToString(range.low,_Digits));
      ObjectSetInteger(NULL,"range low",OBJPROP_COLOR,clrBlue);
      ObjectSetInteger(NULL,"range low",OBJPROP_WIDTH,2);
      ObjectSetInteger(NULL,"range low",OBJPROP_BACK,true);
      
      ObjectCreate(NULL,"range low ",OBJ_TREND,0,range.end_time,range.low,InpRangeClose >= 0 ? range.close_time : INT_MAX,range.low);
      ObjectSetString(NULL,"range low ",OBJPROP_TOOLTIP,"low of the range: "+DoubleToString(range.low,_Digits));
      ObjectSetInteger(NULL,"range low ",OBJPROP_COLOR,clrBlue);
      ObjectSetInteger(NULL,"range low ",OBJPROP_BACK,true);
      ObjectSetInteger(NULL,"range low ",OBJPROP_STYLE,STYLE_DOT);
   }
   
   //chart refresh
   ChartRedraw();  
}

//Check input parameters are valid!
bool CheckInputs(){

  if(InpMagicNumber <= 0){
      Alert("magic number <=0");
      return false;
   }
   if(InpLotMode == LOT_MODE_FIXED && (InpLots <= 0 || InpLots > 10)){
      Alert("lots <=0 || >10");
      return false;
   }
   if(InpLotMode==LOT_MODE_MONEY && (InpLots <= 0 || InpLots > 1000)){
      Alert("lots <=0 || >1000");
      return false;
   }
   if(InpLotMode==LOT_MODE_PCT_ACCOUNT && (InpLots <= 0 || InpLots > 5)){
      Alert("lots <=0 || >5");
      return false;
   }
   if((InpLotMode==LOT_MODE_MONEY || InpLotMode==LOT_MODE_PCT_ACCOUNT)  && (InpStopLoss == 0)){
      Alert("For given mode stoploss is to be set");
      return false;
   }
   if(InpStopLoss < 0 || InpStopLoss > 1000){
      Alert("stoploss <0 percent|| > 1000");
      return false;
   }
   if(InpTakeProfit < 0 || InpTakeProfit > 1000){
      Alert("Take profit <0 || >1");
      return false;
   }
   if(InpMonday+InpTuesday+InpWednesday+InpThursday+InpFriday==0){
      Alert("Range is phrohibited on all days of week");
      return false;;
   }
   if(InpRangeClose < 0 && InpStopLoss == 0){
      Alert("close time and stop loss both should not be off ");
      return false;;
   }
   if(InpRangeStart < 0 || InpRangeStart >= 1440){
      Alert("range start  <0 || >=1440");
      return false;;
   }
   if(InpRangeDuration <= 0 || InpRangeDuration >= 1440){
      Alert("range duration  <=0 || >= 1440");
      return false;
   }
   if(InpRangeClose >= 1440 || (InpRangeStart+InpRangeDuration)%1440 == InpRangeClose){
      Alert("close is at range end || >= 1440");
      return false;
   }
   return true;
}

