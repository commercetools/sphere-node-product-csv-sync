constants =
  HEADER_PRODUCT_TYPE: 'productType'
  HEADER_NAME: 'name'
  HEADER_VARIANT_ID: 'variantId'

  DELIM_HEADER_LANGUAGE: '.'
  DELIM_MULTI_VALUE: ';'

  DEFAULT_LANGUAGE: 'en'

  ATTRIBUTE_TYPE_LTEXT: 'ltext'

for name,value of constants
  exports[name] = value

exports.BASE_HEADERS = [
  constants.HEADER_PRODUCT_TYPE,
  constants.HEADER_NAME,
  constants.HEADER_VARIANT_ID
]

exports.BASE_LOCALIZED_HEADERS = [
  constants.HEADER_NAME,
  'description',
  'slug',
  'metaTitle',
  'metaDescription',
  'metaKeywords'
]
