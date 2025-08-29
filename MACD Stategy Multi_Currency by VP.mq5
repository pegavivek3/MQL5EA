//+------------------------------------------------------------------+
//| MACD + SuperTrend Multi-Currency Strategy with ATR Risk & Logs   |
//| Reads currency pairs from Files/symbols.csv (comma-separated)    |
//| Author: Vivek D, 2025                                            |
//+------------------------------------------------------------------+
#property strict
#include <Trade/Trade.mqh>
CTrade trade;

//--- Inputs
input ENUM_TIMEFRAMES TF = PERIOD_D1;
input double TotalRiskPercent = 2.0;         // Max total risk across all pairs
input int ATR_Period = 14;
input double ATR_Mult = 2.0;                 // SL = ATR*Mult
input int EMA_Period = 200;                  // Trend filter
input int MACD_Fast = 12, MACD_Slow = 26, MACD_Signal = 9;
input int ST_Period = 10;                    // SuperTrend
input double ST_Mult = 3.0;

//--- CSV Logs
input string TradeLogFile  = "MACD_Multi_TradeLog.csv";
input string SignalLogFile = "MACD_TRADE_Multi__SignalLog.csv";
input string ErrorLogFile  = "MACD_TRADE_Multi_ErrorLog.csv";
input string SymbolsFile   = "symbols.csv"; // Comma-separated symbols in Files/

#define MAX_PAIRS 20
string Symbols[MAX_PAIRS];
int SymbolCount = 0;

//--- Per-symbol state
struct SymbolState
{
   int macdHandle, atrHandle, emaHandle, stHandle;
   double macdMain[3], macdSignal[3], atr[1], ema[1], stUp[1], stDown[1];
   datetime lastBar;
   int lastSignal;
};
SymbolState States[MAX_PAIRS];

//+------------------------------------------------------------------+
int OnInit()
{
   if(!LoadSymbols())
   {
      LogError("Failed to load symbols from "+SymbolsFile);
      return INIT_FAILED;
   }

   for(int i=0;i<SymbolCount;i++)
   {
      string sym = Symbols[i];
      States[i].macdHandle = iMACD(sym, TF, MACD_Fast, MACD_Slow, MACD_Signal, PRICE_CLOSE);
      States[i].atrHandle  = iATR(sym, TF, ATR_Period);
      States[i].emaHandle  = iMA(sym, TF, EMA_Period, 0, MODE_EMA, PRICE_CLOSE);
      States[i].stHandle   = iCustom(sym, TF, "SuperTrend", ST_Period, ST_Mult);
      States[i].lastBar = 0;
      States[i].lastSignal = 0;

      if(States[i].macdHandle==INVALID_HANDLE || States[i].atrHandle==INVALID_HANDLE ||
         States[i].emaHandle==INVALID_HANDLE || States[i].stHandle==INVALID_HANDLE)
      {
         LogError("Failed to create indicator handles for "+sym);
         return INIT_FAILED;
      }
   }

   InitLogs();
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnTick()
{
   for(int i=0;i<SymbolCount;i++)
      ProcessSymbol(i);
}

//+------------------------------------------------------------------+
//| Process one symbol                                               |
//+------------------------------------------------------------------+
void ProcessSymbol(int idx)
{
   string sym = Symbols[idx];

   datetime curBar = iTime(sym, TF, 0);
   if(curBar == States[idx].lastBar) return;
   States[idx].lastBar = curBar;

   if(CopyBuffer(States[idx].macdHandle,0,0,3,States[idx].macdMain)<3 ||
      CopyBuffer(States[idx].macdHandle,1,0,3,States[idx].macdSignal)<3 ||
      CopyBuffer(States[idx].atrHandle,0,0,1,States[idx].atr)<1 ||
      CopyBuffer(States[idx].emaHandle,0,0,1,States[idx].ema)<1 ||
      CopyBuffer(States[idx].stHandle,0,0,1,States[idx].stUp)<1 ||
      CopyBuffer(States[idx].stHandle,1,0,1,States[idx].stDown)<1)
   {
      LogError("CopyBuffer failed for "+sym);
      return;
   }

   double close = iClose(sym,TF,1);
   double atrVal = States[idx].atr[0];
   double emaVal = States[idx].ema[0];

   bool bullCross = (States[idx].macdMain[2] <= States[idx].macdSignal[2] && States[idx].macdMain[1] > States[idx].macdSignal[1] && States[idx].macdMain[1] > 0);
   bool bearCross = (States[idx].macdMain[2] >= States[idx].macdSignal[2] && States[idx].macdMain[1] < States[idx].macdSignal[1] && States[idx].macdMain[1] < 0);

   bool trendUp = (close > emaVal);
   bool trendDown = (close < emaVal);

   bool stBull = (close > States[idx].stUp[0]);
   bool stBear = (close < States[idx].stDown[0]);

   int signal=0;
   if(bullCross && trendUp) signal=1;
   if(bearCross && trendDown) signal=-1;

   ManageTrades(sym, States[idx], signal, atrVal, stBull, stBear);
}

//+------------------------------------------------------------------+
//| Manage Trades for one symbol                                     |
//+------------------------------------------------------------------+
void ManageTrades(string sym, SymbolState &S, int signal, double atrVal, bool stBull, bool stBear)
{
   bool hasPos = PositionSelect(sym);
   double bid = SymbolInfoDouble(sym, SYMBOL_BID);
   double ask = SymbolInfoDouble(sym, SYMBOL_ASK);

   // --- Risk management: max 1% per symbol, total 2% across all
   double perPairRisk = MathMin(1.0, TotalRiskPercent / SymbolCount);

   if(signal!=0 && signal!=S.lastSignal)
   {
      if(!hasPos && GetTotalRiskPercent()<TotalRiskPercent) // Open new trade
      {
         double sl = atrVal*ATR_Mult;
         double lot = CalcLot(sym, sl, perPairRisk);
         if(signal==1)
            trade.Buy(lot,sym,0,NormalizeDouble(bid-sl,_Digits),0,"MACD BUY");
         if(signal==-1)
            trade.Sell(lot,sym,0,NormalizeDouble(ask+sl,_Digits),0,"MACD SELL");

         LogTrade(sym,"OPEN",signal,lot,sl);
         Alert("Trade opened: ",sym," ",(signal==1?"BUY":"SELL"));
      }
      S.lastSignal=signal;
      LogSignal(sym,signal,S.macdMain[1],S.macdSignal[1]);
   }

   if(hasPos)
   {
      long type = PositionGetInteger(POSITION_TYPE);
      double entry=PositionGetDouble(POSITION_PRICE_OPEN);
      double lots = PositionGetDouble(POSITION_VOLUME);

      // Half close at +2ATR
      double tpTrigger = entry + (type==POSITION_TYPE_BUY? atrVal*2 : -atrVal*2);
      if((type==POSITION_TYPE_BUY && bid>=tpTrigger) ||
         (type==POSITION_TYPE_SELL && ask<=tpTrigger))
      {
         double half = lots/2.0;
         if(half>=SymbolInfoDouble(sym,SYMBOL_VOLUME_MIN))
         {
            trade.PositionClosePartial(sym,half);
            LogTrade(sym,"PARTIAL CLOSE",type==POSITION_TYPE_BUY?1:-1,half,atrVal*2);
         }
      }

      // Exit on SuperTrend flip or opposite MACD
      if((type==POSITION_TYPE_BUY && (stBear || signal==-1)) ||
         (type==POSITION_TYPE_SELL && (stBull || signal==1)))
      {
         trade.PositionClose(sym);
         LogTrade(sym,"CLOSE",type==POSITION_TYPE_BUY?1:-1,lots,0);
         Alert("Trade closed by exit rule: ",sym);
         S.lastSignal=0;
      }
   }
}

//+------------------------------------------------------------------+
//| Lot Calculation (risk % per symbol)                              |
//+------------------------------------------------------------------+
double CalcLot(string sym, double slPips, double riskPercent)
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmt = balance*riskPercent/100.0;

   double tickVal = SymbolInfoDouble(sym,SYMBOL_TRADE_TICK_VALUE);
   double tickSize= SymbolInfoDouble(sym,SYMBOL_TRADE_TICK_SIZE);
   double contract= SymbolInfoDouble(sym,SYMBOL_TRADE_CONTRACT_SIZE);

   double slPoints = slPips/_Point;
   double lossPerLot = slPoints*tickVal;

   double lots = riskAmt/lossPerLot;
   double step = SymbolInfoDouble(sym,SYMBOL_VOLUME_STEP);

   return NormalizeDouble(MathMax(SymbolInfoDouble(sym,SYMBOL_VOLUME_MIN),
                                  MathMin(lots,SymbolInfoDouble(sym,SYMBOL_VOLUME_MAX))),
                                  (int)MathLog10(1.0/step));
}

//+------------------------------------------------------------------+
//| Helpers                                                          |
//+------------------------------------------------------------------+
string TrimString(const string str)
{
   int first = 0, last = StringLen(str) - 1;
   while(first <= last && (str[first] == ' ' || str[first] == '\t')) first++;
   while(last >= first && (str[last] == ' ' || str[last] == '\t')) last--;
   if(first > last) return "";
   return StringSubstr(str, first, last - first + 1);
}

bool LoadSymbols()
{
   SymbolCount = 0;
   int f = FileOpen(SymbolsFile, FILE_READ|FILE_TXT|FILE_ANSI);
   if(f<0) return false;
   string line = FileReadString(f);
   FileClose(f);
   if(line=="") return false;
   string arr[];
   int n = StringSplit(line,',',arr);
   for(int i=0; i<n && i<MAX_PAIRS; i++)
   {
      string s = TrimString(arr[i]);
      if(s!=""){ Symbols[SymbolCount++] = s; }
   }
   return SymbolCount>0;
}

void InitLogs()
{
   if(!FileIsExist(TradeLogFile))
   {
      int f=FileOpen(TradeLogFile,FILE_WRITE|FILE_CSV); if(f>=0){ FileWrite(f,"Symbol,Time,Action,Signal,Lots,Info"); FileClose(f); }
   }
   if(!FileIsExist(SignalLogFile))
   {
      int f=FileOpen(SignalLogFile,FILE_WRITE|FILE_CSV); if(f>=0){ FileWrite(f,"Symbol,Time,Signal,MACD,SignalLine"); FileClose(f); }
   }
   if(!FileIsExist(ErrorLogFile))
   {
      int f=FileOpen(ErrorLogFile,FILE_WRITE|FILE_CSV); if(f>=0){ FileWrite(f,"Time,Error"); FileClose(f); }
   }
}

void LogTrade(string sym, string action,int signal,double lot,double info)
{
   int f=FileOpen(TradeLogFile,FILE_READ|FILE_WRITE|FILE_CSV);
   if(f<0) return; FileSeek(f,0,SEEK_END);
   FileWrite(f,sym,TimeToString(TimeCurrent(),TIME_DATE|TIME_MINUTES),action,(signal==1?"BUY":"SELL"),lot,DoubleToString(info,2));
   FileClose(f);
}

void LogSignal(string sym, int signal,double macd,double sig)
{
   int f=FileOpen(SignalLogFile,FILE_READ|FILE_WRITE|FILE_CSV);
   if(f<0) return; FileSeek(f,0,SEEK_END);
   FileWrite(f,sym,TimeToString(TimeCurrent(),TIME_DATE|TIME_MINUTES),(signal==1?"BUY":"SELL"),DoubleToString(macd,5),DoubleToString(sig,5));
   FileClose(f);
}

void LogError(string msg)
{
   int f=FileOpen(ErrorLogFile,FILE_READ|FILE_WRITE|FILE_CSV);
   if(f<0) return; FileSeek(f,0,SEEK_END);
   FileWrite(f,TimeToString(TimeCurrent(),TIME_DATE|TIME_MINUTES),msg);
   FileClose(f);
}

//+------------------------------------------------------------------+
//| Calculate total open risk as % of balance                        |
//+------------------------------------------------------------------+
double GetTotalRiskPercent()
{
   double totalRisk = 0.0;
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   for(int i=0;i<PositionsTotal();i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
      {
         string sym = PositionGetString(POSITION_SYMBOL);
         double lots = PositionGetDouble(POSITION_VOLUME);
         double entry = PositionGetDouble(POSITION_PRICE_OPEN);
         double sl = PositionGetDouble(POSITION_SL);
         if(sl>0 && entry!=sl)
         {
            double tickVal = SymbolInfoDouble(sym,SYMBOL_TRADE_TICK_VALUE);
            double risk = MathAbs(entry-sl)/SymbolInfoDouble(sym,SYMBOL_POINT) * tickVal * lots;
            totalRisk += risk;
         }
      }
   }
   if(balance>0)
      return 100.0*totalRisk/balance;
   return 0.0;
}
//+------------------------------------------------------------------+
