_ = require 'underscore'
Csv = require 'csv'
path = require 'path'
Promise = require 'bluebird'
iconv = require 'iconv-lite'
fs = Promise.promisifyAll require('fs')
Excel = require 'exceljs'

class Reader

  constructor: (@options = {}) ->
    logLevel = if @options.debug then 'debug' else 'info'
    @Logger = require('../logger')('IO::Reader', logLevel)

    @Logger.debug "options:", JSON.stringify(@options)
    @options.encoding = @options.encoding || 'utf-8'
    @header = null
    @rows = []

  read: (file) =>
    # read from file or from stdin?
    if file
      @Logger.debug "stream file %s", file
      @inputStream = fs.createReadStream file
    else
      @Logger.debug "stream stdin"
      @inputStream = process.stdin

    if @options.importFormat == 'xlsx'
      @_readXlsx(@inputStream)
    else
      @_readCsv(@inputStream)

  @parseCsv: (csv, delimiter, encoding) ->
    rows = []
    options =
      delimiter: delimiter
      skip_empty_lines: true

    # only buffer can be decoded from another encoding
    if csv instanceof Buffer
      csv = @decode(csv, encoding)

    new Promise (resolve, reject) ->
      Csv()
      .from.string(csv, options)
      .on 'record', (row) ->
        rows.push(row)
      .on 'error', (err) ->
        reject(err)
      .on 'end', () ->
        resolve(rows)

  _readCsv: (stream) =>
    new Promise (resolve, reject) =>
      buffers = []

      # stream whole file to buffer because we need to decode it first from buffer
      # - iconv-lite does not support string to string decoding
      stream.on 'data', (buffer) ->
        buffers.push buffer
      stream.on 'error', (err) -> reject(err)
      stream.on 'end', () =>
        @Logger.debug "file was readed"
        buffer = Buffer.concat(buffers)
        Reader.parseCsv(buffer, @options.csvDelimiter, @options.encoding)
        .then (parsed) -> resolve(parsed)
        .catch (err) -> reject(err)

  _readXlsx: (stream) =>
    workbook = new Excel.Workbook()
    workbook.xlsx.read(stream)
    .then (workbook) ->
      @Logger.debug "file was readed"

      rows = []
      worksheet = workbook.getWorksheet(1)
      worksheet.eachRow (row) =>
        rowValues = row.values
        rowValues.shift()

        rows.push _.map rowValues, (item) ->
          if not item?
            item = ""
          String(item)
      rows

  @decode: (buffer, encoding) =>
    if encoding == 'utf-8'
      return buffer.toString()

    if not iconv.encodingExists encoding
      throw new Error 'Encoding does not exist: '+ encoding

    iconv.decode buffer, encoding

  getHeader: (header) =>
    @Logger.debug "get header"
    @header

module.exports = Reader
