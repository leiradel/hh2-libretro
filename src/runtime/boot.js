function(hh2) {
    // Augment the hh2 module
    hh2.print = function() {
        const args = Array.prototype.slice.call(arguments);
        args.splice(0, 0, "i");
        hh2.log.apply(this, args);
    }

    // Define rtl and pas globaly
    const rtlSource = hh2.load("rtl.js.gz");
    const rtlFunction = hh2.compile("function() { " + rtlSource + " return {rtl, pas}; }", "rtl.js");
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
                hh2.print("Compiling ", unitname);
                var source;

                try {
                    // Try a compressed JavaScript file first
                    source = hh2.load(unitname + ".js.gz");
                }
                catch (e) {
                    // Then try an uncompressed JavaScript file
                    source = hh2.load(unitname + ".js");
                }

                loaded[unitname] = true;
                const func = hh2.compile("function() { " + source + " }", unitname + ".js");
                func();
            }
        }

        loaduseslist(module, useslist, f);
    };

    // Run main.js whcih contains the actual program
    hh2.print("Compiling hh2main");
    const mainSource = hh2.load("hh2main.js");
    const mainFunction = hh2.compile("function() { " + mainSource + " }", "hh2main.js");
    mainFunction();

    // Call rtl.run() to run the program
    rtl.run();
}
