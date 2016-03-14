co = require 'co'
path = require 'path'
express = require 'express'
config = require 'config'
glob = require 'glob'
router = express.Router()

# expose root path for future usage
RootPath = path.dirname require.main.filename
global["RootPath"] = RootPath

app = express()
bodyparser = require('body-parser')
app.use bodyparser.urlencoded(extended: true)
app.use bodyparser.json()

app.set "views", "./app/views"
app.set "view engine", "jade"
app.engine "jade", require("jade").__express

# load models
db = require './app/models'

force_sync = process.env.NDOE_ENV == 'test'
db
  .sequelize
  .sync(force: force_sync)
  .then ->
    # load initializers
    files = glob.sync "#{RootPath}/config/initializers/*.coffee"
    files.forEach (file) ->
      f = require(file)
      if typeof f == 'function'
        if f.length >= 1
          f app, db
        else
          f()

    global["Models"] = db

    # route setup
    require("#{RootPath}/config/routes.coffee") router
    app.use router

    port = process.env.PORT || config.host.port || 9900
    intfc = process.env.INTERFACE || "127.0.0.1"
    app.listen parseInt(port), intfc
    console.log "Server is listening on port #{port}"
  .catch (err) ->
    console.dir err
    throw err
# vim: set ts=2 sw=2:
