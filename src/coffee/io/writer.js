/*
 * decaffeinate suggestions:
 * DS102: Remove unnecessary code created because of implicit returns
 * DS207: Consider shorter variations of null checks
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
const _ = require('underscore');
const Csv = require('csv');
const path = require('path');
const Promise = require('bluebird');
const iconv = require('iconv-lite');
const fs = Promise.promisifyAll(require('fs'));
const Excel = require('exceljs');

class Writer {

  constructor(options) {
    this.encode = this.encode.bind(this);
    this.setHeader = this.setHeader.bind(this);
    this._fixXlsxRow = this._fixXlsxRow.bind(this);
    this._writeXlsxRows = this._writeXlsxRows.bind(this);
    this._writeXlsxHeader = this._writeXlsxHeader.bind(this);
    this._writeCsvRows = this._writeCsvRows.bind(this);
    this.flush = this.flush.bind(this);
    if (options == null) { options = {}; }
    this.options = options;
    const logLevel = this.options.debug ? 'debug' : 'info';
    this.Logger = require('../logger')('IO::Writer', logLevel);

    this.Logger.debug("options:", JSON.stringify(this.options));
    this.options.defaultEncoding = "utf8";
    this.options.availableFormats = ["xlsx", "csv"];

    if (this.options.availableFormats.indexOf(this.options.exportFormat) < 0) {
      throw new Error(`Unsupported file type: ${this.options.exportFormat}, alowed formats are ${this.options.availableFormats.toString()}`);
    }

    // write to file or to stdout?
    if (this.options.outputFile) {
      this.Logger.debug("stream file %s", this.options.outputFile);
      this.outputStream = fs.createWriteStream(this.options.outputFile);
    } else {
      this.Logger.debug("stream stdout");
      this.outputStream = process.stdout;
    }


    // if we use xlsx export - create workbook first
    if (this.options.exportFormat === 'xlsx') {
      this.options.workbookOpts = {
        stream: this.outputStream,
        useStyles: true,
        useSharedStrings: true
      };

      this.workbook = new Excel.stream.xlsx.WorkbookWriter(this.options.workbookOpts);
      this.worksheet = this.workbook.addWorksheet('Products');
    }
  }

  encode(string) {
    if (this.options.encoding === this.options.defaultEncoding) {
      return string;
    }

    if (!iconv.encodingExists(this.options.encoding)) {
      throw new Error(`Encoding does not exist: ${this.options.encoding}`);
    }

    return iconv.encode(string, this.options.encoding);
  }

  // create header
  setHeader(header) {
    this.Logger.debug("writing header %s", header);

    if (this.options.exportFormat === 'xlsx') {
      return this._writeXlsxHeader(header);
    } else {
      return this._writeCsvRows([header]);
    }
  }

  write(rows) {
    this.Logger.debug("writing rows len: %d", rows.length);

    if (this.options.exportFormat === 'xlsx') {
      return this._writeXlsxRows(rows);
    } else {
      return this._writeCsvRows(rows);
    }
  }

  // go through all cells and
  // - replace undefined and empty strings with null value (alias an empty xlsx cell)
  _fixXlsxRow(row) {
    // replace selected values with null
    return _.map(row, function(item) {
      if ((typeof item === "undefined") || (item === '')) { return null; } else { return item; }
    });
  }

  _writeXlsxRows(rows) {
    return Promise.map(rows, row => {
      return this.worksheet.addRow(this._fixXlsxRow(row)).commit();
    }
    , { concurrency: 1});
  }

  _writeXlsxHeader(header) {
    header = header.map(name => ({header: name}));
    this.worksheet.columns = header;
    return Promise.resolve();
  }

  _writeCsvRows(data) {
    return new Promise((resolve, reject) => {
      data.push([]);
      const parsedCsv = Csv().from(data, {delimiter: this.options.csvDelimiter});

      // can't use .pipe - it would close stream right after first batch
      parsedCsv.to.string(string => {
        try {
          string = this.encode(string);
        } catch (e) {
          return reject(e);
        }

        this.outputStream.write(string);
        return resolve();
      });

      return parsedCsv
      .on('error', err => reject(err));
    });
  }

  flush() {
    this.Logger.debug("flushing content");
    if (this.options.exportFormat === 'xlsx') {
      return this.workbook.commit();
    } else {
      return Promise.resolve();
    }
  }
}

module.exports = Writer;
