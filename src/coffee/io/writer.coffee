_ = require 'underscore'
Csv = require 'csv'
path = require 'path'
Promise = require 'bluebird'
iconv = require 'iconv-lite'
fs = Promise.promisifyAll require('fs')
Excel = require 'exceljs'

class Writer

  constructor: (@options = {}) ->
    @options.defaultEncoding = "utf8"
    @options.availableFormats = ["xlsx", "csv"]

    if @options.availableFormats.indexOf(@options.exportFormat) < 0
      throw new Error("Unsupported file type: #{@options.exportFormat}, alowed formats are #{@options.availableFormats.toString()}")

    # write to file or to stdout?
    if @options.outputFile
      @outputStream = fs.createWriteStream @options.outputFile
    else
      @outputStream = process.stdout


    # if we use xlsx export - create workbook first
    if @options.exportFormat == 'xlsx'
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

    if @options.exportFormat == 'xlsx'
      @_writeXlsxHeader header
    else
      @_writeCsvRows [header]

  write: (rows) ->

    if @options.exportFormat == 'xlsx'
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
    if @options.exportFormat == 'xlsx'
      @workbook.commit()
    else
      Promise.resolve()

module.exports = Writer
