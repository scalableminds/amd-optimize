_            = require("lodash")
fs           = require("fs")
path         = require("path")
vinylFs      = require("vinyl-fs")
async        = require("async")
through      = require("through2")

Readable     = require("stream").Readable

trace        = require("./trace")
exportModule = require("./export")


firstChunk = (stream, callback) ->

  settled = false
  stream
    .on("data", (data) ->
      if not settled
        settled = true
        callback(null, data)
      return
    ).on("end", ->
      if not settled
        callback()
      return
    ).on("error", (err) ->
      if not settled
        settled = true
        callback(err)
      return
    )
  return


collectModules = (module, omitInline = true) ->
# Depth-first search over the module dependency tree

  outputBuffer = []

  collector = (currentModule) ->

    currentModule.deps.forEach( (depModule) ->
      collector(depModule)
    )
    if not (omitInline and currentModule.isInline) and not _.any(outputBuffer, name : currentModule.name)
      outputBuffer.push(currentModule)
      outputStream.push(currentModule)

  outputStream = new Readable( objectMode : true )
  outputStream._read = ->
    collector(module)
    outputStream.push(null)
    return

  return outputStream


readConfigStream = (config = {}) ->

  return through.obj(
    (file, enc, done) ->

      config = _.merge(
        {}
        Function("""
          var output,
            require = {
              config : function (config) { output = config; }
            },
            define = function () {};
          #{file.contents.toString("utf8")};
          return output;
          """)()
        config
      )
      done()

    (done) ->

      @push(config)
      done()
  )


defaultLoader = (fileBuffer, options) ->

  return (name, callback) ->

    if file = _.detect(fileBuffer, relative : path.join(options.baseUrl, name + ".js"))
      callback(null, file)
    else if options.loader
      options.loader(name, callback)
    else
      module.exports.loader()(path.join(options.baseUrl, name + ".js"), callback)



module.exports = rjs = (moduleName, options = {}) ->

  options = _.defaults(
    options, {
      baseUrl : ""
      configFile : null
      # exclude : []
      # include : []
      findNestedDependencies : false
      # wrapShim : true
      loader : null
    }
  )

  if _.isString(options.configFile) or _.isArray(options.configFile)
    options.configFile = vinylFs.src(options.configFile)

  configStream = readConfigStream(options)
  if options.configFile
    configStream = options.configFile.pipe(configStream)
  else
    configStream.end()

  fileBuffer = []

  mainStream = through.obj(
    # transform
    (file, enc, done) ->
      fileBuffer.push(file)
      done()

    # flush
    (done) ->

      outputStream = this

      async.waterfall([

        (callback) ->

          configStream
            .on("data", (config) -> callback(null, config))
            .on("error", callback)


        (config, callback) ->

          trace(moduleName, config, null, defaultLoader(fileBuffer, options), callback)

        (module, callback) ->
          # printTree(module)

          exportStream = exportModule(options)
          exportStream.on("data", (file) ->
            outputStream.push(file)
          )
          collectModules(module)
            .pipe(exportStream)
            .on("end", -> callback())
            .on("error", callback)

      ], done)

  )

  return mainStream


module.exports.src = (moduleName, options) ->

  source = rjs(moduleName, options)
  process.nextTick -> source.end()
  return source


module.exports.loader = (filenameResolver, pipe) ->

  (moduleName, callback) ->

    # console.log(filenameResolver(moduleName))
    if filenameResolver
      filename = filenameResolver(moduleName)
    else
      filename = moduleName

    source = vinylFs.src(filename).pipe(through.obj())

    if pipe
      source = source.pipe(pipe())

    firstChunk(source, callback)
    return
