#!/usr/bin/env python3
"""
Script to properly add authentication files to Xcode project
"""
import re
import uuid

def generate_xcode_id():
    """Generate a 24-character hex ID for Xcode"""
    return uuid.uuid4().hex[:24].upper()

def add_file_to_pbxproj(pbxproj_path, file_path, file_name, group_name):
    """Add a Swift file to the Xcode project"""
    
    with open(pbxproj_path, 'r') as f:
        content = f.read()
    
    # Generate UUIDs
    file_ref_id = generate_xcode_id()
    build_file_id = generate_xcode_id()
    
    # Add to PBXBuildFile section
    build_file_entry = f"\t\t{build_file_id} /* {file_name} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_ref_id} /* {file_name} */; }};\n"
    content = re.sub(
        r'(/\* Begin PBXBuildFile section \*/\n)',
        r'\1' + build_file_entry,
        content
    )
    
    # Add to PBXFileReference section
    file_ref_entry = f"\t\t{file_ref_id} /* {file_name} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {file_name}; sourceTree = \"<group>\"; }};\n"
    content = re.sub(
        r'(/\* Begin PBXFileReference section \*/\n)',
        r'\1' + file_ref_entry,
        content
    )
    
    # Add to PBXSourcesBuildPhase (Sources)
    sources_entry = f"\t\t\t\t{build_file_id} /* {file_name} in Sources */,\n"
    content = re.sub(
        r'(/\* Begin PBXSourcesBuildPhase section \*/.*?files = \(\n)',
        r'\1' + sources_entry,
        content,
        flags=re.DOTALL
    )
    
    # Add to the appropriate group (Views, Services, or ViewModels)
    # Find the group and add the file reference
    group_pattern = rf'(/\* {group_name} \*/.*?children = \(\n)'
    group_entry = f"\t\t\t\t{file_ref_id} /* {file_name} */,\n"
    content = re.sub(
        group_pattern,
        r'\1' + group_entry,
        content,
        flags=re.DOTALL
    )
    
    with open(pbxproj_path, 'w') as f:
        f.write(content)
    
    return file_ref_id, build_file_id

def main():
    pbxproj = "/Users/marco.jimenez/Documents/Projects/Library/virtual-library/ios/VirtualLibrary.xcodeproj/project.pbxproj"
    
    files = [
        ("VirtualLibraryApp/Services/AuthenticationService.swift", "AuthenticationService.swift", "Services"),
        ("VirtualLibraryApp/Views/LoginView.swift", "LoginView.swift", "Views"),
        ("VirtualLibraryApp/Views/LibrariesListView.swift", "LibrariesListView.swift", "Views"),
        ("VirtualLibraryApp/ViewModels/LibrariesListViewModel.swift", "LibrariesListViewModel.swift", "ViewModels"),
    ]
    
    print("Adding authentication files to Xcode project...")
    
    for file_path, file_name, group in files:
        try:
            file_ref, build_file = add_file_to_pbxproj(pbxproj, file_path, file_name, group)
            print(f"✅ Added {file_name} to {group}")
            print(f"   FileRef: {file_ref}, BuildFile: {build_file}")
        except Exception as e:
            print(f"❌ Error adding {file_name}: {e}")
    
    print("\n✅ Done! Close and reopen Xcode, then clean build folder.")

if __name__ == "__main__":
    main()
