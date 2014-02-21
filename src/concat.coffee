_         = require("lodash")
fs        = require("fs")
VinylFile = require("vinyl")
path      = require("path")
async     = require("async")
b         = require("ast-types").builders
escodegen = require("escodegen")


fixModuleFile = (module) ->
  if not module.hasDefine
    # console.log(module.name, "added define", _.map(module.deps, "name").join(","), module.exports)
    module.file.ast.body.push(
      b.expressionStatement(
        b.callExpression(
          b.identifier("define")
          [
            b.literal(module.name)
            b.arrayExpression(module.deps.map( (dep) -> b.literal(dep.name) ))
            b.functionExpression(
              null
              []
              b.blockStatement([
                b.returnStatement(
                  if module.exports
                    b.identifier(module.exports)
                  else
                    null
                )
              ])
            )
          ]
        )
      )
    )
    # module.file.stringContents += """\ndefine("#{module.name}", #{JSON.stringify(_.map(module.deps, "name"))}, function () { return #{module.exports or "null"}; });"""
  
  else if module.isAnonymous
    # console.log(module.name, "fixed define")
    module.astNodes.forEach((astNode) ->
      if astNode.callee.name == "define" and 0 < astNode.arguments.length < 3 and astNode.arguments[0].type != "Literal"
        astNode.arguments.unshift(b.literal(module.name))
    )
    # module.file.stringContents = module.file.stringContents.replace(/define\(\s*(\[|function)/g, """define("#{module.name}", $1""")

  # module.file.stringContents = "// BEGIN #{module.name}\n#{module.file.stringContents}\n// END #{module.name}\n// ------------------------------------------------------------------\n\n"
  return module


module.exports = concat = (modules, callback) ->

  modules = modules.map(fixModuleFile)

  joinedBody = _.flatten(
    modules.map( (module) -> module.file.ast.body )
  )
  joinedAst = b.program(joinedBody)

  generatedCode = escodegen.generate(joinedAst, sourceMap : true, sourceMapWithCode : true)

  callback(
    null
    [
      new VinylFile(
        contents : new Buffer(generatedCode.code, "utf8")
      )
      new VinylFile(
        contents : new Buffer(generatedCode.map.toString(), "utf8")
      )
    ]
  )
