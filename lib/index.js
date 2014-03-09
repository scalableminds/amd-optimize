(function() {
  var Readable, async, collectModules, defaultLoader, exportModule, firstChunk, fs, path, readConfigStream, rjs, through, trace, vinylFs, _;

  _ = require("lodash");

  fs = require("fs");

  path = require("path");

  vinylFs = require("vinyl-fs");

  async = require("async");

  through = require("through2");

  Readable = require("stream").Readable;

  trace = require("./trace");

  exportModule = require("./export");

  firstChunk = function(stream, callback) {
    var settled;
    settled = false;
    stream.on("data", function(data) {
      if (!settled) {
        settled = true;
        callback(null, data);
      }
    }).on("end", function() {
      if (!settled) {
        callback();
      }
    }).on("error", function(err) {
      if (!settled) {
        settled = true;
        callback(err);
      }
    });
  };

  collectModules = function(module, omitInline) {
    var collector, outputBuffer, outputStream;
    if (omitInline == null) {
      omitInline = true;
    }
    outputBuffer = [];
    collector = function(currentModule) {
      currentModule.deps.forEach(function(depModule) {
        return collector(depModule);
      });
      if (!(omitInline && currentModule.isInline) && !_.any(outputBuffer, {
        name: currentModule.name
      })) {
        outputBuffer.push(currentModule);
        return outputStream.push(currentModule);
      }
    };
    outputStream = new Readable({
      objectMode: true
    });
    outputStream._read = function() {
      collector(module);
      outputStream.push(null);
    };
    return outputStream;
  };

  readConfigStream = function(config) {
    if (config == null) {
      config = {};
    }
    return through.obj(function(file, enc, done) {
      config = _.merge({}, Function("var output,\n  require = {\n    config : function (config) { output = config; }\n  },\n  define = function () {};\n" + (file.contents.toString("utf8")) + ";\nreturn output;")(), config);
      return done();
    }, function(done) {
      this.push(config);
      return done();
    });
  };

  defaultLoader = function(fileBuffer, options) {
    return function(name, callback) {
      var file;
      if (file = _.detect(fileBuffer, {
        relative: path.join(options.baseUrl, name + ".js")
      })) {
        return callback(null, file);
      } else if (options.loader) {
        return options.loader(name, callback);
      } else {
        return module.exports.loader()(path.join(options.baseUrl, name + ".js"), callback);
      }
    };
  };

  module.exports = rjs = function(moduleName, options) {
    var configStream, fileBuffer;
    if (options == null) {
      options = {};
    }
    options = _.defaults(options, {
      baseUrl: "",
      configFile: null,
      findNestedDependencies: false,
      loader: null
    });
    if (_.isString(options.configFile) || _.isArray(options.configFile)) {
      options.configFile = vinylFs.src(options.configFile);
    }
    configStream = readConfigStream(options);
    if (options.configFile) {
      configStream = options.configFile.pipe(configStream);
    } else {
      configStream.end();
    }
    fileBuffer = [];
    return through.obj(function(file, enc, done) {
      fileBuffer.push(file);
      return done();
    }, function(done) {
      var outputStream;
      outputStream = this;
      return async.waterfall([
        function(callback) {
          return configStream.on("data", function(config) {
            return callback(null, config);
          });
        }, function(config, callback) {
          return trace(moduleName, config, null, defaultLoader(fileBuffer, options), callback);
        }, function(module) {
          var exportStream;
          exportStream = exportModule(options);
          exportStream.on("data", function(file) {
            return outputStream.push(file);
          });
          return collectModules(module).pipe(exportStream).on("end", function() {
            return done();
          });
        }
      ], function(err) {
        return console.log(err);
      });
    });
  };

  module.exports.src = function(moduleName, options) {
    var source;
    source = rjs(moduleName, options);
    process.nextTick(function() {
      return source.end();
    });
    return source;
  };

  module.exports.loader = function(filenameResolver, pipe) {
    return function(moduleName, callback) {
      var filename, source;
      if (filenameResolver) {
        filename = filenameResolver(moduleName);
      } else {
        filename = moduleName;
      }
      source = vinylFs.src(filename).pipe(through.obj());
      if (pipe) {
        source = source.pipe(pipe());
      }
      firstChunk(source, callback);
    };
  };

}).call(this);
