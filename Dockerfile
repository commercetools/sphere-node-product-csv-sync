FROM mhart/alpine-node:4

# Create app directory
RUN mkdir -p /usr/commercetools/product-import
WORKDIR /usr/commercetools/product-import

# Install app dependencies
ADD package.json /usr/commercetools/product-import/
ADD bin /usr/commercetools/product-import/bin
ADD lib /usr/commercetools/product-import/lib
ADD node_modules /usr/commercetools/product-import/node_modules

CMD [ "/usr/commercetools/product-import/bin/run_product_import.sh" ]