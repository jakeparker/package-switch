Bundle = require './bundle'
path = require 'path'
fs = require 'fs'
{Emitter} = require 'atom'
CSON = require 'season'

module.exports =
  class Bundles
    filename: null
    data: {}
    writing: false

    constructor: (arg) ->
      if arg?
        @filename = if arg is '' then null else arg
      else
        @getFileName()
      if @filename?
        @touchFile()
        @getData()
        @watcher = fs.watch @filename, @reload
      else
        @data = {}
      @emitter = new Emitter

    destroy: ->
      @watcher?.close()
      @emitter.dispose()
      @data = {}

    reload: (event,filename) =>
      if not @writing
        @getData() if @filename?
        @emitter.emit 'file-change'
      else
        @writing = false

    getFileName: ->
      @filename = path.join(path.dirname(atom.config.getUserConfigPath()),"package-switch.bundles")

    onFileChange: (callback) ->
      @emitter.on 'file-change', callback

    getData: ->
      try
        data = CSON.readFileSync @filename
        Object.keys(data).forEach (key) =>
          @data[key] = new Bundle(data[key])
      catch error
        @notify 'Error while reading settings from file'

    setData: (emit = true)=>
      if @filename?
        try
          @writing = true
          CSON.writeFileSync @filename, @data
          @emitter.emit 'file-change' if emit
        catch error
          @notify "Settings could not be written to #{@filename}"
      else
        @reload()

    notify: (message) ->
      atom.notifications?.addError message
      console.log('package-switch: ' + message)

    touchFile: ->
      if not fs.existsSync @filename
        fs.writeFileSync @filename, '{}'

    addBundle: (name, packages) ->
      if @data[name]?
        @notify "Bundle \"#{name}\" already exists"
      else
        @data[name] = new Bundle({packages})
        @setData()

    removeBundle: (bundle) ->
      delete @data[bundle]
      @setData()

    getBundle: (bundle) ->
      @data[bundle]

    getBundles: ->
      p = []
      Object.keys(@data).forEach (key) ->
        p.push(key)
      p