# rjs-optimizer

Alternative to [r.js]() build tool (WIP)

# Features
tbd

# Installation

```bash
$ npm install rjs-optimizer
```

# Example

```coffee
optimize(
  "main"
  {
    mainConfigFile : "public/javascripts/require_config.js"
    baseUrl : "public/javascripts"
    paths :
      "services/stack_service/workers/worker": "empty:"
      "admin/views/task/task_overview_view": "empty:"
      "routes": "empty:"
      "cordova" : "empty:"
  }
  (err, vinylFile) ->
    if err
      console.error(err)
    else
      outputStream = vinylFs.dest(".")
      outputStream.write(vinylFile)
      outputStream.end()
      outputStream.on("end", -> console.log("Finished", vinylFile.path))
)
```
