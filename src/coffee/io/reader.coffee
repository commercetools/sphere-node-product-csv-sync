_ = require 'underscore'
Csv = require 'csv'
path = require 'path'
Promise = require 'bluebird'
iconv = require 'iconv-lite'
fs = Promise.promisifyAll require('fs')
Excel = require 'exceljs'

DEBUG = true
debugLog = if DEBUG then console.log else _.noop

class Reader

  constructor: (@options = {}) ->
    debugLog "READER::options:", JSON.stringify(@options)
    @options.encoding = @options.encoding || 'utf-8'
    @header = null
    @rows = []

  read: (file) =>
    # read from file or from stdin?
    if file
      debugLog "READER::stream file %s", file
      @inputStream = fs.createReadStream file
    else
      debugLog "READER::stream stdin"
      @inputStream = process.stdin

    if @options.format == 'xlsx'
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
        buffer = Buffer.concat(buffers)
        Reader.parseCsv(buffer, @options.csvDelimiter, @options.encoding)
        .then (parsed) -> resolve(parsed)
        .catch (err) -> reject(err)

  _readXlsx: (stream) =>
    console.log "NOT IMPLEMENTED"
    @options.workbookOpts =
      stream: @inputStream,
      useStyles: true,
      useSharedStrings: true

    @workbook = new Excel.stream.xlsx.WorkbookReader @options.workbookOpts
    @workbook.on 'end', () -> console.log('reached end of stream')
    @workbook.on 'finished', console.log
    @workbook.on 'worksheet', (worksheet) ->
      console.log(worksheet)

  @decode: (buffer, encoding) =>
    debugLog "READER:decode from %s",encoding
    if encoding == 'utf-8'
      return buffer.toString()

    if not iconv.encodingExists encoding
      throw new Error 'Encoding does not exist: '+ encoding

    iconv.decode buffer, encoding

  getHeader: (header) =>
    debugLog("READER::get header")
    @header

module.exports = Reader