/*
 * decaffeinate suggestions:
 * DS102: Remove unnecessary code created because of implicit returns
 * DS207: Consider shorter variations of null checks
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
const { Export } = require('../lib/main');
const Config = require('../config');
const _ = require('underscore');

const priceFactory = function(param) {
  if (param == null) { param = {}; }
  const { country } = param;
  return {country: country || 'US'};
};

const variantFactory = function(param) {
  if (param == null) { param = {}; }
  const { country, published } = param;
  return {
    prices: [
      priceFactory({ country })
    ],
    attributes: [
      {
        name: 'published',
        value: published || true
      }
    ]
  };
};

describe('Export', function() {

  beforeEach(function() {
    return this.exporter = new Export({ client: Config });
  });

  describe('Function to filter variants by attributes', function() {

    it('should keep all variants if no filter for price is given', function() {

      // init variant without price
      const variant = variantFactory();
      variant.prices = [];
      // filter for US prices -> no price should be left in variant
      const filteredVariants = this.exporter._filterVariantsByAttributes(
        [ variant ],
        []
      );
      const actual = filteredVariants[0];
      const expected = variant;

      return expect(actual).toEqual(expected);
    });

    it('should keep variants that meet the filter condition', function() {

      const variant = variantFactory();
      const filteredVariants = this.exporter._filterVariantsByAttributes(
        [variant],
        [{ name: 'published', value: true }]
      );

      const actual = filteredVariants[0];
      const expected = variant;

      return expect(actual).toEqual(expected);
    });

    it('should remove variants that don\'t meet the filter condition', function() {

      const variant = variantFactory();
      const filteredVariants = this.exporter._filterVariantsByAttributes(
        [variant],
        [{ name: 'published', value: false }]
      );

      const actual = filteredVariants[0];
      const expected = undefined;

      return expect(actual).toEqual(expected);
    });

    it('should filter prices if no variant filter is provided', function() {

      // init variant with DE price
      const variant = variantFactory({country: 'DE'});
      variant.prices.push(priceFactory({ country: 'US' }));
      // filter for US prices -> no price should be left in variant
      this.exporter.queryOptions.filterPrices = [{ name: 'country', value: 'US' }];
      const filteredVariants = this.exporter._filterVariantsByAttributes(
        [ variant ],
        []
      );

      const actual = filteredVariants[0];
      const expected = _.extend(variant, { prices: [] });

      return expect(actual).toEqual(expected);
    });

    return it(`should filter out a variant \
if the price filter filtered out all prices of the variant`, function() {

      // init variant with DE price
      const variant = variantFactory({country: 'US'});
      variant.prices.push(priceFactory({ country: 'US' }));
      // filter for US prices -> no price should be left in variant
      this.exporter.queryOptions.filterPrices = [{ name: 'country', value: 'DE' }];
      const filteredVariants = this.exporter._filterVariantsByAttributes(
        [ variant ],
        []
      );

      const actual = filteredVariants[0];
      const expected = undefined;

      return expect(actual).toEqual(expected);
    });
  });

  describe('Function to filter prices', function() {

    it('should keep prices that meet the filter condition', function() {

      const price = priceFactory();
      const filteredVariants = this.exporter._filterPrices(
        [ price ],
        [{ name: 'country', value: 'US' }]
      );

      const actual = filteredVariants[0];
      const expected = price;

      return expect(actual).toEqual(expected);
    });

    return it('should remove prices that don\'t meet the filter condition', function() {

      const price = priceFactory({ country: 'DE' });
      const usPrice = priceFactory({ country: 'US' });
      const filteredPrices = this.exporter._filterPrices(
        [ price, usPrice, usPrice, usPrice ],
        [{ name: 'country', value: 'DE' }]
      );

      const actual = filteredPrices.length;
      const expected = 1;

      return expect(actual).toEqual(expected);
    });
  });


  return describe('Product queryString', () =>

    it('should append custom condition to queryString', function() {
      const query = 'where=productType(id="987") AND id="567"&staged=false';
      const expectedQuery = 'where=productType(id="987") AND id="567" AND productType(id="123")&staged=false';
      const customWherePredicate = 'productType(id="123")';

      let parsed = this.exporter._parseQueryString(query);
      parsed = this.exporter._appendQueryStringPredicate(parsed, customWherePredicate);
      const result = this.exporter._stringifyQueryString(parsed);

      return expect(result).toEqual(expectedQuery);
    })
  );
});
