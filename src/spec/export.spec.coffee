_ = require('underscore')._
Export = require '../lib/export'
Q = require 'q'
Config = require '../config'

jasmine.getEnv().defaultTimeoutInterval = 10000

describe 'Export', ->
  beforeEach (done) ->
    @export = new Export Config
    @rest = @export.rest
    done()

  it 'should inform about a bad header in the template', (done) ->
    template =
      '''
      productType,name,name
      '''
    @export.export template, null, (res) ->
      expect(res.status).toBe false
      expect(res.message['There are duplicate header entries!']).toBe 1
      expect(res.message["Can't find necessary base header 'variantId'!"]).toBe 1
      done()

  it 'should export based on minimum template', (done) ->
    template =
      '''
      productType,name,variantId
      '''
    @export.export template, '/tmp/output.csv', (res) ->
      console.log res
      expect(res.status).toBe true
      done()
