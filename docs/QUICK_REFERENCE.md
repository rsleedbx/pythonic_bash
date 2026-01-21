# Pythonic Bash Quick Reference

## One-Liner Setup

```bash
curl -o pythonic_bash.sh https://raw.githubusercontent.com/YOUR_USERNAME/pythonic_bash/main/pythonic_bash.sh
source pythonic_bash.sh
```

## Basic Usage

### Read JSON to Bash

```bash
declare -A config
json_to_associative_array config "credentials.json"
echo "${config[azure_storage_account]}"
```

### Write Bash to JSON

```bash
declare -A config
config[app]="myapp"
config[version]="1.0.0"
associative_array_to_json_file config "output.json"
```

### Nested Objects

```bash
# JSON: {"database": {"host": "localhost", "port": 5432}}
# Bash: Use "__" separator

config[database__host]="localhost"
config[database__port]="5432"
```

## Common Patterns

### Pattern 1: Azure Resource Setup

```bash
source pythonic_bash.sh

declare -A creds
json_to_associative_array creds "azure.json" || true

# Create resources
creds[storage_account]="myapp$(date +%s)"
creds[storage_key]=$(az storage account keys list ... | jq -r ...)

# Save back
associative_array_to_json_file creds "azure.json"
```

### Pattern 2: Configuration Inheritance

```bash
declare -A base env
json_to_associative_array base "base.json"
json_to_associative_array env "prod.json"

merge_associative_arrays base env
associative_array_to_json_file base "merged.json"
```

### Pattern 3: Validation

```bash
declare -A config
json_to_associative_array config "config.json"

validate_required_keys config \
  "database__host" \
  "database__port" \
  "api_key"
```

### Pattern 4: Python Interop

**Bash creates config:**
```bash
declare -A config
config[azure__account]="storage123"
associative_array_to_json_file config "shared.json"
```

**Python reads config:**
```python
import json
with open("shared.json") as f:
    config = json.load(f)
print(config["azure"]["account"])  # "storage123"
```

## API Reference

### Functions

| Function | Args | Description |
|----------|------|-------------|
| `json_to_associative_array` | `<array_name> <file>` | Read JSON/YAML to Bash array |
| `associative_array_to_json_file` | `<array_name> [file]` | Write Bash array to JSON |
| `associative_array_to_yaml_file` | `<array_name> <file>` | Write Bash array to YAML |
| `merge_associative_arrays` | `<dest> <src> [prefix]` | Merge two arrays |
| `validate_required_keys` | `<array> <keys...>` | Check required keys exist |
| `print_associative_array` | `<array_name>` | Debug print array |

### Key Separator

- Nested JSON: `{"parent": {"child": "value"}}`
- Bash key: `config[parent__child]="value"`
- Separator: `__` (double underscore)

## Troubleshooting

### Issue: "yq: command not found"

```bash
# macOS
brew install yq

# Linux
sudo snap install yq
```

### Issue: "declare: -A: invalid option"

```bash
# Need Bash 4.0+
bash --version
brew install bash  # macOS
```

### Issue: Special characters not working

```bash
# yq handles escaping automatically - should just work
# If not, check yq version (need 4.0+)
yq --version
```

## Performance

- **Read 100 keys:** ~50ms
- **Write 100 keys:** ~100ms
- **Good for:** CI/CD scripts, configuration management
- **Not for:** Tight loops, very large datasets (>100MB)

## Best Practices

✅ **DO:**
- Use for configuration files
- Share between Bash and Python/Node
- Version control the JSON/YAML files
- Use meaningful nested keys

❌ **DON'T:**
- Use in tight loops (parsing overhead)
- Store binary data
- Use for streaming data
- Use for very large datasets

## Examples Repository

All examples available at:
https://github.com/YOUR_USERNAME/pythonic_bash/tree/main/examples

- `example_usage.sh` - Complete Azure demo
- `interop_demo.py` - Python interoperability
- `test_pythonic_bash.sh` - 12 unit tests

## Support

- Issues: https://github.com/YOUR_USERNAME/pythonic_bash/issues
- Blog Post: [Your blog URL]
- License: MIT

---

**Quick Copy-Paste Snippets:**

```bash
# Setup
curl -sSL https://raw.githubusercontent.com/YOUR_USERNAME/pythonic_bash/main/pythonic_bash.sh | bash

# Read JSON
declare -A cfg; json_to_associative_array cfg "config.json"

# Write JSON
declare -A cfg; cfg[key]="val"; associative_array_to_json_file cfg "out.json"

# Merge configs
declare -A base prod; json_to_associative_array base "base.json"; json_to_associative_array prod "prod.json"; merge_associative_arrays base prod; associative_array_to_json_file base "merged.json"
```
