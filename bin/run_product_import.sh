#!/bin/sh

echo Running CSV product import for project $SPHERE_PROJECT_KEY with SFTP username $SFTP_USERNAME, SFTP in directory $SFTP_IN_DIRECTORY and SFTP out directory $SFTP_OUT_DIRECTORY
/usr/commercetools/product-import/bin/product-csv-sync \
--projectKey=$SPHERE_PROJECT_KEY \
--clientId=$SPHERE_CLIENT_ID \
--clientSecret=$SPHERE_CLIENT_SECRET \
import \
--sftpHost=$SFTP_HOST \
--sftpUsername=$SFTP_USERNAME \
--sftpPassword=$SFTP_PASSWORD \
--sftpSource=$SFTP_IN_DIRECTORY \
--sftpTarget=$SFTP_OUT_DIRECTORY \
--matchBy=$MATCH_BY \
--language=$LANGUAGE \
--csvDelimiter="|"