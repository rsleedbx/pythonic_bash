#!/usr/bin/env python3
"""
Python Interoperability Demo

This script demonstrates how Python and Bash can share the same JSON configuration file
without any translation layer. The Bash script (interop_demo.sh) creates the config,
and this Python script reads and updates it.
"""

import json
import sys
from datetime import datetime
from pathlib import Path


def main():
    config_file = Path("azure_credentials.json")
    
    print("=" * 60)
    print("Python Reading Configuration Created by Bash")
    print("=" * 60)
    print()
    
    if not config_file.exists():
        print("❌ Error: azure_credentials.json not found")
        print("   Run example_usage.sh first to create the configuration")
        return 1
    
    # Read configuration (same file bash wrote!)
    with open(config_file) as f:
        config = json.load(f)
    
    print("📖 Configuration loaded from Bash-created file:")
    print()
    
    # Access nested values naturally in Python
    if "azure" in config and "storage" in config["azure"]:
        print(f"  Storage Account: {config['azure']['storage']['account']}")
        print(f"  Storage Key: {config['azure']['storage']['key'][:20]}...")
        print(f"  Container: {config['azure']['storage']['container']}")
    
    print(f"  Created At: {config.get('created_at', 'N/A')}")
    print(f"  Created By: {config.get('created_by', 'N/A')}")
    print()
    
    # Python can read and process the data
    print("=" * 60)
    print("Python Processing Data")
    print("=" * 60)
    print()
    
    # Simulate using the configuration for Azure operations
    if "blob_url" in config:
        print(f"🔗 Would connect to: {config['blob_url']}")
        print(f"   Using account: {config.get('storage_account', 'N/A')}")
        print()
    
    # Python can also update the configuration
    print("=" * 60)
    print("Python Updating Configuration")
    print("=" * 60)
    print()
    
    # Add Python-specific metadata
    config["python_processed_at"] = datetime.now().isoformat()
    config["python_version"] = f"{sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}"
    
    # Add nested Python-specific config
    if "python" not in config:
        config["python"] = {}
    
    config["python"]["packages"] = {
        "azure-storage-blob": "12.19.0",
        "requests": "2.31.0"
    }
    
    config["python"]["features"] = {
        "async_enabled": True,
        "retry_count": 3,
        "timeout_seconds": 30
    }
    
    # Write back to JSON
    output_file = Path("azure_credentials.python.json")
    with open(output_file, 'w') as f:
        json.dump(config, f, indent=2)
    
    print(f"💾 Updated configuration saved to {output_file}")
    print()
    print("✅ Python processing complete!")
    print()
    
    # Show that Bash can now read Python's updates
    print("=" * 60)
    print("Bidirectional Updates")
    print("=" * 60)
    print()
    print("📝 Bash can now read Python's updates:")
    print(f"   config[python__version]=\"{config['python_version']}\"")
    print(f"   config[python__features__async_enabled]=\"{config['python']['features']['async_enabled']}\"")
    print(f"   config[python__packages__requests]=\"{config['python']['packages']['requests']}\"")
    print()
    print("🔄 This demonstrates true bidirectional configuration sharing!")
    print("   No translation layer, no duplication, just pure JSON.")
    
    return 0


if __name__ == "__main__":
    sys.exit(main())
