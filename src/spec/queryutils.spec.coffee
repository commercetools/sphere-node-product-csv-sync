QueryUtils = require "../lib/queryutils"
GLOBALS = require '../lib/globals'

products = [
  {
    product: {
      masterVariant: {
        id: 1,
        attributes: [
          {
            name: "key",
            value: "1"
          }
        ],
        sku: "1"
      },
      variants: [
        {
          attributes: [
            {
              name: "key",
              value: "2"
            }
          ],
          sku: "2"
        },
        {
          id: 3,
          attributes: [
            {
              name: "key",
              value: "3"
            }
          ],
          sku: "3"
        }
      ],
      id: "1",
      slug: {
        en: "1"
      }
    }
  },
  {
    product: {
      masterVariant: {
        id: 1,
        attributes: [
          {
            name: "key",
            value: "4"
          }
        ],
        sku: "4"
      },
      variants: [
        {
          attributes: [
            {
              name: "key",
              value: "5"
            }
          ],
          sku: "5"
        },
        {
          attributes: [
            {
              name: "key",
              value: "6"
            }
          ],
          sku: "6"
        }
      ],
      id: "2",
      slug: {
        en: "2"
      }
    }
  }
]

describe "QueryUtils", ->

  describe "mapMatchFunction", ->

    it "should return \"matchById\" function if supplied with \"id\" value", ->
      matchFunction = QueryUtils.mapMatchFunction("id")
      expect(matchFunction).toBeDefined()
      expect(matchFunction).toBe QueryUtils.matchById

    it "should return \"matchBySlug\" function if supplied with \"slug\" value", ->
      matchFunction = QueryUtils.mapMatchFunction("slug")
      expect(matchFunction).toBeDefined()
      expect(matchFunction).toBe QueryUtils.matchBySlug

    it "should return \"matchBySku\" function if supplied with \"sku\" value", ->
      matchFunction = QueryUtils.mapMatchFunction("sku")
      expect(matchFunction).toBeDefined()
      expect(matchFunction).toBe QueryUtils.matchBySku

    it "should return \"matchByCustomAttribute\" function if supplied with random value", ->
      matchFunction = QueryUtils.mapMatchFunction("custom_attribute_name")
      expect(matchFunction).toBeDefined()
      expect(typeof matchFunction).toEqual('function')

  describe "matchById", ->
    it "should return query predicte based on products provided", ->
      predicate = QueryUtils.matchById products
      expect(predicate).toEqual "id in (\"1\", \"2\")"

  describe "matchBySlug", ->
    it "should return query predicte based on products provided", ->
      GLOBALS.DEFAULT_LANGUAGE = "en"
      predicate = QueryUtils.matchBySlug products
      expect(predicate).toEqual "slug in (\"1\", \"2\")"

  describe "matchBySku", ->
    it "should return query predicte based on products provided", ->
      predicate = QueryUtils.matchBySku(products)
      expect(predicate).toEqual("masterVariant(sku in " +
      "(\"1\", \"4\")) or " +
      "variants(sku in (\"1\", \"4\"))")

  describe "matchByCustomAttribute", ->
    it "should return query predicte based on products provided", ->
      predicate = QueryUtils.matchByCustomAttribute("key")(products)
      expect(predicate).toEqual("masterVariant(key in " +
      "(\"1\", \"2\", \"3\", \"4\", \"5\", \"6\")) or " +
      "variants(key in (\"1\", \"2\", \"3\", \"4\", \"5\", \"6\"))")
