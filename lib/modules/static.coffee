
fs = require 'fs'
pathutil = require 'path'
async = require 'async'
mime = require 'mime'
uglify = require 'uglify-js'
{Asset} = require '../.'
{DynamicAssets} = require './dynamic'

class StaticAsset extends Asset
    create: (options) ->
        console.log(options)
        @filename = pathutil.resolve options.filename
        @mimetype ?= mime.types[pathutil.extname(@filename).slice 1] || 'text/plain'

        if pathutil.extname(@filename) is '.js'
            fileContent = fs.readFileSync @filename, 'utf8'
            data = uglify.minify(fileContent, {fromString: true}).code
            @emit 'created', contents: data
        else
            fs.readFile @filename, (error, data) =>
                return @emit 'error', error if error?
                @emit 'created', contents: data

class exports.StaticAssets extends DynamicAssets
    constructor: (options) ->
        options?.type = StaticAsset
        super options
