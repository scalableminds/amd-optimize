# rjs-optimizer [![Build Status](https://drone.io/github.com/scalableminds/rjs-optimizer/status.png)](https://drone.io/github.com/scalableminds/rjs-optimizer/latest)

> An AMD ([RequireJS](http://requirejs.org/)) optimizer that's stream-friendly. Made for [gulp](http://gulpjs.com/).

# Features

* Trace all dependencies of an AMD module
* Stream-friendly: Pipe in files and get an ordered stream of files out. No need for writing on disk in between.
* Support for precompilation of source files (ie. CoffeeScript)
* Wraps non-AMD dependencies
* Supply a custom loader for on-demand loading
* Leaves concatenation and minification to your preferred modules


# Motivation
This aims to be an alternative to the powerful [r.js](https://github.com/jrburke/r.js) optimizer, but made for a streaming environment like [gulp](http://gulpjs.com/). This implementation doesn't operate on the file system directly. So, there's no need for complicated setups when dealing with precompiled files. Also, this module only focuses on tracing modules and does not intend replace a full-fletched build system. Therefore, there are a lot of use cases where r.js is probably a better fit.

# Examples

```js
var gulp = require("gulp");
var rjs = require("rjs-optimizer");
 

// Main module. With CoffeeScript precompilation, concatenation and minifiying.
gulp.task("scripts:index", function () {
  
  return gulp.src("src/scripts/**/*.{js,coffee}")
    .pipe(gif(coffee(), function (file) { return path.extname(file.path) == ".coffee"; } ))
    // Traces all modules and outputs them in the correct order.
    .pipe(rjs("index"))
    .pipe(concat("index.js"))
    .pipe(uglify())
    .pipe(gulp.dest("dist/scripts"));

});


# Installation

```bash
$ npm install rjs-optimizer
```


## API

### rjs(moduleName, [options])

#### options.configFile
#### options.wrapFile
#### options.findNestedDependencies
#### options.baseUrl
#### options.exclude
#### options.wrapShim
#### options.loader

// Submodule with distinct dependencies
gulp.task("scripts:submodule", function () {
  
  return gulp.src("src/scripts/**/*.{js,coffee}")
    .pipe(gif(coffee(), function (file) { return path.extname(file.path) == ".coffee"; } ))
    .pipe(rjs("submodule", {
      configFile : gulp.src("src/scripts/require_config.coffee").pipe(coffee()),
      exclude : ["index"],
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
        function () { return gif(coffee(), { return path.extname(file.path) == ".coffee"; } ); }
      ),
      wrapShim : true
    })
    .pipe(concat("index.js"))
    .pipe(gulp.dest("dist/scripts"))
});


## Recommended modules
* [gulp-concat](https://www.npmjs.org/package/gulp-concat/): Concat the output files. Because that's the whole point of module optimization, right?
```js
var concat = require("gulp-concat");

gulp.src("src/scripts/**/*.js")
  .pipe(rjs("index"))
  .pipe(concat("index"))
  .pipe(gulp.dest("dist"));
```

* [gulp-uglify](https://www.npmjs.org/package/gulp-uglify/): Minify the output files.
```js
var uglify = require("gulp-uglify");

gulp.src("src/scripts/**/*.js")
  .pipe(rjs("index"))
  .pipe(concat("index"))
  .pipe(uglify())
  .pipe(gulp.dest("dist"));
```

* [gulp-coffee](https://www.npmjs.org/package/gulp-coffee/): Precompile CoffeeScript source files. Or any other [language that compiles to JS](https://github.com/jashkenas/coffee-script/wiki/List-of-languages-that-compile-to-JS).
```js
var coffee = require("gulp-coffee");

gulp.src("src/scripts/**/*.coffee")
  .pipe(coffee())
  .pipe(rjs("index"))
  .pipe(concat("index"))
  .pipe(gulp.dest("dist"));
```

* [gulp-if](https://www.npmjs.org/package/gulp-if/): Conditionally pipe files through a transform stream. Useful for CoffeeScript precompilation.
```js
var gif = require("gulp-if");

gulp.src("src/scripts/**/*.{coffee,js}")
  .pipe(gif(function (file) { return path.extname(file) == ".coffee"; }, coffee()))
  .pipe(rjs("index"))
  .pipe(concat("index"))
  .pipe(gulp.dest("dist"));
```


## Current limitations
* No sourcemaps.
* No RequireJS plugins.
* No `map` configuration.
* No hybrid AMD-CommonJS module definitions.

## Tests
1. Install npm dev dependencies `npm install`
2. Install gulp globally `npm install -g gulp`
3. Run `gulp test`

## License
MIT &copy; scalable minds 2014

