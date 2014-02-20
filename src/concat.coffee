_         = require("lodash")
fs        = require("fs")
VinylFile = require("vinyl")
path      = require("path")
async     = require("async")

fixModuleFile = (module) ->
  if not module.hasDefine
    # console.log(module.name, "added define", _.map(module.deps, "name").join(","), module.exports)
    module.fileContents += """\ndefine("#{module.name}", #{JSON.stringify(_.map(module.deps, "name"))}, function () { return #{module.exports or "null"}; });"""
  else if module.isAnonymous
    # console.log(module.name, "fixed define")
    module.fileContents = module.fileContents.replace(/define\(\s*(\[|function)/g, """define("#{module.name}", $1""")

  module.fileContents = "// BEGIN #{module.name}\n#{module.fileContents}\n// END #{module.name}\n// ------------------------------------------------------------------\n\n"
  return module


module.exports = concat = (modules, callback) ->

  async.waterfall([
    (callback) ->
      async.map(
        modules
        (module, callback) -> fs.readFile(module.fileName, "utf8", callback)
        callback
      )

    (moduleFileContents, callback) ->

      _.zip(modules, moduleFileContents).forEach( ([module, fileContents]) ->
        module.fileContents = fileContents
        module = fixModuleFile(module)
      )

      callback(
        null
        new VinylFile(
          contents : new Buffer(_.map(modules, "fileContents").join("\n"), "utf8")
        )
      )

  ], callback)

