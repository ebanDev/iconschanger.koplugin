#!/usr/bin/env python3
"""
Custom Icon Pack Validator for KOReader IconsChanger Plugin

This script validates custom icon pack configurations to ensure:
1. JSON files are properly formatted
2. Local icon files exist
3. Icon mappings are valid
4. Directory structure is correct

Usage: python3 validate_icon_pack.py [pack_name]
"""

import json
import os
import sys
from pathlib import Path

def validate_pack(pack_name):
    """Validate a specific icon pack"""
    print(f"Validating icon pack: {pack_name}")
    print("=" * 50)
    
    # Check if pack JSON exists
    pack_file = f"iconpacks/{pack_name}.json"
    if not os.path.exists(pack_file):
        print(f"❌ Pack file not found: {pack_file}")
        return False
    
    try:
        with open(pack_file, 'r') as f:
            pack_data = json.load(f)
    except json.JSONDecodeError as e:
        print(f"❌ Invalid JSON in {pack_file}: {e}")
        return False
    
    print(f"✅ {pack_file} is valid JSON")
    
    local_icons = 0
    iconify_icons = 0
    missing_files = []
    
    for icon_name, icon_value in pack_data.items():
        if icon_value.startswith("local:"):
            local_icons += 1
            # Check if local file exists
            local_path = icon_value[6:]  # Remove "local:" prefix
            full_path = f"icons/{local_path}"
            
            if not os.path.exists(full_path):
                missing_files.append(full_path)
            elif not full_path.endswith('.svg'):
                print(f"⚠️  Local icon should be SVG: {full_path}")
        else:
            iconify_icons += 1
            # Basic validation for iconify format
            if '-' not in icon_value:
                print(f"⚠️  Iconify icon may have invalid format: {icon_value}")
    
    print(f"📊 Icon Statistics:")
    print(f"   Local icons: {local_icons}")
    print(f"   Iconify icons: {iconify_icons}")
    print(f"   Total mappings: {len(pack_data)}")
    
    if missing_files:
        print(f"❌ Missing local icon files:")
        for file in missing_files:
            print(f"   - {file}")
        return False
    else:
        print(f"✅ All local icon files exist")
    
    return True

def validate_all_packs():
    """Validate all packs listed in config.json"""
    if not os.path.exists("config.json"):
        print("❌ config.json not found")
        return False
    
    try:
        with open("config.json", 'r') as f:
            config = json.load(f)
    except json.JSONDecodeError as e:
        print(f"❌ Invalid JSON in config.json: {e}")
        return False
    
    print("✅ config.json is valid JSON")
    print(f"📦 Found {len(config)} icon packs")
    print()
    
    all_valid = True
    for pack in config:
        if 'path' not in pack or 'display_name' not in pack:
            print(f"❌ Invalid pack configuration: {pack}")
            all_valid = False
            continue
        
        pack_path = pack['path']
        if pack_path.startswith('iconpacks/') and pack_path.endswith('.json'):
            pack_name = pack_path[10:-5]  # Remove 'iconpacks/' and '.json'
            if not validate_pack(pack_name):
                all_valid = False
        else:
            print(f"❌ Invalid pack path format: {pack_path}")
            all_valid = False
        print()
    
    return all_valid

def main():
    if not os.path.exists("iconpacks") or not os.path.exists("config.json"):
        print("❌ Please run this script from the plugin root directory")
        print("   (should contain 'iconpacks/' and 'config.json')")
        sys.exit(1)
    
    if len(sys.argv) > 1:
        # Validate specific pack
        pack_name = sys.argv[1]
        if validate_pack(pack_name):
            print(f"✅ Pack '{pack_name}' is valid!")
        else:
            print(f"❌ Pack '{pack_name}' has errors!")
            sys.exit(1)
    else:
        # Validate all packs
        print("Validating all icon packs...")
        print("=" * 50)
        if validate_all_packs():
            print("✅ All icon packs are valid!")
        else:
            print("❌ Some icon packs have errors!")
            sys.exit(1)

if __name__ == "__main__":
    main()