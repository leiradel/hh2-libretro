function(hh2) {
    const bootSource = hh2.loadFile("boot.js.gz");
    const bootFunction = hh2.compile(bootSource, "boot.js");
    bootFunction(hh2);
}
