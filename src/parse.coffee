_ = require("lodash")
acorn = require("acorn")
walk = require("acorn/util/walk")
recast = require("recast")

valuesFromArrayExpression = (expr) -> expr.elements.map( (a) -> a.value )

module.exports = parseRequireDefinitions = (file, callback) ->

  ast = acorn.parse(file.stringContents, sourceFile : file.relative, locations : true)
  file.ast = ast

  definitions = []
  walk.simple(ast, CallExpression : (node) ->

    if node.callee.name == "define"
      
      switch node.arguments.length

        when 2
          switch node.arguments[0].type
            when "Literal"
              moduleName = node.arguments[0].value
            when "ArrayExpression"
              deps = valuesFromArrayExpression(node.arguments[0])

        when 3
          moduleName = node.arguments[0].value
          deps = valuesFromArrayExpression(node.arguments[1])

      definitions.push(
        method : "define"
        moduleName : moduleName
        deps : deps ? []
        node : node
      )


    if node.callee.name == "require" and node.arguments.length > 0 and node.arguments[0].type == "ArrayExpression"
      definitions.push(
        method : "require"
        moduleName : undefined
        deps : valuesFromArrayExpression(node.arguments[0])
        node : node
      )

  )

  callback(null, file, definitions)
  return