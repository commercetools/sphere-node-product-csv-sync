/*
 * decaffeinate suggestions:
 * DS101: Remove unnecessary use of Array.from
 * DS102: Remove unnecessary code created because of implicit returns
 * DS207: Consider shorter variations of null checks
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
const _ = require('underscore')
_.mixin(require('underscore.string').exports())
const CONS = require('./constants')
const GLOBALS = require('./globals')

// TODO:
// - JSDoc
// - no services!!!
// - utils only
class ExportMapping {
  constructor (options) {
    if (options == null) options = {}
    this.typesService = options.typesService
    this.categoryService = options.categoryService
    this.channelService = options.channelService
    this.customerGroupService = options.customerGroupService
    this.taxService = options.taxService
    this.header = options.header
    this.fillAllRows = options.fillAllRows
    this.categoryBy = options.categoryBy
    this.categoryOrderHintBy = options.categoryOrderHintBy
  }

  mapProduct (product, productTypes) {
    const productType = productTypes[this.typesService.id2index[product.productType.id]]
    const rows = []
    const productRow = this._mapBaseProduct(product, productType)
    if (product.masterVariant)
      rows.push(productRow)


    if (product.variants)
      for (const variant of Array.from(product.variants)) {
        const variantRow = this.fillAllRows ?
          _.deepClone(productRow)
          :
          []
        rows.push(this._mapVariant(variant, productType, variantRow))
      }


    return rows
  }

  createTemplate (productType, languages) {
    if (languages == null) languages = [GLOBALS.DEFAULT_LANGUAGE]
    let header = [ CONS.HEADER_PUBLISHED, CONS.HEADER_HAS_STAGED_CHANGES ].concat(CONS.BASE_HEADERS.concat(CONS.SPECIAL_HEADERS))
    _.each(CONS.BASE_LOCALIZED_HEADERS, locBaseAttrib =>
      header = header.concat(_.map(languages, lang => `${locBaseAttrib}${GLOBALS.DELIM_HEADER_LANGUAGE}${lang}`)))
    _.each(productType.attributes, (attribute) => {
      switch (attribute.type.name) {
        case CONS.ATTRIBUTE_TYPE_SET: return header = header.concat(this._mapAttributeTypeDef(attribute.type.elementType, attribute, languages))
        default: return header = header.concat(this._mapAttributeTypeDef(attribute.type, attribute, languages))
      }
    })
    return header
  }

  _mapAttributeTypeDef (attributeTypeDef, attribute, languages) {
    switch (attributeTypeDef.name) {
      case CONS.ATTRIBUTE_TYPE_LTEXT: return _.map(languages, lang => `${attribute.name}${GLOBALS.DELIM_HEADER_LANGUAGE}${lang}`)
      default: return [ attribute.name ]
    }
  }

  _mapBaseProduct (product, productType) {
    const row = product.masterVariant ?
      this._mapVariant(product.masterVariant, productType)
      :
      []

    if (this.header.has(CONS.HEADER_PUBLISHED))
      row[this.header.toIndex(CONS.HEADER_PUBLISHED)] = `${product.published}`


    if (this.header.has(CONS.HEADER_HAS_STAGED_CHANGES))
      row[this.header.toIndex(CONS.HEADER_HAS_STAGED_CHANGES)] = `${product.hasStagedChanges}`


    if (this.header.has(CONS.HEADER_ID))
      row[this.header.toIndex(CONS.HEADER_ID)] = product.id


    if (this.header.has(CONS.HEADER_KEY))
      row[this.header.toIndex(CONS.HEADER_KEY)] = product.key


    if (this.header.has(CONS.HEADER_PRODUCT_TYPE))
      row[this.header.toIndex(CONS.HEADER_PRODUCT_TYPE)] = productType.name


    if (this.header.has(CONS.HEADER_TAX) && _.has(product, 'taxCategory'))
      if (_.has(this.taxService.id2name, product.taxCategory.id)) {
        row[this.header.toIndex(CONS.HEADER_TAX)] = this.taxService.id2name[product.taxCategory.id]
      }


    if (this.header.has(CONS.HEADER_CATEGORIES))
      row[this.header.toIndex(CONS.HEADER_CATEGORIES)] = _.reduce(
        product.categories || [], (memo, category, index) => {
          if (index !== 0) memo += GLOBALS.DELIM_MULTI_VALUE
          return memo + (this.categoryBy === CONS.HEADER_SLUG ?
            this.categoryService.id2slug[category.id]
            : this.categoryBy === CONS.HEADER_EXTERNAL_ID ?
              this.categoryService.id2externalId[category.id]
              :
              this.categoryService.id2fqName[category.id])
        }
        , '',
      )


    if (this.header.has(CONS.HEADER_CREATED_AT))
      row[this.header.toIndex(CONS.HEADER_CREATED_AT)] = product.createdAt


    if (this.header.has(CONS.HEADER_LAST_MODIFIED_AT))
      row[this.header.toIndex(CONS.HEADER_LAST_MODIFIED_AT)] = product.lastModifiedAt


    const object = this.header.toLanguageIndex()
    for (const attribName in object) {
      const h2i = object[attribName]
      for (const lang in h2i) {
        const index = h2i[lang]
        if (product[attribName])
          if (attribName === CONS.HEADER_SEARCH_KEYWORDS) {
            row[index] = _.reduce(
              product[attribName][lang], (memo, val, index) => {
                if (index !== 0) memo += GLOBALS.DELIM_MULTI_VALUE
                return memo + val.text
              }
              , '',
            )
          } else {
            row[index] = product[attribName][lang]
          }
      }
    }

    if (this.header.has(CONS.HEADER_CATEGORY_ORDER_HINTS))
      if (product.categoryOrderHints != null) {
        const categoryIds = Object.keys(product.categoryOrderHints)
        const categoryOrderHints = _.map(categoryIds, (categoryId) => {
          let categoryIdentificator = categoryId
          if (this.categoryOrderHintBy === 'externalId')
            categoryIdentificator = this.categoryService.id2externalId[categoryId]

          return `${categoryIdentificator}:${product.categoryOrderHints[categoryId]}`
        })
        row[this.header.toIndex(CONS.HEADER_CATEGORY_ORDER_HINTS)] = categoryOrderHints.join(GLOBALS.DELIM_MULTI_VALUE)
      } else {
        row[this.header.toIndex(CONS.HEADER_CATEGORY_ORDER_HINTS)] = ''
      }


    return row
  }

  _mapVariant (variant, productType, row) {
    if (row == null) row = []
    if (this.header.has(CONS.HEADER_VARIANT_ID))
      row[this.header.toIndex(CONS.HEADER_VARIANT_ID)] = variant.id


    if (this.header.has(CONS.HEADER_VARIANT_KEY))
      row[this.header.toIndex(CONS.HEADER_VARIANT_KEY)] = variant.key


    if (this.header.has(CONS.HEADER_SKU))
      row[this.header.toIndex(CONS.HEADER_SKU)] = variant.sku


    if (this.header.has(CONS.HEADER_PRICES))
      row[this.header.toIndex(CONS.HEADER_PRICES)] = this._mapPrices(variant.prices)


    if (this.header.has(CONS.HEADER_IMAGES))
      row[this.header.toIndex(CONS.HEADER_IMAGES)] = this._mapImages(variant.images)


    if (variant.attributes)
      for (const attribute of Array.from(variant.attributes)) {
        const attributeTypeDef = this.typesService.id2nameAttributeDefMap[productType.id][attribute.name].type
        if (attributeTypeDef.name === CONS.ATTRIBUTE_TYPE_LTEXT)
          row = this._mapLocalizedAttribute(attribute, productType, row)
        else if ((attributeTypeDef.name === CONS.ATTRIBUTE_TYPE_SET) && ((attributeTypeDef.elementType != null ? attributeTypeDef.elementType.name : undefined) === CONS.ATTRIBUTE_TYPE_LENUM))
          // we need special treatment for set of lenums
          row = this._mapSetOfLenum(attribute, productType, row)
        else if ((attributeTypeDef.name === CONS.ATTRIBUTE_TYPE_SET) && ((attributeTypeDef.elementType != null ? attributeTypeDef.elementType.name : undefined) === CONS.ATTRIBUTE_TYPE_LTEXT))
          row = this._mapSetOfLtext(attribute, productType, row)
        else if (attributeTypeDef.name === CONS.ATTRIBUTE_TYPE_LENUM) // we need special treatnemt for lenums
          row = this._mapLenum(attribute, productType, row)
        else if (this.header.has(attribute.name))
          row[this.header.toIndex(attribute.name)] = this._mapAttribute(attribute, attributeTypeDef)
      }


    return row
  }

  _mapPrices (prices) {
    return _.reduce(
      prices, (acc, price, index) => {
        if (index !== 0) acc += GLOBALS.DELIM_MULTI_VALUE
        let countryPart = ''
        if (price.country)
          countryPart = `${price.country}-`

        let customerGroupPart = ''
        if (price.customerGroup && _.has(this.customerGroupService.id2name, price.customerGroup.id))
          customerGroupPart = ` ${this.customerGroupService.id2name[price.customerGroup.id]}`

        let channelKeyPart = ''
        if (price.channel && _.has(this.channelService.id2key, price.channel.id))
          channelKeyPart = `#${this.channelService.id2key[price.channel.id]}`

        let discountedPricePart = ''

        let validFromPart = ''
        if (price.validFrom)
          validFromPart = `$${price.validFrom}`


        let validUntilPart = ''
        if (price.validUntil)
          validUntilPart = `~${price.validUntil}`


        if (price.discounted != null)
          discountedPricePart = `|${price.discounted.value.centAmount}`

        return `${acc}${countryPart}${price.value.currencyCode} ${price.value.centAmount}${discountedPricePart}${customerGroupPart}${channelKeyPart}${validFromPart}${validUntilPart}`
      }
      , '',
    )
  }

  _mapMoney (money) {
    return `${money.currencyCode} ${money.centAmount}`
  }

  _mapImages (images) {
    return _.reduce(
      images, (acc, image, index) => {
        if (index !== 0) acc += GLOBALS.DELIM_MULTI_VALUE
        return acc + image.url
      }
      , '',
    )
  }

  _mapAttribute (attribute, attributeTypeDef) {
    switch (attributeTypeDef.name) {
      case CONS.ATTRIBUTE_TYPE_SET: return this._mapSetAttribute(attribute, attributeTypeDef)
      case CONS.ATTRIBUTE_TYPE_ENUM: return attribute.value.key
      case CONS.ATTRIBUTE_TYPE_MONEY: return this._mapMoney(attribute.value)
      case CONS.ATTRIBUTE_TYPE_REFERENCE: return (attribute.value != null ? attribute.value.id : undefined)
      case CONS.ATTRIBUTE_TYPE_BOOLEAN: return attribute.value.toString()
      default: return attribute.value
    }
  }

  _mapLocalizedAttribute (attribute, productType, row) {
    const h2i = this.header.productTypeAttributeToIndex(productType, attribute)
    if (h2i)
      for (const lang in h2i) {
        const index = h2i[lang]
        if (attribute.value)
          row[index] = attribute.value[lang]
      }

    return row
  }

  _mapLenum (attribute, productType, row) {
    const noneLangIndex = this.header.toIndex(attribute.name)
    // if my attribute has no language index, I want the key only
    if (noneLangIndex)
      row[noneLangIndex] = attribute.value.key

    const h2i = this.header.productTypeAttributeToIndex(productType, attribute)
    if (h2i)
      for (const lang in h2i) {
        const index = h2i[lang]
        if (attribute.value)
          row[index] = attribute.value.label[lang]
        else
          row[index] = attribute.value.key
      }

    return row
  }

  _mapSetOfLenum (attribute, productType, row) {
    // if my attribute has no language index, I want the keys only
    const noneLangIndex = this.header.toIndex(attribute.name)
    if (noneLangIndex)
      row[noneLangIndex] = _.reduce(
        attribute.value, (memo, val, index) => {
          if (index !== 0) memo += GLOBALS.DELIM_MULTI_VALUE
          return memo + val.key
        }
        , '',
      )

    const h2i = this.header.productTypeAttributeToIndex(productType, attribute)
    if (h2i)
      for (var lang in h2i) {
        const index = h2i[lang]
        if (attribute.value)
          row[index] = _.reduce(
            attribute.value, (memo, val, index) => {
              if (index !== 0) memo += GLOBALS.DELIM_MULTI_VALUE
              return memo + val.label[lang]
            }
            , '',
          )
        else
          row[index] = attribute.value.key
      }


    return row
  }

  _mapSetOfLtext (attribute, productType, row) {
    const h2i = this.header.productTypeAttributeToIndex(productType, attribute)
    for (var lang in h2i) {
      const index = h2i[lang]
      row[index] = _.reduce(
        attribute.value, (memo, val, index) => {
          if (val[lang] == null) return memo

          if (index !== 0) memo += GLOBALS.DELIM_MULTI_VALUE
          return memo + val[lang]
        }
        , '',
      )
    }
    return row
  }

  _mapSetAttribute (attribute, attributeTypeDef) {
    switch (attributeTypeDef.elementType.name) {
      case CONS.ATTRIBUTE_TYPE_ENUM:
        return _.reduce(
          attribute.value, (memo, val, index) => {
            if (index !== 0) memo += GLOBALS.DELIM_MULTI_VALUE
            return memo + val.key
          }
          , '',
        )
      case CONS.ATTRIBUTE_TYPE_MONEY:
        return _.reduce(
          attribute.value, (memo, val, index) => {
            if (index !== 0) memo += GLOBALS.DELIM_MULTI_VALUE
            return memo + this._mapMoney(val)
          }
          , '',
        )
      default:
        return attribute.value.join(GLOBALS.DELIM_MULTI_VALUE)
    }
  }
}


module.exports = ExportMapping
