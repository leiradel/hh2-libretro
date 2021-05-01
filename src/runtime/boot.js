function(hh2) {
    // Define rtl globaly
    const rtlSource = hh2.load("rtl.js");
    const rtlFunction = hh2.compile("function() {" + rtlSource + "return rtl;}", "rtl1.js");
    rtl = rtlFunction();

    rtl.debug_load_units = true;
    rtl.debug_rtti = true;

    // Patch rtl.debug
    rtl.debug = function() {
        str = "";

        for (var i = 0; i < arguments.length; i++) {
            str = str + arguments[i];
        }

        hh2.print(str);
    };

    // Units will call run and error because they're not "program", so make it a dummy
    var run = rtl.run;
    rtl.run = function() {};

    // Patch loaduseslist to load files from memory and the content file
    var loaded = {};

    var loaduseslist = rtl.loaduseslist;
    rtl.loaduseslist = function(module, useslist, f) {
        if (useslist == undefined) {
            return;
        }

        var len = useslist.length;

        for (var i = 0; i<len; i++) {
            var unitname = useslist[i];

            if (loaded[unitname] == undefined) {
                hh2.eval(hh2.load(unitname + ".js"));
                loaded[unitname] = true;
            }
        }

        loaduseslist(module, useslist, f);
    };

    // Run main.js whcih contains the actual program
    //const mainSource = hh2.load("main.js");
    const mainSource = '\
rtl.module("program",["system","unit1"],function () {\
  "use strict";\
  var $mod = this;\
  var $lm = pas.unit1;\
  $mod.$main = function () {\
    $lm.form1.formcreate(null);\
  };\
});';

    hh2.eval(mainSource);

    // Call the original rtl.run() to run the program
    run();

    return true;
}
