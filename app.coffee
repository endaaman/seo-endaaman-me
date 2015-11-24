fs = require 'fs'
url = require 'url'
querystring = require 'querystring'

koa = require 'koa'
phantom = require 'phantom'
Q = require 'q'
coffee = require 'coffee-script'

config = require './config'
prod = process.env.NODE_ENV is 'production'

prettifyUrl = (uglyUrl)->
    oldUrlObj = url.parse uglyUrl
    queryObj = querystring.parse oldUrlObj.query
    escapedFragment = ''
    if queryObj._escaped_fragment_?
        if queryObj._escaped_fragment_
            escapedFragment = '#!' + queryObj._escaped_fragment_;
        delete queryObj['_escaped_fragment_']
    else
        return uglyUrl

    newUrlObj =
        protocol: oldUrlObj.protocol,
        slash: oldUrlObj.slash,
        host: oldUrlObj.host,
        port: oldUrlObj.port,
        hostname: oldUrlObj.hostname,
        hash: escapedFragment,
        query: queryObj,
        pathname: oldUrlObj.pathname
    url.format newUrlObj


__ph = null
initPhantom = ->
    d = do Q.defer
    if __ph
        d.resolve __ph
    else
        phantom.create (ph)->
            console.log 'initialized PhantomJS instance'
            __ph = ph
            d.resolve ph
    d.promise

# initialize PhantomJS instance on started
do initPhantom

createPage = (ph)->
    d = do Q.defer
    ph.createPage (page)->
        d.resolve page
    d.promise


open = (page, targetUrl)->
    deferred = do Q.defer

    isFirstResourceRecieved = true
    finished = false
    result =
        status: 400
        body: ''
        type: 'text/plain'
        custom: {}

    finish = ->
        if finished
            return
        finished = true
        deferred.resolve result

    evalPageBody = ->
        # abort here as well for performace
        if finished
            return
        page.evaluate ->
            doctype = new XMLSerializer().serializeToString document.doctype
            html = document.documentElement.outerHTML
            doctype + html
        , (body)->
            result.body = body
            do finish

    page.set 'settings.loadImages', false
    page.set 'onCallback', (data)->
        switch data.command
            when 'START'
                setTimeout ->
                    # timeout
                    do evalPageBody
                , config.timeoutDuration

            when 'FINISH'
                # TODO: Accept status overwritten (ex. manually set 404, 403, etc)
                console.log data
                if typeof data.status is 'number'
                    result.status = data.status
                do evalPageBody

    page.set 'onResourceReceived', (response)->
        if not isFirstResourceRecieved
            return
        isFirstResourceRecieved = false
        result.status = response.status
        result.type = response.contentType
        if 300 <= response.status < 400
            result.custom.Location = response.redirectURL
            do finish


    page.open targetUrl, (_status)->
        if _status is 'fail'
            result.status = 400
            result.body = 'Could not open the URL'
            do finish

        setTimeout ->
            do evalPageBody
        , config.cushionDuration

    deferred.promise




app = koa()
.use (next)->
    if @request.path isnt '/client.js'
        yield next
        return
    src = yield Q.nfcall fs.readFile, 'public/client.coffee', 'utf-8'
    @type = 'application/javascript'
    @body = coffee.compile src

.use (next)->
    tartgetUrl = @request.url.substr 1, @request.url.length
    urlObj = url.parse tartgetUrl
    if not prod
        @targetUrl = prettifyUrl tartgetUrl
        yield next
        return

    for reg in config.hostsWhiteListed
        if reg.test urlObj.host
            @targetUrl = prettifyUrl tartgetUrl
            yield next
            return

    @status = 400


.use (next)->
    if not @targetUrl
        yield next
        return
    ph = yield initPhantom()
    page = yield createPage ph
    result = yield open page, @targetUrl

    @type = result.type
    @status = result.status
    @body = result.body
    for k, v of result.custom
        @set k, v

    console.log "#{@status}: #{@targetUrl}"
    yield next

app.listen process.env.PORT || 3001

process.on 'SIGINT', ->
    # destroy PhantomJS instance safely
    if __ph
        __ph.exit()
