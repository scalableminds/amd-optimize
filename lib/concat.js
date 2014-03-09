(function() {
  var VinylFile, async, b, concat, escodegen, fixModule, fs, path, through2, _;

  _ = require("lodash");

  fs = require("fs");

  VinylFile = require("vinyl");

  path = require("path");

  async = require("async");

  b = require("ast-types").builders;

  escodegen = require("escodegen");

  through2 = require("through2");

  fixModule = function(module) {
    if (!module.hasDefine) {
      module.file.ast.body.push(b.expressionStatement(b.callExpression(b.identifier("define"), [
        b.literal(module.name), b.arrayExpression(module.deps.map(function(dep) {
          return b.literal(dep.name);
        })), b.functionExpression(null, [], b.blockStatement([b.returnStatement(module.exports ? b.identifier(module.exports) : null)]))
      ])));
    } else if (module.isAnonymous) {
      module.astNodes.forEach(function(astNode) {
        var _ref;
        if (astNode.callee.name === "define" && (0 < (_ref = astNode["arguments"].length) && _ref < 3) && astNode["arguments"][0].type !== "Literal") {
          return astNode["arguments"] = [
            b.literal(module.name), b.arrayExpression(module.deps.map(function(dep) {
              return b.literal(dep.name);
            })), _.last(astNode["arguments"])
          ];
        }
      });
    }
    return module;
  };

  module.exports = concat = function(config) {
    var joinedBody, modules;
    modules = [];
    joinedBody = [];
    return through2.obj(function(module, enc, callback) {
      modules.push(fixModule(module));
      joinedBody.push.apply(joinedBody, module.file.ast.body);
      return callback();
    }, function(callback) {
      var generatedCode, joinedAst;
      joinedAst = b.program(joinedBody);
      if (config.sourceMap) {
        generatedCode = escodegen.generate(joinedAst, {
          sourceMap: true,
          sourceMapWithCode: true
        });
      } else {
        generatedCode = {
          code: escodegen.generate(joinedAst)
        };
      }
      this.push(new VinylFile({
        contents: new Buffer(generatedCode.code, "utf8"),
        path: "file.js"
      }));
      if (generatedCode.map) {
        this.push(new VinylFile({
          contents: new Buffer(generatedCode.map.toString(), "utf8"),
          path: "file.js.map"
        }));
      }
      return callback();
    });
  };

}).call(this);
