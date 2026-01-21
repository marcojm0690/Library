#!/usr/bin/env python3
"""Add CreateLibraryView and CreateLibraryViewModel to Xcode project"""
import re
import uuid

def generate_xcode_id():
    return uuid.uuid4().hex[:24].upper()

pbxproj_path = "/Users/marco.jimenez/Documents/Projects/Library/virtual-library/ios/VirtualLibrary.xcodeproj/project.pbxproj"

with open(pbxproj_path, 'r') as f:
    content = f.read()

files = [
    {
        'name': 'CreateLibraryView.swift',
        'group': 'Views',
        'group_id': '8B2B3C4D5E6F7A8B9C0D1E3F',
        'insert_after': '3DADE27A121746F885AA2B10 /\\* LibrariesListView\\.swift \\*/,'
    },
    {
        'name': 'CreateLibraryViewModel.swift',
        'group': 'ViewModels', 
        'group_id': '0C2B3C4D5E6F7A8B9C0D1E3F',
        'insert_after': '4BBAC38D7436436692BAA2E9 /\\* LibrariesListViewModel\\.swift \\*/,'
    }
]

for file_info in files:
    file_ref_id = generate_xcode_id()
    build_file_id = generate_xcode_id()
    file_name = file_info['name']
    
    print(f"Adding {file_name}...")
    
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
    
    # Add to PBXSourcesBuildPhase
    sources_entry = f"\t\t\t\t{build_file_id} /* {file_name} in Sources */,\n"
    content = re.sub(
        r'(/\* Begin PBXSourcesBuildPhase section \*/.*?files = \(\n)',
        r'\1' + sources_entry,
        content,
        flags=re.DOTALL
    )
    
    # Add to the appropriate group
    group_entry = f"\t\t\t\t{file_ref_id} /* {file_name} */,\n"
    content = re.sub(
        rf'({file_info["insert_after"]})',
        r'\1\n' + group_entry,
        content
    )
    
    print(f"  ✅ FileRef: {file_ref_id}, BuildFile: {build_file_id}")

with open(pbxproj_path, 'w') as f:
    f.write(content)

print("\n✅ Done! CreateLibraryView and CreateLibraryViewModel added to project.")
