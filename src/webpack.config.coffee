###
Webpack configuration file

Run dev server with source maps:

    npm run webpack-watch

Then visit (say)

    https://dev0.sagemath.com/static/webpack.html

This is far from ready to use yet, e.g., we need to properly serve primus websockets, etc.:

    webpack-dev-server --port=9000 -d

Resources for learning webpack:

    - https://github.com/petehunt/webpack-howto
    - http://webpack.github.io/docs/tutorials/getting-started/

###
'use strict';

_        = require('lodash')
webpack  = require('webpack')
path     = require('path')
fs       = require('fs')

VERSION  = "0.0.0"
INPUT    = path.resolve(__dirname, "static")
OUTPUT   = "./webpack"
DEVEL    = "development"
NODE_ENV = process.env.NODE_ENV || DEVEL
dateISO  = new Date().toISOString()

# mathjax version → symlink with version info from package.json
MATHJAX_DIR = 'smc-webapp/node_modules/mathjax'
MATHJAX_VERS = JSON.parse(fs.readFileSync("#{MATHJAX_DIR}/package.json", 'utf8')).version
MATHJAX_ROOT = path.join(OUTPUT, "mathjax-#{MATHJAX_VERS}")

class MathjaxVersionedSymlink

MathjaxVersionedSymlink.prototype.apply = (compiler) ->
    compiler.plugin "done", (compilation, cb) ->
        fs.exists MATHJAX_ROOT,  (exists, cb) ->
            if not exists
                fs.symlink("../#{MATHJAX_DIR}", MATHJAX_ROOT, cb)

mathjaxVersionedSymlink = new MathjaxVersionedSymlink()

# create a file base_url to set a base url
BASE_URL = if fs.existsSync('data/base_url') then fs.readFileSync('data/base_url').toString().trim() + "/" else ''
console.log "NODE_ENV=#{NODE_ENV}"
console.log "base_url='#{BASE_URL}'"
console.log "INPUT='#{INPUT}'"
console.log "OUTPUT='#{OUTPUT}'"

# plugins

# deterministic hashing for assets
WebpackSHAHash = require('webpack-sha-hash')
webpackSHAHash = new WebpackSHAHash()

# cleanup like "make distclean" (necessary, otherwise there are millions of hashed filenames)
CleanWebpackPlugin = require('clean-webpack-plugin')
cleanWebpackPlugin = new CleanWebpackPlugin [OUTPUT],
                                            verbose: true
                                            dry: false

# assets.json file
AssetsPlugin = require('assets-webpack-plugin')
assetsPlugin = new AssetsPlugin
                        filename   : "assets.json"
                        fullPath   : no
                        prettyPrint: true
                        metadata:
                            version: VERSION
                            date   : dateISO

# https://www.npmjs.com/package/html-webpack-plugin
HtmlWebpackPlugin = require('html-webpack-plugin')
jade2html = new HtmlWebpackPlugin
                        date     : dateISO
                        title    : 'SageMathCloud'
                        mathjax  : "#{MATHJAX_ROOT}/MathJax.js"
                        filename : 'index.html'
                        template : 'index.jade'

# https://webpack.github.io/docs/stylesheets.html
ExtractTextPlugin = require("extract-text-webpack-plugin")

# merge + minify of included CSS files
cssConfig = JSON.stringify(minimize: true, discardComments: {removeAll: true}, mergeLonghand: true, sourceMap: true)
extractCSS = new ExtractTextPlugin("styles-[hash].css")
#extractTextCss  = ExtractTextPlugin.extract("style", "css?sourceMap&#{cssConfig}")
#extractTextSass = ExtractTextPlugin.extract("style", "css?#{cssConfig}!sass?sourceMap&indentedSyntax")
#extractTextScss = ExtractTextPlugin.extract("style", "css?#{cssConfig}!sass?sourceMap")
#extractTextLess = ExtractTextPlugin.extract("style", "css?#{cssConfig}!less?sourceMap")

# custom plugin, to handle the quirky situation of index.html
class MoveFilesToTargetPlugin
    constructor: (@files, @target) ->

MoveFilesToTargetPlugin.prototype.apply = (compiler) ->
    compiler.plugin "done", (comp) =>
        #console.log('compilation:', _.keys(comp.compilation))
        _.forEach @files, (fn) =>
            src = path.join(path.resolve(__dirname, INPUT), fn)
            dst = path.join(@target, fn)
            console.log("moving file:", src, "→", dst)
            fs.renameSync(src, dst)

moveFilesToTargetPlugin = new MoveFilesToTargetPlugin([], OUTPUT)

###
CopyWebpackPlugin = require('copy-webpack-plugin')
copyWebpackPlugin = new CopyWebpackPlugin []
###

setNODE_ENV          = new webpack.DefinePlugin
                                'MATHJAX_VERS': MATHJAX_VERS
                                'MATHJAX_ROOT': MATHJAX_ROOT
                                'VERSION'     : VERSION
                                'process.env' :
                                    'NODE_ENV': JSON.stringify(NODE_ENV)

dedupePlugin         = new webpack.optimize.DedupePlugin()
limitChunkCount      = new webpack.optimize.LimitChunkCountPlugin({maxChunks: 10})
minChunkSize         = new webpack.optimize.MinChunkSizePlugin({minChunkSize: 51200})
occurenceOrderPlugin = new webpack.optimize.OccurenceOrderPlugin()
commonsChunkPlugin   = new webpack.optimize.CommonsChunkPlugin
                                                name: "vendor"
                                                minChunks: Infinity

{StatsWriterPlugin} = require("webpack-stats-plugin")
statsWriterPlugin   = new StatsWriterPlugin(filename: "webpack-stats.json")


plugins = [
    cleanWebpackPlugin,
    webpackSHAHash,
    setNODE_ENV,
    jade2html,
    commonsChunkPlugin,
    assetsPlugin,
    occurenceOrderPlugin,
    moveFilesToTargetPlugin,
    extractCSS,
    #copyWebpackPlugin
    statsWriterPlugin,
    mathjaxVersionedSymlink
]

if NODE_ENV != DEVEL
    plugins.push dedupePlugin
    plugins.push limitChunkCount
    plugins.push minChunkSize
    plugins.push new webpack.optimize.UglifyJsPlugin
                            minimize:true
                            comments:false
                            mangle:
                                except: ['$super', '$', 'exports', 'require']

hashname    = '[path][name]-[sha1:hash:base64:10].[ext]'
pngconfig   = JSON.stringify(name: hashname, limit: 12000, mimetype: 'image/png')
svgconfig   = JSON.stringify(name: hashname, limit: 12000, mimetype: 'image/svg+xml')
icoconfig   = JSON.stringify(name: hashname, mimetype: 'image/x-icon')
woffconfig  = JSON.stringify(name: hashname, mimetype: 'application/font-woff')

module.exports =
    cache: true

    entry:
        js           : 'js.coffee'
        vendors_css  : 'vendors-css.coffee'
        vendors      : 'vendors.coffee'
        smc          : 'index.coffee'

    output:
        path          : OUTPUT
        publicPath    : path.join(BASE_URL, OUTPUT) + '/'
        filename      : '[name]-[hash].js'
        chunkFilename : '[name]-[id]-[hash].js'

    module:
        loaders: [
            { test: /\.cjsx$/,   loaders: ['coffee-loader', 'cjsx-loader'] },
            { test: /\.coffee$/, loader: 'coffee-loader' },
            { test: /\.less$/,   loaders: ["style-loader", "css-loader", "less?#{cssConfig}"]},#loader : extractTextLess },
            { test: /\.scss$/,   loaders: ["style-loader", "css-loader", "sass?#{cssConfig}"]}, #loader : extractTextScss },
            { test: /\.sass$/,   loaders: ["style-loader", "css-loader", "sass?#{cssConfig}&indentedSyntax"]}, # loader : extractTextSass },
            { test: /\.json$/,   loaders: ['json-loader'] },
            { test: /\.png$/,    loader: "url-loader?#{pngconfig}" },
            { test: /\.ico$/,    loader: "file-loader?#{icoconfig}" },
            { test: /\.svg(\?v=[0-9].[0-9].[0-9])?$/,    loader: "url-loader?#{svgconfig}" },
            { test: /\.(jpg|gif)$/,    loader: "file-loader"},
            { test: /\.html$/,   loader: "raw!html-minify"},
            { test: /\.hbs$/,    loader: "handlebars-loader" },
            { test: /\.woff(2)?(\?v=[0-9].[0-9].[0-9])?$/, loader: "url-loader?#{woffconfig}" },
            { test: /\.(ttf|eot)(\?v=[0-9].[0-9].[0-9])?$/, loader: "file-loader?name=#{hashname}" },
            # { test: /\.css$/,    loader: 'style!css' },
            { test: /\.css$/, loaders: ["style-loader", "css-loader?#{cssConfig}"]}, # loader: extractTextCss },
            { test: /\.jade$/, loader: 'jade' },
        ]

    resolve:
        # So we can require('file') instead of require('file.coffee')
        extensions : ['', '.js', '.json', '.coffee', '.cjsx', '.scss', '.sass']
        root       : [path.resolve(__dirname),
                      path.resolve(__dirname, 'smc-util'),
                      path.resolve(__dirname, 'smc-util/node_modules'),
                      path.resolve(__dirname, 'smc-webapp'),
                      path.resolve(__dirname, 'smc-webapp/node_modules')]

    plugins: plugins

    'html-minify-loader':
         empty: true        # KEEP empty attributes
         cdata: true        # KEEP CDATA from scripts
         comments: false