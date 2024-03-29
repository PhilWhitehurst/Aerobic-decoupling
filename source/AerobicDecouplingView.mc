import Toybox.Activity;
import Toybox.Lang;
import Toybox.Math;
import Toybox.Time;
import Toybox.FitContributor;
import Toybox.WatchUi;
import Toybox.Application;

class AerobicDecouplingView extends WatchUi.SimpleDataField {
  private var _ad as AerobicDecouplingCalc;
  private var _activeActivity as Boolean;

  var aerobicDecoupling as Field;
  var maxAerobicDecoupling as Field;

  // Set the label of the data field here.
  function initialize() {
    SimpleDataField.initialize();
    label = "DECOUPLING";
    aerobicDecoupling = createField(
      "aerobicDecoupling",
      0,
      FitContributor.DATA_TYPE_FLOAT,
      { :mesgType => FitContributor.MESG_TYPE_RECORD }
    );
     maxAerobicDecoupling = createField(
      "maxAerobicDecoupling",
      1,
      FitContributor.DATA_TYPE_FLOAT,
      { :mesgType => FitContributor.MESG_TYPE_SESSION }
    );

    _ad = new AerobicDecouplingCalc();

    _activeActivity = false;
  }

  // The given info object contains all the current workout
  // information. Calculate a value and return it in this method.
  // Note that compute() and onUpdate() are asynchronous, and there is no
  // guarantee that compute() will be called before onUpdate().
  function compute(
    info as Activity.Info
  ) as Numeric or Duration or String or Null {
    // See Activity.Info in the documentation for available information.

    if (info.timerState == Activity.TIMER_STATE_OFF) {
      // Activity not active
      _activeActivity = false;
    } else {
      // An activity is in progress
      if (_activeActivity == false) {
        // initialise the Aerobic Decoupling class
        _ad.initialize();

        _activeActivity = true;
      }
    }
    var output = _ad.compute(info as Info);

    if (output instanceof Array ) {
      aerobicDecoupling.setData(output[0]);
      maxAerobicDecoupling.setData(output[1]);
      return output[0].format("%+.1f") + "%";
    
    } else {
      aerobicDecoupling.setData(0);
      maxAerobicDecoupling.setData(0);
    }

   
    return output;



    
  }
}
