assert = require 'assert'
express = require 'express'
Store = require('../src')(express)

store = new Store
store.expire()

describe 'Store', ->

  it 'should set/get/del foo', (done) ->
    store.set 'session:1', { foo: 1, cookie: { maxAge: null } }, (err, resp) ->
      assert.equal null, err
      store.get 'session:1', (err, resp) ->
        assert.equal 1, resp.foo
        done()

  it 'should expire session', (done) ->
    @timeout 1000 * 5
    store.set 'session:2', { foo: 2, cookie: { maxAge: 1000 * 1 } }, (err, resp) ->
      assert.equal null, err
      setTimeout ->
        store.get 'session:2', (err, resp) ->
          assert.equal 2, resp.foo
          setTimeout ->
            store.get 'session:2', (err, resp) ->
              assert.equal null, resp
              done()
          ,
            1000 * 1
      ,
        1000 * 0.5
