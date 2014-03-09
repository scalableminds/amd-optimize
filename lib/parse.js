(function() {
  var acorn, parseRequireDefinitions, valuesFromArrayExpression, walk, _;

  _ = require("lodash");

  acorn = require("acorn");

  walk = require("acorn/util/walk");

  valuesFromArrayExpression = function(expr) {
    return expr.elements.map(function(a) {
      return a.value;
    });
  };

  module.exports = parseRequireDefinitions = function(config, file, callback) {
    var ast, definitions;
    ast = acorn.parse(file.stringContents, {
      sourceFile: file.relative,
      locations: config.sourceMap
    });
    file.ast = ast;
    definitions = [];
    walk.ancestor(ast, {
      CallExpression: function(node, state) {
        var defineAncestors, deps, isInsideDefine, moduleName;
        if (node.callee.name === "define") {
          switch (node["arguments"].length) {
            case 2:
              switch (node["arguments"][0].type) {
                case "Literal":
                  moduleName = node["arguments"][0].value;
                  break;
                case "ArrayExpression":
                  deps = valuesFromArrayExpression(node["arguments"][0]);
              }
              break;
            case 3:
              moduleName = node["arguments"][0].value;
              deps = valuesFromArrayExpression(node["arguments"][1]);
          }
          definitions.push({
            method: "define",
            moduleName: moduleName,
            deps: deps != null ? deps : [],
            node: node
          });
          isInsideDefine = true;
        }
        if (node.callee.name === "require" && node["arguments"].length > 0 && node["arguments"][0].type === "ArrayExpression") {
          defineAncestors = _.any(state.slice(0, -1), function(ancestorNode) {
            return ancestorNode.type === "CallExpression" && (ancestorNode.callee.name === "define" || ancestorNode.callee.name === "require");
          });
          if (config.findNestedDependencies || !defineAncestors) {
            return definitions.push({
              method: "require",
              moduleName: void 0,
              deps: valuesFromArrayExpression(node["arguments"][0]),
              node: node
            });
          }
        }
      }
    });
    callback(null, file, definitions);
  };

}).call(this);
