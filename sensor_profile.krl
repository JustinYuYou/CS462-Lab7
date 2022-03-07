ruleset sensor_profile {
   meta {
      shares sensor_location, sensor_name, threshold, sms_number
      provides sensor_location, sensor_name, threshold, sms_number
   }
   
   global {
      sensor_location = function() {
         ent:sensor_location
      }

      sensor_name = function() {
         ent:sensor_name
      }

      threshold = function() {
         ent:threshold
      }

      sms_number = function() {
         ent:sms_number
      }
   }

   rule intialization {
      select when wrangler ruleset_installed where event:attrs{"rids"} >< meta:rid
      fired {
         ent:sensor_name := ""
         ent:sensor_location := ""
         ent:threshold := 0
         ent:sms_number := ""    
      }
    }

   
   rule update_profile {
      select when sensor profile_updated
      always {
         ent:sensor_name := event:attrs{"sensor_name"}
         ent:sensor_location := event:attrs{"sensor_location"}
         ent:threshold := event:attrs{"threshold"}
         ent:sms_number := event:attrs{"sms_number"}
      }
   }
}