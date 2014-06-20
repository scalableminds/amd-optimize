_      = require("lodash")
acorn  = require("acorn")
walk   = require("acorn/util/walk")

valuesFromArrayExpression = (expr) -> expr.elements.map( (a) -> a.value )

module.exports = parseRequireDefinitions = (config, file, callback) ->

  try
    ast = acorn.parse(file.stringContents, sourceFile : file.relative, locations : config.sourceMap)
  catch err
    callback(err)
    return

  file.ast = ast

  definitions = []
  walk.ancestor(ast, CallExpression : (node, state) ->

    if node.callee.name == "define"

      switch node.arguments.length

        when 1
          # define(function (require, exports, module) {})
          if node.arguments[0].type == "FunctionExpression" and
          node.arguments[0].params.length > 0

            deps = []
            walk.simple(node.arguments[0], VariableDeclaration : (node) ->
              node.declarations.forEach( ({ id: left, init: right }) ->
                if right.type == "CallExpression" and right.callee.name == "require"
                  deps.push(right.arguments[0].value)
              )
            )

        when 2
          switch node.arguments[0].type
            when "Literal"
              # define("name", function () {})
              moduleName = node.arguments[0].value
            when "ArrayExpression"
              # define(["dep"], function () {})
              deps = valuesFromArrayExpression(node.arguments[0])

        when 3
          # define("name", ["dep"], function () {})
          moduleName = node.arguments[0].value
          deps = valuesFromArrayExpression(node.arguments[1])

      definitions.push(
        method : "define"
        moduleName : moduleName
        deps : deps ? []
        node : node
      )

      isInsideDefine = true


    if node.callee.name == "require" and node.arguments.length > 0 and node.arguments[0].type == "ArrayExpression"

      defineAncestors = _.any(
        state.slice(0, -1)
        (ancestorNode) -> ancestorNode.type == "CallExpression" and (ancestorNode.callee.name == "define" or ancestorNode.callee.name == "require")
      )
      if config.findNestedDependencies or not defineAncestors
        definitions.push(
          method : "require"
          moduleName : undefined
          deps : valuesFromArrayExpression(node.arguments[0])
          node : node
        )

  )

  callback(null, file, definitions)
  return
