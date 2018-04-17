const constants = {
  HEADER_PRODUCT_TYPE: 'productType',
  HEADER_ID: 'id',
  HEADER_KEY: 'key',
  HEADER_EXTERNAL_ID: 'externalId',
  HEADER_VARIANT_ID: 'variantId',
  HEADER_VARIANT_KEY: 'variantKey',

  HEADER_NAME: 'name',
  HEADER_DESCRIPTION: 'description',
  HEADER_CATEGORY_ORDER_HINTS: 'categoryOrderHints',
  HEADER_SLUG: 'slug',

  HEADER_META_TITLE: 'metaTitle',
  HEADER_META_DESCRIPTION: 'metaDescription',
  HEADER_META_KEYWORDS: 'metaKeywords',
  HEADER_SEARCH_KEYWORDS: 'searchKeywords',

  HEADER_TAX: 'tax',
  HEADER_CATEGORIES: 'categories',

  HEADER_SKU: 'sku',
  HEADER_PRICES: 'prices',
  HEADER_IMAGES: 'images',
  HEADER_IMAGE_LABELS: 'imageLabels',
  HEADER_IMAGE_DIMENSIONS: 'imageDimensions',

  HEADER_PUBLISHED: '_published',
  HEADER_HAS_STAGED_CHANGES: '_hasStagedChanges',
  HEADER_CREATED_AT: '_createdAt',
  HEADER_LAST_MODIFIED_AT: '_lastModifiedAt',

  HEADER_PUBLISH: 'publish',

  ATTRIBUTE_TYPE_SET: 'set',
  ATTRIBUTE_TYPE_LTEXT: 'ltext',
  ATTRIBUTE_TYPE_ENUM: 'enum',
  ATTRIBUTE_TYPE_LENUM: 'lenum',
  ATTRIBUTE_TYPE_NUMBER: 'number',
  ATTRIBUTE_TYPE_MONEY: 'money',
  ATTRIBUTE_TYPE_REFERENCE: 'reference',
  ATTRIBUTE_TYPE_BOOLEAN: 'boolean',

  ATTRIBUTE_CONSTRAINT_SAME_FOR_ALL: 'SameForAll',

  REGEX_PRICE: new RegExp(/^(([A-Za-z]{2})-|)([A-Z]{3}) (-?\d+)(-?\|(\d+)|)( ([^~\$#]*)|)(#([^~\$]*)|)(\$([^~]*)|)(~(.*)|)$/),
  REGEX_MONEY: new RegExp(/^([A-Z]{3}) (-?\d+)$/),
  REGEX_INTEGER: new RegExp(/^-?\d+$/),
  REGEX_FLOAT: new RegExp(/^-?\d+(\.\d+)?$/),
}


for (const name in constants) {
  const value = constants[name]
  exports[name] = value
}

exports.BASE_HEADERS = [
  constants.HEADER_PRODUCT_TYPE,
  constants.HEADER_VARIANT_ID,
  constants.HEADER_VARIANT_KEY,
]

exports.BASE_LOCALIZED_HEADERS = [
  constants.HEADER_NAME,
  constants.HEADER_DESCRIPTION,
  constants.HEADER_SLUG,
  constants.HEADER_META_TITLE,
  constants.HEADER_META_DESCRIPTION,
  constants.HEADER_META_KEYWORDS,
  constants.HEADER_SEARCH_KEYWORDS,
]

exports.SPECIAL_HEADERS = [
  constants.HEADER_ID,
  constants.HEADER_KEY,
  constants.HEADER_SKU,
  constants.HEADER_PRICES,
  constants.HEADER_TAX,
  constants.HEADER_CATEGORIES,
  constants.HEADER_IMAGES,
  // TODO: image labels and dimensions
]

exports.ALL_HEADERS = exports.BASE_HEADERS.concat(exports.BASE_LOCALIZED_HEADERS.concat(exports.SPECIAL_HEADERS))
