# rjs-optimizer

Alternative to [r.js]() build tool (WIP)

# Features
tbd

# Installation

```bash
$ npm install rjs-optimizer
```

# Examples

```js
var gulp = require("gulp");
var rjs = require("rjs-optimizer");
 

// Main module
gulp.task("scripts:index", function () {
  
  return gulp.src("src/scripts/**/*.{js,coffee}")
    .pipe(gif(coffee(), function (file) { return path.extname(file.path) == ".coffee"; } ))
    // Traces all modules and outputs them in the correct order. Also wraps shimmed modules.
    .pipe(rjs("index", {
      baseUrl : "src/scripts"
      configFile : gulp.src("src/scripts/require_config.coffee").pipe(coffee()),
      wrapShim : true,
    }))
    .pipe(concat("index.js"))
    .pipe(uglify())
    .pipe(gulp.dest("dist/scripts"));

});

// Submodule with distinct dependencies
gulp.task("scripts:submodule", function () {
  
  return gulp.src("src/scripts/**/*.{js,coffee}")
    .pipe(gif(coffee(), function (file) { return path.extname(file.path) == ".coffee"; } ))
    .pipe(rjs("submodule", {
      configFile : gulp.src("src/scripts/require_config.coffee").pipe(coffee()),
      exclude : "index",
      findNestedDependencies : true
    }))
    .pipe(concat("submodule.js"))
    .pipe(uglify())
    .pipe(gulp.dest("dist/scripts"));

});

// Sideload dependencies. Useful when working with bower components
gulp.task("scripts:common", function () {
  
  return rjs("index", {
      configFile : gulp.src("src/scripts/require_config.coffee").pipe(coffee())
      loader : rjs.loader(
        function (moduleName) { return path.join("src/{scripts,bower_components}", moduleName + ".{js,coffee}"); },
        gif(coffee(), { return path.extname(file.path) == ".coffee"; } )
      ),
      wrapShim : true
    })
    .pipe(concat("index.js"))
    .pipe(gulp.dest("dist/scripts"))
});


## Recommended modules
* gulp-if
* event-stream: pipeline, merge
* gulp-concat
* gulp-uglify
* gulp-coffee etc.

## Known issues
* No sourcemaps.
* No RequireJS plugins.
* No `map` configuration

## Tests
1. Install npm dev dependencies `npm install`
2. Install gulp globally `npm install -g gulp`
3. Run `gulp test`

## License
MIT &copy; scalable minds 2014

