ruleset manage_sensors {
   meta {
      shares sensors, all_sensors_temperatures
      use module io.picolabs.wrangler alias wrangler
      use module twilio
      with
         sid = meta:rulesetConfig{"sid"}
         authToken = meta:rulesetConfig{"authToken"}
         fromNumber = "+18305803542"
      use module io.picolabs.subscription alias subs
   }

   global {
      sensors = function() {
         ent:sensors
      }

      all_sensors_temperatures = function() {
         subs:established().map(function(v, k){
            tx = v{"Tx"}
            wrangler:picoQuery(tx,"temperature_store","temperatures");
         })
      }
   }

   rule intialization {
      select when wrangler ruleset_installed where event:attrs{"rids"} >< meta:rid
      fired {
         ent:sensors := {}
         ent:wellKnown_ecis := []
      }
   }

   // 1. 
   rule create_sensor {
      select when sensor new_sensor
      pre {
         sensor_name = event:attr("sensor_name")
         threshold = event:attr("threshold")
         sms_number = event:attr("sms_number")
      }

      if ent:sensors >< sensor_name  then
         noop()
      notfired {
         raise wrangler event "new_child_request"
            attributes { "name": sensor_name, "threshold": threshold, "sms_number": sms_number, "backgroundColor": "#ff69b4" }
      }
   }

   // 2.
   rule create_child {
      select when wrangler new_child_created
         foreach ["temperature_store", "twilio","sensor_profile","wovyn_emitter", "wovyn_base"] setting(rs,i)
      
      pre {
         sensor_name = event:attr("name")
         eci = event:attr("eci")
         threshold = event:attr("threshold")
         sms_number = event:attr("sms_number")
      }

      if not (ent:sensors >< sensor_name) then
         event:send(
            { 
              "eci": eci, 
              "eid": "install-ruleset",
              "domain": "wrangler", 
              "type": "install_ruleset_request",
              "attrs": {
                "absoluteURL": meta:rulesetURI,
                "config": {

                },
                "rid": rs,
              }
            }
         )
      
      fired {
         ent:sensors{sensor_name} := { 
            "eci": eci
         } on final
      }
   }

   // 2.
   rule update_profile {
      select when wrangler new_child_created
      
      pre {
         eci = event:attr("eci")
         sensor_name = event:attr("name")
         threshold = event:attr("threshold")
         sms_number = event:attr("sms_number")
      }

      every {
         event:send(
            { 
               "eci": eci, 
               "eid": "update-profile",
               "domain": "sensor", 
               "type": "profile_updated",
               "attrs": {
                 "sensor_name": sensor_name,
                 "threshold": threshold,
                 "sms_number": sms_number
               }
            }
         )

         // Tell the other(child) to initiate subscription to me
         event:send({
            "eci": eci, // the other
            "domain":"wrangler", "name":"subscription",
            "attrs": { //THIS WILL BE PASSED THROUGHOUT WHOLE SUBSCRIPTION PROCESS
              "wellKnown_Tx":subs:wellKnown_Rx(){"id"}, // me
              "Rx_role":"sensor", 
              "Tx_role":"sensor_management",
              "name": "sensor-management-subscription", 
              "channel_type":"subscription",
              "sensor_name": sensor_name
            }
         })
      }
   }

   //3. We need to approve the subscription
   rule auto_accept {
      select when wrangler inbound_pending_subscription_added
      pre {
        my_role = event:attr("Rx_role")
        their_role = event:attr("Tx_role")
      }
      if my_role=="sensor_management" && their_role=="sensor" then noop()
      
      fired {
        raise wrangler event "pending_subscription_approval"
          attributes event:attrs
      } else {
        raise wrangler event "inbound_rejection"
          attributes event:attrs
      }
   }
   
   //4. after the subscription is established, we store the wellknow_eci to keep track of it 
   rule store_sensor_subcription_info {
      select when wrangler subscription_added
      pre {
         sensor_name = event:attr("sensor_name")
      }

      always {
         ent:sensors{[sensor_name,"subscriptionId"]} := event:attr("Id")
      }   
   }

   rule threshold_notification {
      select when sensor threshold_violation
      pre {
         sms_number = event:attr("sms_number")
      }
      twilio:sendMessage(sms_number)
   }

   rule introduce_external_sensor {
      select when sensor connect_external_sensor 
      pre {
         otherSystemPicoEci = event:attr("otherSystemWellKnown")
         otherSystemHostName = event:attr("otherSystemHostName")
         otherSystemPicoName = event:attr("otherSystemPicoName")
      }

         // Tell the other to initiate subscription to me
         event:send({
            "eci": otherSystemPicoEci, // the other
            "domain":"wrangler", "name":"subscription",
            "attrs": {
              "wellKnown_Tx": subs:wellKnown_Rx(){"id"}, // me
              "Rx_role":"sensor-in-external-system", 
              "Tx_role":"sensor-management",
              "name": "sensor-management-subscription", 
              "Tx_host": otherSystemHostName,
              "channel_type":"subscription",
              "sensor_name": otherSystemPicoName
            }
         } , host=otherSystemHostName)
   }

   // Step 2.
   // rule get_notified_child_rulset_installed {
   //    select when sensor identify
   //       wellKnown_eci re#(.+)#
   //       setting(wellKnown_eci)
      
   //    always {
   //       raise sensor event "new_subscription_request"
   //          attributes { "other_wellKnown_eci": wellKnown_eci }
   //    }
   // }

   // // Step 3.
   // rule make_a_subscription {
   //    select when sensor new_subscription_request  
      
   //    pre {
   //       other_wellKnown_eci = event:attr("other_wellKnown_eci")
   //    } 


   // }

   rule delete_sensor {
      select when sensor unneeded_sensor
      pre{
         deleted_sensor_name = event:attr("sensor_name")
         exists = ent:sensors >< deleted_sensor_name 
         eci_to_delete = ent:sensors{[deleted_sensor_name,"eci"]}
      }
      if exists then
        send_directive("deleting_sensor", {"sensor_name":deleted_sensor_name})
      
      fired {
        raise wrangler event "child_deletion_request"
          attributes {"eci": eci_to_delete};
        clear ent:sensors{deleted_sensor_name}
      }
   }
}