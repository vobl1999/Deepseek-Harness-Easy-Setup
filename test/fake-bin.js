// Stand-in for dsh/lib/bin.js. Prints the same startup line and then just stays alive, so
// the launcher and the stopper can be exercised without booting a real server.
console.log('dsh web: http://127.0.0.1:3080 (LAN: none)');
setInterval(function () {}, 1000);
