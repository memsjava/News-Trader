////////////////////////////////////////////////////////////////////////////////
// Mechanical trade system for MetaTrader 5                                   //                                   //
////////////////////////////////////////////////////////////////////////////////
// User script "DarkVenus Default Controller"                   //
// Unit: TimeFrameChangerSL                                                          //
////////////////////////////////////////////////////////////////////////////////
// Version:      1.0                                                          //
// Version File: 1.0.0.0                                                      //
// File name: TimeFrameChangerSL.mq5                                                   //
////////////////////////////////////////////////////////////////////////////////
//                                  Property                                  //
////////////////////////////////////////////////////////////////////////////////
#property description "User script - DarkVenus Default Controller"
#property description "Version File: 1.0.0.0"
#property copyright "Copyright 2024, Interesting"
#property link "http://www.mql5.com"
#include <Trade\Trade.mqh> // Ensure you include the Trade library

#property script_show_inputs
////////////////////////////////////////////////////////////////////////////////
//                      The arrays for keeping main data                      //
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
//                              Input parameters                              //
////////////////////////////////////////////////////////////////////////////////

input ENUM_TIMEFRAMES WorkPeriod1 = PERIOD_M5;  // Work period first
input ENUM_TIMEFRAMES WorkPeriod2 = PERIOD_M15; // Work period second
input ENUM_TIMEFRAMES WorkPeriod3 = PERIOD_M30; // Work period third
input ENUM_TIMEFRAMES WorkPeriod4 = PERIOD_H1;  // Work period fourth
input ENUM_TIMEFRAMES dangerPeriod = PERIOD_H4; // Danger period
input ENUM_TIMEFRAMES newsPeriod = PERIOD_W1;   // News period
input double lossThresholdVal = 25;             // Loss threshold
input double lossThresholdValNews = 5;          // News Loss threshold
input bool enableLoss = false;                  // Enable smart stop

////////////////////////////////////////////////////////////////////////////////
//                Global variables, used in working the script                //
////////////////////////////////////////////////////////////////////////////////
// Define a structure to hold the news information
struct NewsInfo
{
  bool newsFound;  // Indicates if news was found
  int impact_type; // Impact type of the news
};

////////////////////////////////////////////////////////////////////////////////
//                       Script program start function                        //
////////////////////////////////////////////////////////////////////////////////
void SynchronizeTimeframes(ENUM_TIMEFRAMES timeframe)
{
  //----------------------------------------------------------------------------//
  // Work variables
  ENUM_TIMEFRAMES TimeFrames; // TimeFrames
  TimeFrames = timeframe;

  string ChartSymbolName; // The symbol name for the specified chart

  long ChartFirstID; // The ID of the first chart of the client terminal
  long ChartNextID;  // Identifier for of the new chart

  int Limit = CHARTS_MAX;

  int f;

  // DarkVenus Default Controller
  ChartFirstID = ChartFirst();
  // Processing of the main chart
  if (ChartPeriod(ChartFirstID) != TimeFrames)
  {
    ChartSymbolName = ChartSymbol(ChartFirstID);
    // Change the timeframe of the specified chart
    ChartSetSymbolPeriod(ChartFirstID, ChartSymbolName, TimeFrames);
    // Message for user
    PrintFormat("Change the timeframe of the chart %s. New period %s",
                ChartSymbolName, PeriodToStr(TimeFrames));
  }
  // Processing of additional charts
  f = 0;
  while (f < Limit)
  // We have certainly not more than 100 open charts
  {
    // Get the new chart ID by using the previous chart ID
    ChartNextID = ChartNext(ChartFirstID);

    if (ChartNextID < 0)
      break; // Have reached the end of the chart list

    if (ChartPeriod(ChartNextID) != TimeFrames)
    // Change the timeframe of the specified chart
    {
      ChartSymbolName = ChartSymbol(ChartNextID);
      // Change the timeframe of the specified chart
      ChartSetSymbolPeriod(ChartNextID, ChartSymbolName, TimeFrames);
      // Message for user
      PrintFormat("Change the timeframe of the chart %s. New period %s",
                  ChartSymbolName, PeriodToStr(TimeFrames));
    }

    // Let's save the current chart ID for the ChartNext()
    ChartFirstID = ChartNextID;
    // Do not forget to increase the counter
    f++;
  }
}

void checkAndClosePositionsIfNeeded(NewsInfo &newsInfo)
{
  double totalLoss = 0.0;                            // Variable to accumulate total loss
  double equity = AccountInfoDouble(ACCOUNT_EQUITY); // Get current equity

  double adjustedLossThresholdVal = newsInfo.newsFound ? lossThresholdValNews : lossThresholdVal;
  double lossThreshold = equity * (adjustedLossThresholdVal / 100.0); // Calculate threshold based on percentage

  ulong worstPositionTicket = 0; // Ticket of the position with the most loss
  double worstLoss = 0.0;        // Most significant loss

  // Loop through all open positions
  for (int i = 0; i < PositionsTotal(); i++)
  {
    ulong ticket = PositionGetTicket(i); // Get position ticket
    if (PositionSelectByTicket(ticket))  // Select position by ticket
    {
      double profit = PositionGetDouble(POSITION_PROFIT); // Get profit of the position
      totalLoss += profit;                                // Accumulate total loss (profit can be negative)

      // Check if this position has the worst loss
      if (profit < worstLoss) // profit is negative for loss
      {
        worstLoss = profit;           // Update worst loss
        worstPositionTicket = ticket; // Update ticket of the worst position
      }
    }
  }

  // Check if total loss exceeds the threshold
  if (totalLoss < -lossThreshold) // If total loss is more than 1/5 of equity
  {
    // Take action, e.g., close the position with the most loss or send a warning
    Print("Total loss exceeds 1/5 of equity. Current loss: ", totalLoss, ", Threshold: ", -lossThreshold);

    // Close the position with the most loss
    if (worstPositionTicket != 0) // Ensure there is a position to close
    {
      if (PositionSelectByTicket(worstPositionTicket))
      {
        CTrade trade; // Create an instance of the CTrade class
        // Close the position
        if (!trade.PositionClose(worstPositionTicket))
        {
          Print("Failed to close position with ticket: ", worstPositionTicket);
        }
        else
        {
          Print("Closed position with ticket: ", worstPositionTicket, " due to significant loss.");
        }
      }
    }
  }
}

NewsInfo isNewsInterval()
{
  MqlCalendarValue values[];
  datetime startTime = iTime(_Symbol, PERIOD_D1, 0);
  datetime endTime = startTime + 8 * PeriodSeconds(PERIOD_H1); // Check for news in the next 4 hours and previous 4 hours
  CalendarValueHistory(values, startTime, endTime, NULL, NULL);

  NewsInfo result = {false, 0}; // Initialize the result structure

  for (int i = 0; i < ArraySize(values); i++)
  {
    MqlCalendarEvent event;
    CalendarEventById(values[i].event_id, event);

    // Check if the event is related to USD or EUR
    if (event.country_id != 840 && event.country_id != 999) // 840 is USD, 978 is EUR
      continue;

    // Only consider high importance events
    if (event.importance != CALENDAR_IMPORTANCE_HIGH)
      continue;

    // Check if the event time is within 4 hours before or after the current time
    if (TimeCurrent() >= values[i].time - 4 * PeriodSeconds(PERIOD_H1) &&
        TimeCurrent() <= values[i].time + 4 * PeriodSeconds(PERIOD_H1))
    {
      Print(event.name, " -- > ", values[i].actual_value);
      result.newsFound = true;                    // Set newsFound to true
      result.impact_type = values[i].impact_type; // Set the impact type from MqlCalendarValue
      return result;                              // Return the result object
    }
  }
  return result; // No relevant news found
}

////////////////////////////////////////////////////////////////////////////////
//                      Specific procedures and functions                     //
////////////////////////////////////////////////////////////////////////////////
// Function PeriodToStr
string PeriodToStr(ENUM_TIMEFRAMES Value)
{
  //----------------------------------------------------------------------------//
  // Work variables
  string Result; // Returned importance
  //----------------------------------------------------------------------------//

  switch (Value)
  {
  case PERIOD_M1:
    Result = "M1";
    break;
  case PERIOD_M2:
    Result = "M2";
    break;
  case PERIOD_M3:
    Result = "M3";
    break;
  case PERIOD_M4:
    Result = "M4";
    break;
  case PERIOD_M5:
    Result = "M5";
    break;
  case PERIOD_M6:
    Result = "M6";
    break;
  case PERIOD_M10:
    Result = "M10";
    break;
  case PERIOD_M12:
    Result = "M12";
    break;
  case PERIOD_M15:
    Result = "M15";
    break;
  case PERIOD_M20:
    Result = "M20";
    break;
  case PERIOD_M30:
    Result = "M30";
    break;
  case PERIOD_H1:
    Result = "H1";
    break;
  case PERIOD_H2:
    Result = "H2";
    break;
  case PERIOD_H3:
    Result = "H3";
    break;
  case PERIOD_H4:
    Result = "H4";
    break;
  case PERIOD_H6:
    Result = "H6";
    break;
  case PERIOD_H8:
    Result = "H8";
    break;
  case PERIOD_H12:
    Result = "H12";
    break;
  case PERIOD_D1:
    Result = "Day";
    break;
  case PERIOD_W1:
    Result = "Week";
    break;
  case PERIOD_MN1:
    Result = "Month";
    break;
  // Unknown
  default:
    Result = "Unknown";
    break;
  }
  //----------------------------------------------------------------------------//
  return (Result);
  //----------------------------------------------------------------------------//
}
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
//                         Function to handle on tick events                 //
////////////////////////////////////////////////////////////////////////////////
void OnTick()
{
  NewsInfo newsInfo = isNewsInterval();
  if (newsInfo.newsFound)
  {
    SynchronizeTimeframes(newsPeriod);
    // checkAndClosePositionsIfNeeded(newsInfo);
  }
  else if (PositionsTotal() < 2)
  {
    SynchronizeTimeframes(WorkPeriod1);
  }
  else if (PositionsTotal() < 3)
  {
    SynchronizeTimeframes(WorkPeriod2);
  }
  else if (PositionsTotal() < 4)
  {
    SynchronizeTimeframes(WorkPeriod3);
  }
  else if (PositionsTotal() < 5)
  {
    SynchronizeTimeframes(WorkPeriod4);
  }
  else if (PositionsTotal() < 6)
  {
    SynchronizeTimeframes(dangerPeriod);
  }
}
