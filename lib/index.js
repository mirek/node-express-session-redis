(function() {
  var redis,
    __hasProp = {}.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

  redis = require('redis');

  module.exports = function(connect) {
    var Store;
    Store = (function(_super) {
      __extends(Store, _super);

      function Store(options) {
        var db, host, port;
        if (options == null) {
          options = {};
        }
        Store.__super__.constructor.apply(this, arguments);
        this.name = options.name || 'sessions';
        this.expName = options.exName || ("" + this.name + ":exp");
        this.maxTtl = options.maxTtl;
        if (options.client != null) {
          this.client = options.client;
          if (this.client.ready) {
            this.emit('connect');
          } else {
            this.client.on('connect', (function(_this) {
              return function() {
                return _this.emit('connect');
              };
            })(this));
          }
        } else {
          host = options.host || '127.0.0.1';
          port = options.port || '6379';
          db = options.db || '0';
          this.client = redis.createClient(port, host, options.redis);
          this.client.on('error', (function(_this) {
            return function() {
              return _this.emit('disconnect');
            };
          })(this));
          this.client.select(db, (function(_this) {
            return function() {
              return _this.emit('connect');
            };
          })(this));
        }
      }

      Store.prototype.get = function(sid, f) {
        var multi, now;
        now = ((+(new Date)) / 1000) | 0;
        multi = this.client.multi();
        multi.zscore(this.expName, sid);
        multi.hget(this.name, sid);
        return multi.exec((function(_this) {
          return function(err, resps) {
            var ex, score, value;
            if (err == null) {
              score = resps[0], value = resps[1];
              if ((+score !== 0) && (+score >= now)) {
                try {
                  return f(null, JSON.parse(value));
                } catch (_error) {
                  ex = _error;
                  return f(ex, null);
                }
              } else {
                return f(null, null);
              }
            } else {
              return f(err, null);
            }
          };
        })(this));
      };

      Store.prototype.set = function(sid, session, f) {
        var distantFuture, ex, expiresAt, multi, now;
        now = (+(new Date) / 1000) | 0;
        distantFuture = 4294967295;
        expiresAt = distantFuture;
        if (typeof this.maxTtl === 'number') {
          expiresAt = now + (+this.maxTtl | 0);
        }
        if (typeof session.cookie.maxAge === 'number') {
          expiresAt = Math.min(expiresAt, now + ((session.cookie.maxAge / 1000) | 0));
        }
        try {
          multi = this.client.multi();
          multi.zadd(this.expName, expiresAt, sid);
          multi.hset(this.name, sid, JSON.stringify(session));
          return multi.exec((function(_this) {
            return function(err, resp) {
              if (f != null) {
                return f(err, resp);
              }
            };
          })(this));
        } catch (_error) {
          ex = _error;
          if (f != null) {
            return f(ex, null);
          }
        }
      };

      Store.prototype.expire = function(now, f) {
        if (now == null) {
          now = null;
        }
        if (now === null) {
          now = (+(new Date) / 1000) | 0;
        }
        return this.client.zrangebyscore(this.expName, 0, now, (function(_this) {
          return function(err, resp) {
            var multi;
            if (err == null) {
              if (resp.length > 0) {
                multi = _this.client.multi();
                multi.zrem(_this.expName, resp);
                multi.hdel(_this.name, resp);
                return multi.exec(f);
              } else {
                return f(null, null);
              }
            } else {
              return f(err, null);
            }
          };
        })(this));
      };

      Store.prototype.destroy = function(sid, f) {
        var multi;
        multi = this.client.multi();
        multi.zrem(this.expName, sid);
        multi.hdel(this.name, sid);
        return multi.exec(f);
      };

      Store.prototype.length = function(f) {
        return this.client.hlen(this.name, f);
      };

      Store.prototype.clear = function(f) {
        var multi;
        multi = this.client.multi();
        multi.del(this.name);
        multi.del(this.expName);
        return multi.exec(f);
      };

      return Store;

    })(connect.session.Store);
    return Store;
  };

}).call(this);
