#ifndef __MOHY_RUNTIME_AUDIT_MQH__
#define __MOHY_RUNTIME_AUDIT_MQH__

#include <MOHY/Runtime/RuntimeCommon.mqh>
#include <MOHY/Domain/Contracts.mqh>

class CMohyRuntimeAudit
  {
private:
   string   m_scope_tag;
   long     m_chart_id;
   bool     m_enable_file_audit;
   bool     m_enable_terminal_alerts;
   long     m_next_sequence;
   string   m_last_alert_key;
   datetime m_last_alert_time;

   string AuditPath() const
     {
      return MohyRuntimeBuildRuntimePath(m_scope_tag, "ui_audit.csv");
     }

   void SkipFields(const int handle,
                   const int count) const
     {
      for(int i = 0; i < count && !FileIsEnding(handle); ++i)
         FileReadString(handle);
     }

   long ResolveLastSequence() const
     {
      if(m_scope_tag == "" || !m_enable_file_audit)
         return 0;

      const string path = AuditPath();
      if(!FileIsExist(path))
         return 0;

      const int handle = FileOpen(path, FILE_READ | FILE_CSV | FILE_ANSI, ',');
      if(handle == INVALID_HANDLE)
         return 0;

      long last_sequence = 0;
      while(!FileIsEnding(handle))
        {
         const string schema = FileReadString(handle);
         if(schema == "")
            break;

         const string sequence_text = !FileIsEnding(handle) ? FileReadString(handle) : "0";
         if(schema != "schema_version")
            last_sequence = (long)StringToInteger(sequence_text);

         SkipFields(handle, 15);
        }

      FileClose(handle);
      return last_sequence;
     }

   long NextSequence()
     {
      if(m_next_sequence <= 0)
         m_next_sequence = ResolveLastSequence();
      m_next_sequence++;
      return m_next_sequence;
     }

public:
            CMohyRuntimeAudit()
              {
               m_scope_tag = "";
               m_chart_id = 0;
               m_enable_file_audit = true;
               m_enable_terminal_alerts = true;
               m_next_sequence = 0;
               m_last_alert_key = "";
               m_last_alert_time = 0;
              }

   void     Configure(const string scope_tag,
                      const long chart_id,
                      const bool enable_file_audit,
                      const bool enable_terminal_alerts)
     {
      m_scope_tag = MohyRuntimeSanitizeToken(scope_tag);
      m_chart_id = chart_id;
      m_enable_file_audit = enable_file_audit;
      m_enable_terminal_alerts = enable_terminal_alerts;
      m_next_sequence = 0;
      m_last_alert_key = "";
      m_last_alert_time = 0;
     }

   bool     LogUiAction(const StrategyConfig &cfg,
                        const string symbol,
                        const string stage,
                        const MohyUiActionId action_id,
                        const string correlation_id,
                        const string pre_state_hash,
                        const string post_state_hash,
                        const MohyUiResultCode result_code,
                        const MohyUiAlertEventType severity,
                        const int broker_error,
                        const string message,
                        const string source)
     {
      if(m_scope_tag == "" || !m_enable_file_audit)
         return false;
      if(!MohyRuntimeEnsureDirectory(MohyRuntimeBuildRuntimeDirectory(m_scope_tag)))
         return false;

      const string path = AuditPath();
      const bool exists = FileIsExist(path);
      const int handle = FileOpen(path,
                                  FILE_READ | FILE_WRITE | FILE_CSV | FILE_ANSI,
                                  ',');
      if(handle == INVALID_HANDLE)
         return false;

      if(!exists)
        {
         FileWrite(handle,
                   "schema_version",
                   "sequence_no",
                   "timestamp",
                   "chart_id",
                   "symbol",
                   "scope_tag",
                   "config_hash",
                   "stage",
                   "action_id",
                   "correlation_id",
                   "pre_state_hash",
                   "post_state_hash",
                   "result_code",
                   "severity",
                   "broker_error",
                   "message",
                   "source");
        }
      else
         FileSeek(handle, 0, SEEK_END);

      FileWrite(handle,
                "phase5",
                IntegerToString((int)NextSequence()),
                IntegerToString((int)TimeCurrent()),
                IntegerToString((int)m_chart_id),
                symbol,
                m_scope_tag,
                MohyRuntimeBuildConfigHash(cfg),
                stage,
                MohyUiActionIdToString(action_id),
                correlation_id,
                pre_state_hash,
                post_state_hash,
                MohyUiResultCodeToString(result_code),
                MohyUiAlertEventTypeToString(severity),
                IntegerToString(broker_error),
                message,
                source);
      FileClose(handle);
      return true;
     }

   void     EmitAlert(const MohyUiAlertEventType severity,
                      const string alert_key,
                      const string message)
     {
      if(!m_enable_terminal_alerts || message == "")
         return;

      const datetime now = TimeCurrent();
      if(alert_key != "" &&
         alert_key == m_last_alert_key &&
         m_last_alert_time > 0 &&
         (now - m_last_alert_time) < 5)
         return;

      Alert(StringFormat("MOHY [%s] %s",
                         MohyUiAlertEventTypeToString(severity),
                         message));
      m_last_alert_key = alert_key;
      m_last_alert_time = now;
     }
  };

#endif

