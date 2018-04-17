/*
 * decaffeinate suggestions:
 * DS102: Remove unnecessary code created because of implicit returns
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
const _ = require('underscore');
const Categories = require('../lib/categories');

describe('Categories', function() {
  beforeEach(function() {
    return this.categories = new Categories();
  });

  describe('#constructor', () =>
    it('should construct', function() {
      return expect(this.categories).toBeDefined();
    })
  );

  return describe('#buildMaps', function() {
    it('should create maps for root categories', function() {
      const categories = [
        { id: 1, name: { en: 'cat1' }, slug: { en: 'cat-1'} },
        { id: 2, name: { en: 'cat2' }, slug: { en: 'cat-2'} }
      ];
      this.categories.buildMaps(categories);
      expect(_.size(this.categories.id2index)).toBe(2);
      expect(_.size(this.categories.name2id)).toBe(2);
      expect(_.size(this.categories.fqName2id)).toBe(2);
      return expect(_.size(this.categories.duplicateNames)).toBe(0);
    });

    it('should create maps for children categories', function() {
      const categories = [
        { id: 'idx', name: { en: 'root' }, slug: { en: 'root'} },
        { id: 'idy', name: { en: 'main' }, ancestors: [ { id: 'idx' } ], slug: { en: 'main'} },
        { id: 'idz', name: { en: 'sub' }, ancestors: [ { id: 'idx' }, { id: 'idy' } ], slug: { en: 'sub'} }
      ];
      this.categories.buildMaps(categories);
      expect(_.size(this.categories.id2index)).toBe(3);
      expect(_.size(this.categories.name2id)).toBe(3);
      expect(_.size(this.categories.fqName2id)).toBe(3);
      expect(this.categories.fqName2id['root']).toBe('idx');
      expect(this.categories.fqName2id['root>main']).toBe('idy');
      expect(this.categories.fqName2id['root>main>sub']).toBe('idz');
      return expect(_.size(this.categories.duplicateNames)).toBe(0);
    });

    return it('should create maps for categories with externalId', function() {
      const categories = [
        { id: 'idx', name: { en: 'root' }, externalId: '123', slug: { en: 'root'} },
        { id: 'idy', name: { en: 'main' }, externalId: '234', slug: { en: 'main'} },
        { id: 'idz', name: { en: 'sub' }, externalId: '345', slug: { en: 'sub'} }
      ];
      this.categories.buildMaps(categories);
      expect(_.size(this.categories.id2index)).toBe(3);
      expect(_.size(this.categories.name2id)).toBe(3);
      expect(_.size(this.categories.fqName2id)).toBe(3);
      expect(_.size(this.categories.externalId2id)).toBe(3);
      expect(this.categories.externalId2id['123']).toBe('idx');
      expect(this.categories.externalId2id['234']).toBe('idy');
      expect(this.categories.externalId2id['345']).toBe('idz');
      return expect(_.size(this.categories.duplicateNames)).toBe(0);
    });
  });
});
