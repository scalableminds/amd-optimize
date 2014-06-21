_         = require("lodash")
b         = require("ast-types").builders
escodegen = require("escodegen")
through   = require("through2")

module.exports = fixModule = (options = {}) ->

  options = _.defaults(options,
    sourceMap : false
    wrapShim : true
  )

  through.obj( (module, enc, done) ->

    if module.isShallow
      done()
      return

    ast = module.file.ast

    if not module.hasDefine

      defineReturnStatement = b.returnStatement(
        if module.exports
          b.identifier(module.exports)
        else
          null
      )

      if options.wrapShim and module.isShimmed
        defineBody = ast.body.concat([defineReturnStatement])
      else
        defineBody = [defineReturnStatement]

      defineCall = b.callExpression(
        b.identifier("define")
        [
          b.literal(module.name)
          b.arrayExpression(module.deps.map( (dep) -> b.literal(dep.name) ))
          b.functionExpression(
            null
            []
            b.blockStatement(defineBody)
          )
        ]
      )

      if options.wrapShim and module.isShimmed
        ast.body = [b.expressionStatement(
          defineCall
        )]

      else
        ast.body.push(
          b.expressionStatement(defineCall)
        )

    else if module.isAnonymous

      module.astNodes.forEach((astNode) ->
        if astNode.callee.name == "define" and 0 < astNode.arguments.length < 3 and astNode.arguments[0].type != "Literal"

          astNode.arguments = [
            b.literal(module.name)
            b.arrayExpression(module.deps.map( (dep) -> b.literal(dep.name) ))
            _.last(astNode.arguments)
          ]
      )

    if module.hasDefine and module.isShimmed
      ast.body = [b.expressionStatement(
        b.callExpression(
          b.memberExpression(
            b.functionExpression(
              null
              []
              b.blockStatement(
                ast.body
              )
            )
            b.identifier("call")
            false
          )
          [b.thisExpression()]
        )
      )]

    # TODO: Handle shimmed, mapped and relative deps

    # console.log escodegen.generate(module.file.ast, sourceMap : true).toString()


    if options.sourceMap
      generatedCode = escodegen.generate(
        ast
        sourceMap : true, sourceMapWithCode : true
      )

      sourceFile = module.file.clone()
      sourceFile.contents = new Buffer(generatedCode.code, "utf8")

      sourceMapFile = module.file.clone()
      sourceMapFile.path += ".map"
      sourceMapFile.contents = new Buffer(generatedCode.map.toString(), "utf8")

      @push(sourceFile)
      @push(sourceMapFile)

    else
      sourceFile = module.file.clone()
      sourceFile.contents = new Buffer(escodegen.generate(ast), "utf8")

      @push(sourceFile)

    done()

  )
