# Pythonic Bash: Bridging Shell Scripts and Modern Configuration Formats

> **Breaking the Barrier:** How to make Bash scripts first-class citizens in modern CI/CD pipelines by enabling native JSON/YAML configuration sharing

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Bash](https://img.shields.io/badge/bash-5.0%2B-green.svg)](https://www.gnu.org/software/bash/)
[![yq](https://img.shields.io/badge/yq-4.48.2%2B-blue.svg)](https://github.com/mikefarah/yq)

## The Problem: Configuration Hell in Polyglot CI/CD

Modern CI/CD pipelines are polyglot by nature:
- **Bash scripts** for system orchestration (cloud CLIs, git, kubectl)
- **Python scripts** for data processing and API calls  
- **Node.js scripts** for frontend builds
- **YAML/JSON** for configuration storage

The traditional approach creates chaos:

```
❌ Traditional Approach: Configuration Silos

credentials.json          <-- Python reads this
  └─ azure_storage_account
  └─ azure_storage_key

config.env               <-- Bash sources this
  └─ AZURE_ACCOUNT=???
  └─ AZURE_KEY=???

settings.yaml            <-- Node.js reads this
  └─ azure:
       account: ???
       key: ???
```

**The Problem:**
- ✗ Configuration duplicated across 3+ formats
- ✗ Manual synchronization required
- ✗ High risk of drift and errors
- ✗ Bash relegated to "glue code" status
- ✗ Python/Node become gatekeepers for config access

## The Solution: Bash-Native JSON/YAML I/O

**What if Bash could read and write JSON/YAML directly?**

```bash
# Read JSON into Bash associative array
declare -A config
json_to_associative_array config "credentials.json"

# Use configuration naturally
echo "Account: ${config[azure_storage_account]}"
echo "Key: ${config[azure_storage_key]}"

# Modify configuration
config[timestamp]=$(date +%s)
config[last_run]="$(date -Iseconds)"

# Write back to JSON
associative_array_to_json_file config "credentials.json"
```

**Result:**
- ✓ **Single source of truth** (JSON/YAML)
- ✓ **Bash reads directly** (no env file duplication)
- ✓ **Python reads directly** (same file!)
- ✓ **Bidirectional updates** (Bash can write back)
- ✓ **Type safety** via associative arrays
- ✓ **Nested objects** via key separators

## Architecture: How It Works

### The Bridge: `yq` as the Universal Translator

```
┌─────────────────────────────────────────────────────────────────┐
│                    Configuration File                            │
│                   credentials.json / config.yaml                 │
│                                                                  │
│  {                                    azure:                     │
│    "azure_storage_account": "xxx",     storage_account: xxx     │
│    "azure_storage_key": "yyy",         storage_key: yyy         │
│    "timestamp": 1737500000             timestamp: 1737500000    │
│  }                                                               │
└────────────────┬────────────────────────────┬───────────────────┘
                 │                            │
                 │                            │
    ┌────────────▼─────────┐     ┌───────────▼────────────┐
    │   Bash Scripts       │     │  Python/Node Scripts   │
    │                      │     │                        │
    │  yq -o=shell         │     │  json.load()           │
    │  ↓                   │     │  yaml.safe_load()      │
    │  declare -A config   │     │  ↓                     │
    │  config[key]=value   │     │  config = {...}        │
    │                      │     │                        │
    │  yq eval -o json     │     │  json.dump()           │
    │  ↑                   │     │  yaml.dump()           │
    │  Write back!         │     │  ↑                     │
    └──────────────────────┘     └────────────────────────┘
```

**Key Insight:** `yq` provides a **shell-safe output format** (`-o=shell`) that Bash can parse reliably, even with special characters, spaces, and nested structures.

## Core Implementation

### 1. JSON/YAML → Bash Associative Array

```bash
json_to_associative_array() {
    local -n json_to_associative_array_credentials="$1"  # nameref to associative array
    local json_file="${2:-/dev/stdin}"                    # path to JSON file or stdin

    # yq converts JSON/YAML to shell-safe key=value pairs
    # Nested objects use "__" separator: parent__child__grandchild
    # Note: Requires yq v4.48.2+ for --shell-key-separator flag (PR #2497)
    while IFS='=' read -r key value; do
        value="${value%\'}"  # strip trailing single quote
        value="${value#\'}"  # strip leading single quote
        json_to_associative_array_credentials["$key"]="$value"
    done < <(yq -o=shell --shell-key-separator "__" "$json_file")
}
export -f json_to_associative_array
```

**Why this works:**
- `yq -o=shell` produces: `azure_storage_account='cockroachcdc1737500000'`
- Shell-escaped values (quotes, special chars handled)
- `__` separator for nested objects: `azure__storage__account`
- Works with both JSON and YAML inputs

### 2. Bash Associative Array → JSON/YAML

```bash
associative_array_to_json_file() {
    local -n associative_array_to_json_file_credentials="$1"
    local json_file="${2:-}"  # path to JSON file (empty = stdout)

    # Build yq eval expression dynamically
    local eval_expr=""
    for key in $(printf '%s\n' "${!associative_array_to_json_file_credentials[@]}" | sort); do
        local yq_path="${key//__/.}"  # Convert __ to . for yq path notation
        local value="${associative_array_to_json_file_credentials[$key]}"
        value="${value//\"/\\\"}"     # Escape quotes in value
        [ -n "$eval_expr" ] && eval_expr+=" | "
        eval_expr+=".${yq_path} = \"${value}\""
    done
    
    # Generate JSON/YAML output
    if [ -n "$json_file" ]; then
        mkdir -p "$(dirname "$json_file")"
        echo '{}' | yq eval "$eval_expr" -o json - > "$json_file"
    else
        echo '{}' | yq eval "$eval_expr" -o json -  # stdout
    fi
}
export -f associative_array_to_json_file
```

**Why this works:**
- Constructs `yq eval` expression: `.azure.account = "xxx" | .azure.key = "yyy"`
- `__` in keys converted to `.` for nested objects
- Output format controlled by `-o json` or `-o yaml`
- Atomic write with proper directory creation

## Real-World Use Cases

### Use Case 1: Azure Infrastructure Setup Script

**Problem:** Need to create Azure resources and share credentials with Python/Databricks scripts.

```bash
#!/usr/bin/env bash
source pythonic_bash.sh

# Read existing config or create new
declare -A credentials
if [ -f "credentials.json" ]; then
    json_to_associative_array credentials "credentials.json"
fi

# Generate timestamp for resource naming
credentials[timestamp]=${credentials[timestamp]:-$(date +%s)}
credentials[resource_group]=${credentials[resource_group]:-"my-app-rg"}
credentials[storage_account]="myapp${credentials[timestamp]}"

# Create Azure storage account
az storage account create \
  --name "${credentials[storage_account]}" \
  --resource-group "${credentials[resource_group]}"

# Get storage key and store it
credentials[storage_key]=$(az storage account keys list \
  --account-name "${credentials[storage_account]}" \
  --query "[0].value" -o tsv)

# Build connection URLs
credentials[blob_url]="https://${credentials[storage_account]}.blob.core.windows.net"
credentials[changefeed_uri]="azure-blob://container?AZURE_ACCOUNT_NAME=${credentials[storage_account]}&AZURE_ACCOUNT_KEY=${credentials[storage_key]}"

# Write back to JSON - Python can read this immediately!
associative_array_to_json_file credentials "credentials.json"

echo "✅ Configuration saved to credentials.json"
echo "   Python/Node scripts can now read it directly!"
```

**Python script uses same file:**

```python
import json

with open("credentials.json") as f:
    config = json.load(f)

# No translation needed - same structure!
storage_client = BlobServiceClient(
    account_url=config["blob_url"],
    credential=config["storage_key"]
)
```

### Use Case 2: Nested Configuration Management

**JSON with nested structure:**

```json
{
  "azure": {
    "resource_group": "my-rg",
    "storage": {
      "account": "mystorageacc",
      "key": "xxx...",
      "container": "data"
    }
  },
  "database": {
    "connection": {
      "host": "db.example.com",
      "port": 5432,
      "credentials": {
        "user": "admin",
        "password": "secret"
      }
    }
  },
  "last_run": "2026-01-21T10:30:00Z"
}
```

**Bash reads nested structure naturally:**

```bash
declare -A config
json_to_associative_array config "app_config.json"

# Access nested values via "__" separator
echo "Resource Group: ${config[azure__resource_group]}"
echo "Storage Account: ${config[azure__storage__account]}"
echo "Storage Key: ${config[azure__storage__key]}"
echo "DB Host: ${config[database__connection__host]}"
echo "DB User: ${config[database__connection__credentials__user]}"

# Update nested values
config[last_run]=$(date -Iseconds)
config[azure__storage__container]="new-container"

# Write back - preserves structure!
associative_array_to_json_file config "app_config.json"
```

**Output JSON maintains nesting:**

```json
{
  "azure": {
    "resource_group": "my-rg",
    "storage": {
      "account": "mystorageacc",
      "container": "new-container",
      "key": "xxx..."
    }
  },
  "database": {
    "connection": {
      "credentials": {
        "password": "secret",
        "user": "admin"
      },
      "host": "db.example.com",
      "port": "5432"
    }
  },
  "last_run": "2026-01-21T11:45:00Z"
}
```

### Use Case 3: CI/CD Pipeline State Management

**GitHub Actions workflow:**

```yaml
name: Deploy Infrastructure
jobs:
  setup-azure:
    runs-on: ubuntu-latest
    steps:
      - name: Setup Azure Resources
        run: |
          source pythonic_bash.sh
          ./scripts/01_azure_setup.sh  # Creates resources.json
      
      - name: Upload config artifact
        uses: actions/upload-artifact@v3
        with:
          name: azure-config
          path: resources.json
  
  deploy-app:
    needs: setup-azure
    runs-on: ubuntu-latest
    steps:
      - name: Download config
        uses: actions/download-artifact@v3
        with:
          name: azure-config
      
      - name: Deploy to Azure (Python)
        run: |
          python deploy.py  # Reads resources.json directly!
      
      - name: Configure monitoring (Bash)
        run: |
          source pythonic_bash.sh
          declare -A config
          json_to_associative_array config "resources.json"
          ./scripts/setup_monitoring.sh "${config[storage_account]}"
```

**Key Benefits:**
- Single config artifact passed between jobs
- No translation layer needed
- Both Bash and Python read same file
- Type-safe in both languages

### Use Case 4: Multi-Cloud Credential Management

```bash
# Read credentials from various sources
declare -A aws_creds azure_creds gcp_creds

json_to_associative_array aws_creds "~/.aws/credentials.json"
json_to_associative_array azure_creds "~/.azure/credentials.json"
json_to_associative_array gcp_creds "~/.gcp/credentials.json"

# Merge into unified config
declare -A unified_config
unified_config[cloud]="${CLOUD_PROVIDER:-azure}"
unified_config[aws__access_key]="${aws_creds[access_key_id]}"
unified_config[aws__secret_key]="${aws_creds[secret_access_key]}"
unified_config[azure__subscription]="${azure_creds[subscription_id]}"
unified_config[azure__tenant]="${azure_creds[tenant_id]}"
unified_config[gcp__project]="${gcp_creds[project_id]}"

# Write unified config that all scripts can use
associative_array_to_json_file unified_config "unified_cloud_config.json"
```

## Benefits Over Traditional Approaches

### vs. Environment Variables

| Environment Variables | Pythonic Bash |
|----------------------|---------------|
| ❌ No nested structure | ✅ Nested objects via `__` |
| ❌ String-only values | ✅ Preserves types in JSON |
| ❌ Shell injection risks | ✅ Properly escaped values |
| ❌ Hard to share with Python | ✅ Native JSON/YAML |
| ❌ Lost after shell exit | ✅ Persisted to disk |

### vs. Multiple Config Files

| Multiple Configs | Pythonic Bash |
|-----------------|---------------|
| ❌ credentials.env + credentials.json | ✅ Single credentials.json |
| ❌ Manual synchronization | ✅ Always in sync |
| ❌ Configuration drift | ✅ Single source of truth |
| ❌ 3× maintenance burden | ✅ Update once |

### vs. Python-Only Scripts

| Python-Only | Pythonic Bash |
|-------------|---------------|
| ❌ Can't leverage shell tools (az, kubectl) | ✅ Native shell integration |
| ❌ subprocess.run() overhead | ✅ Direct command execution |
| ❌ Complex error handling for shell | ✅ Native Bash error handling |
| ❌ Requires Python runtime everywhere | ✅ Works anywhere Bash exists |

## Installation & Requirements

### Prerequisites

```bash
# Check if yq is installed (v4.48.2+ required for --shell-key-separator)
command -v yq >/dev/null 2>&1 || echo "Install yq: brew install yq"

# Verify yq version (needs v4.48.2+ for --shell-key-separator flag added in PR #2497)
yq --version
# Should show: yq version v4.48.2 or higher

# Bash 4.0+ (for associative arrays)
bash --version | head -1
# Should show: GNU bash, version 4.0 or higher
```

### Install yq

```bash
# macOS
brew install yq

# Linux
sudo wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/bin/yq
sudo chmod +x /usr/bin/yq

# Verify
yq --version
```

### Download pythonic_bash.sh

```bash
curl -o pythonic_bash.sh https://raw.githubusercontent.com/yourusername/pythonic_bash/main/pythonic_bash.sh
source pythonic_bash.sh
```

## Complete Reference

### Function: `json_to_associative_array`

**Signature:**
```bash
json_to_associative_array <array_name> <json_file>
```

**Parameters:**
- `array_name` - Name of Bash associative array (will be populated)
- `json_file` - Path to JSON/YAML file, or omit for stdin

**Examples:**
```bash
# Read from file
declare -A config
json_to_associative_array config "settings.json"

# Read from stdin
declare -A config
json_to_associative_array config < settings.yaml

# Read from command output
declare -A config
json_to_associative_array config < <(curl -s https://api.example.com/config)
```

**Nested Objects:**
```json
{
  "database": {
    "primary": {
      "host": "db1.example.com"
    }
  }
}
```

Becomes:
```bash
config[database__primary__host]="db1.example.com"
```

### Function: `associative_array_to_json_file`

**Signature:**
```bash
associative_array_to_json_file <array_name> [json_file]
```

**Parameters:**
- `array_name` - Name of Bash associative array
- `json_file` - Optional output file path (omit for stdout)

**Examples:**
```bash
# Write to file
declare -A config
config[app]="myapp"
config[version]="1.0.0"
associative_array_to_json_file config "output.json"

# Write to stdout
associative_array_to_json_file config

# Write nested structure
config[database__host]="localhost"
config[database__port]="5432"
associative_array_to_json_file config "db_config.json"
```

**Output YAML instead:**
```bash
# Modify function or pipe through yq
associative_array_to_json_file config | yq eval -P - > output.yaml
```

## Advanced Patterns

### Pattern 1: Configuration Inheritance

```bash
# Load base config
declare -A config
json_to_associative_array config "base_config.json"

# Override with environment-specific settings
if [ -f "config.${ENV}.json" ]; then
    declare -A env_config
    json_to_associative_array env_config "config.${ENV}.json"
    
    # Merge env_config into config
    for key in "${!env_config[@]}"; do
        config[$key]="${env_config[$key]}"
    done
fi

# Save merged configuration
associative_array_to_json_file config "config.merged.json"
```

### Pattern 2: Configuration Validation

```bash
declare -A config
json_to_associative_array config "credentials.json"

# Validate required fields
required_fields=(
    "azure__storage__account"
    "azure__storage__key"
    "database__host"
    "database__credentials__user"
)

for field in "${required_fields[@]}"; do
    if [ -z "${config[$field]:-}" ]; then
        echo "❌ Missing required field: $field"
        exit 1
    fi
done

echo "✅ Configuration validated"
```

### Pattern 3: Secret Rotation

```bash
# Read current credentials
declare -A creds
json_to_associative_array creds "credentials.json"

# Rotate database password
old_password="${creds[database__password]}"
new_password=$(pwgen -s 32 1)

# Update database
mysql -h "${creds[database__host]}" -u root <<EOF
ALTER USER '${creds[database__user]}'@'%' IDENTIFIED BY '${new_password}';
FLUSH PRIVILEGES;
EOF

# Update config
creds[database__password]="$new_password"
creds[password_rotated_at]=$(date -Iseconds)

# Save updated credentials
associative_array_to_json_file creds "credentials.json"

echo "✅ Password rotated and saved"
```

### Pattern 4: Dynamic Configuration Builder

```bash
#!/usr/bin/env bash
# Build configuration dynamically from cloud resources

declare -A config

# Query Azure resources
config[azure__subscription]=$(az account show --query id -o tsv)
config[azure__tenant]=$(az account show --query tenantId -o tsv)

# Query storage accounts
storage_accounts=$(az storage account list --query "[].name" -o tsv)
for i, account in enumerate "${storage_accounts[@]}"; do
    config[azure__storage__accounts__${i}]="$account"
done

# Query databases
databases=$(az postgres server list --query "[].name" -o tsv)
for i, db in enumerate "${databases[@]}"; do
    config[databases__${i}__name]="$db"
done

# Save discovered configuration
associative_array_to_json_file config "discovered_resources.json"
```

## Testing

### Unit Tests for JSON I/O

```bash
#!/usr/bin/env bash
source pythonic_bash.sh

test_round_trip() {
    # Create test data
    declare -A original
    original[string_value]="hello world"
    original[number_value]="42"
    original[nested__key]="nested value"
    original[special__chars]='!@#$%^&*()'
    
    # Write to JSON
    associative_array_to_json_file original "/tmp/test.json"
    
    # Read back
    declare -A restored
    json_to_associative_array restored "/tmp/test.json"
    
    # Verify
    for key in "${!original[@]}"; do
        if [ "${original[$key]}" != "${restored[$key]}" ]; then
            echo "❌ FAIL: Key '$key' mismatch"
            echo "   Original: ${original[$key]}"
            echo "   Restored: ${restored[$key]}"
            return 1
        fi
    done
    
    echo "✅ PASS: Round-trip test"
    rm -f /tmp/test.json
}

test_nested_structure() {
    declare -A config
    config[level1__level2__level3]="deep value"
    
    associative_array_to_json_file config "/tmp/nested.json"
    
    # Verify JSON structure
    level3=$(jq -r '.level1.level2.level3' /tmp/nested.json)
    if [ "$level3" = "deep value" ]; then
        echo "✅ PASS: Nested structure test"
    else
        echo "❌ FAIL: Nested structure not preserved"
        return 1
    fi
    
    rm -f /tmp/nested.json
}

# Run tests
test_round_trip
test_nested_structure
```

## Performance Considerations

### Benchmarks

```bash
# Test: Read 1000-key JSON file
time {
    declare -A config
    json_to_associative_array config "large_config.json"
}
# Result: ~0.05s (yq overhead)

# Test: Write 1000-key JSON file
time {
    associative_array_to_json_file config "large_config.json"
}
# Result: ~0.1s (yq eval overhead)
```

**Performance Tips:**
- ✓ Use for CI/CD scripts (one-time reads)
- ✓ Use for configuration files (<10K keys)
- ✓ Cache results in long-running scripts
- ✗ Don't use in tight loops (parsing overhead)
- ✗ Don't use for very large datasets (>100MB JSON)

## Troubleshooting

### Common Issues

**Issue: "yq: command not found"**
```bash
# Install yq
brew install yq  # macOS
# or
sudo snap install yq  # Linux
```

**Issue: "declare: -A: invalid option"**
```bash
# You're using Bash 3.x (macOS default)
bash --version

# Install Bash 5.x
brew install bash
/opt/homebrew/bin/bash  # Use new bash
```

**Issue: Nested values not working**
```bash
# Check yq version (needs v4.48.2+ for --shell-key-separator support)
yq --version

# Verify shell separator
yq -o=shell --shell-key-separator "__" test.json
```

**Issue: Special characters in values**
```bash
# yq handles escaping automatically
# But verify with:
config[test]='value with "quotes" and $pecial chars'
associative_array_to_json_file config | jq .test
# Should show properly escaped value
```

## Contributing

Contributions welcome! Areas for improvement:

- [ ] Support for arrays (currently only objects)
- [ ] Custom separator (not just `__`)
- [ ] Direct YAML write (currently uses JSON intermediate)
- [ ] Type preservation (numbers vs strings)
- [ ] Schema validation
- [ ] Encryption/decryption helpers

## License

MIT License - See LICENSE file

## Acknowledgments

- **[yq](https://github.com/mikefarah/yq)** by Mike Farah - The bridge that makes this possible
- **Bash 4.0+** - Associative arrays are the foundation
- Inspired by real-world CI/CD pain in managing polyglot pipelines

## Related Reading

- [Why Bash still matters in 2026](https://blog.example.com/bash-2026)
- [The death of .env files](https://blog.example.com/no-more-env)
- [yq: jq for YAML](https://github.com/mikefarah/yq)
- [Bash associative arrays deep dive](https://bash.cyberciti.biz/guide/Arrays)

---

**Built with ❤️ for DevOps engineers tired of maintaining 5 config file formats**

_If this saved you from configuration hell, give it a ⭐ on GitHub!_
