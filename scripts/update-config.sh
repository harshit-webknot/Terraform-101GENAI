#!/bin/bash

# Configuration Update Script
# This script helps update the config.yaml file with new values

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
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

# Function to update service replicas
update_replicas() {
    local service=$1
    local replicas=$2
    
    if [ -z "$service" ] || [ -z "$replicas" ]; then
        print_error "Usage: update_replicas <service> <replicas>"
        return 1
    fi
    
    print_status "Updating $service replicas to $replicas"
    
    # Use yq if available, otherwise use sed
    if command -v yq >/dev/null 2>&1; then
        yq eval ".services.$service.replicas = $replicas" -i config.yaml
    else
        # Fallback to sed (less reliable but works)
        sed -i "/^  $service:/,/^  [a-zA-Z]/ s/replicas: [0-9]*/replicas: $replicas/" config.yaml
    fi
    
    print_success "Updated $service replicas to $replicas"
}

# Function to update resource limits
update_resources() {
    local service=$1
    local cpu_request=$2
    local memory_request=$3
    local cpu_limit=$4
    local memory_limit=$5
    
    if [ -z "$service" ] || [ -z "$cpu_request" ] || [ -z "$memory_request" ] || [ -z "$cpu_limit" ] || [ -z "$memory_limit" ]; then
        print_error "Usage: update_resources <service> <cpu_request> <memory_request> <cpu_limit> <memory_limit>"
        return 1
    fi
    
    print_status "Updating $service resources"
    
    if command -v yq >/dev/null 2>&1; then
        yq eval ".services.$service.resources.requests.cpu = \"$cpu_request\"" -i config.yaml
        yq eval ".services.$service.resources.requests.memory = \"$memory_request\"" -i config.yaml
        yq eval ".services.$service.resources.limits.cpu = \"$cpu_limit\"" -i config.yaml
        yq eval ".services.$service.resources.limits.memory = \"$memory_limit\"" -i config.yaml
    else
        print_warning "yq not found. Please install yq for reliable YAML editing or edit config.yaml manually"
        return 1
    fi
    
    print_success "Updated $service resources"
}

# Function to scale cluster nodes
scale_nodes() {
    local node_count=$1
    
    if [ -z "$node_count" ]; then
        print_error "Usage: scale_nodes <node_count>"
        return 1
    fi
    
    print_status "Updating cluster node count to $node_count"
    
    if command -v yq >/dev/null 2>&1; then
        yq eval ".nodes.node_count = $node_count" -i config.yaml
    else
        sed -i "s/node_count: [0-9]*/node_count: $node_count/" config.yaml
    fi
    
    print_success "Updated cluster node count to $node_count"
}

# Function to change machine type
change_machine_type() {
    local machine_type=$1
    
    if [ -z "$machine_type" ]; then
        print_error "Usage: change_machine_type <machine_type>"
        return 1
    fi
    
    print_status "Updating machine type to $machine_type"
    
    if command -v yq >/dev/null 2>&1; then
        yq eval ".nodes.machine_type = \"$machine_type\"" -i config.yaml
    else
        sed -i "s/machine_type: \".*\"/machine_type: \"$machine_type\"/" config.yaml
    fi
    
    print_success "Updated machine type to $machine_type"
}

# Function to show current configuration
show_config() {
    print_status "Current configuration:"
    echo
    
    if [ -f "config.yaml" ]; then
        cat config.yaml
    else
        print_error "config.yaml not found"
        return 1
    fi
}

# Function to validate configuration
validate_config() {
    print_status "Validating configuration..."
    
    if [ ! -f "config.yaml" ]; then
        print_error "config.yaml not found"
        return 1
    fi
    
    # Check if yq is available for validation
    if command -v yq >/dev/null 2>&1; then
        if yq eval '.' config.yaml >/dev/null 2>&1; then
            print_success "Configuration is valid YAML"
        else
            print_error "Configuration contains invalid YAML"
            return 1
        fi
    else
        print_warning "yq not found. Cannot validate YAML syntax"
    fi
    
    # Basic validation checks
    local provider=$(grep "^provider:" config.yaml | awk '{print $2}' | tr -d '"')
    if [ "$provider" != "aws" ] && [ "$provider" != "gcp" ]; then
        print_error "Invalid provider: $provider. Must be 'aws' or 'gcp'"
        return 1
    fi
    
    print_success "Configuration validation completed"
}

# Function to backup configuration
backup_config() {
    local backup_name="config-backup-$(date +%Y%m%d-%H%M%S).yaml"
    
    if [ -f "config.yaml" ]; then
        cp config.yaml "$backup_name"
        print_success "Configuration backed up to $backup_name"
    else
        print_error "config.yaml not found"
        return 1
    fi
}

# Function to restore configuration
restore_config() {
    local backup_file=$1
    
    if [ -z "$backup_file" ]; then
        print_error "Usage: restore_config <backup_file>"
        return 1
    fi
    
    if [ -f "$backup_file" ]; then
        cp "$backup_file" config.yaml
        print_success "Configuration restored from $backup_file"
    else
        print_error "Backup file $backup_file not found"
        return 1
    fi
}

# Function to show help
show_help() {
    echo "Configuration Update Script"
    echo "=========================="
    echo
    echo "Usage: $0 <command> [arguments]"
    echo
    echo "Commands:"
    echo "  show                                    - Show current configuration"
    echo "  validate                               - Validate configuration"
    echo "  backup                                 - Backup current configuration"
    echo "  restore <backup_file>                  - Restore from backup"
    echo "  scale-nodes <count>                    - Update node count"
    echo "  change-machine-type <type>             - Change machine type"
    echo "  update-replicas <service> <count>      - Update service replicas"
    echo "  update-resources <service> <cpu_req> <mem_req> <cpu_lim> <mem_lim> - Update service resources"
    echo
    echo "Examples:"
    echo "  $0 scale-nodes 5"
    echo "  $0 update-replicas mongodb 5"
    echo "  $0 update-resources backend 1000m 2Gi 2000m 4Gi"
    echo "  $0 change-machine-type t3a.2xlarge"
    echo
}

# Main script logic
case "${1:-}" in
    "show")
        show_config
        ;;
    "validate")
        validate_config
        ;;
    "backup")
        backup_config
        ;;
    "restore")
        restore_config "$2"
        ;;
    "scale-nodes")
        scale_nodes "$2"
        ;;
    "change-machine-type")
        change_machine_type "$2"
        ;;
    "update-replicas")
        update_replicas "$2" "$3"
        ;;
    "update-resources")
        update_resources "$2" "$3" "$4" "$5" "$6"
        ;;
    "help"|"-h"|"--help")
        show_help
        ;;
    *)
        print_error "Unknown command: ${1:-}"
        echo
        show_help
        exit 1
        ;;
esac
