_ = require 'underscore'
Promise = require 'bluebird'
Excel = require 'exceljs'
Reader = require '../lib/io/reader'

tmp = require 'tmp'
fs = Promise.promisifyAll require('fs')

tmp.setGracefulCleanup()


writeXlsx = (filePath, data) ->
  workbook = new Excel.Workbook()
  workbook.created = new Date()
  worksheet = workbook.addWorksheet('Products')
  console.log "Generating Xlsx file"

  data.forEach (items, index) ->
    if index
      worksheet.addRow items
    else
      headers = []
      for i of items
        headers.push {
          header: items[i]
        }
      worksheet.columns = headers

  workbook.xlsx.writeFile(filePath)

describe 'IO Reader test', ->

  it 'should read xlsx file', (done) ->
    filePath = "/tmp/test.xlsx"
    expected = ['TEXT', '1', '2', '', '', 'false', 'true']
    data = [
      ["a","b","c","d","e","f","g"],
      ["TEXT",1,"2",null,undefined,false,true]
    ]

    writeXlsx(filePath, data)
    .then () =>
      reader = new Reader
        importFormat: "xlsx",
      reader.read(filePath)
    .then (result) =>
      expect(result.length).toBe(2)
      expect(result[1]).toEqual(expected)
      done()
    .catch (err) -> done _.prettify(err)