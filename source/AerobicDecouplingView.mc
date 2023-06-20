import Toybox.Activity;
import Toybox.Lang;
import Toybox.Math;
import Toybox.Time;
import Toybox.WatchUi;
import Toybox.Application;


class AerobicDecouplingView extends WatchUi.SimpleDataField {
    
    var warmupDuration = Properties.getValue("warmupDuration") * 60000; // Warm up period in minutes converted to milliseconds
    var aerobicBaselineDuration = Properties.getValue("aerobicBaselineDuration") * 60000; // Aerobic duration in minutes converted to milliseconds
    var aerobicBaselineDurationSeconds = Properties.getValue("aerobicBaselineDuration") * 60; // Aerobic duration in minutes converted to seconds

    var exponentialSmoothingFactor = 1.00 /  (Properties.getValue("aerobicBaselineDuration") * 60); // Smoothing factor for exponential moving average 

    var smoothingFactor = Properties.getValue("smoothingFactor"); // This one is applied to the aerobic decoupling to smooth the output.
    
    var heartRate30s = null;
    var heartRate30sMean = null;
    var meanHeartRate = null;
    
    


    var power30s = null;
    var meanPowerTo4thPower = null;
    var meanPowerTo4thPowerCount = 0;
 
   

    var baselineAerobicEfficiency = null;
    var aerobicDecoupling = 0.0;
    var field = null;

    var normalisedPower = null;
    
    var aerobicEfficiency = null;





    // Set the label of the data field here.
    function initialize() {
        SimpleDataField.initialize();
        label = "Decoupling";
         field = createField("aerobicDecoupling",0,FitContributor.DATA_TYPE_FLOAT, {:mesgType => FitContributor.MESG_TYPE_RECORD});
    }

    // The given info object contains all the current workout
    // information. Calculate a value and return it in this method.
    // Note that compute() and onUpdate() are asynchronous, and there is no
    // guarantee that compute() will be called before onUpdate().
    function compute(info as Activity.Info) as Numeric or Duration or String or Null {
        // See Activity.Info in the documentation for available information.

            
       
        if (info.currentHeartRate == null) { // We don't have heart rate nothing to calculate
                 return "no heart rate!";
               }

        if (info.currentPower == null) { // We don't have power data nothing to calculate
                return "no power data!";
               }

                
        if (info.elapsedTime < warmupDuration) { // Still in the warm up period, don't process activity data
            field.setData(0); 
            return "warm up";
        }

        // Heart Rate

        if (info.currentHeartRate != null) { // Make sure heart rate available
            if (heartRate30s == null) { // initial average = first value
              heartRate30s = [info.currentHeartRate]; 
          
        } else { 
           heartRate30s.add(info.currentHeartRate);
              if (heartRate30s.size() == 30) {

              
              var heartRate30sMean = Math.mean( heartRate30s ); //Calculate 30 second average of heart rate data 
                          
              
              if (meanHeartRate == null) { // first value
                meanHeartRate = heartRate30sMean;
                
              } else { // Calculate new average, exponential smoothed equivalent to simple moving average
                   
                
                 meanHeartRate = (1 - exponentialSmoothingFactor) * meanHeartRate + exponentialSmoothingFactor * heartRate30sMean ;
                
                 System.println(exponentialSmoothingFactor);
                 System.println( "mean heart rate  " + meanHeartRate + " " + heartRate30sMean);
               
            
           
                
              }
               heartRate30s = heartRate30s.slice(1,null); // Remove the oldest heart rate value so that we can maintain rolling 30s average (zero index array)
             
            } 
          
            
        }

       
        // Power 
             

        if (info.currentPower != null) { // Make sure power available
            if (power30s == null) { // New array
              power30s = [info.currentPower]; 
            } else { // Add latest power to existing array
              power30s.add(info.currentPower);
             
              if (power30s.size() == 30) {

              
              var power30sMean = Math.mean( power30s ); //Calculate 30 average of last 30 seconds of power data
              var power30sMeanTo4thPower = Math.pow ( power30sMean, 4 ); // Raise average to 4th power
              
              
              if (meanPowerTo4thPower == null) { // first value
                meanPowerTo4thPower = power30sMeanTo4thPower;
               

                
              } else { // Calculate new average, exponential smoothed equivalent to simple moving average
                   
             
                 meanPowerTo4thPower = (1 - exponentialSmoothingFactor) * meanPowerTo4thPower + exponentialSmoothingFactor * power30sMeanTo4thPower ;
                
                 System.println( "meanPower " + meanPowerTo4thPower);
              
                          
           
                
              }
               power30s = power30s.slice(1,null); // Remove the oldest power value so that we can maintain rolling 30s average (zero index array)
             
            } 

            
        } 

        if (info.elapsedTime < warmupDuration + aerobicBaselineDuration)
        {
          field.setData(0); 
          return "baseline";
        }
          
       

          

            if (info.elapsedTime >= warmupDuration + aerobicBaselineDuration) { // We can now calculate aerobic efficiency

                             
               
               

               // Normalised Power

               if (meanPowerTo4thPower != null) { // We have collected power data, calculate normalised
                 
                 normalisedPower = Math.pow(meanPowerTo4thPower, 0.25); // The 4th root of the mean 30s power average (raised to 4th power);

               } 

            
                            
               // Aerobic Efficiency

               if (normalisedPower != null ) {

                System.println( "normalisedPower " + normalisedPower + " HR " + meanHeartRate);

                if (aerobicEfficiency != null) {
                  aerobicEfficiency = doubleExponentialSmoothingFactor * normalisedPower / meanHeartRate + (1 - doubleExponentialSmoothingFactor) * aerobicEfficiency; // Smooth changes in aerobic efficiency

                } else {
                  aerobicEfficiency = normalisedPower / meanHeartRate;
                }
                
                
               }  

               if (baselineAerobicEfficiency == null) {
                    baselineAerobicEfficiency = aerobicEfficiency;
                     
                } else {
                    aerobicDecoupling =    (baselineAerobicEfficiency - aerobicEfficiency ) / baselineAerobicEfficiency * 100 ; // Express as percentage
                  
               }

                       

            

  
            }
        }
    }
     
      if (normalisedPower != null) {
        System.println( "normalisedPower " + normalisedPower + " HR " + meanHeartRate + " Aerobic Decoupling " + aerobicDecoupling);

      }

     field.setData(aerobicDecoupling); 
     
     return aerobicDecoupling.format("%+.1f") + "%";  
}

}