/*
 * decaffeinate suggestions:
 * DS102: Remove unnecessary code created because of implicit returns
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
const _ = require('underscore');
const Promise = require('bluebird');
const Excel = require('exceljs');
const Reader = require('../lib/io/reader');

const tmp = require('tmp');
const fs = Promise.promisifyAll(require('fs'));

tmp.setGracefulCleanup();


const writeXlsx = function(filePath, data) {
  const workbook = new Excel.Workbook();
  workbook.created = new Date();
  const worksheet = workbook.addWorksheet('Products');
  console.log("Generating Xlsx file");

  data.forEach(function(items, index) {
    if (index) {
      return worksheet.addRow(items);
    } else {
      const headers = [];
      for (let i in items) {
        headers.push({
          header: items[i]
        });
      }
      return worksheet.columns = headers;
    }
  });

  return workbook.xlsx.writeFile(filePath);
};

describe('IO Reader test', function() {
  it('should trim csv header file', function(done) {
    const sampleCsv =
      `\
myHeader ,name
row1,name1\
`;
    return Reader.parseCsv(sampleCsv).then(data => {
      expect(data).toEqual([ [ 'myHeader ,name' ], [ 'row1,name1' ] ]);
      return done();
    });
  });

  it('should stringify richText', function(done) {
    const expected = 'Stringified rich text';
    const richText = [
      {
        font: { size: 10, name: 'Arial', family: 2, charset: 1 },
        text: 'Stringified '
      },
      {
        font: { size: 14, name: 'Arial', family: 2, charset: 1 },
        text: 'rich text'
      }
    ];

    const reader = new Reader();
    const actual = reader._stringifyRichText(richText);
    expect(actual).toBe(expected);
    return done();
  });

  return it('should read xlsx file', function(done) {
    const filePath = "/tmp/test.xlsx";
    const expected = ['TEXT', '1', '2', '', '', 'false', 'true'];
    const data = [
      ["a","b","c","d","e","f","g"],
      ["TEXT",1,"2",null,undefined,false,true]
    ];

    return writeXlsx(filePath, data)
    .then(() => {
      const reader = new Reader({
        importFormat: "xlsx",
        debug: true
      });
      return reader.read(filePath);
  }).then(result => {
      expect(result.length).toBe(2);
      expect(result[1]).toEqual(expected);
      return done();
    }).catch(err => done(_.prettify(err)));
  });
});
