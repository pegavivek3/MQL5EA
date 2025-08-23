//+------------------------------------------------------------------+
//| Ichimoku Cloud Strategy with Alerts + Logging + Push (MQL5)      |
//| By VP (modified with CTrade + logging fixes)                     |
//+------------------------------------------------------------------+
#include <Trade/Trade.mqh>
CTrade trade;

//--- File names
string signalFile = "IchimokuSignals.csv";
string errorFile  = "IchimokuErrors.csv";

//--- Indicator handles
int ichHandle, maHandle;

//--- For daily push notifications
datetime lastPushTime = 0;

//+------------------------------------------------------------------+
//| Expert initialization                                            |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- Ichimoku Cloud
   ichHandle = iIchimoku(_Symbol, PERIOD_CURRENT, 9, 26, 52);
   if(ichHandle==INVALID_HANDLE)
   {
      LogError("Error creating Ichimoku handle for "+_Symbol);
      return(INIT_FAILED);
   }

   //--- 200-period MA
   maHandle = iMA(_Symbol, PERIOD_CURRENT, 200, 0, MODE_SMA, PRICE_CLOSE);
   if(maHandle==INVALID_HANDLE)
   {
      LogError("Error creating MA handle for "+_Symbol);
      return(INIT_FAILED);
   }

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization                                          |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {}

//+------------------------------------------------------------------+
//| Expert tick                                                      |
//+------------------------------------------------------------------+
void OnTick()
{
   static datetime lastBar = 0;
   datetime curBar = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(curBar == lastBar) return;
   lastBar = curBar;

   CheckSignal();

   // push notification at 5:30 IST daily
   SendDailyPush();
}

//+------------------------------------------------------------------+
//| Check Ichimoku + MA signals                                      |
//+------------------------------------------------------------------+
void CheckSignal()
{
   double tenkan[3], kijun[3], senkouA[3], senkouB[3];
   double ma200[3], closePrice[3];

   if(CopyBuffer(ichHandle,0,0,3,tenkan)<3) return;
   if(CopyBuffer(ichHandle,1,0,3,kijun)<3) return;
   if(CopyBuffer(ichHandle,2,0,3,senkouA)<3) return;
   if(CopyBuffer(ichHandle,3,0,3,senkouB)<3) return;
   if(CopyBuffer(maHandle,0,0,3,ma200)<3) return;
   if(CopyClose(_Symbol,PERIOD_CURRENT,0,3,closePrice)<3) return;

   double price = closePrice[1]; // last closed bar

   // check cross
   bool bullishCross = (tenkan[2]<kijun[2] && tenkan[1]>kijun[1]);
   bool bearishCross = (tenkan[2]>kijun[2] && tenkan[1]<kijun[1]);

   bool aboveCloud = (price > MathMax(senkouA[1], senkouB[1]));
   bool belowCloud = (price < MathMin(senkouA[1], senkouB[1]));

   bool above200 = (price > ma200[1]);
   bool below200 = (price < ma200[1]);

   string signal="";
   datetime sigTime = iTime(_Symbol,PERIOD_CURRENT,1);

   if(bullishCross && aboveCloud && above200)
      signal = "BUY";
   else if(bearishCross && belowCloud && below200)
      signal = "SELL";

   if(signal!="")
   {
      string msg = TimeToString(sigTime,TIME_DATE|TIME_MINUTES)+","+_Symbol+","+signal;
      Print(msg);
      Alert(msg);
      LogSignal(msg);
   }
}

//+------------------------------------------------------------------+
//| Log to signals.csv (append)                                      |
//+------------------------------------------------------------------+
void LogSignal(string text)
{
   int h = FileOpen(signalFile, FILE_WRITE|FILE_READ|FILE_CSV|FILE_ANSI, ";");
   if(h==INVALID_HANDLE) { Print("Cannot open signals.csv"); return; }
   FileSeek(h, 0, SEEK_END); // move to end for append
   FileWrite(h, text);
   FileClose(h);
}

//+------------------------------------------------------------------+
//| Log to errors.csv (append)                                       |
//+------------------------------------------------------------------+
void LogError(string text)
{
   int h = FileOpen(errorFile, FILE_WRITE|FILE_READ|FILE_CSV|FILE_ANSI, ";");
   if(h==INVALID_HANDLE) { Print("Cannot open errors.csv"); return; }
   FileSeek(h, 0, SEEK_END); // move to end for append
   FileWrite(h, TimeToString(TimeCurrent(),TIME_DATE|TIME_MINUTES)+","+text);
   FileClose(h);
   Print("ERROR: ",text);
}

//+------------------------------------------------------------------+
//| Daily Push at 5:30 IST                                           |
//+------------------------------------------------------------------+
void SendDailyPush()
{
   //--- Current IST time
   datetime now      = TimeCurrent();             // server time
   int offset        = 19800;                     // +5h30m in seconds
   datetime istNow   = now + offset;              // IST datetime

   
   MqlDateTime t;
   TimeToStruct(istNow,t);

   if(t.hour==5 && t.min==30) // push at 5:30 IST
   {
      // avoid multiple sends in same minute
      if(TimeCurrent()-lastPushTime < 60) return;
      lastPushTime = TimeCurrent();

      // collect today's signals
      string todaySignals="";
      int h = FileOpen(signalFile, FILE_READ|FILE_CSV|FILE_ANSI, ";");
      if(h!=INVALID_HANDLE)
      {
         while(!FileIsEnding(h))
         {
            string line = FileReadString(h);
            if(line=="") continue;

            // check if today
            string parts[];
            int n = StringSplit(line,',',parts);
            if(n>=2)
            {
               datetime sigTime = StringToTime(parts[0]);
               MqlDateTime ts, tn;
               TimeToStruct(sigTime, ts);
               TimeToStruct(TimeCurrent(), tn);

               if(ts.year==tn.year && ts.mon==tn.mon && ts.day==tn.day)
                  todaySignals += line+"\n";
            }
         }
         FileClose(h);
      }

      if(todaySignals!="")
         SendNotification("Ichimoku Signals Today:\n"+todaySignals);
   }
}
