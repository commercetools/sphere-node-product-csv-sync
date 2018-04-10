MatchUtils = require "../lib/matchutils"
GLOBALS = require '../lib/globals'

product1 = {
  slug: {
    en: "1"
  },
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
      id: 2,
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
  id: "1"
}

product2 = {
  slug: {
    en: "2"
  }
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
      id: 2
      attributes: [
        {
          name: "key",
          value: "5"
        }
      ],
      sku: "5"
    },
    {
      id: 3
      attributes: [
        {
          name: "key",
          value: "6"
        }
      ],
      sku: "6"
    }
  ],
  id: "2"
}

products = [
  {
    product: product1
  },
  {
    product: product2
  }
]

describe "MatchUtils", ->
  describe "mapById", ->
    it "should return the map of id -> product", ->
      map = MatchUtils.mapById(product1)
      expect(map).toEqual({"1": product1})

  describe "mapBySlug", ->
    it "should return the map of slug -> product", ->
      GLOBALS.DEFAULT_LANGUAGE = "en"
      map = MatchUtils.mapBySlug(product1)
      expect(map).toEqual({"1": product1})

  describe "mapBySku", ->
    it "should return the map of [skus] -> product", ->
      map = MatchUtils.mapBySku(product1)
      expect(map).toEqual({
        "1": product1,
        "2": product1,
        "3": product1
      })

  describe "mapByCustomAttribute", ->
    it "should return the map of [customAttributes] -> product", ->
      p = product1
      map = MatchUtils.mapByCustomAttribute("key")(p)
      expect(map).toEqual({
        "1": p,
        "2": p,
        "3": p
      })

  describe "mapIdentifier", ->
    it "should return function which returns an id of product entry", ->
      p = product1
      foo = MatchUtils.mapIdentifier("id")
      id = foo({ product: p })
      expect(id).toBe("1")

    it "should return function which returns a slug of product entry", ->
      GLOBALS.DEFAULT_LANGUAGE = "en"
      p = product1
      foo = MatchUtils.mapIdentifier("slug")
      slug = foo({ product: p })
      expect(slug).toBe("1")

    it "should return function which returns an sku of product entry", ->
      p = product1
      foo = MatchUtils.mapIdentifier("sku")
      sku = foo({ product: p })
      expect(sku).toBe("1")

    it "should return function which returns a custom attribute value of product's master variant", ->
      p = product1
      foo = MatchUtils.mapIdentifier("key")
      value = foo({ product: p })
      expect(value).toEqual("1")

  describe "initMatcher", ->
    it "should produce the function which maps the given entry to existing product based on id", ->
      foo = MatchUtils.initMatcher("id", [product1, product2])
      p = product1
      existingProduct = foo({ product: p })
      expect(existingProduct).toEqual(p)

    it "should produce the function which maps the given entry to existing product based on slug", ->
      GLOBALS.DEFAULT_LANGUAGE = "en"
      foo = MatchUtils.initMatcher("slug", [product1, product2])
      p = product1
      existingProduct = foo({ product: p })
      expect(existingProduct).toEqual(p)

    it "should produce the function which maps the given entry to existing product based on sku", ->
      foo = MatchUtils.initMatcher("sku", [product1, product2])
      p = product1
      existingProduct = foo({ product: p })
      expect(existingProduct).toEqual(p)

    it "should produce the function which maps the given entry to existing product based on custom attribute", ->
      foo = MatchUtils.initMatcher("key", [product1, product2])
      p = product1
      existingProduct = foo({ product: p })
      expect(existingProduct).toEqual(p)
