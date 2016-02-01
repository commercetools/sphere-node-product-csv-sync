{ Export } = require '../lib/main'
Config = require '../config'
_ = require 'underscore'

priceFactory = ({ country } = {}) ->
  country: country or 'US'

variantFactory = ({ country, published } = {}) ->
  prices: [
    priceFactory({ country })
  ],
  attributes: [
    {
      name: 'published',
      value: published or true
    }
  ]

describe 'Export', ->

  beforeEach ->
    @exporter = new Export({ client: Config })

  describe 'Function to filter variants by attributes', ->

    it 'should keep variants that meet the filter condition', ->

      variant = variantFactory()
      filteredVariants = @exporter._filterVariantsByAttributes(
        [variant],
        [{ name: 'published', value: true }]
      )

      actual = filteredVariants[0]
      expected = variant

      expect(actual).toEqual(expected)

    it 'should remove variants that don\'t meet the filter condition', ->

      variant = variantFactory()
      filteredVariants = @exporter._filterVariantsByAttributes(
        [variant],
        [{ name: 'published', value: false }]
      )

      actual = filteredVariants[0]
      expected = undefined

      expect(actual).toEqual(expected)

    it 'should filter prices if no variant filter is provided', ->

      # init variant with DE price
      variant = variantFactory({country: 'DE'})
      variant.prices.push(priceFactory({ country: 'US' }))
      # filter for US prices -> no price should be left in variant
      @exporter.queryOptions.filterPrices = [{ name: 'country', value: 'US' }]
      filteredVariants = @exporter._filterVariantsByAttributes(
        [ variant ],
        []
      )

      actual = filteredVariants[0]
      expected = _.extend(variant, { prices: [] })

      expect(actual).toEqual(expected)

    it 'should filter out a variant
    if the price filter filtered out all prices of the variant', ->

      # init variant with DE price
      variant = variantFactory({country: 'US'})
      variant.prices.push(priceFactory({ country: 'US' }))
      # filter for US prices -> no price should be left in variant
      @exporter.queryOptions.filterPrices = [{ name: 'country', value: 'DE' }]
      filteredVariants = @exporter._filterVariantsByAttributes(
        [ variant ],
        []
      )

      actual = filteredVariants[0]
      expected = undefined

      expect(actual).toEqual(expected)

  describe 'Function to filter prices', ->

    it 'should keep prices that meet the filter condition', ->

      price = priceFactory()
      filteredVariants = @exporter._filterPrices(
        [ price ],
        [{ name: 'country', value: 'US' }]
      )

      actual = filteredVariants[0]
      expected = price

      expect(actual).toEqual(expected)

    it 'should remove prices that don\'t meet the filter condition', ->

      price = priceFactory({ country: 'DE' })
      usPrice = priceFactory({ country: 'US' })
      filteredPrices = @exporter._filterPrices(
        [ price, usPrice, usPrice, usPrice ],
        [{ name: 'country', value: 'DE' }]
      )

      actual = filteredPrices.length
      expected = 1

      expect(actual).toEqual(expected)
