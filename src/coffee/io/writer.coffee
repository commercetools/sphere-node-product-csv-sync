_ = require 'underscore'
Csv = require 'csv'
path = require 'path'
Promise = require 'bluebird'
iconv = require 'iconv-lite'
fs = Promise.promisifyAll require('fs')
Excel = require 'exceljs'

DEBUG = false
debugLog = if DEBUG then console.log else _.noop

class Writer

  constructor: (@options = {}) ->
    debugLog "WRITER::options:", JSON.stringify(@options)
    @options.defaultEncoding = "utf8"

    # write to file or to stdout?
    if @options.outputFile
      debugLog "WRITER::stream file %s", @options.outputFile
      @outputStream = fs.createWriteStream @options.outputFile
    else
      debugLog "WRITER::stream stdout"
      @outputStream = process.stdout

    # if we use xlsx export - create workbook first
    if @options.format == 'xlsx'
      @options.workbookOpts = {
        stream: @outputStream,
        useStyles: true,
        useSharedStrings: true
      }

      @workbook = new Excel.stream.xlsx.WorkbookWriter @options.workbookOpts
      @worksheet = @workbook.addWorksheet('Products')

  encode: (string) =>
    if @options.encoding == @options.defaultEncoding
      return string

    if not iconv.encodingExists @options.encoding
      throw new Error 'Encoding does not exist: '+ @options.encoding

    iconv.encode string, @options.encoding

  # create header
  setHeader: (header) =>
    debugLog("WRITER::writing header %s", header)

    if @options.format == 'xlsx'
      @_writeXlsxHeader header
    else
      @_writeCsvRows [header]

  write: (rows) ->
    debugLog("WRITER::writing rows len: %d", rows.length)

    if @options.format == 'xlsx'
      @_writeXlsxRows rows
    else
      @_writeCsvRows rows

  # go through all cells and
  # - replace undefined and empty strings with null value (alias an empty xlsx cell)
  _fixXlsxRow: (row) =>
    # replace selected values with null
    _.map row, (item) ->
      if typeof item == "undefined" || item == '' then null else item

  _writeXlsxRows: (rows) =>
    Promise.map rows, (row) =>
      @worksheet.addRow(@_fixXlsxRow(row)).commit()
    , { concurrency: 1}

  _writeXlsxHeader: (header) =>
    header = header.map((name) => {header: name})
    @worksheet.columns = header
    Promise.resolve()

  _writeCsvRows: (data) =>
    new Promise (resolve, reject) =>
      data.push([])
      parsedCsv = Csv().from(data, {delimiter: @options.csvDelimiter})

      # can't use .pipe - it would close stream right after first batch
      parsedCsv.to.string (string) =>
        try
          string = @encode(string)
        catch e
          return reject e

        @outputStream.write(string)
        resolve()

      parsedCsv
      .on 'error', (err) -> reject err

  flush: () =>
    debugLog("WRITER::flushing content")
    if @options.format == 'xlsx'
      @workbook.commit()
    else
      Promise.resolve()

module.exports = Writer
