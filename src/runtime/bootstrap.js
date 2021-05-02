function(hh2) {
    const bootSource = hh2.load("boot.js");
    const bootFunction = hh2.compile(bootSource, "boot.js");
    bootFunction(hh2);
}
