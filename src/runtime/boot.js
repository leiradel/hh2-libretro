function(hh2) {
    // Augment the hh2 module
    hh2.print = function() {
        const args = Array.prototype.slice.call(arguments);
        args.splice(0, 0, "i");
        hh2.log.apply(this, args);
    }

    // Define rtl and pas globaly
    const rtlSource = hh2.load("rtl.js.gz");
    const rtlFunction = hh2.compile("function() {" + rtlSource + "return {rtl, pas};}", "rtl1.js");
    const rtlGlobals = rtlFunction();
    rtl = rtlGlobals.rtl;
    pas = rtlGlobals.pas;

    rtl.debug_load_units = true;
    rtl.debug_rtti = true;

    // Patch rtl.debug
    rtl.debug = function() {
        if (rtl.quiet) {
            return;
        }

        const args = Array.prototype.slice.call(arguments);
        args.splice(0, 0, "d");
        hh2.log.apply(this, args);
    };

    // Patch loaduseslist to load files from memory and the content file
    const loaded = {};

    const loaduseslist = rtl.loaduseslist;
    rtl.loaduseslist = function(module, useslist, f) {
        if (useslist == undefined) {
            return;
        }

        const len = useslist.length;

        for (var i = 0; i<len; i++) {
            var unitname = useslist[i];

            if (loaded[unitname] == undefined) {
                const name = unitname + ".js";
                hh2.print("Compiling ", name);

                const code = hh2.load(name);
                const source = "function() { " + code + " }";
                const func = hh2.compile(source, name);
                func();

                loaded[unitname] = true;
            }
        }

        loaduseslist(module, useslist, f);
    };

    // Run main.js whcih contains the actual program
    //const mainSource = hh2.load("main.js");
    const mainSource = '\
function() {\
rtl.module("program",["system","unit1"],function () {\
  "use strict";\
  var $mod = this;\
  var $lm = pas.unit1;\
  $mod.$main = function () {\
    $lm.form1.formcreate(null);\
  };\
});\
}';

    const mainFunction = hh2.compile(mainSource, "main.js");
    mainFunction();

    // Call rtl.run() to run the program
    rtl.run();
}
