(function() {
  var b, escodegen, fixModule, through, _;

  _ = require("lodash");

  b = require("ast-types").builders;

  escodegen = require("escodegen");

  through = require("through2");

  module.exports = fixModule = function(options) {
    if (options == null) {
      options = {};
    }
    options = _.defaults(options, {
      sourceMap: false,
      wrapShim: true
    });
    return through.obj(function(module, enc, done) {
      var ast, defineBody, defineCall, defineReturnStatement, generatedCode, sourceFile, sourceMapFile;
      if (module.isShallow) {
        done();
        return;
      }
      ast = module.file.ast;
      if (!module.hasDefine) {
        defineReturnStatement = b.returnStatement(module.exports ? b.identifier(module.exports) : null);
        if (options.wrapShim) {
          defineBody = ast.body.concat([defineReturnStatement]);
        } else {
          defineBody = [defineReturnStatement];
        }
        defineCall = b.callExpression(b.identifier("define"), [
          b.literal(module.name), b.arrayExpression(module.deps.map(function(dep) {
            return b.literal(dep.name);
          })), b.functionExpression(null, [], b.blockStatement(defineBody))
        ]);
        if (options.wrapShim) {
          ast.body = [b.expressionStatement(defineCall)];
        } else {
          ast.body.push(b.expressionStatement(defineCall));
        }
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
      if (module.hasDefine && module.isShimmed) {
        ast.body = [b.expressionStatement(b.callExpression(b.memberExpression(b.functionExpression(null, [], b.blockStatement(ast.body)), b.identifier("call"), false), [b.thisExpression()]))];
      }
      if (options.sourceMap) {
        generatedCode = escodegen.generate(ast, {
          sourceMap: true,
          sourceMapWithCode: true
        });
        sourceFile = module.file.clone();
        sourceFile.contents = new Buffer(generatedCode.code, "utf8");
        sourceMapFile = module.file.clone();
        sourceMapFile.path += ".map";
        sourceMapFile.contents = new Buffer(generatedCode.map.toString(), "utf8");
        this.push(sourceFile);
        this.push(sourceMapFile);
      } else {
        sourceFile = module.file.clone();
        sourceFile.contents = new Buffer(escodegen.generate(ast), "utf8");
        this.push(sourceFile);
      }
      return done();
    });
  };

}).call(this);
