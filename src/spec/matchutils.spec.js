/*
 * decaffeinate suggestions:
 * DS102: Remove unnecessary code created because of implicit returns
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
const MatchUtils = require("../lib/matchutils");
const GLOBALS = require('../lib/globals');

const product1 = {
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
};

const product2 = {
  slug: {
    en: "2"
  },
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
      id: 2,
      attributes: [
        {
          name: "key",
          value: "5"
        }
      ],
      sku: "5"
    },
    {
      id: 3,
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
};

const products = [
  {
    product: product1
  },
  {
    product: product2
  }
];

describe("MatchUtils", function() {
  describe("mapById", () =>
    it("should return the map of id -> product", function() {
      const map = MatchUtils.mapById(product1);
      return expect(map).toEqual({"1": product1});
    })
  );

  describe("mapBySlug", () =>
    it("should return the map of slug -> product", function() {
      GLOBALS.DEFAULT_LANGUAGE = "en";
      const map = MatchUtils.mapBySlug(product1);
      return expect(map).toEqual({"1": product1});
    })
  );

  describe("mapBySku", () =>
    it("should return the map of [skus] -> product", function() {
      const map = MatchUtils.mapBySku(product1);
      return expect(map).toEqual({
        "1": product1,
        "2": product1,
        "3": product1
      });
    })
  );

  describe("mapByCustomAttribute", function() {
    const p = product1;
    const map = MatchUtils.mapByCustomAttribute("key")(p);
    return expect(map).toEqual({
      "1": p,
      "2": p,
      "3": p
    });
  });

  describe("mapIdentifier", function() {
    it("should return function which returns an id of product entry", function() {
      const p = product1;
      const foo = MatchUtils.mapIdentifier("id");
      const id = foo({ product: p });
      return expect(id).toBe("1");
    });

    it("should return function which returns a slug of product entry", function() {
      GLOBALS.DEFAULT_LANGUAGE = "en";
      const p = product1;
      const foo = MatchUtils.mapIdentifier("slug");
      const slug = foo({ product: p });
      return expect(slug).toBe("1");
    });

    it("should return function which returns an sku of product entry", function() {
      const p = product1;
      const foo = MatchUtils.mapIdentifier("sku");
      const sku = foo({ product: p });
      return expect(sku).toBe("1");
    });

    return it("should return function which returns a custom attribute value of product's master variant", function() {
      const p = product1;
      const foo = MatchUtils.mapIdentifier("key");
      const value = foo({ product: p });
      return expect(value).toEqual("1");
    });
  });

  return describe("initMatcher", function() {
    it("should produce the function which maps the given entry to existing product based on id", function() {
      const foo = MatchUtils.initMatcher("id", [product1, product2]);
      const p = product1;
      const existingProduct = foo({ product: p });
      return expect(existingProduct).toEqual(p);
    });

    it("should produce the function which maps the given entry to existing product based on slug", function() {
      GLOBALS.DEFAULT_LANGUAGE = "en";
      const foo = MatchUtils.initMatcher("slug", [product1, product2]);
      const p = product1;
      const existingProduct = foo({ product: p });
      return expect(existingProduct).toEqual(p);
    });

    it("should produce the function which maps the given entry to existing product based on sku", function() {
      const foo = MatchUtils.initMatcher("sku", [product1, product2]);
      const p = product1;
      const existingProduct = foo({ product: p });
      return expect(existingProduct).toEqual(p);
    });

    return it("should produce the function which maps the given entry to existing product based on custom attribute", function() {
      const foo = MatchUtils.initMatcher("key", [product1, product2]);
      const p = product1;
      const existingProduct = foo({ product: p });
      return expect(existingProduct).toEqual(p);
    });
  });
});
