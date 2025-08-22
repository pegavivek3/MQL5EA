//+------------------------------------------------------------------+
//|                                          macd strategy by VP.mq5 |
//|                                          Copyright 2025, Vivek D |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Vivek D"
#property link      "https://www.mql5.com"
#property version   "1.00"


// Include the Trade class for easier trade operations
#include <Trade\Trade.mqh>
CTrade trade;

// Input parameters
input int                  InpFastEMA = 12;       // Fast EMA period
input int                  InpSlowEMA = 26;       // Slow EMA period
input int                  InpSignalSMA = 9;      // Signal SMA period
//input double               InpLotSize = 0.1;      // Lot size
input int                  InpMagicNumber = 12345;// Magic number
//input int                  InpStopLoss = 200;     // Stop loss in points
//input int                  InpTakeProfit = 400;   // Take profit in points
input int atrperiod = 14;
input double slatrmultiplier = 1.5;
input double tpatrmultiplier = 2.0;
//input bool buy = true; //for sell false
input double balance = 5000.00;
input int risk_percentage = 1;
int atrhandle;
datetime atr_calc_time = 0;

// Global variables
int macdHandle; // Handle for MACD indicator
double macdBuffer[]; // Array to store MACD values
double signalBuffer[]; // Array to store signal line values


//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   if (atrperiod<0 || atrperiod > 21){
       Print("parameters incorrect try to change atrperiod");
       return INIT_PARAMETERS_INCORRECT;
     }
     trade.SetExpertMagicNumber(InpMagicNumber);
   
     atrhandle = iATR(_Symbol,PERIOD_CURRENT,atrperiod);
   // Create MACD indicator handle
   macdHandle = iMACD(NULL, 0, InpFastEMA, InpSlowEMA, InpSignalSMA, PRICE_CLOSE);
   
   // Set indicator buffers
   ArraySetAsSeries(macdBuffer, true);
   ArraySetAsSeries(signalBuffer, true);
   
   // Check if handle was created successfully
   if(macdHandle == INVALID_HANDLE)
   {
      Print("Failed to create MACD handle");
      return(INIT_FAILED);
   }
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Release indicator handle
   IndicatorRelease(macdHandle);
   IndicatorRelease(atrhandle);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   static double tp = 0.0;
   static double sl =0.0;
   static double lot = 0.0;
   // Check if we have enough bars
   if(Bars(NULL, 0) < InpSlowEMA + InpSignalSMA)
      return;
   
   // Get MACD values
   if(CopyBuffer(macdHandle, 0, 0, 3, macdBuffer) < 3 || 
      CopyBuffer(macdHandle, 1, 0, 3, signalBuffer) < 3)
   {
      Print("Failed to copy MACD buffers");
      return;
   }
   double atr[];
   CopyBuffer(atrhandle,0,0,1,atr);
        
   
        
           
           double riskMoney = balance * (risk_percentage / 100.0);
           if(riskMoney <= 0) return;
           double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
           double sl_price_dist = atr[0] * slatrmultiplier ;
           double sl_points = sl_price_dist / point;
           
           lot = CalculateVolume(riskMoney, sl_points);
           
           
            
           // Check for open positions
           bool positionExists = PositionSelect(Symbol());
         
           // MACD trading logic
           if(!positionExists)
           {
              // Buy signal: MACD crosses above signal line
              if( (macdBuffer[1] <= signalBuffer[1] && macdBuffer[0] > signalBuffer[0]) )
              {
                  
                  double ask = SymbolInfoDouble(NULL, SYMBOL_ASK);
                  tp = ask + atr[0] * tpatrmultiplier;
                  tp = NormalizeDouble(tp,_Digits);
                  sl = ask - atr[0] * slatrmultiplier;
                  sl = NormalizeDouble(sl,_Digits);
                  
                  trade.Buy(lot, NULL, ask, sl, tp, "MACD Buy");
                  
               }
               // Sell signal: MACD crosses below signal line
               else if( (macdBuffer[1] >= signalBuffer[1] && macdBuffer[0] < signalBuffer[0]) )
               {
                  
                  double bid = SymbolInfoDouble(NULL, SYMBOL_BID);
                  tp = bid - atr[0] * tpatrmultiplier;
                  tp = NormalizeDouble(tp,_Digits);
                  sl = bid + atr[0] * slatrmultiplier;
                  sl = NormalizeDouble(sl,_Digits);
                   
                  
                  trade.Sell(lot, NULL, bid, sl, tp, "MACD Sell");
                  
               }
             ObjectsDeleteAll(0,"atr");
             DrawObjects(sl,tp,lot);
            }
           
           CloseAllPositions(macdBuffer);
           Comment("sl: "+DoubleToString(sl,8)+"\ntp:  "+DoubleToString(tp,8)+"\nvolume  "+DoubleToString(lot,4));
           
   
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



void CloseAllPositions(double &macdline[])
{
   int total = PositionsTotal();

   for(int i = total - 1; i >= 0; i--)
   {
      string symbol = PositionGetSymbol(i);

      if(PositionSelect(symbol))
      {
         long   type   = PositionGetInteger(POSITION_TYPE);
         double volume = PositionGetDouble(POSITION_VOLUME);

         if(type == POSITION_TYPE_BUY && (macdline[1] > 0.0 && macdline[0] <= 0.0))
            trade.PositionClose(symbol);   // Close Buy
         else if(type == POSITION_TYPE_SELL && (macdline[1] < 0.0 && macdline[0] >= 0.0))
            trade.PositionClose(symbol);    // Close Sell
      }
   }
}

