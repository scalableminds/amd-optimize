fs = require("fs")
path = require("path")
vinylFs = require("vinyl-fs")
async = require("async")
_ = require("lodash")

defineRegex = /(define|require)\((?:\s*"([^"]*)"\s*,)?\s*\[([^\]]*)\]\s*,\s*function/g

Module = (@name, @fileName, @deps = []) -> 

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


gatherModules = (currentModule, output = []) ->

  currentModule.deps.forEach( (depModule) ->
    gatherModules(depModule, output)
  )
  if not _.contains(output, currentModule)
    output.push(currentModule)
  return output


optimize = (startModuleName, config = {}, callback) ->

  allDeps = []
  depsByName = {}
  fileBuffer = {}

  allModules = []

  resolveModuleName = (moduleName, relativeTo = "") ->

    if moduleName[0] == "."
      return path.join(path.dirname(relativeTo), moduleName)
    else
      return moduleName


  resolveModuleFileName = (moduleName) ->

    if config.paths[moduleName]
      if config.paths[moduleName] == "empty:"
        return
      else
        return path.resolve(config.baseUrl, config.paths[moduleName]) + ".js"
    else
      return path.resolve(config.baseUrl, moduleName) + ".js"


  emitModule = (moduleName, fileName, deps) ->

    mod = new Module(moduleName, fileName, deps)
    allModules.push(mod)
    # console.log("Resolved", moduleName, fileName, _.map(deps, "name"))
    return mod


  resolveModules = (moduleNames, callback) ->

    async.mapSeries(moduleNames, resolveModule, callback)
    return


  parseRequireDefinitions = (fileData, callback) ->

    matches = []
    fileData.replace(
      defineRegex
      (fullMatch, method, _moduleName, deps) ->

        deps = deps
          .replace(/\"([^\"]*)\"/g, "$1")
          .split(",")
          .map((a) -> a.trim())

        deps = _.compact(deps)

        matches.push(
          method : method
          moduleName : _moduleName
          deps : deps
        )
        return fullMatch
    )

    callback(null, fileData, matches)
    return


  resolveInlinedModule = (moduleName, deps, fileName, callback) ->

    async.waterfall([
      
      (callback) -> resolveModules(deps, callback)
      
      (modules, callback) -> 
        emitModule(moduleName, fileName, _.compact(modules))
        callback()

    ], callback)
    return


  resolveModule = (moduleName, callback) ->

    module = _.detect(allModules, name : moduleName)
    if module
      callback(null, module)
      return

    fileName = resolveModuleFileName(moduleName)
    if not fileName
      callback()
      return

    # console.log("Resolving", moduleName, fileName)

    async.waterfall([

      (callback) -> fs.readFile(fileName, "utf8", callback)

      parseRequireDefinitions

      (fileData, definitions, callback) ->

        async.mapSeries(
          definitions
          (def, callback) ->

            def.deps = def.deps.map( (depName) -> resolveModuleName(depName, def.moduleName ? moduleName) )

            if def.method == "define" and def.moduleName != undefined
              async.waterfall([
                (callback) -> resolveInlinedModule(def.moduleName, def.deps, fileName, callback)
                (callback) -> callback(null, [])
              ], callback)

            else
              resolveModules(def.deps, callback)
            return
          callback
        )

      (unflatModules, callback) ->

        depModules = _.compact(_.flatten(unflatModules))
        callback(null, emitModule(moduleName, fileName, depModules))

    ], callback)
    return
      



  async.waterfall([

    (callback) ->

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
        # console.log("Config", config)
        callback()
      )

    (callback) ->

      resolveModule(startModuleName, callback)

    (module, callback) ->

      # printTree(module)
      # gatherModules(module).forEach((a) -> console.log(a.name, "in", path.relative(process.cwd(), a.fileName)))
      console.log("Finished")

  ], callback)


optimize(
  "index"
  mainConfigFile : "build/javascripts/require_config.js"
  baseUrl : "build/javascripts"
  paths :
    "services/stack_service/workers/worker": "empty:"
    cordova : "empty:"
)