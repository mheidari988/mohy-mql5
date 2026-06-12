#ifndef __MOHY_RUNTIME_PANEL_MQH__
#define __MOHY_RUNTIME_PANEL_MQH__

#include <MOHY/Runtime/RuntimeCommon.mqh>
#include <MOHY/Domain/Contracts.mqh>

class CMohyRuntimePanel
  {
private:
   long   m_chart_id;
   string m_prefix;
   bool   m_enabled;
   int    m_corner;
   int    m_x;
   int    m_y;
   int    m_width;
   int    m_height;

   string Name(const string suffix) const
     {
      return StringFormat("%s%s", m_prefix, suffix);
     }

   bool IsRightCorner() const
     {
      return (m_corner == CORNER_RIGHT_UPPER || m_corner == CORNER_RIGHT_LOWER);
     }

   bool IsLowerCorner() const
     {
      return (m_corner == CORNER_LEFT_LOWER || m_corner == CORNER_RIGHT_LOWER);
     }

   void ResolvePanelOrigin(int &out_x,
                           int &out_y) const
     {
      out_x = m_x;
      out_y = m_y;

      long chart_width = 0;
      long chart_height = 0;
      if(!ChartGetInteger(m_chart_id, CHART_WIDTH_IN_PIXELS, 0, chart_width) ||
         !ChartGetInteger(m_chart_id, CHART_HEIGHT_IN_PIXELS, 0, chart_height))
         return;

      if(IsRightCorner())
         out_x = MathMax(0, (int)chart_width - m_x - m_width);
      if(IsLowerCorner())
         out_y = MathMax(0, (int)chart_height - m_y - m_height);
     }

   string CompactText(const string value,
                      const int max_len) const
     {
      if(max_len <= 3 || StringLen(value) <= max_len)
         return value;

      const int head = MathMax(1, (max_len - 3) / 2);
      const int tail = MathMax(1, max_len - 3 - head);
      return StringFormat("%s...%s",
                          StringSubstr(value, 0, head),
                          StringSubstr(value, StringLen(value) - tail, tail));
     }

   void UpsertRect(const string name,
                   const color fill_color,
                   const color border_color,
                   const int x,
                   const int y,
                   const int width,
                   const int height) const
     {
      if(ObjectFind(m_chart_id, name) < 0)
         ObjectCreate(m_chart_id, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);

      ObjectSetInteger(m_chart_id, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(m_chart_id, name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(m_chart_id, name, OBJPROP_YDISTANCE, y);
      ObjectSetInteger(m_chart_id, name, OBJPROP_XSIZE, width);
      ObjectSetInteger(m_chart_id, name, OBJPROP_YSIZE, height);
      ObjectSetInteger(m_chart_id, name, OBJPROP_BGCOLOR, fill_color);
      ObjectSetInteger(m_chart_id, name, OBJPROP_COLOR, border_color);
      ObjectSetInteger(m_chart_id, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(m_chart_id, name, OBJPROP_BACK, false);
      ObjectSetInteger(m_chart_id, name, OBJPROP_HIDDEN, true);
      ObjectSetInteger(m_chart_id, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(m_chart_id, name, OBJPROP_SELECTED, false);
      ObjectSetInteger(m_chart_id, name, OBJPROP_ZORDER, 0);
     }

   void UpsertLabel(const string name,
                    const string text,
                    const int x,
                    const int y,
                    const color text_color,
                    const int font_size,
                    const bool bold = false) const
     {
      if(ObjectFind(m_chart_id, name) < 0)
         ObjectCreate(m_chart_id, name, OBJ_LABEL, 0, 0, 0);

      ObjectSetInteger(m_chart_id, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(m_chart_id, name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(m_chart_id, name, OBJPROP_YDISTANCE, y);
      ObjectSetInteger(m_chart_id, name, OBJPROP_COLOR, text_color);
      ObjectSetInteger(m_chart_id, name, OBJPROP_FONTSIZE, font_size);
      ObjectSetString(m_chart_id, name, OBJPROP_FONT, bold ? "Consolas Bold" : "Consolas");
      ObjectSetString(m_chart_id, name, OBJPROP_TEXT, text);
      ObjectSetInteger(m_chart_id, name, OBJPROP_HIDDEN, true);
      ObjectSetInteger(m_chart_id, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(m_chart_id, name, OBJPROP_SELECTED, false);
      ObjectSetInteger(m_chart_id, name, OBJPROP_ZORDER, 1);
     }

   void UpsertButton(const string name,
                     const string text,
                     const int x,
                     const int y,
                     const int width,
                     const int height,
                     const color bg_color,
                     const color text_color) const
     {
      if(ObjectFind(m_chart_id, name) < 0)
         ObjectCreate(m_chart_id, name, OBJ_BUTTON, 0, 0, 0);

      ObjectSetInteger(m_chart_id, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(m_chart_id, name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(m_chart_id, name, OBJPROP_YDISTANCE, y);
      ObjectSetInteger(m_chart_id, name, OBJPROP_XSIZE, width);
      ObjectSetInteger(m_chart_id, name, OBJPROP_YSIZE, height);
      ObjectSetInteger(m_chart_id, name, OBJPROP_BGCOLOR, bg_color);
      ObjectSetInteger(m_chart_id, name, OBJPROP_COLOR, text_color);
      ObjectSetInteger(m_chart_id, name, OBJPROP_FONTSIZE, 9);
      ObjectSetString(m_chart_id, name, OBJPROP_FONT, "Consolas");
      ObjectSetString(m_chart_id, name, OBJPROP_TEXT, text);
      ObjectSetInteger(m_chart_id, name, OBJPROP_HIDDEN, true);
      ObjectSetInteger(m_chart_id, name, OBJPROP_ZORDER, 2);
     }

public:
            CMohyRuntimePanel()
              {
               m_chart_id = 0;
               m_prefix = "";
               m_enabled = true;
               m_corner = CORNER_RIGHT_UPPER;
               m_x = 20;
               m_y = 20;
               m_width = 360;
               m_height = 338;
              }

   void     Configure(const long chart_id,
                      const string prefix,
                      const bool enabled,
                      const int corner,
                      const int x,
                      const int y)
     {
      m_chart_id = chart_id;
      m_prefix = prefix;
      m_enabled = enabled;
      m_corner = corner;
      m_x = x;
      m_y = y;
     }

   void     Clear() const
     {
      if(m_chart_id == 0 || m_prefix == "")
         return;

      ObjectsDeleteAll(m_chart_id, m_prefix);

      const string suffixes[] =
        {
         "PANEL_BG",
         "TITLE",
         "LINE1",
         "LINE2",
         "LINE3",
         "LINE4",
         "LINE5",
         "LINE6",
         "LINE7",
         "LINE8",
         "LINE9",
         "LINE10",
         "LINE11",
         "LINE12",
         "LINE13",
         "BTN_PAUSE",
         "BTN_RESUME",
         "BTN_CANCEL_WAITING",
         "BTN_CLOSE_TRADES",
         "BTN_FLATTEN"
        };
      for(int i = 0; i < ArraySize(suffixes); ++i)
        {
         const string name = Name(suffixes[i]);
         if(ObjectFind(m_chart_id, name) >= 0)
            ObjectDelete(m_chart_id, name);
        }

      ChartRedraw(m_chart_id);
     }

   void     Render(const UiRuntimeSnapshot &snapshot) const
     {
      if(!m_enabled)
        {
         Clear();
         return;
        }

      int panel_x = m_x;
      int panel_y = m_y;
      ResolvePanelOrigin(panel_x, panel_y);

      const bool blocked = (snapshot.position_state == "Blocked");
      const color fill_color = blocked ? C'255,235,238' : C'245,247,250';
      const color border_color = blocked ? C'183,28,28' : C'80,95,110';
      const string title_text = blocked ? "MOHY EA Phase 5 [BLOCKED]" : "MOHY EA Phase 5";

      UpsertRect(Name("PANEL_BG"),
                 fill_color,
                 border_color,
                 panel_x,
                 panel_y,
                 m_width,
                 m_height);
      UpsertLabel(Name("TITLE"),
                  title_text,
                  panel_x + 12,
                  panel_y + 8,
                  clrBlack,
                  11,
                  true);

      UpsertLabel(Name("LINE1"),
                  StringFormat("Symbol: %s | Pair: %s/%s",
                               snapshot.symbol,
                               snapshot.context_timeframe,
                               snapshot.execution_timeframe),
                  panel_x + 12,
                  panel_y + 34,
                  clrBlack,
                  9);
      UpsertLabel(Name("LINE2"),
                  StringFormat("Mode: %s | Pause: %s | Phase: %s",
                               snapshot.execution_mode,
                               snapshot.pause_state,
                               snapshot.strategy_phase),
                  panel_x + 12,
                  panel_y + 52,
                  clrBlack,
                  9);
      UpsertLabel(Name("LINE3"),
                  StringFormat("Setup: %s | Position: %s",
                               snapshot.setup_validity,
                               snapshot.position_state),
                  panel_x + 12,
                  panel_y + 70,
                  clrBlack,
                  9);
      UpsertLabel(Name("LINE4"),
                  StringFormat("SetupKey: %s",
                               CompactText(snapshot.setup_key, 34)),
                  panel_x + 12,
                  panel_y + 88,
                  clrBlack,
                  8);
      UpsertLabel(Name("LINE5"),
                  StringFormat("Impulse: %s",
                               CompactText(snapshot.impulse_id, 34)),
                  panel_x + 12,
                  panel_y + 106,
                  clrBlack,
                  8);
      UpsertLabel(Name("LINE6"),
                  StringFormat("Trigger: %s | RR: %s | Spread: %s",
                               snapshot.trigger_state,
                               snapshot.rr_state,
                               snapshot.spread_gate_state),
                  panel_x + 12,
                  panel_y + 124,
                  clrBlack,
                  8);
      UpsertLabel(Name("LINE7"),
                  StringFormat("BE: %s | Mgmt: %s",
                               snapshot.break_even_state,
                               snapshot.post_be_profile_state),
                  panel_x + 12,
                  panel_y + 142,
                  clrBlack,
                  8);
      UpsertLabel(Name("LINE8"),
                  StringFormat("Trail: %s | Partial: %s",
                               snapshot.trailing_state,
                               snapshot.partial_progress_state),
                  panel_x + 12,
                  panel_y + 160,
                  clrBlack,
                  8);
      UpsertLabel(Name("LINE9"),
                  StringFormat("Confirm: %s",
                               CompactText(snapshot.confirmation_state, 30)),
                  panel_x + 12,
                  panel_y + 178,
                  clrBlack,
                  8);
      UpsertLabel(Name("LINE10"),
                  StringFormat("Mgmt: %s",
                               CompactText(snapshot.last_management_action_result, 33)),
                  panel_x + 12,
                  panel_y + 196,
                  clrBlack,
                  8);
      UpsertLabel(Name("LINE11"),
                  StringFormat("PotImpulse: %s",
                               CompactText(snapshot.potential_impulse_state, 31)),
                  panel_x + 12,
                  panel_y + 214,
                  clrBlack,
                  8);
      UpsertLabel(Name("LINE12"),
                  StringFormat("PotCorr: %s",
                               CompactText(snapshot.potential_correction_state, 33)),
                  panel_x + 12,
                  panel_y + 232,
                  clrBlack,
                  8);
      UpsertLabel(Name("LINE13"),
                  StringFormat("Last: %s",
                               CompactText(snapshot.last_action_result, 32)),
                  panel_x + 12,
                  panel_y + 250,
                  clrBlack,
                  8);

      UpsertButton(Name("BTN_PAUSE"),
                   "Pause",
                   panel_x + 12,
                   panel_y + 276,
                   90,
                   24,
                   C'210,90,90',
                   clrWhite);
      UpsertButton(Name("BTN_RESUME"),
                   "Resume",
                   panel_x + 112,
                   panel_y + 276,
                   90,
                   24,
                   C'76,175,80',
                   clrWhite);
      UpsertButton(Name("BTN_CANCEL_WAITING"),
                   "Cancel Wait",
                   panel_x + 212,
                   panel_y + 276,
                   120,
                   24,
                   C'244,180,0',
                   clrBlack);
      UpsertButton(Name("BTN_CLOSE_TRADES"),
                   "Close Trades",
                   panel_x + 12,
                   panel_y + 304,
                   150,
                   24,
                   C'255,138,101',
                   clrBlack);
      UpsertButton(Name("BTN_FLATTEN"),
                   "Emergency Flat",
                   panel_x + 172,
                   panel_y + 304,
                   160,
                   24,
                   C'183,28,28',
                   clrWhite);
     }

   bool     HandleChartEvent(const int id,
                             const string sparam,
                             MohyUiActionId &out_action) const
     {
      out_action = MOHY_UI_ACTION_NONE;
      if(id != CHARTEVENT_OBJECT_CLICK)
         return false;

      if(sparam == Name("BTN_PAUSE"))
        {
         out_action = MOHY_UI_ACTION_PAUSE_ENTRIES;
         return true;
        }
      if(sparam == Name("BTN_RESUME"))
        {
         out_action = MOHY_UI_ACTION_RESUME_ENTRIES;
         return true;
        }
      if(sparam == Name("BTN_CANCEL_WAITING"))
        {
         out_action = MOHY_UI_ACTION_CANCEL_WAITING_ENTRIES;
         return true;
        }
      if(sparam == Name("BTN_CLOSE_TRADES"))
        {
         out_action = MOHY_UI_ACTION_CLOSE_STRATEGY_TRADES;
         return true;
        }
      if(sparam == Name("BTN_FLATTEN"))
        {
         out_action = MOHY_UI_ACTION_EMERGENCY_FLATTEN;
         return true;
        }
      return false;
     }
  };

#endif

