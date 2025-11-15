#!/bin/bash

# Configuration
MONGO_URI=${1:-"mongodb://18.201.40.250:27017"}
MONGO_DB=${2:-"userDB"}
BACKUP_FOLDER_PATH="/home/ubuntu/mongodb-backups"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_NAME="mongodb_backup_${TIMESTAMP}"
S3_BUCKET=${S3_BUCKET:-"your-s3-bucket-name"}
RETENTION_DAYS=7

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "=== MongoDB Automated Backup Script ==="
echo "Started at: $(date)"

# Step 1: Check MongoDB status
echo -e "\n${YELLOW}[1/5] Checking MongoDB connection...${NC}"
echo "$MONGO_URI" --eval "db.adminCommand('ping')"
if mongosh "$MONGO_URI" --eval "db.adminCommand('ping')"; then
    echo -e "${GREEN}✓ MongoDB is reachable and running${NC}"
else
    echo -e "${RED}✗ Cannot connect to MongoDB${NC}"
    exit 1
fi

# Step 2: Create backup directory
echo -e "\n${YELLOW}[2/5] Creating backup directory...${NC}"
if [ -d "$BACKUP_FOLDER_PATH" ]; then
    echo "Directory '$BACKUP_FOLDER_PATH' exists."
else
    mkdir -p "$BACKUP_FOLDER_PATH"
    echo -e "${GREEN}✓ Created directory '$BACKUP_FOLDER_PATH'${NC}"
fi

# Step 3: Backup database
echo -e "\n${YELLOW}[3/5] Creating MongoDB backup...${NC}"
BACKUP_PATH="$BACKUP_FOLDER_PATH/$BACKUP_NAME"

mongodump \
    --uri="$MONGO_URI" \
    --db="$MONGO_DB" \
    --out="$BACKUP_PATH"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ MongoDB dump completed${NC}"
    
    # Create tar.gz archive
    echo "Creating compressed archive..."
    tar -czf "$BACKUP_PATH.tar.gz" -C "$BACKUP_FOLDER_PATH" "$BACKUP_NAME"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Archive created: $BACKUP_NAME.tar.gz${NC}"
        rm -rf "$BACKUP_PATH"
    else
        echo -e "${RED}✗ Failed to create archive${NC}"
        exit 1
    fi
else
    echo -e "${RED}✗ MongoDB dump failed${NC}"
    exit 1
fi

# Step 4: Upload to S3 and cleanup
echo -e "\n${YELLOW}[4/5] Uploading to S3...${NC}"

aws s3 cp "$BACKUP_PATH.tar.gz" "s3://$S3_BUCKET/mongodb-backups/" --storage-class STANDARD_IA

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Backup uploaded to S3${NC}"
    
    # Delete backups older than RETENTION_DAYS
    echo "Cleaning up backups older than $RETENTION_DAYS days..."
    
    aws s3api list-objects --bucket "$S3_BUCKET" --prefix "mongodb-backups/" --query 'Contents[?LastModified<=`'$(date -d "$RETENTION_DAYS days ago" --iso-8601=seconds)'`].[Key]' --output text | while read key; do
        if [ ! -z "$key" ]; then
            echo "Deleting: $key"
            aws s3 rm "s3://$S3_BUCKET/$key"
        fi
    done
    
    echo -e "${GREEN}✓ Old backups cleaned up${NC}"
else
    echo -e "${RED}✗ Failed to upload to S3${NC}"
    exit 1
fi

# Remove local backup
rm -f "$BACKUP_PATH.tar.gz"

# Step 5: Complete
echo -e "\n${GREEN}[5/5] ✓ Backup completed successfully!${NC}"
echo "Finished at: $(date)"
exit 0