redis = require 'redis'

module.exports = (connect) ->

  # We're using Redis hash container together with zset to keep track
  # of expired sessions.
  #
  # Middleware code based on reference https://github.com/expressjs/session
  # and `connect-redis` middleware code.
  class Store extends connect.session.Store

    # options.ttl Time to live in 
    constructor: (options = {}) ->
      super

      @name = options.name || 'sessions'
      @expName = options.exName || "#{@name}:exp"
      @maxTtl = options.maxTtl

      if options.client?
        @client = options.client
        if @client.ready
          @emit 'connect'
        else
          @client.on 'connect', =>
            @emit 'connect'
      else
        host = options.host || '127.0.0.1'
        port = options.port || '6379'
        db = options.db || '0'

        @client = redis.createClient(port, host, options.redis)

        @client.on 'error', =>
          @emit 'disconnect'

        @client.select db, =>
          @emit 'connect'

    get: (sid, f) ->
      now = ((+new Date) / 1000) | 0
      multi = @client.multi()
      multi.zscore @expName, sid
      multi.hget @name, sid
      multi.exec (err, resps) =>
        unless err?
          [score, value] = resps
          if (+score isnt 0) and (+score >= now)
            try
              f null, JSON.parse(value)
            catch ex

              # Error parsing JSON
              f ex, null
          else

            # Expired
            f null, null
        else
          f err, null

    set: (sid, session, f) ->
      now = (+new Date / 1000) | 0
      distantFuture = 4294967295
      expiresAt = distantFuture
      if typeof @maxTtl is 'number'
        expiresAt = now + (+@maxTtl | 0)
      if typeof session.cookie.maxAge is 'number'
        expiresAt = Math.min expiresAt, now + ((session.cookie.maxAge / 1000) | 0)
      try
        multi = @client.multi()
        multi.zadd @expName, expiresAt, sid
        multi.hset @name, sid, JSON.stringify(session)
        multi.exec (err, resp) =>
          f err, resp if f?
      catch ex
        f ex, null if f?

    # Remove sessions 
    expire: (now = null, f) ->
      if now is null
        now = (+new Date / 1000) | 0
      @client.zrangebyscore @expName, 0, now, (err, resp) =>
        unless err?
          if resp.length > 0
            multi = @client.multi()
            multi.zrem @expName, resp
            multi.hdel @name, resp
            multi.exec f
          else

            # Nothing to expire.
            f null, null
        else
          f err, null

    destroy: (sid, f) ->
      multi = @client.multi()
      multi.zrem @expName, sid
      multi.hdel @name, sid
      multi.exec f

    # length: (f) ->
    #   @client.hlen @name, f

    # clear: (f) ->

  Store