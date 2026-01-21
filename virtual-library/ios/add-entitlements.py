#!/usr/bin/env python3
"""Add entitlements file to Xcode project and configure Sign in with Apple"""
import re
import uuid

def generate_xcode_id():
    return uuid.uuid4().hex[:24].upper()

pbxproj_path = "/Users/marco.jimenez/Documents/Projects/Library/virtual-library/ios/VirtualLibrary.xcodeproj/project.pbxproj"

with open(pbxproj_path, 'r') as f:
    content = f.read()

# Generate UUID for entitlements file
file_ref_id = generate_xcode_id()

print("Adding VirtualLibrary.entitlements to project...")

# Add to PBXFileReference section
file_ref_entry = f"\t\t{file_ref_id} /* VirtualLibrary.entitlements */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.entitlements; path = VirtualLibrary.entitlements; sourceTree = \"<group>\"; }};\n"
content = re.sub(
    r'(/\* Begin PBXFileReference section \*/\n)',
    r'\1' + file_ref_entry,
    content
)

# Add to VirtualLibraryApp group (main app group)
group_entry = f"\t\t\t\t{file_ref_id} /* VirtualLibrary.entitlements */,\n"
content = re.sub(
    r'(6B2B3C4D5E6F7A8B9C0D1E3F /\* VirtualLibraryApp \*/ = \{[\s\S]*?children = \([\s\S]*?)(1A2B3C4D5E6F7A8B9C0D1E3F /\* VirtualLibraryApp\.swift \*/,)',
    r'\1' + group_entry + r'\2',
    content
)

# Add CODE_SIGN_ENTITLEMENTS to build settings
# Find the Debug configuration
debug_pattern = r'(name = Debug;[\s\S]*?buildSettings = \{)'
content = re.sub(
    debug_pattern,
    r'\1\n\t\t\t\tCODE_SIGN_ENTITLEMENTS = VirtualLibraryApp/VirtualLibrary.entitlements;',
    content,
    count=1
)

# Find the Release configuration
release_pattern = r'(name = Release;[\s\S]*?buildSettings = \{)'
content = re.sub(
    release_pattern,
    r'\1\n\t\t\t\tCODE_SIGN_ENTITLEMENTS = VirtualLibraryApp/VirtualLibrary.entitlements;',
    content,
    count=1
)

with open(pbxproj_path, 'w') as f:
    f.write(content)

print(f"✅ Entitlements file added with ID: {file_ref_id}")
print("✅ CODE_SIGN_ENTITLEMENTS configured for Debug and Release")
print("\n⚠️  IMPORTANT: In Xcode, you MUST:")
print("1. Select the project in navigator")
print("2. Select VirtualLibrary target")
print("3. Go to 'Signing & Capabilities' tab")
print("4. Click '+ Capability' button")
print("5. Add 'Sign in with Apple'")
print("6. Ensure your team is selected under 'Signing'")
print("7. Clean and rebuild")
