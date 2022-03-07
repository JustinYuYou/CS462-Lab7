ruleset wovyn_base {
   meta {
      use module sensor_profile
      use module io.picolabs.subscription alias subs
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


   // // Step 1.
   // rule send_eci {
   //    select when wrangler ruleset_installed
   //       where event:attr("rids") >< meta:rid
   //    pre {
   //       parent_eci = wrangler:parent_eci()
   //       wellKnown_eci = subs:wellKnown_Rx(){"id"}
   //    }
   //    event:send({"eci":parent_eci,
   //    "domain": "sensor", 
   //    "type": "identify",
   //    "attrs": {
   //      "wellKnown_eci": wellKnown_eci
   //    }})
   // }
}