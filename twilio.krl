ruleset twilio {
   meta {
     configure using
       sid = ""
       authToken = ""
       fromNumber = ""
     provides sendMessage, message
   }

   global {
      baseUrl = "https://api.twilio.com/2010-04-01"
      pageSize = 5
      sendMessage = defaction(toNumber) {
         http:post(<<#{baseUrl}/Accounts/#{sid}/Messages.json>>, form={"To": toNumber, "From": fromNumber, "Body":"this is a test message"}, auth={"username": sid, "password": authToken}) 
         setting (output)
         return output.klog()
      }

      message = function() {
        http:get(<<#{baseUrl}/Accounts/#{sid}/Messages.json?&PageSize=#{pageSize}>>, auth={"username": sid, "password": authToken}).klog() 
      }
   }
 }