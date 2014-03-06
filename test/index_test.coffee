_       = require("lodash")
assert  = require("assert")
vinylfs = require("vinyl-fs")
coffee  = require("gulp-coffee")
acorn   = require("acorn")
walk    = require("acorn/util/walk")

rjs     = require("../src/index")


checkExpectedFiles = (expectedFiles, stream, done) ->

  expectedFiles = expectedFiles.slice(0)
  stream
    .on("data", (file) ->
      assert.equal(expectedFiles.shift(), file.relative)
    )
    .on("end", ->
      assert.equal(expectedFiles.length, 0)
      done()
    )

describe "core", ->

  it "should work without configuration", (done) ->

    checkExpectedFiles(
      ["foo.js", "index.js"]
      vinylfs.src("#{__dirname}/fixtures/core/*.js")
        .pipe(rjs("index"))
      done
    )


  it "should work with relative dependencies", (done) ->

    checkExpectedFiles(
      ["foo.js", "relative.js"]
      vinylfs.src("#{__dirname}/fixtures/core/*.js")
        .pipe(rjs("relative"))
      done
    )


  it "should work with inline dependencies", (done) ->

    expectedFiles = ["foo.js", "bar.js", "inline.js"]

    counter = 0
    vinylfs.src("#{__dirname}/fixtures/core/*.js")
      .pipe(rjs("inline"))
      .on("data", (file) ->
        if counter < 2
          assert(_.contains(expectedFiles[0..1], file.relative))
        else
          assert.equal(expectedFiles[2], file.relative)
        counter++
      )
      .on("end", ->
        assert.equal(counter, 3)
        done()
      )


  it "should work with a file loader", (done) ->

    checkExpectedFiles(
      ["foo.js", "index.js"]
      source = rjs(
        "index"
        loader : rjs.loader((name) -> "#{__dirname}/fixtures/core/#{name}.js")
      )
      done
    )
    source.end()

  it "should work with a file loader with a pipe", (done) ->

    checkExpectedFiles(
      ["foo.js", "index.js"]
      source = rjs(
        "index"
        loader : rjs.loader(
          (name) -> "#{__dirname}/fixtures/core/#{name}.coffee"
          -> coffee()
        )
      )
      done
    )
    source.end()


  it "should work with `paths` config", (done) ->

    checkExpectedFiles(
      ["bar.js", "index.js"]

      vinylfs.src("#{__dirname}/fixtures/core/*.js")
        .pipe(rjs(
          "index"
          paths : {
            foo : "bar"
          }
        ))
      
      done
    )


  it "should work with `map` config"#, (done) ->

  #   expectedFiles = ["bar.js", "index.js"]

  #   vinylfs.src("#{__dirname}/fixtures/core/*.js")
  #     .pipe(rjs(
  #       "index"
  #       map : {
  #         index : {
  #           foo : "bar"
  #         }
  #       }
  #     ))
  #     .on("data", (file) ->
  #       assert.equal(expectedFiles.shift(), file.relative)
  #     )
  #     .on("end", done)


  it "should trace CommonJS-style module definitions"

  it "should exclude modules and their dependency tree"
  
  it "should shallowly exclude modules"

  it "should start searching for files, if no input but an output pipe"



describe "shim", ->

  it "should add a `define` for non-AMD modules", (done) ->

    vinylfs.src("#{__dirname}/fixtures/shim/*.js")
      .pipe(rjs(
        "index"
      ))
      .on("data", (file) ->
        if file.relative == "no_amd.js"
          stringContents = file.contents.toString("utf8")
          assert(/define\(\s*["']no_amd['"]\s*/.test(stringContents))
      )
      .on("end", done)


  it "should add shimmed dependencies `define` for non-AMD modules", (done) ->

    vinylfs.src("#{__dirname}/fixtures/shim/*.js")
      .pipe(rjs(
        "index"
        shim : {
          no_amd : {
            deps : ["no_amd2"]
          }
        }
      ))
      .on("data", (file) ->
        if file.relative == "no_amd.js"
          stringContents = file.contents.toString("utf8")
          assert(/define\(\s*["'].*['"]\s*,\s*\[\s*["']no_amd2["']\s*\]/.test(stringContents))
      )
      .on("end", done)


  it "should add shimmed export for non-AMD modules", (done) ->

    exportVariable = "test"

    vinylfs.src("#{__dirname}/fixtures/shim/*.js")
      .pipe(rjs(
        "index"
        shim : {
          no_amd : {
            exports : exportVariable
          }
        }
      ))
      .on("data", (file) ->
        if file.relative == "no_amd.js"
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

  it "should wrap non-AMD modules with a `define` call"


describe "nested dependencies", ->

  it "should not trace nested dependencies by default", (done) ->

    checkExpectedFiles(
      ["foo.js", "nested.js"]
      vinylfs.src("#{__dirname}/fixtures/core/*.js")
        .pipe(rjs("nested"))
      done
    )


  it "should trace nested dependencies", (done) ->

    checkExpectedFiles(
      ["bar.js", "foo.js", "nested.js"]

      vinylfs.src("#{__dirname}/fixtures/core/*.js")
        .pipe(rjs(
          "nested"
          findNestedDependencies : true
        ))

      done
    )


describe "config file", ->

  it "should read from config file from path", (done) ->

    checkExpectedFiles(
      ["index.js"]
      vinylfs.src("#{__dirname}/fixtures/config/index.js")
        .pipe(rjs(
          "index"
          configFile : "#{__dirname}/fixtures/config/config.js"
        ))
      done
    )


  it "should read from config file from vinyl stream", (done) ->

    checkExpectedFiles(
      ["index.js"]
      vinylfs.src("#{__dirname}/fixtures/config/index.js")
        .pipe(rjs(
          "index"
          configFile : vinylfs.src("#{__dirname}/fixtures/config/config.js")
        ))
      done
    )


  it "should read from config object"


describe "special paths", ->

  it "should ignore requirejs plugins", (done) ->

    checkExpectedFiles(
      ["bar.js", "plugin.js"]
      vinylfs.src("#{__dirname}/fixtures/core/*.js")
        .pipe(rjs("plugin"))
      done
    )


  it "should ignore empty paths", (done) ->

    checkExpectedFiles(
      ["index.js"]
      vinylfs.src("#{__dirname}/fixtures/core/index.js")
        .pipe(rjs(
          "index"
          paths : {
            foo : "empty:"
          }
        ))
      done
    )


  it "should ignore `exports` and `require` dependencies", (done) ->

    checkExpectedFiles(
      ["bar.js", "require_exports.js"]
      vinylfs.src("#{__dirname}/fixtures/core/*.js")
        .pipe(rjs("require_exports"))
      done
    )

