/*
 * decaffeinate suggestions:
 * DS102: Remove unnecessary code created because of implicit returns
 * DS206: Consider reworking classes to avoid initClass
 * DS207: Consider shorter variations of null checks
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
const _ = require('underscore')
const Csv = require('csv')
const path = require('path')
const Promise = require('bluebird')
const iconv = require('iconv-lite')
const fs = Promise.promisifyAll(require('fs'))
const Excel = require('exceljs')

class Reader {
  static initClass () {
    this.decode = (buffer, encoding) => {
      if (encoding === 'utf-8')
        return buffer.toString()


      if (!iconv.encodingExists(encoding))
        throw new Error(`Encoding does not exist: ${encoding}`)


      return iconv.decode(buffer, encoding)
    }
  }

  constructor (options) {
    this.read = this.read.bind(this)
    this._readCsv = this._readCsv.bind(this)
    this._readXlsx = this._readXlsx.bind(this)
    this.getHeader = this.getHeader.bind(this)
    if (options == null) options = {}
    this.options = options
    const logLevel = this.options.debug ? 'debug' : 'info'
    this.Logger = require('../logger')('IO::Reader', logLevel)
    this.Logger.debug('options:', JSON.stringify(this.options))
    this.options.encoding = this.options.encoding || 'utf-8'
    this.header = null
    this.rows = []
  }

  read (file) {
    // read from file or from stdin?
    if (file) {
      this.Logger.debug('stream file %s', file)
      this.inputStream = fs.createReadStream(file)
    } else {
      this.Logger.debug('stream stdin')
      this.inputStream = process.stdin
    }

    if (this.options.importFormat === 'xlsx')
      return this._readXlsx(this.inputStream)
    return this._readCsv(this.inputStream)
  }

  static parseCsv (csv, delimiter, encoding) {
    const rows = []
    const options = {
      delimiter,
      skip_empty_lines: true,
      trim: true, // trim csv cells
    }

    // only buffer can be decoded from another encoding
    if (csv instanceof Buffer)
      csv = this.decode(csv, encoding)


    return new Promise(((resolve, reject) => Csv()
      .from.string(csv, options)
      .on('record', row => rows.push(row)).on('error', err => reject(err)).on('end', () => resolve(rows))))
  }

  _readCsv (stream) {
    return new Promise((resolve, reject) => {
      const buffers = []

      // stream whole file to buffer because we need to decode it first from buffer
      // - iconv-lite does not support string to string decoding
      stream.on('data', buffer => buffers.push(buffer))
      stream.on('error', err => reject(err))
      return stream.on('end', () => {
        this.Logger.debug('file was readed')
        const buffer = Buffer.concat(buffers)
        return Reader.parseCsv(buffer, this.options.csvDelimiter, this.options.encoding)
          .then(parsed => resolve(parsed))
          .catch(err => reject(err))
      })
    })
  }

  _readXlsx (stream) {
    const workbook = new Excel.Workbook()
    return workbook.xlsx.read(stream)
      .then((workbook) => {
        this.Logger.debug('file was readed')

        const rows = []
        const worksheet = workbook.getWorksheet(1)
        worksheet.eachRow((row) => {
          const rowValues = row.values
          rowValues.shift()

          return rows.push(_.map(rowValues, (item) => {
            if ((item == null))
              item = ''


            if (_.isObject(item) && item.richText)
              return this._stringifyRichText(item.richText)
            return String(item)
          }))
        })
        return rows
      })
  }

  getHeader (header) {
    this.Logger.debug('get header')
    return this.header
  }

  // method will remove styling from richText and return a plain text
  _stringifyRichText (richText) {
    return richText.reduce(
      (text, chunk) => text + chunk.text
      , '',
    )
  }
}
Reader.initClass()

module.exports = Reader
