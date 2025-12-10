#!/usr/bin/env python3
"""
Arcular+ Version Manager
Automatically manages version numbers for APK builds
"""

import re
import sys
from datetime import datetime

def read_current_version():
    """Read current version from pubspec.yaml"""
    try:
        with open('pubspec.yaml', 'r', encoding='utf-8') as file:
            content = file.read()
            match = re.search(r'version:\s*(\d+\.\d+\.\d+)\+(\d+)', content)
            if match:
                return match.group(1), int(match.group(2))
    except FileNotFoundError:
        print("❌ pubspec.yaml not found!")
        return None, None
    return None, None

def update_version(version_type='patch', description=''):
    """Update version in pubspec.yaml"""
    try:
        with open('pubspec.yaml', 'r', encoding='utf-8') as file:
            content = file.read()
        
        # Find current version
        match = re.search(r'version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)', content)
        if not match:
            print("❌ Could not find version in pubspec.yaml")
            return False
        
        major, minor, patch, build = map(int, match.groups())
        
        # Update version based on type
        if version_type == 'major':
            major += 1
            minor = 0
            patch = 0
        elif version_type == 'minor':
            minor += 1
            patch = 0
        elif version_type == 'patch':
            patch += 1
        else:
            print("❌ Invalid version type. Use: major, minor, or patch")
            return False
        
        # Increment build number
        build += 1
        
        # Create new version string
        new_version = f"{major}.{minor}.{patch}+{build}"
        
        # Update version in content
        content = re.sub(r'version:\s*\d+\.\d+\.\d+\+\d+', f'version: {new_version}', content)
        
        # Add version history entry
        timestamp = datetime.now().strftime("%Y-%m-%d")
        history_entry = f"# {new_version} - {description} ({timestamp})"
        
        # Find version history section and add entry
        if '# Version History:' in content:
            # Add new entry after version history comment
            content = content.replace('# Version History:', f'# Version History:\n# {history_entry}')
        else:
            # Add version history section after version line
            content = re.sub(r'(version:\s*\d+\.\d+\.\d+\+\d+)', 
                           f'\\1\n\n# Version History:\n# {history_entry}', content)
        
        # Write updated content
        with open('pubspec.yaml', 'w', encoding='utf-8') as file:
            file.write(content)
        
        print(f"✅ Version updated to {new_version}")
        print(f"📝 Description: {description}")
        return True
        
    except Exception as e:
        print(f"❌ Error updating version: {e}")
        return False

def show_current_version():
    """Display current version information"""
    version, build = read_current_version()
    if version and build:
        print(f"📱 Current Version: {version}+{build}")
        print(f"🔢 Build Number: {build}")
        
        # Show version meaning
        major, minor, patch = map(int, version.split('.'))
        print(f"📊 Version Breakdown:")
        print(f"   Major: {major} (API breaking changes)")
        print(f"   Minor: {minor} (new features)")
        print(f"   Patch: {patch} (bug fixes)")
        print(f"   Build: {build} (build number)")
    else:
        print("❌ Could not read current version")

def show_help():
    """Display help information"""
    print("🚀 Arcular+ Version Manager")
    print("=" * 40)
    print("Usage:")
    print("  python version_manager.py [command] [description]")
    print("\nCommands:")
    print("  current              - Show current version")
    print("  major [description]  - Increment major version (breaking changes)")
    print("  minor [description]  - Increment minor version (new features)")
    print("  patch [description]  - Increment patch version (bug fixes)")
    print("  help                 - Show this help")
    print("\nExamples:")
    print("  python version_manager.py current")
    print("  python version_manager.py patch 'Fixed login issue'")
    print("  python version_manager.py minor 'Added new nurse features'")
    print("  python version_manager.py major 'Complete UI redesign'")

def main():
    if len(sys.argv) < 2:
        show_help()
        return
    
    command = sys.argv[1].lower()
    
    if command == 'current':
        show_current_version()
    elif command == 'help':
        show_help()
    elif command in ['major', 'minor', 'patch']:
        description = ' '.join(sys.argv[2:]) if len(sys.argv) > 2 else f'{command.capitalize()} update'
        if update_version(command, description):
            print(f"\n🎉 Ready to build APK with new version!")
            print("💡 Run: flutter build apk --release")
    else:
        print(f"❌ Unknown command: {command}")
        show_help()

if __name__ == "__main__":
    main() 