//+------------------------------------------------------------------+
//|                            atr based sl and tp draw on chart.mq5 |
//|                                          Copyright 2025, Vivek D |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Vivek D"
#property link      "https://www.mql5.com"
#property version   "1.00"
input int atrperiod = 14;
input double slatrmultiplier = 1.5;
input double tpatrmultiplier = 2.0;
input bool buy = true; //for sell false
input double balance = 5000.00;
input int risk_percentage = 1;
int atrhandle;
datetime atr_calc_time = 0;
static double tp = 0.0;
static double sl =0.0;
static double volume = 0.0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
     if (atrperiod<0 && atrperiod > 21){
       Print("parameters incorrect try to change atrperiod");
       return INIT_PARAMETERS_INCORRECT;
     }
     atrhandle = iATR(_Symbol,PERIOD_CURRENT,atrperiod);
   
//---
     return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
     if(atrhandle != INIT_FAILED ) {IndicatorRelease(atrhandle);}
     ObjectsDeleteAll(0,"atr");
   
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
        double atr[];
        CopyBuffer(atrhandle,0,0,1,atr);
        
        static datetime last_bar_time = 0;
        datetime current_bar_time = iTime(_Symbol, PERIOD_CURRENT, 0);
        if(current_bar_time != last_bar_time){
           last_bar_time = current_bar_time ;
           if(buy){
              double entry = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
              entry = NormalizeDouble(entry,_Digits);
              tp = entry + atr[0] * tpatrmultiplier;
              tp = NormalizeDouble(tp,_Digits);
              sl = entry - atr[0] * slatrmultiplier;
              sl = NormalizeDouble(sl,_Digits);
           }
           if(!buy){
              double entry = SymbolInfoDouble(_Symbol,SYMBOL_BID);
              entry = NormalizeDouble(entry,_Digits);
              tp = entry - atr[0] * tpatrmultiplier;
              tp = NormalizeDouble(tp,_Digits);
              sl = entry + atr[0] * slatrmultiplier;
              sl = NormalizeDouble(sl,_Digits);
          
           }
           double riskMoney = balance * (risk_percentage / 100.0);
           if(riskMoney <= 0) return;
           double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
           double sl_price_dist = atr[0] * slatrmultiplier ;
           double sl_points = sl_price_dist / point;
           
           volume = CalculateVolume(riskMoney, sl_points);
           ObjectsDeleteAll(0,"atr");
           DrawObjects(sl,tp,volume);
        }
        Comment("sl: "+DoubleToString(sl,8)+"\ntp:  "+DoubleToString(tp,8)+"\nvolume  "+DoubleToString(volume,4));
            
   
  }
  
  void DrawObjects(double sl1,double tp1,double volume1){

   //start time
      string slstr = "sl :"+DoubleToString(sl1,8)+" \nlots:"+DoubleToString(volume1,4);
      ObjectCreate(0,"atr sl",OBJ_HLINE,0,0,sl1);
      ObjectSetString(0,"atr sl",OBJPROP_TOOLTIP,slstr);
      ObjectSetInteger(0,"atr sl",OBJPROP_COLOR,clrBlue);
      ObjectSetInteger(0,"atr sl",OBJPROP_WIDTH,2);
      ObjectSetInteger(0,"atr sl",OBJPROP_BACK,false);
   
      string tpstr = "tp :"+DoubleToString(tp1,8)+" \nlots:"+DoubleToString(volume1,4);
      ObjectCreate(0,"atr tp",OBJ_HLINE,0,0,tp1);
      ObjectSetString(0,"atr tp",OBJPROP_TOOLTIP,tpstr);
      ObjectSetInteger(0,"atr tp",OBJPROP_COLOR,clrBlue);
      ObjectSetInteger(0,"atr tp",OBJPROP_WIDTH,2);
      ObjectSetInteger(0,"atr tp",OBJPROP_BACK,false);
   
   
   }
   
   
   //end time
   //ObjectDelete(NULL,"range end");
   
   
  
 //normalize volume
  double NormalizeVolume(double vol)
{
  double minlot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
  double maxlot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
  double step   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
  if(step <= 0) step = 0.01;
  // round down to nearest step
  double steps = MathFloor(vol / step + 0.0000001);
  double rounded = steps * step;
  // clamp
  if(rounded < minlot) rounded = minlot;
  if(rounded > maxlot) rounded = maxlot;
  // final normalization to step precision
  return NormalizeDouble(rounded, (int)MathMax(0, (int)MathCeil(-MathLog10(step))));
}

// Calculate volume based on risk money and stop distance (in points)
double CalculateVolume(double riskMoney, double stopDistancePoints)
{
  //if(stopDistancePoints <= 0) return 0.0;
  // Tick value is value of one tick (point) for 1 lot
  double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
  if(tickValue <= 0)
  {
    // fall back to approximate calc using contract size and point value
    double contractSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE);
    double point       = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    // Value per lot per point: contractSize * point (approx) * price of quote currency -> complicated
    // For safety return 0
    return 0.0;
  }
  // Risk per 1 lot = stopDistancePoints * tickValue
  double vol = riskMoney / (stopDistancePoints * tickValue);
  return NormalizeVolume(vol);
}
//+------------------------------------------------------------------+
