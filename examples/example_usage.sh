#!/usr/bin/env bash
#
# Example: Using pythonic_bash for Azure resource management
#

set -e

# Load pythonic_bash library
source pythonic_bash.sh

echo "================================================"
echo "Example 1: Create Azure Resources"
echo "================================================"
echo ""

# Initialize or load existing configuration
declare -A credentials

if [ -f "azure_credentials.json" ]; then
    echo "📖 Loading existing configuration..."
    json_to_associative_array credentials "azure_credentials.json"
else
    echo "🆕 Creating new configuration..."
fi

# Set/update configuration values
credentials[timestamp]=${credentials[timestamp]:-$(date +%s)}
credentials[resource_group]=${credentials[resource_group]:-"pythonic-bash-demo-rg"}
credentials[storage_account]="pythonicbash${credentials[timestamp]}"
credentials[container]="demo-container"
credentials[location]="East US"

echo "📝 Configuration:"
echo "   Resource Group: ${credentials[resource_group]}"
echo "   Storage Account: ${credentials[storage_account]}"
echo "   Container: ${credentials[container]}"
echo ""

# Simulate Azure CLI calls (uncomment to actually create resources)
# az group create --name "${credentials[resource_group]}" --location "${credentials[location]}"
# az storage account create --name "${credentials[storage_account]}" --resource-group "${credentials[resource_group]}"

# Simulate getting storage key
credentials[storage_key]="SIMULATED_KEY_$(pwgen -s 64 1 2>/dev/null || echo 'xxxxxxxxxxxxx')"

# Build connection URLs
credentials[blob_url]="https://${credentials[storage_account]}.blob.core.windows.net"
credentials[connection_string]="DefaultEndpointsProtocol=https;AccountName=${credentials[storage_account]};AccountKey=${credentials[storage_key]};EndpointSuffix=core.windows.net"

# Add nested configuration
credentials[azure__subscription]="00000000-0000-0000-0000-000000000000"
credentials[azure__tenant]="11111111-1111-1111-1111-111111111111"
credentials[azure__storage__account]="${credentials[storage_account]}"
credentials[azure__storage__key]="${credentials[storage_key]}"
credentials[azure__storage__container]="${credentials[container]}"

# Add metadata
credentials[created_at]=$(date -Iseconds)
credentials[created_by]="${USER}"

# Write to JSON file
echo "💾 Saving configuration to azure_credentials.json..."
associative_array_to_json_file credentials "azure_credentials.json"

echo "✅ Configuration saved!"
echo ""

# Verify by reading back
echo "================================================"
echo "Example 2: Verify Configuration"
echo "================================================"
echo ""

declare -A verified
json_to_associative_array verified "azure_credentials.json"

echo "📖 Read back from JSON:"
echo "   Storage Account: ${verified[azure__storage__account]}"
echo "   Container: ${verified[azure__storage__container]}"
echo "   Created At: ${verified[created_at]}"
echo "   Created By: ${verified[created_by]}"
echo ""

# Show nested structure
echo "================================================"
echo "Example 3: Pretty Print"
echo "================================================"
echo ""
print_associative_array verified

# Validate required fields
echo ""
echo "================================================"
echo "Example 4: Validation"
echo "================================================"
echo ""

if validate_required_keys verified "azure__storage__account" "azure__storage__key" "azure__storage__container"; then
    echo "✅ All required fields present"
else
    echo "❌ Validation failed"
fi

echo ""
echo "================================================"
echo "Example 5: Configuration Merging"
echo "================================================"
echo ""

# Create environment-specific overrides
declare -A prod_overrides
prod_overrides[environment]="production"
prod_overrides[azure__storage__container]="prod-data"
prod_overrides[logging__level]="INFO"

# Merge overrides
merge_associative_arrays verified prod_overrides

echo "🔄 After merging production overrides:"
echo "   Environment: ${verified[environment]}"
echo "   Container: ${verified[azure__storage__container]}"
echo "   Logging Level: ${verified[logging__level]}"

# Save merged configuration
associative_array_to_json_file verified "azure_credentials.prod.json"
echo "💾 Saved to azure_credentials.prod.json"

echo ""
echo "================================================"
echo "Example 6: Generate YAML"
echo "================================================"
echo ""

associative_array_to_yaml_file verified "azure_credentials.yaml"
echo "💾 Saved to azure_credentials.yaml"
echo ""
echo "📄 YAML content:"
cat azure_credentials.yaml

echo ""
echo "✅ All examples complete!"
echo ""
echo "📚 Files created:"
echo "   - azure_credentials.json (original)"
echo "   - azure_credentials.prod.json (with overrides)"
echo "   - azure_credentials.yaml (YAML format)"
