_ = require 'underscore'
Csv = require 'csv'
path = require 'path'
Promise = require 'bluebird'
iconv = require 'iconv-lite'
fs = Promise.promisifyAll require('fs')
Excel = require 'exceljs'

DEBUG = true
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
      };

      @workbook = new Excel.stream.xlsx.WorkbookWriter @options.workbookOpts
      @worksheet = @workbook.addWorksheet('Products', {views:[{ySplit:1}]});

  # encode all strings in subarrays
  encode: (data) =>
    if @options.encoding == @options.defaultEncoding
      return Promise.resolve(data)

    if not iconv.encodingExists(@options.encoding)
      return Promise.reject 'Encoding does not exist: '+ @options.encoding

    new Promise (resolve) =>
      # iterate throught rows and cells
      data = data.map (row) =>
        row.map (item) =>
          if _.isString(item)
            iconv.encode(item, @options.encoding)
          else
            item

      resolve(data)

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

  _writeXlsxRows: (rows) =>
    Promise.map rows, (row) =>
      @worksheet.addRow(row).commit()

  _writeXlsxHeader: (header) =>
    header = header.map((name) => {header: name})
    @worksheet.columns = header
    Promise.resolve()

  _writeCsvRows: (data) =>
    @encode data
    .then (data) =>
      new Promise (resolve, reject) =>
        data.push([])
        parsedCsv = Csv().from(data, {delimiter: @options.csvDelimiter})

        # can't use .pipe - it would close stream right after first batch
        parsedCsv.to.string (string) =>
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
