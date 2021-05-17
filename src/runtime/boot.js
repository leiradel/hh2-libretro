function(hh2) {
    // Augment the hh2 module
    hh2.print = function() {
        const args = Array.prototype.slice.call(arguments);
        args.splice(0, 0, "i");
        hh2.log.apply(this, args);
    }

    // Define rtl and pas globaly
    const rtlSource = hh2.loadFile("rtl.js.gz");
    const rtlFunction = hh2.compile("function() { " + rtlSource + " return {rtl, pas}; }", "rtl.js");
    const rtlGlobals = rtlFunction();
    rtl = rtlGlobals.rtl;
    pas = rtlGlobals.pas;

    rtl.debug_load_units = false;
    rtl.debug_rtti = false;
    rtl.quiet = false;

    // Patch rtl.debug
    rtl.debug = function() {
        if (rtl.quiet) {
            return;
        }

        const args = Array.prototype.slice.call(arguments);
        args.splice(0, 0, "i");
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

        for (var i = 0; i < len; i++) {
            const unitname = useslist[i];

            if (loaded[unitname] == undefined) {
                hh2.print("Compiling ", unitname);
                var source;

                if (hh2.fileExists(unitname + ".js.gz")) {
                    // Try a compressed JavaScript file first
                    source = hh2.loadFile(unitname + ".js.gz");
                }
                else {
                    // Then try an uncompressed JavaScript file
                    source = hh2.loadFile(unitname + ".js");
                }

                loaded[unitname] = true;
                const func = hh2.compile("function(hh2) { " + source + " }", unitname + ".js");
                func(hh2);
            }
        }

        loaduseslist(module, useslist, f);
    };

    // Run hh2boot.js whcih contains the actual program
    hh2.print("Compiling hh2boot");
    const mainSource = hh2.loadFile("hh2boot.js");
    const mainFunction = hh2.compile("function(hh2) { " + mainSource + " }", "hh2boot.js");
    mainFunction(hh2);

    // Call rtl.run() to run the program
    rtl.run();
}
