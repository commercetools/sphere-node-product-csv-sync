/*
 * decaffeinate suggestions:
 * DS102: Remove unnecessary code created because of implicit returns
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
const _ = require('underscore');
const Types = require('../lib/types');

describe('Types', function() {
  beforeEach(function() {
    return this.types = new Types();
  });

  describe('#constructor', () =>
    it('should construct', function() {
      return expect(this.types).toBeDefined();
    })
  );

  return describe('#buildMaps', () =>
    it('should create maps for product types', function() {
      const pt1 = {
        id: 'pt1',
        name: 'myType'
      };
      const pt2 = {
        id: 'pt2',
        name: 'myType2',
        attributes: [
          { name: 'foo', attributeConstraint: 'SameForAll' }
        ]
      };
      const pt3 = {
        id: 'pt3',
        name: 'myType'
      };
      this.types.buildMaps([pt1, pt2, pt3]);
      expect(_.size(this.types.id2index)).toBe(3);
      expect(this.types.id2index['pt1']).toBe(0);
      expect(this.types.id2index['pt2']).toBe(1);
      expect(this.types.id2index['pt3']).toBe(2);
      expect(this.types.name2id['myType']).toBe('pt3');
      expect(this.types.name2id['myType2']).toBe('pt2');
      expect(_.size(this.types.duplicateNames)).toBe(1);
      expect(this.types.duplicateNames[0]).toBe('myType');
      expect(_.size(this.types.id2SameForAllAttributes)).toBe(3);
      expect(this.types.id2SameForAllAttributes['pt1']).toEqual([]);
      expect(this.types.id2SameForAllAttributes['pt2']).toEqual([ 'foo' ]);
      expect(this.types.id2SameForAllAttributes['pt3']).toEqual([]);
      expect(_.size(this.types.id2nameAttributeDefMap)).toBe(3);
      const expectedObj =
        {foo: pt2.attributes[0]};
      return expect(this.types.id2nameAttributeDefMap['pt2']).toEqual(expectedObj);
    })
  );
});
