#!/bin/bash

MONGO_USERNAME=$1
MONGO_PASSWORD=$2
BACKUP_FOLDER_PATH="./home/ubuntu/mongodb-backups"

if [ -d "$BACKUP_FOLDER_PATH" ]; then
  echo "Directory '$BACKUP_FOLDER_PATH' exists."
else
  mkdir -p ./home/ubuntu/mongodb-backups
  echo "Directory '$BACKUP_FOLDER_PATH' does not exist, creating new directory"
fi



# mongodump --host localhost --port 27017 --db userDB --username admin --password password --authenticationDatabase admin --out /home/mongodb-backups/