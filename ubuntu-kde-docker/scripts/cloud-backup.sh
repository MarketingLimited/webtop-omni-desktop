#!/bin/bash

# Advanced Cloud Backup System
# Part of the enterprise webtop.sh enhancement suite

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
BACKUP_CONFIG_FILE="config/backup-config.yml"
CLOUD_CONFIG_FILE="config/cloud-storage.yml"
BACKUP_DIR="./backups"
CLOUD_BACKUP_DIR="./cloud-backups"
BACKUP_LOG_FILE="logs/backup.log"

# Ensure directories exist
mkdir -p logs config "$BACKUP_DIR" "$CLOUD_BACKUP_DIR"

print_status() {
    echo -e "${BLUE}[BACKUP]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Initialize backup configuration
init_backup_config() {
    if [ ! -f "$BACKUP_CONFIG_FILE" ]; then
        print_status "Creating default backup configuration..."
        cat > "$BACKUP_CONFIG_FILE" << 'EOF'
backup_system:
  enabled: true
  default_type: "full"
  compression: "gzip"
  encryption: false
  
retention:
  local:
    full_backups: 7
    incremental_backups: 30
    max_age_days: 90
  cloud:
    full_backups: 30
    incremental_backups: 90
    max_age_days: 365

incremental:
  enabled: true
  base_backup_required: true
  track_changes: true
  metadata_file: ".backup-metadata.json"

scheduling:
  enabled: false
  full_backup_schedule: "0 2 * * 0"  # Weekly at 2 AM Sunday
  incremental_schedule: "0 3 * * 1-6"  # Daily at 3 AM Mon-Sat
  
notifications:
  enabled: false
  on_success: false
  on_failure: true
  webhook_url: ""
  
performance:
  parallel_compression: true
  max_parallel_jobs: 4
  compression_level: 6
  buffer_size: "64MB"

verification:
  enabled: true
  checksum_algorithm: "sha256"
  verify_after_backup: true
  verify_after_restore: true
EOF
        print_success "Backup configuration created: $BACKUP_CONFIG_FILE"
    fi
    
    if [ ! -f "$CLOUD_CONFIG_FILE" ]; then
        print_status "Creating cloud storage configuration..."
        cat > "$CLOUD_CONFIG_FILE" << 'EOF'
cloud_storage:
  enabled: false
  provider: "s3"  # s3, gcs, azure, ftp, sftp
  
providers:
  s3:
    enabled: false
    bucket: ""
    region: "us-east-1"
    access_key: ""
    secret_key: ""
    endpoint: ""  # For S3-compatible services
    encryption: "AES256"
    storage_class: "STANDARD_IA"
    
  gcs:
    enabled: false
    bucket: ""
    project_id: ""
    service_account_key: ""
    storage_class: "NEARLINE"
    
  azure:
    enabled: false
    container: ""
    account_name: ""
    account_key: ""
    storage_tier: "Cool"
    
  ftp:
    enabled: false
    host: ""
    port: 21
    username: ""
    password: ""
    passive_mode: true
    ssl: false
    
  sftp:
    enabled: false
    host: ""
    port: 22
    username: ""
    password: ""
    key_file: ""

sync_options:
  upload_on_backup: true
  download_on_restore: true
  verify_upload: true
  retry_attempts: 3
  timeout: 300
  bandwidth_limit: ""  # e.g., "10MB/s"
EOF
        print_success "Cloud storage configuration created: $CLOUD_CONFIG_FILE"
    fi
}

# Load backup configuration
load_backup_config() {
    if command -v yq &> /dev/null && [ -f "$BACKUP_CONFIG_FILE" ]; then
        COMPRESSION=$(yq eval '.backup_system.compression' "$BACKUP_CONFIG_FILE" 2>/dev/null || echo "gzip")
        ENCRYPTION_ENABLED=$(yq eval '.backup_system.encryption' "$BACKUP_CONFIG_FILE" 2>/dev/null || echo "false")
        INCREMENTAL_ENABLED=$(yq eval '.incremental.enabled' "$BACKUP_CONFIG_FILE" 2>/dev/null || echo "true")
        VERIFICATION_ENABLED=$(yq eval '.verification.enabled' "$BACKUP_CONFIG_FILE" 2>/dev/null || echo "true")
        MAX_PARALLEL_JOBS=$(yq eval '.performance.max_parallel_jobs' "$BACKUP_CONFIG_FILE" 2>/dev/null || echo "4")
    else
        # Default values
        COMPRESSION="gzip"
        ENCRYPTION_ENABLED="false"
        INCREMENTAL_ENABLED="true"
        VERIFICATION_ENABLED="true"
        MAX_PARALLEL_JOBS="4"
    fi
}

# Create full backup
create_full_backup() {
    local container_name="$1"
    local backup_name="${2:-${container_name}_full_$(date +%Y%m%d_%H%M%S)}"
    local cloud_upload="${3:-false}"
    
    if [ -z "$container_name" ]; then
        print_error "Container name required"
        return 1
    fi
    
    print_status "Creating full backup for container: $container_name"
    log_backup "INFO" "Starting full backup for $container_name"
    
    local backup_path="$BACKUP_DIR/$backup_name"
    mkdir -p "$backup_path"
    
    # Create backup metadata
    cat > "$backup_path/backup-metadata.json" << EOF
{
    "container_name": "$container_name",
    "backup_name": "$backup_name",
    "backup_type": "full",
    "created": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "compression": "$COMPRESSION",
    "encryption": $ENCRYPTION_ENABLED,
    "verification": $VERIFICATION_ENABLED,
    "volumes": []
}
EOF
    
    # Backup container volumes
    local volumes="config home wine projects logs"
    local volume_list=()
    
    for vol in $volumes; do
        local volume_name="${container_name}_${vol}"
        if docker volume ls | grep -q "$volume_name"; then
            print_status "Backing up volume: $volume_name"
            
            local volume_backup_file="$backup_path/${vol}.tar"
            
            # Create volume backup with compression
            if docker run --rm \
                -v "$volume_name":/source:ro \
                -v "$backup_path":/backup \
                alpine sh -c "cd /source && tar -cf /backup/${vol}.tar ." 2>/dev/null; then
                
                # Apply compression
                if [ "$COMPRESSION" = "gzip" ]; then
                    gzip "$volume_backup_file"
                    volume_backup_file="${volume_backup_file}.gz"
                elif [ "$COMPRESSION" = "bzip2" ]; then
                    bzip2 "$volume_backup_file"
                    volume_backup_file="${volume_backup_file}.bz2"
                elif [ "$COMPRESSION" = "xz" ]; then
                    xz "$volume_backup_file"
                    volume_backup_file="${volume_backup_file}.xz"
                fi
                
                # Calculate checksum if verification enabled
                local checksum=""
                if [ "$VERIFICATION_ENABLED" = "true" ]; then
                    checksum=$(sha256sum "$volume_backup_file" | cut -d' ' -f1)
                fi
                
                # Update metadata
                local temp_file=$(mktemp)
                jq ".volumes += [{\"name\": \"$vol\", \"volume_name\": \"$volume_name\", \"file\": \"$(basename "$volume_backup_file")\", \"checksum\": \"$checksum\", \"size\": $(stat -c%s "$volume_backup_file")}]" "$backup_path/backup-metadata.json" > "$temp_file" && mv "$temp_file" "$backup_path/backup-metadata.json"
                
                volume_list+=("$vol")
                print_success "Volume $vol backed up successfully"
            else
                print_error "Failed to backup volume: $volume_name"
                log_backup "ERROR" "Failed to backup volume $volume_name for container $container_name"
            fi
        else
            print_warning "Volume not found: $volume_name"
        fi
    done
    
    # Save container configuration
    if [ -f ".container-registry.json" ] && command -v jq &> /dev/null; then
        if jq -e ".\"$container_name\"" ".container-registry.json" > /dev/null 2>&1; then
            jq ".\"$container_name\"" ".container-registry.json" > "$backup_path/container-config.json"
            print_success "Container configuration saved"
        fi
    fi
    
    # Finalize metadata
    local total_size=$(du -sb "$backup_path" | cut -f1)
    local temp_file=$(mktemp)
    jq ".total_size = $total_size | .completed = \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\" | .status = \"completed\"" "$backup_path/backup-metadata.json" > "$temp_file" && mv "$temp_file" "$backup_path/backup-metadata.json"
    
    print_success "Full backup completed: $backup_path"
    print_status "Backup size: $(numfmt --to=iec $total_size)B"
    print_status "Volumes backed up: ${volume_list[*]}"
    
    log_backup "SUCCESS" "Full backup completed for $container_name: $backup_path ($(numfmt --to=iec $total_size)B)"
    
    # Upload to cloud if requested
    if [ "$cloud_upload" = "true" ]; then
        upload_to_cloud "$backup_path"
    fi
    
    # Apply retention policy
    apply_retention_policy "$container_name" "full"
    
    echo "$backup_path"
}

# Create incremental backup
create_incremental_backup() {
    local container_name="$1"
    local base_backup="$2"
    local backup_name="${3:-${container_name}_incremental_$(date +%Y%m%d_%H%M%S)}"
    local cloud_upload="${4:-false}"
    
    if [ -z "$container_name" ] || [ -z "$base_backup" ]; then
        print_error "Container name and base backup required"
        return 1
    fi
    
    if [ ! -d "$BACKUP_DIR/$base_backup" ]; then
        print_error "Base backup not found: $base_backup"
        return 1
    fi
    
    print_status "Creating incremental backup for container: $container_name"
    log_backup "INFO" "Starting incremental backup for $container_name (base: $base_backup)"
    
    local backup_path="$BACKUP_DIR/$backup_name"
    mkdir -p "$backup_path"
    
    # Create backup metadata
    cat > "$backup_path/backup-metadata.json" << EOF
{
    "container_name": "$container_name",
    "backup_name": "$backup_name",
    "backup_type": "incremental",
    "base_backup": "$base_backup",
    "created": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "compression": "$COMPRESSION",
    "encryption": $ENCRYPTION_ENABLED,
    "verification": $VERIFICATION_ENABLED,
    "volumes": []
}
EOF
    
    # Load base backup metadata
    local base_backup_path="$BACKUP_DIR/$base_backup"
    if [ ! -f "$base_backup_path/backup-metadata.json" ]; then
        print_error "Base backup metadata not found"
        return 1
    fi
    
    # Create incremental backups for each volume
    local volumes="config home wine projects logs"
    local volume_list=()
    
    for vol in $volumes; do
        local volume_name="${container_name}_${vol}"
        if docker volume ls | grep -q "$volume_name"; then
            print_status "Creating incremental backup for volume: $volume_name"
            
            # Get base backup file info
            local base_checksum=$(jq -r ".volumes[] | select(.name == \"$vol\") | .checksum" "$base_backup_path/backup-metadata.json")
            
            if [ "$base_checksum" != "null" ] && [ -n "$base_checksum" ]; then
                # Calculate current checksum
                local current_backup_file=$(mktemp)
                docker run --rm \
                    -v "$volume_name":/source:ro \
                    alpine sh -c "cd /source && tar -cf - ." > "$current_backup_file" 2>/dev/null
                
                local current_checksum=$(sha256sum "$current_backup_file" | cut -d' ' -f1)
                
                if [ "$current_checksum" != "$base_checksum" ]; then
                    # Volume has changed, create incremental backup
                    local volume_backup_file="$backup_path/${vol}.tar"
                    mv "$current_backup_file" "$volume_backup_file"
                    
                    # Apply compression
                    if [ "$COMPRESSION" = "gzip" ]; then
                        gzip "$volume_backup_file"
                        volume_backup_file="${volume_backup_file}.gz"
                    elif [ "$COMPRESSION" = "bzip2" ]; then
                        bzip2 "$volume_backup_file"
                        volume_backup_file="${volume_backup_file}.bz2"
                    elif [ "$COMPRESSION" = "xz" ]; then
                        xz "$volume_backup_file"
                        volume_backup_file="${volume_backup_file}.xz"
                    fi
                    
                    # Update metadata
                    local temp_file=$(mktemp)
                    jq ".volumes += [{\"name\": \"$vol\", \"volume_name\": \"$volume_name\", \"file\": \"$(basename "$volume_backup_file")\", \"checksum\": \"$current_checksum\", \"size\": $(stat -c%s "$volume_backup_file"), \"changed\": true}]" "$backup_path/backup-metadata.json" > "$temp_file" && mv "$temp_file" "$backup_path/backup-metadata.json"
                    
                    volume_list+=("$vol")
                    print_success "Volume $vol has changes, backed up"
                else
                    # Volume unchanged, reference base backup
                    rm -f "$current_backup_file"
                    local temp_file=$(mktemp)
                    jq ".volumes += [{\"name\": \"$vol\", \"volume_name\": \"$volume_name\", \"checksum\": \"$base_checksum\", \"changed\": false, \"reference\": \"$base_backup\"}]" "$backup_path/backup-metadata.json" > "$temp_file" && mv "$temp_file" "$backup_path/backup-metadata.json"
                    
                    print_status "Volume $vol unchanged, referencing base backup"
                fi
            else
                print_warning "Base backup checksum not found for volume $vol, creating full backup"
                # Fall back to full backup for this volume
                local volume_backup_file="$backup_path/${vol}.tar"
                
                if docker run --rm \
                    -v "$volume_name":/source:ro \
                    -v "$backup_path":/backup \
                    alpine sh -c "cd /source && tar -cf /backup/${vol}.tar ." 2>/dev/null; then
                    
                    # Apply compression and update metadata (similar to full backup)
                    if [ "$COMPRESSION" = "gzip" ]; then
                        gzip "$volume_backup_file"
                        volume_backup_file="${volume_backup_file}.gz"
                    fi
                    
                    local checksum=$(sha256sum "$volume_backup_file" | cut -d' ' -f1)
                    local temp_file=$(mktemp)
                    jq ".volumes += [{\"name\": \"$vol\", \"volume_name\": \"$volume_name\", \"file\": \"$(basename "$volume_backup_file")\", \"checksum\": \"$checksum\", \"size\": $(stat -c%s "$volume_backup_file"), \"changed\": true}]" "$backup_path/backup-metadata.json" > "$temp_file" && mv "$temp_file" "$backup_path/backup-metadata.json"
                    
                    volume_list+=("$vol")
                fi
            fi
        fi
    done
    
    # Finalize metadata
    local total_size=$(du -sb "$backup_path" | cut -f1)
    local temp_file=$(mktemp)
    jq ".total_size = $total_size | .completed = \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\" | .status = \"completed\"" "$backup_path/backup-metadata.json" > "$temp_file" && mv "$temp_file" "$backup_path/backup-metadata.json"
    
    if [ ${#volume_list[@]} -gt 0 ]; then
        print_success "Incremental backup completed: $backup_path"
        print_status "Backup size: $(numfmt --to=iec $total_size)B"
        print_status "Changed volumes: ${volume_list[*]}"
    else
        print_success "Incremental backup completed: No changes detected"
        print_status "Backup size: $(numfmt --to=iec $total_size)B"
    fi
    
    log_backup "SUCCESS" "Incremental backup completed for $container_name: $backup_path ($(numfmt --to=iec $total_size)B)"
    
    # Upload to cloud if requested
    if [ "$cloud_upload" = "true" ]; then
        upload_to_cloud "$backup_path"
    fi
    
    # Apply retention policy
    apply_retention_policy "$container_name" "incremental"
    
    echo "$backup_path"
}

# Upload backup to cloud storage
upload_to_cloud() {
    local backup_path="$1"
    
    if [ ! -d "$backup_path" ]; then
        print_error "Backup path not found: $backup_path"
        return 1
    fi
    
    if [ ! -f "$CLOUD_CONFIG_FILE" ]; then
        print_error "Cloud storage not configured"
        return 1
    fi
    
    # Load cloud configuration
    if command -v yq &> /dev/null; then
        local provider=$(yq eval '.cloud_storage.provider' "$CLOUD_CONFIG_FILE" 2>/dev/null || echo "")
        local enabled=$(yq eval '.cloud_storage.enabled' "$CLOUD_CONFIG_FILE" 2>/dev/null || echo "false")
        
        if [ "$enabled" != "true" ]; then
            print_warning "Cloud storage is disabled"
            return 1
        fi
        
        print_status "Uploading backup to cloud storage ($provider)..."
        
        case "$provider" in
            "s3")
                upload_to_s3 "$backup_path"
                ;;
            "gcs")
                upload_to_gcs "$backup_path"
                ;;
            "azure")
                upload_to_azure "$backup_path"
                ;;
            "ftp"|"sftp")
                upload_to_ftp "$backup_path" "$provider"
                ;;
            *)
                print_error "Unsupported cloud provider: $provider"
                return 1
                ;;
        esac
    else
        print_warning "yq not available, cannot parse cloud configuration"
        return 1
    fi
}

# Upload to AWS S3
upload_to_s3() {
    local backup_path="$1"
    local backup_name=$(basename "$backup_path")
    
    # Load S3 configuration
    local bucket=$(yq eval '.providers.s3.bucket' "$CLOUD_CONFIG_FILE")
    local region=$(yq eval '.providers.s3.region' "$CLOUD_CONFIG_FILE")
    local access_key=$(yq eval '.providers.s3.access_key' "$CLOUD_CONFIG_FILE")
    local secret_key=$(yq eval '.providers.s3.secret_key' "$CLOUD_CONFIG_FILE")
    
    if [ -z "$bucket" ] || [ "$bucket" = "null" ]; then
        print_error "S3 bucket not configured"
        return 1
    fi
    
    # Set AWS credentials
    export AWS_ACCESS_KEY_ID="$access_key"
    export AWS_SECRET_ACCESS_KEY="$secret_key"
    export AWS_DEFAULT_REGION="$region"
    
    # Create archive of backup
    local archive_path="$CLOUD_BACKUP_DIR/${backup_name}.tar.gz"
    mkdir -p "$CLOUD_BACKUP_DIR"
    
    print_status "Creating archive for cloud upload..."
    tar czf "$archive_path" -C "$(dirname "$backup_path")" "$(basename "$backup_path")"
    
    # Upload using AWS CLI or curl
    if command -v aws &> /dev/null; then
        print_status "Uploading to S3 using AWS CLI..."
        if aws s3 cp "$archive_path" "s3://$bucket/webtop-backups/$backup_name.tar.gz"; then
            print_success "Backup uploaded to S3: s3://$bucket/webtop-backups/$backup_name.tar.gz"
            log_backup "SUCCESS" "Backup uploaded to S3: $backup_name"
        else
            print_error "Failed to upload backup to S3"
            log_backup "ERROR" "Failed to upload backup to S3: $backup_name"
            return 1
        fi
    else
        print_warning "AWS CLI not available, cannot upload to S3"
        return 1
    fi
    
    # Clean up local archive
    rm -f "$archive_path"
    
    # Unset credentials
    unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_DEFAULT_REGION
}

# Upload to Google Cloud Storage
upload_to_gcs() {
    local backup_path="$1"
    local backup_name=$(basename "$backup_path")
    
    print_status "GCS upload not implemented yet"
    # TODO: Implement GCS upload
    return 1
}

# Upload to Azure Storage
upload_to_azure() {
    local backup_path="$1"
    local backup_name=$(basename "$backup_path")
    
    print_status "Azure upload not implemented yet"
    # TODO: Implement Azure upload
    return 1
}

# Upload via FTP/SFTP
upload_to_ftp() {
    local backup_path="$1"
    local protocol="$2"
    local backup_name=$(basename "$backup_path")
    
    print_status "$protocol upload not implemented yet"
    # TODO: Implement FTP/SFTP upload
    return 1
}

# Apply retention policy
apply_retention_policy() {
    local container_name="$1"
    local backup_type="$2"
    
    print_status "Applying retention policy for $backup_type backups of $container_name"
    
    # Load retention configuration
    local retention_count=7
    if command -v yq &> /dev/null && [ -f "$BACKUP_CONFIG_FILE" ]; then
        if [ "$backup_type" = "full" ]; then
            retention_count=$(yq eval '.retention.local.full_backups' "$BACKUP_CONFIG_FILE" 2>/dev/null || echo "7")
        else
            retention_count=$(yq eval '.retention.local.incremental_backups' "$BACKUP_CONFIG_FILE" 2>/dev/null || echo "30")
        fi
    fi
    
    # Find old backups to remove
    local backups_to_remove=()
    local backup_count=0
    
    # Sort backups by creation date (newest first)
    for backup_dir in $(ls -dt "$BACKUP_DIR"/${container_name}_${backup_type}_* 2>/dev/null); do
        ((backup_count++))
        if [ $backup_count -gt $retention_count ]; then
            backups_to_remove+=("$backup_dir")
        fi
    done
    
    # Remove old backups
    for backup_dir in "${backups_to_remove[@]}"; do
        if [ -d "$backup_dir" ]; then
            print_status "Removing old backup: $(basename "$backup_dir")"
            rm -rf "$backup_dir"
            log_backup "INFO" "Removed old backup: $(basename "$backup_dir")"
        fi
    done
    
    if [ ${#backups_to_remove[@]} -gt 0 ]; then
        print_success "Removed ${#backups_to_remove[@]} old backup(s)"
    else
        print_status "No old backups to remove"
    fi
}

# Restore from backup
restore_backup() {
    local container_name="$1"
    local backup_name="$2"
    local stop_container="${3:-true}"
    
    if [ -z "$container_name" ] || [ -z "$backup_name" ]; then
        print_error "Container name and backup name required"
        return 1
    fi
    
    local backup_path="$BACKUP_DIR/$backup_name"
    if [ ! -d "$backup_path" ]; then
        print_error "Backup not found: $backup_path"
        return 1
    fi
    
    if [ ! -f "$backup_path/backup-metadata.json" ]; then
        print_error "Backup metadata not found"
        return 1
    fi
    
    print_status "Restoring container: $container_name from backup: $backup_name"
    log_backup "INFO" "Starting restore for $container_name from backup $backup_name"
    
    # Stop container if requested
    if [ "$stop_container" = "true" ]; then
        local container_id="webtop-$container_name"
        if docker ps --format "{{.Names}}" | grep -q "^$container_id$"; then
            print_status "Stopping container: $container_id"
            docker stop "$container_id" 2>/dev/null || true
        fi
    fi
    
    # Load backup metadata
    local backup_type=$(jq -r '.backup_type' "$backup_path/backup-metadata.json")
    
    if [ "$backup_type" = "incremental" ]; then
        # Handle incremental restore
        restore_incremental_backup "$container_name" "$backup_name"
    else
        # Handle full restore
        restore_full_backup "$container_name" "$backup_name"
    fi
}

# Restore full backup
restore_full_backup() {
    local container_name="$1"
    local backup_name="$2"
    local backup_path="$BACKUP_DIR/$backup_name"
    
    print_status "Restoring full backup..."
    
    # Get volumes from metadata
    local volumes=$(jq -r '.volumes[].name' "$backup_path/backup-metadata.json")
    
    for vol in $volumes; do
        local volume_name="${container_name}_${vol}"
        local volume_file=$(jq -r ".volumes[] | select(.name == \"$vol\") | .file" "$backup_path/backup-metadata.json")
        local volume_path="$backup_path/$volume_file"
        
        if [ -f "$volume_path" ]; then
            print_status "Restoring volume: $volume_name"
            
            # Remove existing volume
            docker volume rm "$volume_name" 2>/dev/null || true
            docker volume create "$volume_name"
            
            # Determine decompression command
            local decompress_cmd="cat"
            if [[ "$volume_file" == *.gz ]]; then
                decompress_cmd="gunzip -c"
            elif [[ "$volume_file" == *.bz2 ]]; then
                decompress_cmd="bunzip2 -c"
            elif [[ "$volume_file" == *.xz ]]; then
                decompress_cmd="unxz -c"
            fi
            
            # Restore volume data
            if $decompress_cmd "$volume_path" | docker run --rm -i \
                -v "$volume_name":/target \
                -v "$backup_path":/backup:ro \
                alpine sh -c "cd /target && tar -xf -"; then
                
                print_success "Volume $vol restored successfully"
            else
                print_error "Failed to restore volume: $vol"
                log_backup "ERROR" "Failed to restore volume $vol for container $container_name"
            fi
        else
            print_warning "Volume file not found: $volume_path"
        fi
    done
    
    # Restore container configuration
    if [ -f "$backup_path/container-config.json" ]; then
        print_status "Restoring container configuration..."
        
        # Update container registry
        if [ -f ".container-registry.json" ]; then
            local temp_file=$(mktemp)
            jq ".\"$container_name\" = $(cat "$backup_path/container-config.json")" ".container-registry.json" > "$temp_file" && mv "$temp_file" ".container-registry.json"
            print_success "Container configuration restored"
        fi
    fi
    
    print_success "Full backup restore completed for container: $container_name"
    log_backup "SUCCESS" "Full backup restore completed for $container_name from $backup_name"
}

# Restore incremental backup
restore_incremental_backup() {
    local container_name="$1"
    local backup_name="$2"
    local backup_path="$BACKUP_DIR/$backup_name"
    
    print_status "Restoring incremental backup..."
    
    # Get base backup
    local base_backup=$(jq -r '.base_backup' "$backup_path/backup-metadata.json")
    if [ "$base_backup" = "null" ] || [ -z "$base_backup" ]; then
        print_error "Base backup not specified in incremental backup"
        return 1
    fi
    
    local base_backup_path="$BACKUP_DIR/$base_backup"
    if [ ! -d "$base_backup_path" ]; then
        print_error "Base backup not found: $base_backup_path"
        return 1
    fi
    
    print_status "Restoring base backup first: $base_backup"
    restore_full_backup "$container_name" "$base_backup"
    
    print_status "Applying incremental changes..."
    
    # Apply incremental changes
    local volumes=$(jq -r '.volumes[] | select(.changed == true) | .name' "$backup_path/backup-metadata.json")
    
    for vol in $volumes; do
        local volume_name="${container_name}_${vol}"
        local volume_file=$(jq -r ".volumes[] | select(.name == \"$vol\") | .file" "$backup_path/backup-metadata.json")
        local volume_path="$backup_path/$volume_file"
        
        if [ -f "$volume_path" ]; then
            print_status "Applying incremental changes to volume: $volume_name"
            
            # Determine decompression command
            local decompress_cmd="cat"
            if [[ "$volume_file" == *.gz ]]; then
                decompress_cmd="gunzip -c"
            elif [[ "$volume_file" == *.bz2 ]]; then
                decompress_cmd="bunzip2 -c"
            elif [[ "$volume_file" == *.xz ]]; then
                decompress_cmd="unxz -c"
            fi
            
            # Apply incremental changes
            if $decompress_cmd "$volume_path" | docker run --rm -i \
                -v "$volume_name":/target \
                alpine sh -c "cd /target && tar -xf -"; then
                
                print_success "Incremental changes applied to volume $vol"
            else
                print_error "Failed to apply incremental changes to volume: $vol"
                log_backup "ERROR" "Failed to apply incremental changes to volume $vol for container $container_name"
            fi
        fi
    done
    
    print_success "Incremental backup restore completed for container: $container_name"
    log_backup "SUCCESS" "Incremental backup restore completed for $container_name from $backup_name"
}

# List backups
list_backups() {
    local container_name="$1"
    local backup_type="$2"
    
    print_status "Available backups:"
    echo
    
    local pattern="*"
    if [ -n "$container_name" ]; then
        pattern="${container_name}_*"
    fi
    if [ -n "$backup_type" ]; then
        pattern="${pattern%_*}_${backup_type}_*"
    fi
    
    printf "%-30s %-15s %-20s %-10s %-15s\n" "BACKUP NAME" "TYPE" "CREATED" "SIZE" "CONTAINER"
    printf "%-30s %-15s %-20s %-10s %-15s\n" "-----------" "----" "-------" "----" "---------"
    
    for backup_dir in $(ls -dt "$BACKUP_DIR"/$pattern 2>/dev/null); do
        if [ -d "$backup_dir" ] && [ -f "$backup_dir/backup-metadata.json" ]; then
            local backup_name=$(basename "$backup_dir")
            local container=$(jq -r '.container_name' "$backup_dir/backup-metadata.json")
            local type=$(jq -r '.backup_type' "$backup_dir/backup-metadata.json")
            local created=$(jq -r '.created' "$backup_dir/backup-metadata.json" | cut -d'T' -f1)
            local size=$(jq -r '.total_size' "$backup_dir/backup-metadata.json")
            
            if [ "$size" != "null" ] && [ -n "$size" ]; then
                size=$(numfmt --to=iec "$size")
            else
                size=$(du -sh "$backup_dir" | cut -f1)
            fi
            
            printf "%-30s %-15s %-20s %-10s %-15s\n" "$backup_name" "$type" "$created" "$size" "$container"
        fi
    done
    echo
}

# Verify backup integrity
verify_backup() {
    local backup_name="$1"
    
    if [ -z "$backup_name" ]; then
        print_error "Backup name required"
        return 1
    fi
    
    local backup_path="$BACKUP_DIR/$backup_name"
    if [ ! -d "$backup_path" ] || [ ! -f "$backup_path/backup-metadata.json" ]; then
        print_error "Backup not found or invalid: $backup_name"
        return 1
    fi
    
    print_status "Verifying backup integrity: $backup_name"
    
    local verification_failed=0
    local volumes=$(jq -r '.volumes[].name' "$backup_path/backup-metadata.json")
    
    for vol in $volumes; do
        local volume_file=$(jq -r ".volumes[] | select(.name == \"$vol\") | .file" "$backup_path/backup-metadata.json")
        local expected_checksum=$(jq -r ".volumes[] | select(.name == \"$vol\") | .checksum" "$backup_path/backup-metadata.json")
        local volume_path="$backup_path/$volume_file"
        
        if [ -f "$volume_path" ] && [ "$expected_checksum" != "null" ] && [ -n "$expected_checksum" ]; then
            print_status "Verifying volume: $vol"
            
            local actual_checksum=$(sha256sum "$volume_path" | cut -d' ' -f1)
            
            if [ "$actual_checksum" = "$expected_checksum" ]; then
                print_success "Volume $vol checksum verified"
            else
                print_error "Volume $vol checksum mismatch"
                print_error "Expected: $expected_checksum"
                print_error "Actual:   $actual_checksum"
                ((verification_failed++))
            fi
        else
            print_warning "Cannot verify volume $vol (file or checksum missing)"
        fi
    done
    
    if [ $verification_failed -eq 0 ]; then
        print_success "Backup verification completed successfully"
        log_backup "SUCCESS" "Backup verification passed for $backup_name"
        return 0
    else
        print_error "Backup verification failed ($verification_failed errors)"
        log_backup "ERROR" "Backup verification failed for $backup_name ($verification_failed errors)"
        return 1
    fi
}

# Schedule backups
schedule_backup() {
    local action="$1"
    
    case "$action" in
        "enable")
            print_status "Enabling backup scheduling..."
            
            # Add cron jobs for scheduled backups
            local cron_full="0 2 * * 0 $(pwd)/scripts/cloud-backup.sh auto-full"
            local cron_incremental="0 3 * * 1-6 $(pwd)/scripts/cloud-backup.sh auto-incremental"
            
            # Check if cron jobs already exist
            if ! crontab -l 2>/dev/null | grep -q "cloud-backup.sh"; then
                (crontab -l 2>/dev/null; echo "$cron_full"; echo "$cron_incremental") | crontab -
                print_success "Backup scheduling enabled"
                log_backup "INFO" "Backup scheduling enabled"
            else
                print_warning "Backup scheduling already enabled"
            fi
            ;;
        "disable")
            print_status "Disabling backup scheduling..."
            
            # Remove cron jobs
            crontab -l 2>/dev/null | grep -v "cloud-backup.sh" | crontab -
            print_success "Backup scheduling disabled"
            log_backup "INFO" "Backup scheduling disabled"
            ;;
        "status")
            print_status "Backup scheduling status:"
            
            local cron_jobs=$(crontab -l 2>/dev/null | grep "cloud-backup.sh" || echo "")
            if [ -n "$cron_jobs" ]; then
                echo "$cron_jobs"
            else
                print_warning "No scheduled backups found"
            fi
            ;;
        *)
            print_error "Unknown scheduling action: $action"
            echo "Usage: $0 schedule {enable|disable|status}"
            return 1
            ;;
    esac
}

# Automatic backup (for scheduled execution)
auto_backup() {
    local backup_type="$1"
    
    print_status "Running automatic $backup_type backup..."
    log_backup "INFO" "Starting automatic $backup_type backup"
    
    # Get all containers
    local registry_file=".container-registry.json"
    if [ ! -f "$registry_file" ]; then
        print_warning "No container registry found"
        return 0
    fi
    
    local containers=$(jq -r 'keys[]' "$registry_file" 2>/dev/null)
    local backup_count=0
    local failed_count=0
    
    for container in $containers; do
        print_status "Processing container: $container"
        
        if [ "$backup_type" = "full" ]; then
            if create_full_backup "$container" "" "true"; then
                ((backup_count++))
            else
                ((failed_count++))
            fi
        else
            # Find most recent full backup for incremental
            local latest_full=$(ls -dt "$BACKUP_DIR"/${container}_full_* 2>/dev/null | head -1)
            if [ -n "$latest_full" ]; then
                local base_backup=$(basename "$latest_full")
                if create_incremental_backup "$container" "$base_backup" "" "true"; then
                    ((backup_count++))
                else
                    ((failed_count++))
                fi
            else
                print_warning "No full backup found for $container, creating full backup"
                if create_full_backup "$container" "" "true"; then
                    ((backup_count++))
                else
                    ((failed_count++))
                fi
            fi
        fi
    done
    
    print_success "Automatic backup completed: $backup_count successful, $failed_count failed"
    log_backup "SUCCESS" "Automatic $backup_type backup completed: $backup_count successful, $failed_count failed"
}

# Log backup activities
log_backup() {
    local level="$1"
    local message="$2"
    local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    
    echo "[$timestamp] [$level] $message" >> "$BACKUP_LOG_FILE"
}

# Main function
main() {
    case "$1" in
        init)
            init_backup_config
            ;;
        full)
            load_backup_config
            create_full_backup "$2" "$3" "$4"
            ;;
        incremental)
            load_backup_config
            create_incremental_backup "$2" "$3" "$4" "$5"
            ;;
        restore)
            load_backup_config
            restore_backup "$2" "$3" "$4"
            ;;
        list)
            list_backups "$2" "$3"
            ;;
        verify)
            verify_backup "$2"
            ;;
        upload)
            upload_to_cloud "$2"
            ;;
        schedule)
            schedule_backup "$2"
            ;;
        auto-full)
            load_backup_config
            auto_backup "full"
            ;;
        auto-incremental)
            load_backup_config
            auto_backup "incremental"
            ;;
        *)
            echo "Usage: $0 {init|full|incremental|restore|list|verify|upload|schedule|auto-full|auto-incremental} [options]"
            echo
            echo "Commands:"
            echo "  init                                    Initialize backup system configuration"
            echo "  full <container> [name] [cloud]        Create full backup"
            echo "  incremental <container> <base> [name] [cloud]  Create incremental backup"
            echo "  restore <container> <backup> [stop]    Restore from backup"
            echo "  list [container] [type]                 List available backups"
            echo "  verify <backup>                         Verify backup integrity"
            echo "  upload <backup_path>                    Upload backup to cloud storage"
            echo "  schedule {enable|disable|status}       Manage backup scheduling"
            echo "  auto-full                               Run automatic full backup (for cron)"
            echo "  auto-incremental                        Run automatic incremental backup (for cron)"
            exit 1
            ;;
    esac
}

# Install dependencies if missing
if ! command -v jq &> /dev/null; then
    print_warning "jq not found. JSON processing features may not work properly."
fi

if ! command -v yq &> /dev/null; then
    print_warning "yq not found. YAML processing features may not work properly."
fi

# Run main function
main "$@"