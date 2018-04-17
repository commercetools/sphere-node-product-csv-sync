/*
 * decaffeinate suggestions:
 * DS102: Remove unnecessary code created because of implicit returns
 * DS207: Consider shorter variations of null checks
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
const _ = require('underscore');
_.mixin(require('underscore-mixins'));
const {Import, Export} = require('../../lib/main');
const Config = require('../../config');
const TestHelpers = require('./testhelpers');
const Promise = require('bluebird');
const fs = Promise.promisifyAll(require('fs'));

const defaultProduct = (productTypeId, categoryId) => {
  return {
    name: {
      en: 'test product'
    },
    productType: {
      typeId: 'product-type',
      id: productTypeId
    },
    slug: {
      en: TestHelpers.uniqueId('slug-')
    },
    categories: [{
      typeId: 'category',
      id: categoryId
    }
    ],
    masterVariant: {}
  };
};

const createImporter = function() {
  const im = new Import(Config);
  im.allowRemovalOfVariants = true;
  im.suppressMissingHeaderWarning = true;
  return im;
};

const CHANNEL_KEY = 'retailerA';

const uniqueId = prefix => _.uniqueId(`${prefix}${new Date().getTime()}_`);

const newCategory = function(name, externalId) {
  if (name == null) { name = 'Category name'; }
  if (externalId == null) { externalId = 'externalCategoryId'; }
  return {
    name: {
      en: name
    },
    slug: {
      en: uniqueId('c')
    },
    externalId
  };
};

const prepareCategoryAndProduct = function(done) {
  jasmine.getEnv().defaultTimeoutInterval = 90000; // 90 sec
  this.export = new Export({client: Config});
  this.importer = createImporter();
  this.importer.suppressMissingHeaderWarning = true;
  this.client = this.importer.client;

  console.log('create a category to work with');
  return this.client.categories.save(newCategory())
  .then(results => {
    this.category = results.body;
    console.log(`Created ${results.length} categories`);

    this.productType = TestHelpers.mockProductType();
    return TestHelpers.setupProductType(this.client, this.productType);
}).then(result => {
    this.productType = result;
    return this.client.channels.ensure(CHANNEL_KEY, 'InventorySupply');
  }).then(() => done())
  .catch(error => done(_.prettify(error)));
};

describe('categoryOrderHints', function() {

  describe('Import', function() {

    beforeEach(prepareCategoryAndProduct);

    afterEach(function(done) {
      console.log('About to delete all categories');
      return this.client.categories.process(payload => {
        console.log(`Deleting ${payload.body.count} categories`);
        return Promise.map(payload.body.results, category => {
          return this.client.categories.byId(category.id).delete(category.version);
        });
    }).then(results => {
        console.log(`Deleted ${results.length} categories`);
        console.log("Delete all the created products");
        return this.client.products.process(payload => {
          console.log(`Deleting ${payload.body.count} products`);
          return Promise.map(payload.body.results, product => {
            return this.client.products.byId(product.id).delete(product.version);
          });
        });
      }).then(function(results) {
        console.log(`Deleted ${results.length} products`);
        return done();}).catch(error => done(_.prettify(error)));
    }
    , 60000); // 1min

    it('should add categoryOrderHints', function(done) {

      return this.client.products.save(defaultProduct(this.productType.id, this.category.id))
      .then(result => {
        this.product = result.body;
        const csv =
          `\
productType,id,version,slug,categoryOrderHints
${this.productType.id},${this.product.id},${this.product.version},${this.product.slug},${this.category.id}:0.5\
`;
        const im = createImporter({
          continueOnProblems: true
        });
        return im.import(csv);
    }).then(result => {
        expect(result[0]).toBe('[row 2] Product updated.');
        return this.client.products.byId(this.product.id).fetch();
      }).then(result => {
        expect(result.body.masterData.staged.categoryOrderHints).toEqual({[this.category.id]: '0.5'});
        return done();
      }).catch(err => done(_.prettify(err)));
    });

    it('should add categoryOrderHints when using an external category id', function(done) {

      return this.client.products.save(defaultProduct(this.productType.id, this.category.id))
      .then(result => {
        this.product = result.body;
        const csv =
          `\
productType,id,version,slug,categoryOrderHints
${this.productType.id},${this.product.id},${this.product.version},${this.product.slug},externalCategoryId:0.5\
`;
        const im = createImporter({
          continueOnProblems: true
        });
        return im.import(csv);
    }).then(result => {
        expect(result[0]).toBe('[row 2] Product updated.');
        return this.client.products.byId(this.product.id).fetch();
      }).then(result => {
        expect(result.body.masterData.staged.categoryOrderHints).toEqual({[this.category.id]: '0.5'});
        return done();
      }).catch(err => done(_.prettify(err)));
    });

    it('should add categoryOrderHints when using an category name', function(done) {

      return this.client.products.save(defaultProduct(this.productType.id, this.category.id))
      .then(result => {
        this.product = result.body;
        const csv =
          `\
productType,id,version,slug,categoryOrderHints
${this.productType.id},${this.product.id},${this.product.version},${this.product.slug},${this.category.name.en}:0.5\
`;
        const im = createImporter({
          continueOnProblems: true
        });
        return im.import(csv);
    }).then(result => {
        expect(result[0]).toBe('[row 2] Product updated.');
        return this.client.products.byId(this.product.id).fetch();
      }).then(result => {
        expect(result.body.masterData.staged.categoryOrderHints).toEqual({[this.category.id]: '0.5'});
        return done();
      }).catch(err => done(_.prettify(err)));
    });

    it('should add categoryOrderHints when using an category slug', function(done) {

      return this.client.products.save(defaultProduct(this.productType.id, this.category.id))
      .then(result => {
        this.product = result.body;
        const csv =
          `\
productType,id,version,slug,categoryOrderHints
${this.productType.id},${this.product.id},${this.product.version},${this.product.slug},${this.category.slug.en}:0.5\
`;
        const im = createImporter({
          continueOnProblems: true
        });
        return im.import(csv);
    }).then(result => {
        expect(result[0]).toBe('[row 2] Product updated.');
        return this.client.products.byId(this.product.id).fetch();
      }).then(result => {
        expect(result.body.masterData.staged.categoryOrderHints).toEqual({[this.category.id]: '0.5'});
        return done();
      }).catch(err => done(_.prettify(err)));
    });

    it('should remove categoryOrderHints', function(done) {

      return this.client.products.save(
        _.extend({}, defaultProduct(this.productType.id, this.category.id), {
          categoryOrderHints: {
            [this.category.id]: '0.5'
          }
        })
      )
      .then(result => {
        this.product = result.body;
        const csv =
          `\
productType,id,version,slug,categoryOrderHints
${this.productType.id},${this.product.id},${this.product.version},${this.product.slug},\
`;
        const im = createImporter({
          continueOnProblems: true
        });
        return im.import(csv);
    }).then(result => {
        expect(result[0]).toBe('[row 2] Product updated.');
        return this.client.products.byId(this.product.id).fetch();
      }).then(result => {
        expect(result.body.masterData.staged.categoryOrderHints).toEqual({});
        return done();
      }).catch(err => done(_.prettify(err)));
    });

    it('should change categoryOrderHints', function(done) {

      return this.client.products.save(
        _.extend({}, defaultProduct(this.productType.id, this.category.id), {
          categoryOrderHints: {
            [this.category.id]: '0.5'
          }
        })
      )
      .then(result => {
        this.product = result.body;
        const csv =
          `\
productType,id,version,slug,categoryOrderHints
${this.productType.id},${this.product.id},${this.product.version},${this.product.slug},${this.category.externalId}: 0.9\
`;
        const im = createImporter({
          continueOnProblems: true
        });
        return im.import(csv);
    }).then(result => {
        expect(result[0]).toBe('[row 2] Product updated.');
        return this.client.products.byId(this.product.id).fetch();
      }).then(result => {
        expect(result.body.masterData.staged.categoryOrderHints).toEqual({[this.category.id]: '0.9'});
        return done();
      }).catch(err => done(_.prettify(err)));
    });

    it('should add another categoryOrderHint', function(done) {

      return this.client.categories.save(newCategory('Second category', 'externalId2'))
      .then(result => {
        this.newCategory = result.body;
        const productDraft = _.extend({}, defaultProduct(this.productType.id, this.category.id), {
          categoryOrderHints: {
            [this.category.id]: '0.5'
          }
        }
        );

        productDraft.categories.push({
          typeId: 'category',
          id: this.newCategory.id
        });

        return this.client.products.save(productDraft);
    }).then(result => {
        this.product = result.body;
        const csv =
          `\
productType,id,version,categoryOrderHints
${this.productType.id},${this.product.id},${this.product.version},${this.newCategory.externalId}: 0.8\
`;

        const im = createImporter({
          continueOnProblems: true
        });
        im.mergeCategoryOrderHints = true;
        return im.import(csv);
      }).then(result => {
        expect(result[0]).toBe('[row 2] Product updated.');
        return this.client.products.byId(this.product.id).fetch();
      }).then(result => {
        const product = result.body.masterData.staged;
        expect(product.categoryOrderHints).toEqual({
          [this.category.id]: '0.5',
          [this.newCategory.id]: '0.8'
        });
        return done();
      }).catch(err => done(_.prettify(err)));
    });

    return it('should add another categoryOrderHint when matching by SKU', function(done) {

      return this.client.categories.save(newCategory('Second category', 'externalId2'))
      .then(result => {
        this.newCategory = result.body;
        const productDraft = _.extend({}, defaultProduct(this.productType.id, this.category.id), {
          categoryOrderHints: {
            [this.category.id]: '0.5'
          }
        }
        );

        productDraft.masterVariant.sku = '123';
        productDraft.categories.push({
          typeId: 'category',
          id: this.newCategory.id
        });

        return this.client.products.save(productDraft);
    }).then(result => {
        this.product = result.body;
        const csv =
          `\
productType,sku,categoryOrderHints
${this.productType.id},${this.product.masterData.staged.masterVariant.sku},${this.newCategory.externalId}: 0.8\
`;
        const im = createImporter({
          continueOnProblems: true
        });
        im.mergeCategoryOrderHints = true;
        return im.import(csv);
      }).then(result => {
        expect(result[0]).toBe('[row 2] Product updated.');
        return this.client.products.byId(this.product.id).fetch();
      }).then(result => {
        const product = result.body.masterData.staged;
        expect(product.categoryOrderHints).toEqual({
          [this.category.id]: '0.5',
          [this.newCategory.id]: '0.8'
        });
        return done();
      }).catch(err => done(_.prettify(err)));
    });
  });

  return describe('Export', function() {

    beforeEach(prepareCategoryAndProduct);

    it('should export categoryOrderHints', function(done) {

      return this.client.products.save(
        _.extend({}, defaultProduct(this.productType.id, this.category.id), {
          categoryOrderHints: {
            [this.category.id]: '0.5'
          }
        })
      )
      .then(result => {
        this.product = result.body;
        return this.client.products.byId(this.product.id).fetch();
    }).then(() => {
        const template =
          `\
productType,id,variantId,categoryOrderHints\
`;
        const file = '/tmp/output.csv';
        const expectedCSV =
          `\
productType,id,variantId,categoryOrderHints
${this.productType.name},${this.product.id},${this.product.lastVariantId},${this.category.id}:0.5
\
`;
        return this.export.exportDefault(template, file)
        .then(function(result) {
          expect(result).toBe('Export done.');
          return fs.readFileAsync(file, {encoding: 'utf8'});})
        .then(function(content) {
          expect(content).toBe(expectedCSV);
          return done();}).catch(err => done(_.prettify(err)));
      });
    });

    return it('should export categoryOrderHints with category externalId', function(done) {
      const customExport = new Export({
        client: Config,
        categoryOrderHintBy: 'externalId'
      });

      return this.client.products.save(
        _.extend({}, defaultProduct(this.productType.id, this.category.id), {
          categoryOrderHints: {
            [this.category.id]: '0.5'
          }
        })
      )
      .then(result => {
        this.product = result.body;
        return this.client.products.byId(this.product.id).fetch();
    }).then(() => {
        const template =
          `\
productType,id,variantId,categoryOrderHints\
`;
        const file = '/tmp/output.csv';
        const expectedCSV =
          `\
productType,id,variantId,categoryOrderHints
${this.productType.name},${this.product.id},${this.product.lastVariantId},${this.category.externalId}:0.5
\
`;

        return customExport.exportDefault(template, file)
        .then(function(result) {
          expect(result).toBe('Export done.');
          return fs.readFileAsync(file, {encoding: 'utf8'});})
        .then(function(content) {
          expect(content).toBe(expectedCSV);
          return done();
        });
      }).catch(err => done(_.prettify(err)));
    });
  });
});
