ruleset wovyn_base {
   meta {
      use module sensor_profile
      use module io.picolabs.subscription alias subs
      use module temperature_store
      shares message
   }

   global {
      message = function() {
         twilio:message()
      }
   }

   rule process_heartbeat {
      select when wovyn heartbeat where event:attrs{"genericThing"} 
      send_directive("heartbeat", {"body": "Beat beat"})

      fired {
         raise wovyn event "new_temperature_reading"
            attributes {
               "temperature": event:attrs{"genericThing"}{"data"}{"temperature"}[0]{"temperatureF"},
               "timestamp": event:time
            } 
      }
   }

   rule find_high_temps {
      select when wovyn new_temperature_reading
      always {
         raise wovyn event "threshold_violation"
            attributes event:attrs
            if event:attrs >< "temperature" && event:attrs{"temperature"} > sensor_profile:threshold()
      }
   }

   rule threshold_notification {
      select when wovyn threshold_violation
         foreach subs:established() setting(value,i)
      
      event:send({
         "eci": value{"Tx"},
         "domain":"sensor", "name":"threshold_violation",
         "attrs": {
            "sms_number": sensor_profile:sms_number()
         }
      })
   }

   rule listen_report{
      select when wovyn report
      pre {
         cid = event:attrs{"cid"}
         most_recent_temp = temperature_store:current_temp()
      }
      event:send({
         "eci": subs:established().filter(function(x){x{"Rx"} == meta:eci}).head(){"Tx"},
         "domain":"sensor", "name":"send_back_report",
         "attrs": {
            "cid": cid,
            "most_recent_temp": most_recent_temp,
         }
      })
   }
}