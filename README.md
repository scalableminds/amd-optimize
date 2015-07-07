# amd-optimize [![Build Status](https://drone.io/github.com/scalableminds/amd-optimize/status.png)](https://drone.io/github.com/scalableminds/amd-optimize/latest)

> An AMD ([RequireJS](http://requirejs.org/)) optimizer that's stream-friendly. Made for [gulp](http://gulpjs.com/). (WIP)

# Features

* Trace all dependencies of an AMD module
* Stream-friendly: Pipe in files and get an ordered stream of files out. No need for writing on disk in between.
* Support for precompilation of source files (ie. CoffeeScript)
* Wraps non-AMD dependencies
* Supply a custom loader for on-demand loading
* Leaves concatenation and minification to your preferred choice of modules
* [gulp-sourcemaps](https://www.npmjs.org/package/gulp-sourcemaps) support

# Example

```js
var gulp = require("gulp");
var amdOptimize = require("amd-optimize");
var concat = require('gulp-concat');

gulp.task("scripts:index", function () {

  return gulp.src("src/scripts/**/*.js")
    // Traces all modules and outputs them in the correct order.
    .pipe(amdOptimize("main"))
    .pipe(concat("index.js"))
    .pipe(gulp.dest("dist/scripts"));

});
```

# Motivation
This aims to be an alternative to the powerful [r.js](https://github.com/jrburke/r.js) optimizer, but made for a streaming environment like [gulp](http://gulpjs.com/). This implementation doesn't operate on the file system directly. So, there's no need for complicated setups when dealing with precompiled files. Also, this module only focuses on tracing modules and does not intend replace a full-fletched build system. Therefore, there might be tons of use cases where r.js is a better fit.


# Installation

```bash
$ npm install amd-optimize
```


## API

### amdOptimize(moduleName, [options])

#### moduleName
Type: `String`

#### options.paths

```js
paths : {
  "backbone" : "../bower_components/backbone/backbone",
  "jquery" : "../bower_components/jquery/jquery"
}
```

#### options.map

```js
map : {
  // Replace underscore with lodash for the backbone module
  "backbone" : {
    "underscore" : "lodash"
  }
}
```

#### options.shim

```js
shim : {
  // Shimmed export. Specify the variable name that is being exported.
  "three" : {
     exports : "THREE"
  },

  // Shimmed dependecies and export
  "three.color" : {
     deps : ["three"],
     exports : "THREE.ColorConverter"
  },

  // Shimmed dependencies
  "bootstrap" : ["jquery"]
}
```

#### options.configFile
Type: `Stream` or `String`

Supply a filepath (can be a glob) or a gulp stream to your config file that lists all your paths, shims and maps.

```js
amdOptimize.src("index", {
  configFile : "src/scripts/require_config.js"
});

amdOptimize.src("index", {
  configFile : gulp.src("src/scripts/require_config.coffee").pipe(coffee())
});
```

#### options.findNestedDependencies
Type: `Boolean`  
Default: `false`


If `true` it will trace `require()` dependencies inside of top-level `require()` or `define()` calls. Usually, these nested dependencies are considered dynamic or runtime calls, so it's disabled by default.

Would trace both `router` and `controllers/home`:

```js
define("router", [], function () {
  return {
    "/home" : function () {
      require(["controllers/home"]);
    },
    ...
  }
})
```

#### options.baseUrl
#### options.exclude
#### options.include

#### options.wrapShim

Type: `Boolean`  
Default: `false`

If `true` all files that you have declared a shim for and don't have a proper `define()` call will be wrapped in a `define()` call.



```js
// Original
var test = "Test";

// Output
define("test", [], function () {
  var test = "Test";
  return test;
});

// Shim config
shim : {
  test : {
    exports : "test"
  }
}
```

#### options.preserveFiles

Type: `Boolean`  
Default: `false`

If `true` all files that you combine will not be altered from the source, should be used for outputted files to match the original source file, good for debugging and inline sourcemaps. A good code minifier or uglify will remove comments and strip new lines anyway.


#### options.loader
WIP. Subject to change.

```js
amdOptimize.src(
  "index",
  loader : amdOptimize.loader(
    // Used for turning a moduleName into a filepath glob.
    function (moduleName) { return "src/scripts/" + moduleName + ".coffee" },
    // Returns a transform stream.
    function () { return coffee(); }
  )
)
```

### amdOptimize.src(moduleName, options)
Same as `amdOptimize()`, but won't accept an input stream. Instead it will rely on loading the files by itself.


## Algorithms
### Resolving paths

### Finding files
1. Check the input stream.
2. Look for files with the default loader and `baseUrl`.
3. Look for files with the custom loader and its transform streams.
4. Give up.


## Recommended modules
* [gulp-concat](https://www.npmjs.org/package/gulp-concat/): Concat the output files. Because that's the whole point of module optimization, right?

```js
var concat = require("gulp-concat");

gulp.src("src/scripts/**/*.js")
  .pipe(amdOptimize("index"))
  .pipe(concat
