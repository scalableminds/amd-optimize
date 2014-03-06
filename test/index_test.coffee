_       = require("lodash")
assert  = require("assert")
vinylfs = require("vinyl-fs")
coffee  = require("gulp-coffee")
acorn   = require("acorn")
walk    = require("acorn/util/walk")

rjs     = require("../src/index")

describe "rjs-optimizer", ->

  it "should work without configuration", (done) ->

    expectedFiles = ["test.js", "index.js"]

    vinylfs.src("#{__dirname}/fixtures/core/*.js")
      .pipe(rjs("index"))
      .on("data", (file) ->
        assert.equal(expectedFiles.shift(), file.relative)
      )
      .on("end", done)


  it "should work with a file loader", (done) ->

    expectedFiles = ["test.js", "index.js"]

    rjs(
      "index"
      loader : rjs.loader((name) -> "#{__dirname}/fixtures/core/#{name}.js")
    )
      .on("data", (file) ->
        assert.equal(expectedFiles.shift(), file.relative)
      )
      .on("end", done)
      .end()


  it "should work with `paths` config", (done) ->

    expectedFiles = ["test2.js", "index.js"]

    vinylfs.src("#{__dirname}/fixtures/core/*.js")
      .pipe(rjs(
        "index"
        paths : {
          test : "test2"
        }
      ))
      .on("data", (file) ->
        assert.equal(expectedFiles.shift(), file.relative)
      )
      .on("end", done)


  # it "should work with `map` config", (done) ->

  #   expectedFiles = ["test2.js", "index.js"]

  #   vinylfs.src("#{__dirname}/fixtures/core/*.js")
  #     .pipe(rjs(
  #       "index"
  #       map : {
  #         index : {
  #           test : "test2"
  #         }
  #       }
  #     ))
  #     .on("data", (file) ->
  #       assert.equal(expectedFiles.shift(), file.relative)
  #     )
  #     .on("end", done)


describe "shim", ->

  it "should add a `define` for non-AMD modules", (done) ->

    vinylfs.src("#{__dirname}/fixtures/shim/*.js")
      .pipe(rjs(
        "index"
      ))
      .on("data", (file) ->
        if file.relative == "test.js"
          stringContents = file.contents.toString("utf8")
          assert(/define\(\s*["']test['"]\s*/.test(stringContents))
      )
      .on("end", done)


  it "should add shimmed dependencies `define` for non-AMD modules", (done) ->

    vinylfs.src("#{__dirname}/fixtures/shim/*.js")
      .pipe(rjs(
        "index"
        shim : {
          test : {
            deps : ["test2"]
          }
        }
      ))
      .on("data", (file) ->
        if file.relative == "test.js"
          stringContents = file.contents.toString("utf8")
          assert(/define\(\s*["']test['"]\s*,\s*\[\s*["']test2["']\s*\]/.test(stringContents))
      )
      .on("end", done)


  it "should add shimmed export for non-AMD modules", (done) ->

    exportVariable = "test"

    vinylfs.src("#{__dirname}/fixtures/shim/*.js")
      .pipe(rjs(
        "index"
        shim : {
          test : {
            exports : exportVariable
          }
        }
      ))
      .on("data", (file) ->
        if file.relative == "test.js"
          stringContents = file.contents.toString("utf8")
          ast = acorn.parse(stringContents)

          hasDefine = false
          walk.simple(ast, CallExpression : (node) ->

            if node.callee.name == "define"

              hasDefine = true

              funcNode = _.last(node.arguments)
              assert.equal(funcNode.type, "FunctionExpression")

              returnNode = funcNode.body.body[0]
              assert.equal(returnNode.type, "ReturnStatement")

              assert.equal(returnNode.argument.type, "Identifier")
              assert.equal(returnNode.argument.name, exportVariable)

          )
          assert(hasDefine)
      )
      .on("end", done)

