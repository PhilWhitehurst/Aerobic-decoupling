import Toybox.Activity;
import Toybox.Lang;
import Toybox.Application;

class AerobicDecouplingCalc {
  var warmupDuration = Properties.getValue("warmupDuration") * 60000; // Warm up period in minutes converted to milliseconds
  var aerobicBaselineDuration =
    Properties.getValue("aerobicBaselineDuration") * 60000; // Aerobic duration in minutes converted to milliseconds
  var aerobicBaselineDurationSeconds =
    Properties.getValue("aerobicBaselineDuration") * 60; // Aerobic duration in minutes converted to seconds

  var timeDuration = Properties.getValue("aerobicBaselineDuration") * 60000; // Smoothing factor for exponential moving average

  var heartRate30s = null;
  var heartRate30sMean = null;
  var meanHeartRate = null;

  var value30s = null;
  var meanValueTo4thPower = null;
  var meanValueTo4thPowerCount = 0;

  var baselineAerobicEfficiency = null;

  var aerobicDecoupling = 0.0;
  var maxAerobicDecoupling = 0f;
  

  var normalisedValue = null;

  var aerobicEfficiency = null;

  enum {
    POWER,
    SPEED,
    NO_CALC,
  }

  var _calc;

  function initialize() {
    var profile = Activity.getProfileInfo();

    switch (profile.sport) {
      case Activity.SPORT_CYCLING:
        _calc = POWER;
        break;
      case Activity.SPORT_RUNNING:
        _calc = SPEED;
        break;
      default:
        _calc = NO_CALC;
    }
  }

  function compute(info as Info) as Array<Float> or String or Null {
    var currentHeartRate = info.currentHeartRate;
    var currentValue = null;

    if (currentHeartRate == null) {
      // We don't have heart rate nothing to calculate
      return "NO HEART RATE!";
    }

    switch (_calc) {
      case POWER:
        currentValue = info.currentPower;
        break;
      case SPEED:
        currentValue = info.currentSpeed;
        break;
      case NO_CALC:
        return "ACTIVITY N/A";
    }

    if (currentValue == null) {
      // We don't have power data nothing to calculate
      return "NO DATA!";
    }

    System.println(info.elapsedTime + " " +  warmupDuration);

    if (info.elapsedTime <  warmupDuration) {
      // Still in the warm up period, don't process activity data

      return "WARM UP";
    }

    // Heart Rate

    if (info.currentHeartRate != null) {
      // Make sure heart rate available
      if (heartRate30s == null) {
        // initial average = first value
        heartRate30s = [info.currentHeartRate];
      } else {
        heartRate30s.add(info.currentHeartRate);
        if (heartRate30s.size() == 30) {
          var heartRate30sMean = Math.mean(heartRate30s); //Calculate 30 second average of heart rate data

          if (meanHeartRate == null) {
            // first value
            meanHeartRate = heartRate30sMean;
          } else {
            // Calculate new average, exponential smoothed equivalent to simple moving average

            meanHeartRate =
              (heartRate30sMean - meanHeartRate) / timeDuration + meanHeartRate;
          }
          heartRate30s = heartRate30s.slice(1, null); // Remove the oldest heart rate value so that we can maintain rolling 30s average (zero index array)
        }
      }

      // Power or Speed

      if (currentValue != null) {
        // Make sure power available
        if (value30s == null) {
          // New array
          value30s = [currentValue];
        } else {
          // Add latest power to existing array
          value30s.add(currentValue);

          if (value30s.size() == 30) {
            var value30sMean = Math.mean(value30s); //Calculate 30 average of last 30 seconds of power data
            var value30sMeanTo4thPower = Math.pow(value30sMean, 4); // Raise average to 4th power

            if (meanValueTo4thPower == null) {
              // first value
              meanValueTo4thPower = value30sMeanTo4thPower;
            } else {
              // Calculate new average, exponential smoothed equivalent to simple moving average

              meanValueTo4thPower =
                (value30sMeanTo4thPower - meanValueTo4thPower) / timeDuration +
                meanValueTo4thPower;
            }
            value30s = value30s.slice(1, null); // Remove the oldest power value so that we can maintain rolling 30s average
          }
        }

        if (info.elapsedTime < warmupDuration + aerobicBaselineDuration) {
         
          return "BASELINE";
        }

        if (info.elapsedTime >= warmupDuration + aerobicBaselineDuration) {
          // We can now calculate aerobic efficiency

          // Normalised Power / Speed

          if (meanValueTo4thPower != null) {
            // We have collected power data, calculate normalised

            normalisedValue = Math.pow(meanValueTo4thPower, 0.25); // The 4th root of the mean 30s power average (raised to 4th power);
          }

          // Aerobic Efficiency

          if (normalisedValue != null) {
            System.println(
              "normalisedValue " + normalisedValue + " HR " + meanHeartRate
            );

            aerobicEfficiency = normalisedValue / meanHeartRate;
          }

          if (baselineAerobicEfficiency == null) {
            baselineAerobicEfficiency = aerobicEfficiency;
          } else {
            var currentDecoupling =
              (baselineAerobicEfficiency - aerobicEfficiency) /
              baselineAerobicEfficiency;

            aerobicDecoupling =
              (currentDecoupling - baselineAerobicEfficiency) / timeDuration +
              aerobicDecoupling;
          }
        }
      }
    }

    if (normalisedValue != null) {
      System.println(
        "normalisedValue " +
          normalisedValue +
          " HR " +
          meanHeartRate +
          " Aerobic Decoupling " +
          aerobicDecoupling
      );
    }

    if (aerobicDecoupling > maxAerobicDecoupling) {
      maxAerobicDecoupling = aerobicDecoupling;
    }
   
    
       // Express as percentage to 1dp.
    return [aerobicDecoupling * 100, maxAerobicDecoupling * 100];
  }
}
