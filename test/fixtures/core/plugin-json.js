(function () {
  define(["bar", "json!./test.json"], function (bar, test) {
    console.log(bar, test);
  });
})();