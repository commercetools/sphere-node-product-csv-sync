/*
 * decaffeinate suggestions:
 * DS102: Remove unnecessary code created because of implicit returns
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
const _ = require('underscore');
const CONS = require('../lib/constants');
const {Import} = require('../lib/main');

describe('Import', function() {
  beforeEach(function() {
    return this.importer = new Import();
  });

  describe('#constructor', function() {
    it('should initialize without options', function() {
      expect(this.importer).toBeDefined();
      expect(this.importer.sync).not.toBeDefined();
      return expect(this.importer.client).not.toBeDefined();
    });

    return it('should initialize with options', function() {
      const importer = new Import({
        config: {
          project_key: 'foo',
          client_id: 'id',
          client_secret: 'secret'
        }
      });
        // logConfig:
        //   streams: [
        //     {level: 'warn', stream: process.stdout}
        //   ]
      expect(importer).toBeDefined();
      expect(importer.client).toBeDefined();
      expect(importer.client._task._maxParallel).toBe(10);
      return expect(importer.sync).toBeDefined();
    });
  });

  xdescribe('match on custom attribute', () =>
    it('should find match based on custom attribute', function() {
      const product = {
        id: '123',
        masterVariant: {
          attributes: [
            { name: 'foo', value: 'bar' }
          ]
        }
      };
      this.importer.customAttributeNameToMatch = 'foo';

      const val = this.importer.getCustomAttributeValue(product.masterVariant);
      expect(val).toEqual('bar');

      this.importer.initMatcher([product]);
      expect(this.importer.id2index).toEqual({ 123: 0 });
      expect(this.importer.sku2index).toEqual({});
      expect(this.importer.slug2index).toEqual({});
      expect(this.importer.customAttributeValue2index).toEqual({ 'bar': 0 });

      const index = this.importer._matchOnCustomAttribute(product);
      expect(index).toBe(0);

      const match = this.importer.match({
        product: {
          masterVariant: {
            attributes: []
          },
          variants: [
            { attributes: [{ name: 'foo', value: 'bar' }] }
          ]
        },
        header: {
          has() { return false; },
          hasLanguageForBaseAttribute() { return false; }
        }
      });

      return expect(match).toBe(product);
    })
  );

  describe('mapVariantsBasedOnSKUs', function() {
    beforeEach(function() {
      return this.header = {};});
    it('should map masterVariant', function() {
      const existingProducts = [
        { masterVariant: { id: 2, sku: "mySKU" }, variants: [] }
      ];
      //@importer.initMatcher existingProducts
      const entry = {
        product: {
          masterVariant: { sku: "mySKU", attributes: [ { foo: 'bar' } ] }
        }
      };
      const productsToUpdate = this.importer.mapVariantsBasedOnSKUs(existingProducts, [entry]);
      expect(_.size(productsToUpdate)).toBe(1);
      const { product } = productsToUpdate[0];
      expect(product.masterVariant).toBeDefined();
      expect(product.masterVariant.id).toBe(2);
      expect(product.masterVariant.sku).toBe('mySKU');
      expect(_.size(product.variants)).toBe(0);
      return expect(product.masterVariant.attributes).toEqual([{ foo: 'bar' }]);
  });

    return xit('should map several variants into one product', function() {
      const existingProducts = [
        { masterVariant: { id: 1, sku: "mySKU" }, variants: [] },
        { masterVariant: { id: 1, sku: "mySKU1" }, variants: [
          { id: 2, sku: "mySKU2", attributes: [ { foo: 'bar' } ] },
          { id: 4, sku: "mySKU4", attributes: [ { foo: 'baz' } ] }
        ] }
      ];
      //@importer.initMatcher existingProducts
      const entry = {
        product: {
          variants: [
            { sku: "mySKU4", attributes: [ { foo: 'bar4' } ] },
            { sku: "mySKU2", attributes: [ { foo: 'bar2' } ] },
            { sku: "mySKU3", attributes: [ { foo: 'bar3' } ] }
          ]
        }
      };
      const productsToUpdate = this.importer.mapVariantsBasedOnSKUs(existingProducts, [entry]);
      expect(_.size(productsToUpdate)).toBe(1);
      const { product } = productsToUpdate[0];
      expect(product.masterVariant.id).toBe(1);
      expect(product.masterVariant.sku).toBe('mySKU1');
      expect(_.size(product.variants)).toBe(2);
      expect(product.variants[0].id).toBe(2);
      expect(product.variants[0].sku).toBe('mySKU2');
      expect(product.variants[0].attributes).toEqual([ { foo: 'bar2' } ]);
      expect(product.variants[1].id).toBe(4);
      return expect(product.variants[1].attributes).toEqual([ { foo: 'bar4' } ]);
  });
});

  return describe('splitUpdateActionsArray', () =>
    it('should split an array when exceeding max amount of allowed actions', function() {
      const updateRequest = {
        actions: [
          { action: 'updateAction1', payload: 'bar1' },
          { action: 'updateAction2', payload: 'bar2' },
          { action: 'updateAction3', payload: 'bar3' },
          { action: 'updateAction4', payload: 'bar4' },
          { action: 'updateAction5', payload: 'bar5' },
          { action: 'updateAction6', payload: 'bar6' },
          { action: 'updateAction7', payload: 'bar7' },
          { action: 'updateAction8', payload: 'bar8' },
          { action: 'updateAction9', payload: 'bar9' },
          { action: 'updateAction10', payload: 'bar10' }
        ],
        version: 1
      };
      // max amount of actions = 3
      const splitArray = this.importer.splitUpdateActionsArray(updateRequest, 3);
      // array of 10 actions divided by max of 3 becomes 4 arrays
      return expect(splitArray.length).toEqual(4);
    })
  );
});