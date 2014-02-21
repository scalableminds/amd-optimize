_       = require("lodash")
fs      = require("fs")
path    = require("path")
vinylFs = require("vinyl-fs")
async   = require("async")

trace   = require("./src/trace")
concat  = require("./src/concat")


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


collectModules = (currentModule, omitInline = true, output = []) ->

  currentModule.deps.forEach( (depModule) ->
    collectModules(depModule, omitInline, output)
  )
  if not (omitInline and currentModule.isInline) and not _.any(output, name : currentModule.name)
    output.push(currentModule)
  return output


readConfig = (configFile, config = {}, callback) ->

  fs.readFile(config.mainConfigFile, "utf8", (err, configScriptData) ->

    config = _.merge(
      {}
      Function("""
        var output,
          require = {
            config : function (config) { output = config; }
          },
          define = function () {};
        #{configScriptData};
        return output;
        """)()
      config
    )
    callback(
      null
      config
    )
  )


optimize = (startModuleName, config, callback) ->

  async.waterfall([

    (callback) -> 
      readConfig(config.mainConfigFile, config, callback)

    (config, callback) -> 
      trace(startModuleName, config, null, callback)

    (module, callback) -> 
      # printTree(module)
      callback(null, collectModules(module))

    (modules, callback) -> 
      concat(modules, callback)

    (files, callback) -> 
      
      callback(null, files.map((file, i) ->
        file.cwd = process.cwd()
        file.base = process.cwd()
        file.path = path.resolve(process.cwd(), "#{startModuleName}.min.js#{if i == 1 then ".map" else ""}")
        return file
      ))

  ], callback)


optimize(
  "main"
  {
    cwd : "public"
    mainConfigFile : "public/javascripts/require_config.js"
    baseUrl : "public/javascripts"
    paths :
      "services/stack_service/workers/worker": "empty:"
      "admin/views/task/task_overview_view": "empty:"
      "routes": "empty:"
      cordova : "empty:"
    sourceMap : true
  }
  (err, files) ->
    if err
      console.error(err)
    # console.log(_.map(modules, "name"))
    # console.log("vinyl", vinylFile)
    else
      outputStream = vinylFs.dest(".")
      outputStream.write(files[0])
      outputStream.write(files[1])
      outputStream.end()
      outputStream.on("end", -> console.log("Finished"))
)