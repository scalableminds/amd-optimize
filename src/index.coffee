_            = require("lodash")
fs           = require("fs")
path         = require("path")
vinylFs      = require("vinyl-fs")
async        = require("async")
through      = require("through2")

Readable     = require("stream").Readable

trace        = require("./trace")
exportModule = require("./export")


logger = ->
  return through.obj((file, enc, callback) ->
    console.log(">>", path.relative(process.cwd(), file.path))
    callback(null, file)
  )


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



printTree = (currentModule, prefix = "") ->

  console.log(prefix, currentModule.name, "(#{path.relative(process.cwd(), currentModule.fileName)})")

  depPrefix = prefix
    .replace("├", "|")
    .replace("└", " ")
    .replace(/─/g, " ")
  currentModule.deps.forEach((depModule, i) ->

    if i + 1 < currentModule.deps.length
      printTree(depModule, "#{depPrefix} ├──")
    else
      printTree(depModule, "#{depPrefix} └──")
  )


collectModules = (module, omitInline = true) ->

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


readConfig = (configFileStream, config = {}, callback) ->

  configFileStream
    .on("data", (file) ->

      # console.log(file)

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

    ).on("end", ->
      callback(null, config)
    ).on("error", (err) ->
      callback(err)
    )

  configFileStream.resume()
  return


module.exports = rjs = (moduleName, options = {}) ->

  fileBuffer = []

  options = _.defaults(
    options, {
      baseUrl : ""
      configFile : null
      # exclude : []
      findNestedDependencies : false
      # wrapShim : true
      loader : (name, callback) -> 
        callback(null, _.detect(fileBuffer, relative : path.join(options.baseUrl, name + ".js")))
        return
    }
  )

  if _.isString(options.configFile) or _.isArray(options.configFile)
    options.configFile = vinylFs.src(options.configFile)


  configStream = through.obj()
  configStream.pause()
  if options.configFile
    options.configFile.pipe(configStream)

  return through.obj(
    # transform
    (file, enc, done) ->
      fileBuffer.push(file)
      done()

    # flush
    (done) ->

      outputStream = this

      async.waterfall([

        (callback) -> 
          if options.configFile
            readConfig(configStream, options, callback)
          else
            callback(null, options)

        (config, callback) ->

          trace(moduleName, config, null, options.loader, callback)

        (module) -> 
          # printTree(module)

          exportStream = exportModule(options)
          exportStream.on("data", (file) ->
            outputStream.push(file)
          )
          collectModules(module)
            .pipe(exportStream)
            .on("end", -> done())

      ], (err) -> console.log(err))

  )


module.exports.loader = (filenameResolver, pipe) ->

  (moduleName, callback) ->

    # console.log(filenameResolver(moduleName))
    source = vinylFs.src(filenameResolver(moduleName)).pipe(through.obj())

    if pipe
      source = source.pipe(pipe())

    settled = false
    firstChunk(source, callback)
    return


module.exports.printModuleTree = printTree
