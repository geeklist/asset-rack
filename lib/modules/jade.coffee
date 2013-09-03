fs = require 'fs'
pathutil = require 'path'
uglify = require 'uglify-js'
async = require 'async'
jade = require 'jade'
Asset = require('../index').Asset

class exports.JadeAsset extends Asset
    mimetype: 'text/javascript'

    create: (options) ->
        if options.dirname instanceof Array
            @dirnames = options.dirname.map (dirname) -> pathutil.resolve dirname
        else
            @dirnames = [pathutil.resolve options.dirname]
        @separator = options.separator or '/'
        @compress = options.compress or false
        @clientVariable = options.clientVariable or 'Templates'
        @beforeCompile = options.beforeCompile or null
        @base = pathutil.resolve options.base or null
        @fileObjects = @getFileObjects @dirnames
        if @rack?
            assets = {}
            for asset in @rack.assets
                assets[asset.url] = asset.specificUrl

            @assetsMap = """
                var assets = { 
                    assets: #{JSON.stringify(assets)},
                    url: #{(url) -> @assets[url]}
                };
            """
        @createContents()

    createContents: ->
        @contents = fs.readFileSync require.resolve('jade').replace 'index.js', 'runtime.js'
        @contents += '(function(){ \n' if @assetsMap?
        @contents += @assetsMap if @assetsMap?
        @contents += "window.#{@clientVariable} = {\n"
        @fileContents = ""

        for fileObject in @fileObjects
            if @fileContents.length > 0
                @fileContents += ","
            @fileContents += "'#{fileObject.funcName}': #{fileObject.compiled}"
        @contents += @fileContents
        @contents += '};'
        @contents += '})();' if @assetsMap?
        @contents = uglify.minify(@contents, {fromString: true}).code if @compress
        unless @hasError
            @emit 'created'
        
    getFileObjects: (dirnames, prefix='') ->
        self = this
        paths = []
        async.each dirnames, ((dirname, cb) ->
            if self.base && prefix is ''
                prefix = (dirname.replace self.base + '/', '') + '/'
            filenames = fs.readdirSync dirname
            for filename in filenames
                continue if filename.slice(0, 1) is '.'
                path = pathutil.join dirname, filename
                stats = fs.statSync path
                if stats.isDirectory()
                    newPrefix = "#{prefix}#{pathutil.basename(path)}#{self.separator}"
                    paths = paths.concat self.getFileObjects [path], newPrefix
                else
                    continue if pathutil.extname(path) isnt '.jade'
                    funcName = "#{prefix}#{pathutil.basename(path, '.jade')}"
                    fileContents = fs.readFileSync path, 'utf8'
                    fileContents = self.beforeCompile fileContents if self.beforeCompile?
                    try
                        compiled = jade.compile fileContents,
                            client: true,
                            compileDebug: false,
                            filename: path
                        paths.push
                            path: path
                            funcName: funcName
                            compiled: compiled
                    catch error
                        @hasError = true
                        @emit 'error', error
            prefix = ''
            cb paths
        ), (paths) ->
            paths = paths.concat paths
        paths